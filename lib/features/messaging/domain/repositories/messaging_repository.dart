import 'package:fixbrief/features/messaging/domain/entities/messaging_models.dart';

abstract interface class MessagingRepository {
  Stream<List<ConversationSummary>> watchConversations();

  Future<ConversationSummary?> loadConversation(String conversationId);

  Stream<List<RepairMessage>> watchMessages(String conversationId);

  Stream<List<RepairAppointment>> watchAppointments(String conversationId);

  Future<RepairMessage> sendText(String conversationId, String body);

  Future<RepairMessage> sendAttachment(
    String conversationId,
    MessageAttachmentDraft attachment, {
    String? caption,
  });

  Future<void> markRead(String conversationId);

  Future<RepairAppointment> proposeAppointment({
    required String conversationId,
    required AppointmentKind kind,
    required DateTime startsAt,
    required DateTime endsAt,
    required String timezone,
  });

  Future<RepairAppointment> respondToAppointment({
    required String appointmentId,
    required AppointmentStatus status,
    String? message,
    bool releaseCustomerLocation = false,
  });

  Future<void> setBlocked(
    String conversationId, {
    required bool blocked,
    String? reason,
  });

  Future<String> reportUser(
    String conversationId, {
    required ReportReason reason,
    String? details,
  });

  Stream<bool> watchCounterpartTyping(String conversationId);

  Future<void> setTyping(String conversationId, {required bool typing});

  Future<void> dispose();
}
