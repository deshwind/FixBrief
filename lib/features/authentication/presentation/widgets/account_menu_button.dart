import 'dart:async';

import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            if (action == _AccountAction.signOut) {
              unawaited(_signOut(context, ref));
            }
          },
          itemBuilder: (context) => [
            if (email != null)
              PopupMenuItem<_AccountAction>(
                enabled: false,
                child: Text(email, overflow: TextOverflow.ellipsis),
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

enum _AccountAction { signOut }
