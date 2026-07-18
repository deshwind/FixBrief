import 'package:fixbrief/features/onboarding/domain/entities/profile_media.dart';

class RepairerOnboardingData {
  const RepairerOnboardingData({
    required this.fullName,
    required this.businessName,
    required this.phoneNumber,
    required this.email,
    required this.businessDescription,
    required this.yearsExperience,
    required this.repairCategories,
    required this.specialisations,
    required this.qualifications,
    required this.certifications,
    required this.inspectionFeeMinor,
    required this.serviceRadiusKilometres,
    required this.address,
    required this.workingHours,
    required this.emergencyServiceAvailable,
    required this.mobileRepairAvailable,
    required this.collectionServiceAvailable,
    this.businessLogo,
  });

  final String fullName;
  final String businessName;
  final String phoneNumber;
  final String email;
  final String businessDescription;
  final int yearsExperience;
  final List<String> repairCategories;
  final List<String> specialisations;
  final List<String> qualifications;
  final List<String> certifications;
  final int inspectionFeeMinor;
  final double serviceRadiusKilometres;
  final String address;
  final String workingHours;
  final bool emergencyServiceAvailable;
  final bool mobileRepairAvailable;
  final bool collectionServiceAvailable;
  final ProfileMedia? businessLogo;
}
