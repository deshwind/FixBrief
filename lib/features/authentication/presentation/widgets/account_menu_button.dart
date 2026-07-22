import 'dart:async';

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authSessionControllerProvider).user?.email;
    return SizedBox.square(
      dimension: 48,
      child: LiquidGlassContainer(
        radius: 16,
        showShadow: false,
        child: PopupMenuButton<_AccountAction>(
          tooltip: 'Account menu',
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (action) {
            switch (action) {
              case _AccountAction.profile:
                unawaited(context.push(AppPaths.profile));
                return;
              case _AccountAction.notifications:
                unawaited(context.push(AppPaths.notifications));
                return;
              case _AccountAction.settings:
                unawaited(context.push(AppPaths.settings));
                return;
              case _AccountAction.signOut:
                unawaited(_signOut(context, ref));
                return;
            }
          },
          itemBuilder: (context) => [
            if (email != null)
              PopupMenuItem<_AccountAction>(
                enabled: false,
                child: Text(email, overflow: TextOverflow.ellipsis),
              ),
            const PopupMenuItem<_AccountAction>(
              value: _AccountAction.profile,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline_rounded),
                title: Text('Profile'),
              ),
            ),
            const PopupMenuItem<_AccountAction>(
              value: _AccountAction.notifications,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.notifications_outlined),
                title: Text('Notifications'),
              ),
            ),
            const PopupMenuItem<_AccountAction>(
              value: _AccountAction.settings,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.settings_outlined),
                title: Text('Settings'),
              ),
            ),
            const PopupMenuItem<_AccountAction>(
              value: _AccountAction.signOut,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded),
                title: Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authSessionControllerProvider.notifier).signOut();
    if (!context.mounted) {
      return;
    }
    final error = ref.read(authSessionControllerProvider).errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

enum _AccountAction { profile, notifications, settings, signOut }
