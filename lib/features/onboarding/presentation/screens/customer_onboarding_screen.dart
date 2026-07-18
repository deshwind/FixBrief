import 'dart:async';

import 'package:fixbrief/core/validation/input_validators.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_text_field.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:fixbrief/features/onboarding/domain/entities/customer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/entities/profile_media.dart';
import 'package:fixbrief/features/onboarding/presentation/widgets/profile_media_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerOnboardingScreen extends ConsumerStatefulWidget {
  const CustomerOnboardingScreen({super.key});

  @override
  ConsumerState<CustomerOnboardingScreen> createState() =>
      _CustomerOnboardingScreenState();
}

class _CustomerOnboardingScreenState
    extends ConsumerState<CustomerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  var _contactMethod = PreferredContactMethod.inApp;
  var _pushNotifications = true;
  var _emailNotifications = true;
  ProfileMedia? _profileImage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    return AuthShell(
      showBack: false,
      maxWidth: 680,
      title: 'Complete your customer profile',
      subtitle:
          'We use an approximate area for matching. Your exact repair location is collected only when a request needs it.',
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
            ProfileMediaPicker(
              label: 'Profile image (optional)',
              media: _profileImage,
              onSelected: (media) => setState(() => _profileImage = media),
            ),
            const SizedBox(height: 16),
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
              controller: _phoneController,
              label: 'Phone number',
              hintText: '+44 7700 900000',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: InputValidators.phone,
            ),
            const SizedBox(height: 14),
            LiquidGlassTextField(
              controller: _locationController,
              label: 'Town, city, or postcode area',
              prefixIcon: Icons.location_on_outlined,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.addressCity],
              validator: (value) =>
                  InputValidators.requiredText(value, label: 'Location'),
            ),
            const SizedBox(height: 22),
            Text(
              'Preferred contact method',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            SegmentedButton<PreferredContactMethod>(
              segments: const [
                ButtonSegment(
                  value: PreferredContactMethod.inApp,
                  label: Text('In app'),
                  icon: Icon(Icons.chat_bubble_outline),
                ),
                ButtonSegment(
                  value: PreferredContactMethod.email,
                  label: Text('Email'),
                  icon: Icon(Icons.mail_outline),
                ),
                ButtonSegment(
                  value: PreferredContactMethod.phone,
                  label: Text('Phone'),
                  icon: Icon(Icons.phone_outlined),
                ),
              ],
              selected: {_contactMethod},
              onSelectionChanged: (selection) {
                setState(() => _contactMethod = selection.first);
              },
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Push notifications'),
              subtitle: const Text('Quotes, messages, and appointment updates'),
              value: _pushNotifications,
              onChanged: (value) {
                setState(() => _pushNotifications = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Email notifications'),
              subtitle: const Text('Important account and repair updates'),
              value: _emailNotifications,
              onChanged: (value) {
                setState(() => _emailNotifications = value);
              },
            ),
            const SizedBox(height: 18),
            LiquidGlassButton(
              label: 'Finish customer setup',
              icon: Icons.check_circle_outline_rounded,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting ? null : () => unawaited(_submit()),
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
    await ref
        .read(authSessionControllerProvider.notifier)
        .completeCustomerOnboarding(
          CustomerOnboardingData(
            fullName: _nameController.text,
            phoneNumber: _phoneController.text,
            location: _locationController.text,
            preferredContactMethod: _contactMethod,
            pushNotifications: _pushNotifications,
            emailNotifications: _emailNotifications,
            profileImage: _profileImage,
          ),
        );
  }
}
