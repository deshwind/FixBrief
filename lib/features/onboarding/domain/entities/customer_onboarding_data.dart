import 'package:fixbrief/features/onboarding/domain/entities/profile_media.dart';

enum PreferredContactMethod { inApp, email, phone }

class CustomerOnboardingData {
  const CustomerOnboardingData({
    required this.fullName,
    required this.phoneNumber,
    required this.location,
    required this.preferredContactMethod,
    required this.pushNotifications,
    required this.emailNotifications,
    this.profileImage,
  });

  final String fullName;
  final String phoneNumber;
  final String location;
  final PreferredContactMethod preferredContactMethod;
  final bool pushNotifications;
  final bool emailNotifications;
  final ProfileMedia? profileImage;
}
