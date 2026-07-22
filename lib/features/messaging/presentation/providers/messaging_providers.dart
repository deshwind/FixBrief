import 'dart:async';

import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/messaging/data/repositories/demo_messaging_repository.dart';
import 'package:fixbrief/features/messaging/data/repositories/supabase_messaging_repository.dart';
import 'package:fixbrief/features/messaging/domain/entities/messaging_models.dart';
import 'package:fixbrief/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final MessagingRepository repository;
  if (environment.useDemoAuthentication) {
    final auth = ref.watch(authSessionControllerProvider);
    repository = DemoMessagingRepository(
      auth.user?.id ?? 'demo-user',
      auth.onboarding.role ?? UserRole.customer,
    );
  } else {
    repository = SupabaseMessagingRepository(ref.watch(supabaseClientProvider));
  }
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final conversationsProvider = StreamProvider<List<ConversationSummary>>((ref) {
  return ref.watch(messagingRepositoryProvider).watchConversations();
});

final conversationProvider = FutureProvider.autoDispose
    .family<ConversationSummary?, String>((ref, conversationId) {
      return ref
          .watch(messagingRepositoryProvider)
          .loadConversation(conversationId);
    });

final conversationMessagesProvider = StreamProvider.autoDispose
    .family<List<RepairMessage>, String>((ref, conversationId) {
      return ref
          .watch(messagingRepositoryProvider)
          .watchMessages(conversationId);
    });

final conversationAppointmentsProvider = StreamProvider.autoDispose
    .family<List<RepairAppointment>, String>((ref, conversationId) {
      return ref
          .watch(messagingRepositoryProvider)
          .watchAppointments(conversationId);
    });

final counterpartTypingProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, conversationId) {
      return ref
          .watch(messagingRepositoryProvider)
          .watchCounterpartTyping(conversationId);
    });
