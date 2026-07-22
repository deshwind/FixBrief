import 'dart:typed_data';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/messaging/data/repositories/demo_messaging_repository.dart';
import 'package:fixbrief/features/messaging/domain/entities/messaging_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stage 9 messaging repository', () {
    late DemoMessagingRepository repository;

    setUp(() {
      repository = DemoMessagingRepository('customer-user', UserRole.customer);
    });

    tearDown(() => repository.dispose());

    test('streams authorized conversations and sends text', () async {
      final conversations = await repository.watchConversations().first;
      expect(conversations, hasLength(1));
      expect(conversations.single.counterpartName, 'Northside Auto Care');

      final conversationId = conversations.single.id;
      final nextMessages = repository
          .watchMessages(conversationId)
          .skip(1)
          .first;
      final sent = await repository.sendText(
        conversationId,
        'Could we arrange an inspection?',
      );

      expect(sent.isMine, isTrue);
      expect(sent.body, 'Could we arrange an inspection?');
      expect((await nextMessages).last.id, sent.id);
    });

    test('uploads attachment metadata with the private path shape', () async {
      final conversation = (await repository.watchConversations().first).single;
      final sent = await repository.sendAttachment(
        conversation.id,
        MessageAttachmentDraft(
          name: 'warning-light.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          type: RepairMessageType.image,
        ),
      );

      expect(sent.type, RepairMessageType.image);
      expect(sent.attachmentPath, contains('/${conversation.id}/'));
      expect(sent.attachmentSize, 4);
    });

    test('proposes and cancels an appointment', () async {
      final conversation = (await repository.watchConversations().first).single;
      final start = DateTime.now().add(const Duration(days: 2));
      final proposal = await repository.proposeAppointment(
        conversationId: conversation.id,
        kind: AppointmentKind.inspection,
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
        timezone: 'Europe/London',
      );

      expect(proposal.status, AppointmentStatus.proposed);
      expect(proposal.proposedByMe, isTrue);

      final cancelled = await repository.respondToAppointment(
        appointmentId: proposal.id,
        status: AppointmentStatus.cancelled,
      );
      expect(cancelled.status, AppointmentStatus.cancelled);
    });

    test(
      'blocking prevents new messages and reporting remains available',
      () async {
        final conversation =
            (await repository.watchConversations().first).single;
        await repository.setBlocked(conversation.id, blocked: true);

        await expectLater(
          repository.sendText(conversation.id, 'This must not send'),
          throwsA(isA<MessagingFailure>()),
        );
        final reportId = await repository.reportUser(
          conversation.id,
          reason: ReportReason.harassment,
          details: 'Test report',
        );
        expect(reportId, startsWith('demo-report-'));
      },
    );
  });

  test('message and appointment models parse database values safely', () {
    final message = RepairMessage.fromJson({
      'id': 'message-1',
      'conversation_id': 'conversation-1',
      'sender_id': 'user-1',
      'message_type': 'repair_evidence',
      'sent_at': '2026-07-22T10:00:00Z',
      'attachment_size': '2048',
    }, currentUserId: 'user-1');
    final appointment = RepairAppointment.fromJson({
      'id': 'appointment-1',
      'conversation_id': 'conversation-1',
      'request_id': 'request-1',
      'proposed_by': 'user-2',
      'kind': 'inspection',
      'status': 'no_show',
      'starts_at': '2026-07-23T10:00:00Z',
      'ends_at': '2026-07-23T11:00:00Z',
      'timezone': 'Europe/London',
    });

    expect(message.type, RepairMessageType.repairEvidence);
    expect(message.isMine, isTrue);
    expect(message.attachmentSize, 2048);
    expect(appointment.status, AppointmentStatus.noShow);
  });
}
