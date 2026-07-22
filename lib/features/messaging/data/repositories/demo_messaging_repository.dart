import 'dart:async';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/messaging/domain/entities/messaging_models.dart';
import 'package:fixbrief/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:uuid/uuid.dart';

class DemoMessagingRepository implements MessagingRepository {
  DemoMessagingRepository(
    this._currentUserId,
    this._role, {
    this.simulatedDelay = Duration.zero,
  }) {
    _seed();
  }

  final String _currentUserId;
  final UserRole _role;
  final Duration simulatedDelay;
  final Uuid _uuid = const Uuid();
  final StreamController<List<ConversationSummary>> _conversationsController =
      StreamController<List<ConversationSummary>>.broadcast();
  final Map<String, StreamController<List<RepairMessage>>> _messageControllers =
      {};
  final Map<String, StreamController<List<RepairAppointment>>>
  _appointmentControllers = {};
  final Map<String, StreamController<bool>> _typingControllers = {};
  final List<ConversationSummary> _conversations = [];
  final Map<String, List<RepairMessage>> _messages = {};
  final Map<String, List<RepairAppointment>> _appointments = {};
  bool _disposed = false;

  @override
  Stream<List<ConversationSummary>> watchConversations() async* {
    yield List.unmodifiable(_conversations);
    yield* _conversationsController.stream;
  }

  @override
  Future<ConversationSummary?> loadConversation(String conversationId) async {
    await _wait();
    return _conversations
        .where((item) => item.id == conversationId)
        .firstOrNull;
  }

  @override
  Stream<List<RepairMessage>> watchMessages(String conversationId) async* {
    _requireConversation(conversationId);
    yield List.unmodifiable(_messages[conversationId] ?? const []);
    yield* _messageController(conversationId).stream;
  }

  @override
  Stream<List<RepairAppointment>> watchAppointments(
    String conversationId,
  ) async* {
    _requireConversation(conversationId);
    yield List.unmodifiable(_appointments[conversationId] ?? const []);
    yield* _appointmentController(conversationId).stream;
  }

  @override
  Future<RepairMessage> sendText(String conversationId, String body) async {
    await _wait();
    _requireCanSend(conversationId);
    final normalized = body.trim();
    if (normalized.isEmpty || normalized.length > 10000) {
      throw const MessagingFailure(
        'Enter a message of up to 10,000 characters.',
      );
    }
    return _addMessage(
      conversationId,
      type: RepairMessageType.text,
      body: normalized,
    );
  }

  @override
  Future<RepairMessage> sendAttachment(
    String conversationId,
    MessageAttachmentDraft attachment, {
    String? caption,
  }) async {
    await _wait();
    _requireCanSend(conversationId);
    if (attachment.size < 1 || attachment.size > 25 * 1024 * 1024) {
      throw const MessagingFailure('Attachments must be smaller than 25 MB.');
    }
    return _addMessage(
      conversationId,
      type: attachment.type,
      body: caption?.trim(),
      attachmentName: attachment.name,
      attachmentMimeType: attachment.mimeType,
      attachmentSize: attachment.size,
    );
  }

  @override
  Future<void> markRead(String conversationId) async {
    await _wait();
    final index = _conversationIndex(conversationId);
    _conversations[index] = _copyConversation(
      _conversations[index],
      unreadCount: 0,
    );
    _emitConversations();
  }

  @override
  Future<RepairAppointment> proposeAppointment({
    required String conversationId,
    required AppointmentKind kind,
    required DateTime startsAt,
    required DateTime endsAt,
    required String timezone,
  }) async {
    await _wait();
    _requireCanSend(conversationId);
    final conversation = _conversations[_conversationIndex(conversationId)];
    if (!startsAt.isAfter(DateTime.now()) || !endsAt.isAfter(startsAt)) {
      throw const MessagingFailure('Choose a future appointment time.');
    }
    if (conversation.jobId == null && kind != AppointmentKind.inspection) {
      throw const MessagingFailure(
        'Only an inspection can be proposed before quote acceptance.',
      );
    }
    final appointment = RepairAppointment(
      id: _uuid.v4(),
      conversationId: conversationId,
      requestId: conversation.requestId,
      jobId: conversation.jobId,
      proposedBy: _currentUserId,
      proposedByMe: true,
      kind: kind,
      status: AppointmentStatus.proposed,
      startsAt: startsAt,
      endsAt: endsAt,
      timezone: timezone,
      locationReleased: false,
    );
    final values = _appointments.putIfAbsent(conversationId, () => []);
    values.insert(0, appointment);
    _emitAppointments(conversationId);
    _addMessage(
      conversationId,
      type: RepairMessageType.appointment,
      body: 'Proposed an appointment.',
      relatedAppointmentId: appointment.id,
    );
    return appointment;
  }

  @override
  Future<RepairAppointment> respondToAppointment({
    required String appointmentId,
    required AppointmentStatus status,
    String? message,
    bool releaseCustomerLocation = false,
  }) async {
    await _wait();
    if (!const {
      AppointmentStatus.confirmed,
      AppointmentStatus.declined,
      AppointmentStatus.cancelled,
    }.contains(status)) {
      throw const MessagingFailure('Unsupported appointment response.');
    }
    for (final entry in _appointments.entries) {
      final index = entry.value.indexWhere((item) => item.id == appointmentId);
      if (index < 0) {
        continue;
      }
      final current = entry.value[index];
      if (current.proposedByMe && status != AppointmentStatus.cancelled) {
        throw const MessagingFailure(
          'The other participant must answer this proposal.',
        );
      }
      final updated = RepairAppointment(
        id: current.id,
        conversationId: current.conversationId,
        requestId: current.requestId,
        jobId: current.jobId,
        proposedBy: current.proposedBy,
        proposedByMe: current.proposedByMe,
        kind: current.kind,
        status: status,
        startsAt: current.startsAt,
        endsAt: current.endsAt,
        timezone: current.timezone,
        locationReleased:
            releaseCustomerLocation && status == AppointmentStatus.confirmed,
        locationAddress:
            releaseCustomerLocation && status == AppointmentStatus.confirmed
            ? 'Customer address shared securely after confirmation'
            : current.locationAddress,
        responseMessage: message?.trim(),
        respondedAt: DateTime.now(),
      );
      entry.value[index] = updated;
      _emitAppointments(entry.key);
      _addMessage(
        entry.key,
        type: RepairMessageType.appointment,
        body: 'Appointment ${status.label.toLowerCase()}.',
        relatedAppointmentId: appointmentId,
      );
      return updated;
    }
    throw const MessagingFailure('This appointment is no longer available.');
  }

  @override
  Future<void> setBlocked(
    String conversationId, {
    required bool blocked,
    String? reason,
  }) async {
    await _wait();
    final index = _conversationIndex(conversationId);
    _conversations[index] = _copyConversation(
      _conversations[index],
      isBlocked: blocked,
      status: blocked ? ConversationStatus.closed : ConversationStatus.active,
    );
    _emitConversations();
  }

  @override
  Future<String> reportUser(
    String conversationId, {
    required ReportReason reason,
    String? details,
  }) async {
    await _wait();
    _requireConversation(conversationId);
    if ((details?.length ?? 0) > 5000) {
      throw const MessagingFailure(
        'Report details must be under 5,000 characters.',
      );
    }
    return 'demo-report-${_uuid.v4()}';
  }

  @override
  Stream<bool> watchCounterpartTyping(String conversationId) async* {
    _requireConversation(conversationId);
    yield false;
    yield* _typingController(conversationId).stream;
  }

  @override
  Future<void> setTyping(String conversationId, {required bool typing}) async {
    _requireConversation(conversationId);
    // Demo mode has no remote participant. Keep the channel available so UI
    // and tests use the same contract as Supabase.
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _conversationsController.close();
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
    for (final controller in _appointmentControllers.values) {
      await controller.close();
    }
    for (final controller in _typingControllers.values) {
      await controller.close();
    }
  }

  void _seed() {
    final isCustomer = _role == UserRole.customer;
    final now = DateTime.now();
    const conversationId = '70000000-0000-4000-8000-000000000001';
    final counterpartId = isCustomer
        ? '20000000-0000-4000-8000-000000000001'
        : '10000000-0000-4000-8000-000000000001';
    _conversations.add(
      ConversationSummary(
        id: conversationId,
        requestId: 'demo-request-vehicle',
        jobId: 'demo-job-vehicle',
        itemName: '2018 Ford Focus',
        approximateArea: 'Manchester M20',
        counterpartId: counterpartId,
        counterpartName: isCustomer ? 'Northside Auto Care' : 'Alex Morgan',
        counterpartRole: isCustomer ? 'repairer' : 'customer',
        status: ConversationStatus.active,
        lastMessage: isCustomer
            ? 'I can inspect the clicking noise tomorrow morning.'
            : 'The clicking is louder on full-lock turns.',
        lastMessageAt: now.subtract(const Duration(minutes: 18)),
        unreadCount: 1,
        isBlocked: false,
      ),
    );
    _messages[conversationId] = [
      RepairMessage(
        id: _uuid.v4(),
        conversationId: conversationId,
        senderId: isCustomer ? _currentUserId : counterpartId,
        isMine: isCustomer,
        type: RepairMessageType.text,
        body: 'The clicking is louder on full-lock turns.',
        sentAt: now.subtract(const Duration(minutes: 24)),
      ),
      RepairMessage(
        id: _uuid.v4(),
        conversationId: conversationId,
        senderId: isCustomer ? counterpartId : _currentUserId,
        isMine: !isCustomer,
        type: RepairMessageType.text,
        body: 'I can inspect the clicking noise tomorrow morning.',
        sentAt: now.subtract(const Duration(minutes: 18)),
      ),
    ];
    _appointments[conversationId] = [];
  }

  RepairMessage _addMessage(
    String conversationId, {
    required RepairMessageType type,
    String? body,
    String? attachmentName,
    String? attachmentMimeType,
    int? attachmentSize,
    String? relatedAppointmentId,
  }) {
    final now = DateTime.now();
    final message = RepairMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: _currentUserId,
      isMine: true,
      type: type,
      body: body,
      attachmentBucket: attachmentName == null ? null : 'message-attachments',
      attachmentPath: attachmentName == null
          ? null
          : '$_currentUserId/$conversationId/${_uuid.v4()}-$attachmentName',
      attachmentName: attachmentName,
      attachmentMimeType: attachmentMimeType,
      attachmentSize: attachmentSize,
      relatedAppointmentId: relatedAppointmentId,
      sentAt: now,
    );
    final values = _messages.putIfAbsent(conversationId, () => []);
    values.add(message);
    _messageController(conversationId).add(List.unmodifiable(values));

    final index = _conversationIndex(conversationId);
    final current = _conversations[index];
    _conversations[index] = _copyConversation(
      current,
      lastMessage: body,
      lastMessageType: type,
      lastMessageIsMine: true,
      lastMessageAt: now,
    );
    _emitConversations();
    return message;
  }

  ConversationSummary _copyConversation(
    ConversationSummary value, {
    String? lastMessage,
    RepairMessageType? lastMessageType,
    bool? lastMessageIsMine,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isBlocked,
    ConversationStatus? status,
  }) {
    return ConversationSummary(
      id: value.id,
      requestId: value.requestId,
      jobId: value.jobId,
      itemName: value.itemName,
      approximateArea: value.approximateArea,
      counterpartId: value.counterpartId,
      counterpartName: value.counterpartName,
      counterpartRole: value.counterpartRole,
      status: status ?? value.status,
      lastMessage: lastMessage ?? value.lastMessage,
      lastMessageType: lastMessageType ?? value.lastMessageType,
      lastMessageIsMine: lastMessageIsMine ?? value.lastMessageIsMine,
      lastMessageAt: lastMessageAt ?? value.lastMessageAt,
      unreadCount: unreadCount ?? value.unreadCount,
      isBlocked: isBlocked ?? value.isBlocked,
    );
  }

  void _requireConversation(String id) => _conversationIndex(id);

  void _requireCanSend(String id) {
    final conversation = _conversations[_conversationIndex(id)];
    if (conversation.isBlocked ||
        conversation.status == ConversationStatus.closed) {
      throw const MessagingFailure(
        'Unblock this member before sending a message.',
      );
    }
  }

  int _conversationIndex(String id) {
    final index = _conversations.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const MessagingFailure('This conversation is no longer available.');
    }
    return index;
  }

  StreamController<List<RepairMessage>> _messageController(String id) =>
      _messageControllers.putIfAbsent(
        id,
        StreamController<List<RepairMessage>>.broadcast,
      );

  StreamController<List<RepairAppointment>> _appointmentController(String id) =>
      _appointmentControllers.putIfAbsent(
        id,
        StreamController<List<RepairAppointment>>.broadcast,
      );

  StreamController<bool> _typingController(String id) =>
      _typingControllers.putIfAbsent(id, StreamController<bool>.broadcast);

  void _emitConversations() {
    if (!_disposed) {
      _conversationsController.add(List.unmodifiable(_conversations));
    }
  }

  void _emitAppointments(String conversationId) {
    if (!_disposed) {
      _appointmentController(
        conversationId,
      ).add(List.unmodifiable(_appointments[conversationId] ?? const []));
    }
  }

  Future<void> _wait() => Future<void>.delayed(simulatedDelay);
}
