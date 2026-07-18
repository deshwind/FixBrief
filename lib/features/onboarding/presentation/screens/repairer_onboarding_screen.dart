import 'dart:async';

import 'package:fixbrief/core/validation/input_validators.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_chip.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_text_field.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:fixbrief/features/onboarding/domain/entities/profile_media.dart';
import 'package:fixbrief/features/onboarding/domain/entities/repairer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/presentation/widgets/profile_media_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RepairerOnboardingScreen extends ConsumerStatefulWidget {
  const RepairerOnboardingScreen({super.key});

  @override
  ConsumerState<RepairerOnboardingScreen> createState() =>
      _RepairerOnboardingScreenState();
}

class _RepairerOnboardingScreenState
    extends ConsumerState<RepairerOnboardingScreen> {
  static const _categories = [
    'Cars',
    'Motorcycles',
    'Plumbing',
    'Electrical',
    'Washing machines',
    'Refrigerators',
    'Cookers and ovens',
    'Dishwashers',
    'Air conditioning',
    'Heating',
    'Computers',
    'Laptops',
    'Phones',
    'Tablets',
    'Bicycles',
    'Furniture',
    'Property damage',
    'Roofing',
    'Doors and windows',
    'Garden equipment',
    'Power tools',
    'Industrial equipment',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specialisationsController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _inspectionFeeController = TextEditingController();
  final _radiusController = TextEditingController(text: '15');
  final _addressController = TextEditingController();
  final _workingHoursController = TextEditingController();
  final Set<String> _selectedCategories = {};
  ProfileMedia? _businessLogo;
  var _emergencyService = false;
  var _mobileRepair = false;
  var _collectionService = false;

  @override
  void initState() {
    super.initState();
    _emailController.text =
        ref.read(authSessionControllerProvider).user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _experienceController.dispose();
    _specialisationsController.dispose();
    _qualificationsController.dispose();
    _certificationsController.dispose();
    _inspectionFeeController.dispose();
    _radiusController.dispose();
    _addressController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    return AuthShell(
      showBack: false,
      maxWidth: 760,
      title: 'Build your repair business profile',
      subtitle:
          'Customers will see clear business information. Qualifications and certifications remain unverified until reviewed.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFeedback(
              error: state.errorMessage,
              notice: state.noticeMessage,
            ),
            if (state.errorMessage != null || state.noticeMessage != null)
              const SizedBox(height: 18),
            _SectionTitle('Business identity'),
            const SizedBox(height: 12),
            ProfileMediaPicker(
              label: 'Business logo (optional)',
              media: _businessLogo,
              onSelected: (media) => setState(() => _businessLogo = media),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _nameController,
              label: 'Full name',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (value) =>
                  InputValidators.requiredText(value, label: 'Full name'),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _businessNameController,
              label: 'Business name',
              prefixIcon: Icons.storefront_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  InputValidators.requiredText(value, label: 'Business name'),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _phoneController,
              label: 'Business phone number',
              hintText: '+44 7700 900000',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: InputValidators.phone,
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _emailController,
              label: 'Business email',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: InputValidators.email,
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _descriptionController,
              label: 'Business description',
              hintText: 'Describe the work you do and the customers you serve.',
              prefixIcon: Icons.description_outlined,
              maxLines: 4,
              maxLength: 1000,
              validator: (value) => InputValidators.requiredText(
                value,
                label: 'Business description',
              ),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _experienceController,
              label: 'Years of experience',
              prefixIcon: Icons.workspace_premium_outlined,
              keyboardType: TextInputType.number,
              validator: (value) => InputValidators.nonNegativeNumber(
                value,
                label: 'years of experience',
              ),
            ),
            const SizedBox(height: 26),
            _SectionTitle('Repair categories'),
            const SizedBox(height: 6),
            const Text('Choose every category you currently service.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in _categories)
                  LiquidGlassChip(
                    label: category,
                    selected: _selectedCategories.contains(category),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LiquidGlassTextField(
              controller: _specialisationsController,
              label: 'Specialisations',
              hintText: 'Steering, suspension, vehicle diagnostics',
              prefixIcon: Icons.tune_rounded,
              maxLines: 2,
              validator: (value) => InputValidators.requiredText(
                value,
                label: 'At least one specialisation',
              ),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _qualificationsController,
              label: 'Qualifications',
              hintText: 'Separate multiple entries with commas',
              prefixIcon: Icons.school_outlined,
              maxLines: 2,
              validator: (value) =>
                  InputValidators.requiredText(value, label: 'Qualifications'),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _certificationsController,
              label: 'Certifications',
              hintText: 'Separate multiple entries with commas',
              prefixIcon: Icons.verified_outlined,
              maxLines: 2,
              validator: (value) =>
                  InputValidators.requiredText(value, label: 'Certifications'),
            ),
            const SizedBox(height: 26),
            _SectionTitle('Service and availability'),
            const SizedBox(height: 12),
            LiquidGlassTextField(
              controller: _inspectionFeeController,
              label: 'Inspection fee (£)',
              hintText: '45.00',
              prefixIcon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => InputValidators.nonNegativeNumber(
                value,
                label: 'inspection fee',
              ),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _radiusController,
              label: 'Service radius (km)',
              prefixIcon: Icons.radar_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => InputValidators.nonNegativeNumber(
                value,
                label: 'service radius',
              ),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _addressController,
              label: 'Business address',
              prefixIcon: Icons.location_on_outlined,
              autofillHints: const [AutofillHints.fullStreetAddress],
              maxLines: 2,
              validator: (value) => InputValidators.requiredText(
                value,
                label: 'Business address',
              ),
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _workingHoursController,
              label: 'Working hours',
              hintText: 'Mon–Fri 08:00–17:30, Sat 09:00–13:00',
              prefixIcon: Icons.schedule_outlined,
              maxLines: 2,
              validator: (value) =>
                  InputValidators.requiredText(value, label: 'Working hours'),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Emergency service available'),
              value: _emergencyService,
              onChanged: (value) => setState(() => _emergencyService = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mobile repair available'),
              value: _mobileRepair,
              onChanged: (value) => setState(() => _mobileRepair = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Collection service available'),
              value: _collectionService,
              onChanged: (value) => setState(() => _collectionService = value),
            ),
            const SizedBox(height: 20),
            LiquidGlassButton(
              label: 'Submit business profile',
              icon: Icons.send_rounded,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting ? null : () => unawaited(_submit()),
            ),
            const SizedBox(height: 12),
            const Text(
              'Submitting does not mark qualifications or the business as verified. Verification is a separate review.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one repair category.')),
      );
      return;
    }
    final fee = double.parse(_inspectionFeeController.text.trim());
    await ref
        .read(authSessionControllerProvider.notifier)
        .submitRepairerOnboarding(
          RepairerOnboardingData(
            fullName: _nameController.text,
            businessName: _businessNameController.text,
            phoneNumber: _phoneController.text,
            email: _emailController.text,
            businessDescription: _descriptionController.text,
            yearsExperience: int.parse(_experienceController.text.trim()),
            repairCategories: _selectedCategories.toList(growable: false),
            specialisations: _splitEntries(_specialisationsController.text),
            qualifications: _splitEntries(_qualificationsController.text),
            certifications: _splitEntries(_certificationsController.text),
            inspectionFeeMinor: (fee * 100).round(),
            serviceRadiusKilometres: double.parse(
              _radiusController.text.trim(),
            ),
            address: _addressController.text,
            workingHours: _workingHoursController.text,
            emergencyServiceAvailable: _emergencyService,
            mobileRepairAvailable: _mobileRepair,
            collectionServiceAvailable: _collectionService,
            businessLogo: _businessLogo,
          ),
        );
  }

  static List<String> _splitEntries(String value) {
    return value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}
