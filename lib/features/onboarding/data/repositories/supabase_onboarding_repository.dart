import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/onboarding/domain/entities/customer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:fixbrief/features/onboarding/domain/entities/profile_media.dart';
import 'package:fixbrief/features/onboarding/domain/entities/repairer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/errors/onboarding_failure.dart';
import 'package:fixbrief/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OnboardingProgress> claimRole({
    required String userId,
    required UserRole role,
  }) async {
    try {
      await _client.rpc<void>(
        'claim_role',
        params: <String, Object?>{'selected_role': role.databaseValue},
      );
      return fetchProgress(userId: userId);
    } on PostgrestException catch (error) {
      throw _mapFailure(error, action: 'select your account type');
    }
  }

  @override
  Future<OnboardingProgress> completeCustomerOnboarding({
    required String userId,
    required CustomerOnboardingData data,
  }) async {
    try {
      final avatarPath = await _uploadProfileMedia(
        userId: userId,
        bucket: 'profile-images',
        folder: 'avatars',
        media: data.profileImage,
      );
      await _client.rpc<void>(
        'complete_customer_onboarding',
        params: <String, Object?>{
          'profile_data': <String, Object?>{
            'full_name': data.fullName.trim(),
            'phone_number': data.phoneNumber.trim(),
            'location': data.location.trim(),
            'preferred_contact': switch (data.preferredContactMethod) {
              PreferredContactMethod.inApp => 'in_app',
              PreferredContactMethod.email => 'email',
              PreferredContactMethod.phone => 'phone',
            },
            'push_notifications': data.pushNotifications,
            'email_notifications': data.emailNotifications,
            'avatar_path': avatarPath,
          },
        },
      );
      return fetchProgress(userId: userId);
    } on PostgrestException catch (error) {
      throw _mapFailure(error, action: 'save your customer profile');
    } on StorageException catch (error) {
      throw OnboardingFailure(
        'Your profile details are safe, but the image could not be uploaded. Try another image.',
        code: error.statusCode,
      );
    }
  }

  @override
  Future<OnboardingProgress> fetchProgress({required String userId}) async {
    try {
      final row = await _client
          .from('profiles')
          .select('role, onboarding_status')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        return const OnboardingProgress.notStarted();
      }
      final roleValue = row['role'] as String?;
      return OnboardingProgress(
        role: roleValue == null ? null : UserRole.fromDatabase(roleValue),
        status: OnboardingStatus.fromDatabase(
          row['onboarding_status'] as String?,
        ),
      );
    } on PostgrestException catch (error) {
      throw _mapFailure(error, action: 'load your profile');
    }
  }

  @override
  Future<OnboardingProgress> submitRepairerOnboarding({
    required String userId,
    required RepairerOnboardingData data,
  }) async {
    try {
      final logoPath = await _uploadProfileMedia(
        userId: userId,
        bucket: 'business-logos',
        folder: 'business-logos',
        media: data.businessLogo,
      );
      await _client.rpc<void>(
        'submit_repairer_onboarding',
        params: <String, Object?>{
          'profile_data': <String, Object?>{
            'full_name': data.fullName.trim(),
            'business_name': data.businessName.trim(),
            'phone_number': data.phoneNumber.trim(),
            'email': data.email.trim().toLowerCase(),
            'business_description': data.businessDescription.trim(),
            'years_experience': data.yearsExperience,
            'repair_categories': data.repairCategories,
            'specialisations': data.specialisations,
            'qualifications': data.qualifications,
            'certifications': data.certifications,
            'inspection_fee_minor': data.inspectionFeeMinor,
            'service_radius_kilometres': data.serviceRadiusKilometres,
            'address': data.address.trim(),
            'working_hours': data.workingHours.trim(),
            'emergency_service_available': data.emergencyServiceAvailable,
            'mobile_repair_available': data.mobileRepairAvailable,
            'collection_service_available': data.collectionServiceAvailable,
            'business_logo_path': logoPath,
          },
        },
      );
      return fetchProgress(userId: userId);
    } on PostgrestException catch (error) {
      throw _mapFailure(error, action: 'submit your business profile');
    } on StorageException catch (error) {
      throw OnboardingFailure(
        'Your business details are safe, but the logo could not be uploaded. Try another image.',
        code: error.statusCode,
      );
    }
  }

  Future<String?> _uploadProfileMedia({
    required String userId,
    required String bucket,
    required String folder,
    required ProfileMedia? media,
  }) async {
    if (media == null) {
      return null;
    }
    final extension = media.fileName.contains('.')
        ? media.fileName.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(extension)
        ? extension
        : 'jpg';
    final objectPath = '$userId/$folder/profile.$safeExtension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          objectPath,
          media.bytes,
          fileOptions: FileOptions(contentType: media.mimeType, upsert: true),
        );
    return objectPath;
  }

  static OnboardingFailure _mapFailure(
    PostgrestException error, {
    required String action,
  }) {
    final setupMissing = error.code == '42P01' || error.code == 'PGRST202';
    return OnboardingFailure(
      setupMissing
          ? 'Account setup is not available in this environment yet.'
          : 'We could not $action. Check your connection and try again.',
      code: error.code,
    );
  }
}
