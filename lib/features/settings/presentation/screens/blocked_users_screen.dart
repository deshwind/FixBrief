import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:fixbrief/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked users'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FluidBackground(
        child: users.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error is SettingsFailure
                    ? error.message
                    : 'Blocked users could not be loaded.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (items) => items.isEmpty
              ? const Center(child: Text('You have not blocked anyone.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) => _BlockedUserCard(
                    user: items[index],
                    onUnblock: () => _unblock(context, ref, items[index]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    BlockedUser user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock ${user.displayName}?'),
        content: const Text(
          'They may be able to message you again when marketplace contact rules allow it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(settingsRepositoryProvider).unblockUser(user.userId);
      ref.invalidate(blockedUsersProvider);
    } on SettingsFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _BlockedUserCard extends StatelessWidget {
  const _BlockedUserCard({required this.user, required this.onUnblock});

  final BlockedUser user;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person_off_outlined)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Blocked ${DateFormat('d MMM y').format(user.blockedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onUnblock, child: const Text('Unblock')),
        ],
      ),
    );
  }
}
