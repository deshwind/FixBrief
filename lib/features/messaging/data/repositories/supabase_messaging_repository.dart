import 'dart:async';

import 'package:fixbrief/features/messaging/domain/entities/messaging_models.dart';
import 'package:fixbrief/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseMessagingRepository implements MessagingRepository {
  SupabaseMessagingRepository(this._client);

  final SupabaseClient _client;
  final Uuid _uuid = const Uuid();
  final Map<String, RealtimeChannel> _typingChannels = {};
  final Map<String, StreamController<bool>> _typingControllers = {};
  final Map<String, Timer> _typingTimeouts = {};
  bool _disposed = false;

  String get _currentUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const MessagingFailure('Sign in again to use messages.');
    }
    return id;
  }

  @override
  Stream<List<ConversationSummary>> watchConversations() async* {
    yield await _loadConversations();
    final changes = _client
        .from('conversations')
        .stream(primaryKey: const ['id'])
        .order('last_message_at', ascending: false);
    await for (final _ in changes) {
      yield await _loadConversations();
    }
  }

  @override
  Future<ConversationSummary?> loadConversation(String conversationId) async {
    final conversations = await _loadConversations();
    for (final conversation in conversations) {
      if (conversation.id == conversationId) {
        return conversation;
      }
    }
    return null;
  }

  @override
  Stream<List<RepairMessage>> watchMessages(String conversationId) {
    _validateId(conversationId, 'conversation');
    return _client
        .from('messages')
        .stream(primaryKey: const ['id'])
        .eq('conversation_id', conversationId)
        .order('sent_at')
        .asyncMap(_messagesFromRows)
        .handleError((Object error) {
          throw _mapError(error, action: 'load messages');
        });
  }

  @override
  Stream<List<RepairAppointment>> watchAppointments(String conversationId) {
    _validateId(conversationId, 'conversation');
    return _client
        .from('appointments')
        .stream(primaryKey: const ['id'])
        .eq('conversation_id', conversationId)
        .order('starts_at', ascending: false)
        .map(
          (rows) => rows
              .map<Map<String, Object?>>(_map)
              .map((row) {
                row['proposed_by_me'] =
                    row['proposed_by']?.toString() == _currentUserId;
                return RepairAppointment.fromJson(row);
              })
              .toList(growable: false),
        )
        .handleError((Object error) {
          throw _mapError(error, action: 'load appointments');
        });
  }

  @override
  Future<RepairMessage> sendText(String conversationId, String body) async {
    final normalized = body.trim();
    if (normalized.isEmpty || normalized.length > 10000) {
      throw const MessagingFailure(
        'Enter a message of up to 10,000 characters.',
      );
    }
    final response = await _rpc(
      'send_conversation_message',
      params: <String, Object?>{
        'target_conversation_id': conversationId,
        'client_message_id': _uuid.v4(),
        'message_kind': 'text',
        'message_body': normalized,
      },
    );
    return RepairMessage.fromJson(
      _map(response),
      currentUserId: _currentUserId,
    );
  }

  @override
  Future<RepairMessage> sendAttachment(
    String conversationId,
    MessageAttachmentDraft attachment, {
    String? caption,
  }) async {
    _validateId(conversationId, 'conversation');
    if (attachment.size < 1 || attachment.size > 25 * 1024 * 1024) {
      throw const MessagingFailure('Attachments must be smaller than 25 MB.');
    }
    if (attachment.type != RepairMessageType.image &&
        attachment.type != RepairMessageType.document &&
        attachment.type != RepairMessageType.repairEvidence) {
      throw const MessagingFailure('Unsupported attachment type.');
    }

    final safeName = _safeFileName(attachment.name);
    final clientId = _uuid.v4();
    final path = '$_currentUserId/$conversationId/$clientId-$safeName';
    try {
      await _client.storage
          .from('message-attachments')
          .uploadBinary(
            path,
            attachment.bytes,
            fileOptions: FileOptions(
              contentType: attachment.mimeType,
              upsert: false,
            ),
          )
          .timeout(const Duration(seconds: 45));

      final response = await _rpc(
        'send_conversation_message',
        params: <String, Object?>{
          'target_conversation_id': conversationId,
          'client_message_id': clientId,
          'message_kind': attachment.type.databaseValue,
          'message_body': caption?.trim(),
          'target_attachment_path': path,
          'target_attachment_name': safeName,
          'target_attachment_mime_type': attachment.mimeType,
          'target_attachment_size': attachment.size,
        },
      );
      final signedUrl = await _client.storage
          .from('message-attachments')
          .createSignedUrl(path, 300);
      return RepairMessage.fromJson(
        _map(response),
        currentUserId: _currentUserId,
        attachmentUrl: signedUrl,
      );
    } on MessagingFailure {
      await _removeFailedUpload(path);
      rethrow;
    } on StorageException catch (error) {
      throw MessagingFailure(
        error.statusCode == '413'
            ? 'This attachment is too large.'
            : 'The attachment could not be uploaded. Try again.',
        code: error.statusCode,
      );
    } on TimeoutException {
      await _removeFailedUpload(path);
      throw const MessagingFailure(
        'The attachment upload timed out. Check your connection and try again.',
        code: 'timeout',
      );
    }
  }

  @override
  Future<void> markRead(String conversationId) async {
    await _rpc(
      'mark_conversation_read',
      params: <String, Object?>{'target_conversation_id': conversationId},
    );
  }

  @override
  Future<RepairAppointment> proposeAppointment({
    required String conversationId,
    required AppointmentKind kind,
    required DateTime startsAt,
    required DateTime endsAt,
    required String timezone,
  }) async {
    final response = await _rpc(
      'propose_appointment',
      params: <String, Object?>{
        'target_conversation_id': conversationId,
        'appointment_kind': kind.name,
        'appointment_starts_at': startsAt.toUtc().toIso8601String(),
        'appointment_ends_at': endsAt.toUtc().toIso8601String(),
        'timezone_name': timezone,
      },
    );
    return RepairAppointment.fromJson(_map(response));
  }

  @override
  Future<RepairAppointment> respondToAppointment({
    required String appointmentId,
    required AppointmentStatus status,
    String? message,
    bool releaseCustomerLocation = false,
  }) async {
    final response = await _rpc(
      'respond_to_appointment',
      params: <String, Object?>{
        'target_appointment_id': appointmentId,
        'response_status': status.databaseValue,
        'response_message': message?.trim(),
        'release_customer_location': releaseCustomerLocation,
      },
    );
    return RepairAppointment.fromJson(_map(response));
  }

  @override
  Future<void> setBlocked(
    String conversationId, {
    required bool blocked,
    String? reason,
  }) async {
    await _rpc(
      'set_conversation_blocked',
      params: <String, Object?>{
        'target_conversation_id': conversationId,
        'should_block': blocked,
        'block_reason': reason?.trim(),
      },
    );
  }

  @override
  Future<String> reportUser(
    String conversationId, {
    required ReportReason reason,
    String? details,
  }) async {
    final response = await _rpc(
      'report_conversation_user',
      params: <String, Object?>{
        'target_conversation_id': conversationId,
        'report_reason': reason.databaseValue,
        'report_details': details?.trim(),
      },
    );
    final id = response?.toString() ?? '';
    if (id.isEmpty) {
      throw const MessagingFailure('The report could not be confirmed.');
    }
    return id;
  }

  @override
  Stream<bool> watchCounterpartTyping(String conversationId) async* {
    _ensureTypingChannel(conversationId);
    yield false;
    yield* _typingControllers[conversationId]!.stream;
  }

  @override
  Future<void> setTyping(String conversationId, {required bool typing}) async {
    final channel = _ensureTypingChannel(conversationId);
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: <String, dynamic>{
        'sender_id': _currentUserId,
        'is_typing': typing,
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final timer in _typingTimeouts.values) {
      timer.cancel();
    }
    for (final channel in _typingChannels.values) {
      await _client.removeChannel(channel);
    }
    for (final controller in _typingControllers.values) {
      await controller.close();
    }
  }

  Future<List<ConversationSummary>> _loadConversations() async {
    final response = await _rpc('get_conversations');
    return _maps(
      response,
    ).map(ConversationSummary.fromJson).toList(growable: false);
  }

  Future<List<RepairMessage>> _messagesFromRows(
    List<Map<String, dynamic>> rows,
  ) async {
    return Future.wait(
      rows.map((raw) async {
        final row = _map(raw);
        final path = row['attachment_path']?.toString();
        String? signedUrl;
        if (path != null && path.isNotEmpty && row['deleted_at'] == null) {
          try {
            signedUrl = await _client.storage
                .from('message-attachments')
                .createSignedUrl(path, 300);
          } on StorageException {
            // Metadata and retry UI remain available if a preview URL fails.
          }
        }
        return RepairMessage.fromJson(
          row,
          currentUserId: _currentUserId,
          attachmentUrl: signedUrl,
        );
      }),
    );
  }

  RealtimeChannel _ensureTypingChannel(String conversationId) {
    _validateId(conversationId, 'conversation');
    return _typingChannels.putIfAbsent(conversationId, () {
      // Owned by this repository and closed in dispose.
      // ignore: close_sinks
      final controller = _typingControllers.putIfAbsent(
        conversationId,
        StreamController<bool>.broadcast,
      );
      final channel = _client.channel(
        'conversation-typing:$conversationId',
        opts: const RealtimeChannelConfig(private: true),
      );
      channel
          .onBroadcast(
            event: 'typing',
            callback: (payload) {
              if (_disposed ||
                  payload['sender_id']?.toString() == _currentUserId) {
                return;
              }
              final typing = payload['is_typing'] == true;
              controller.add(typing);
              _typingTimeouts[conversationId]?.cancel();
              if (typing) {
                _typingTimeouts[conversationId] = Timer(
                  const Duration(seconds: 4),
                  () {
                    if (!_disposed) {
                      controller.add(false);
                    }
                  },
                );
              }
            },
          )
          .subscribe();
      return channel;
    });
  }

  Future<Object?> _rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) async {
    try {
      return await _client
          .rpc<Object?>(function, params: params)
          .timeout(const Duration(seconds: 20));
    } on PostgrestException catch (error) {
      throw _mapError(error, action: 'update this conversation');
    } on TimeoutException {
      throw const MessagingFailure(
        'Messaging is taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }

  MessagingFailure _mapError(Object error, {required String action}) {
    if (error is MessagingFailure) {
      return error;
    }
    if (error is PostgrestException) {
      final setupMissing =
          error.code == '42P01' ||
          error.code == '42703' ||
          error.code == '42883' ||
          error.code == 'PGRST202';
      final invalid = error.code == '22023' || error.code == '23514';
      return MessagingFailure(
        setupMissing
            ? 'The Stage 9 messaging migration has not been deployed in this environment.'
            : invalid
            ? error.message
            : error.code == '42501'
            ? 'This conversation is unavailable or messaging has been blocked.'
            : 'We could not $action. Check your connection and try again.',
        code: error.code,
      );
    }
    return MessagingFailure(
      'We could not $action. Check your connection and try again.',
    );
  }

  Future<void> _removeFailedUpload(String path) async {
    try {
      await _client.storage.from('message-attachments').remove([path]);
    } on Object {
      // The private orphan is harmless and can be removed by storage cleanup.
    }
  }

  void _validateId(String value, String label) {
    if (value.trim().isEmpty || value.length > 100) {
      throw MessagingFailure('The $label link is invalid.');
    }
  }

  String _safeFileName(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-');
    if (normalized.isEmpty) {
      return 'attachment';
    }
    return normalized.length <= 120 ? normalized : normalized.substring(0, 120);
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, Object?>{};
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value.map(_map).toList(growable: false);
}
