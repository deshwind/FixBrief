import 'package:flutter/foundation.dart';

enum ConversationStatus { active, closed }

enum RepairMessageType {
  text,
  image,
  document,
  repairEvidence,
  appointment,
  quote,
  jobSystem;

  static RepairMessageType fromDatabase(Object? value) =>
      switch (value?.toString()) {
        'image' => RepairMessageType.image,
        'document' => RepairMessageType.document,
        'repair_evidence' => RepairMessageType.repairEvidence,
        'appointment' => RepairMessageType.appointment,
        'quote' => RepairMessageType.quote,
        'job_system' => RepairMessageType.jobSystem,
        _ => RepairMessageType.text,
      };

  String get databaseValue => switch (this) {
    RepairMessageType.repairEvidence => 'repair_evidence',
    RepairMessageType.jobSystem => 'job_system',
    _ => name,
  };
}

enum AppointmentKind { inspection, repair, collection }

extension AppointmentKindView on AppointmentKind {
  String get label => switch (this) {
    AppointmentKind.inspection => 'Inspection',
    AppointmentKind.repair => 'Repair',
    AppointmentKind.collection => 'Collection',
  };
}

enum AppointmentStatus {
  proposed,
  confirmed,
  declined,
  cancelled,
  completed,
  noShow;

  static AppointmentStatus fromDatabase(Object? value) =>
      switch (value?.toString()) {
        'confirmed' => AppointmentStatus.confirmed,
        'declined' => AppointmentStatus.declined,
        'cancelled' => AppointmentStatus.cancelled,
        'completed' => AppointmentStatus.completed,
        'no_show' => AppointmentStatus.noShow,
        _ => AppointmentStatus.proposed,
      };

  String get databaseValue =>
      this == AppointmentStatus.noShow ? 'no_show' : name;

  String get label => switch (this) {
    AppointmentStatus.proposed => 'Awaiting response',
    AppointmentStatus.confirmed => 'Confirmed',
    AppointmentStatus.declined => 'Declined',
    AppointmentStatus.cancelled => 'Cancelled',
    AppointmentStatus.completed => 'Completed',
    AppointmentStatus.noShow => 'No show',
  };
}

enum ReportReason {
  spam,
  harassment,
  fraud,
  unsafeContent,
  inappropriateContent,
  identityConcern,
  other;

  String get databaseValue => switch (this) {
    ReportReason.unsafeContent => 'unsafe_content',
    ReportReason.inappropriateContent => 'inappropriate_content',
    ReportReason.identityConcern => 'identity_concern',
    _ => name,
  };

  String get label => switch (this) {
    ReportReason.spam => 'Spam',
    ReportReason.harassment => 'Harassment',
    ReportReason.fraud => 'Suspected fraud',
    ReportReason.unsafeContent => 'Unsafe content',
    ReportReason.inappropriateContent => 'Inappropriate content',
    ReportReason.identityConcern => 'Identity concern',
    ReportReason.other => 'Other',
  };
}

@immutable
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.requestId,
    required this.counterpartId,
    required this.counterpartName,
    required this.counterpartRole,
    required this.status,
    required this.unreadCount,
    required this.isBlocked,
    this.jobId,
    this.itemName,
    this.approximateArea,
    this.lastMessage,
    this.lastMessageType = RepairMessageType.text,
    this.lastMessageIsMine = false,
    this.lastMessageAt,
  });

  factory ConversationSummary.fromJson(Map<String, Object?> json) {
    return ConversationSummary(
      id: _string(json['id']),
      requestId: _string(json['request_id']),
      jobId: _nullableString(json['job_id']),
      itemName: _nullableString(json['item_name']),
      approximateArea: _nullableString(json['approximate_area']),
      counterpartId: _string(json['counterpart_id']),
      counterpartName: _string(
        json['counterpart_name'],
        fallback: 'FixBrief member',
      ),
      counterpartRole: _string(json['counterpart_role']),
      status: json['status']?.toString() == 'closed'
          ? ConversationStatus.closed
          : ConversationStatus.active,
      lastMessage: _nullableString(json['last_message']),
      lastMessageType: RepairMessageType.fromDatabase(
        json['last_message_type'],
      ),
      lastMessageIsMine: _bool(json['last_message_is_mine']),
      lastMessageAt: _date(json['last_message_at']),
      unreadCount: _int(json['unread_count']),
      isBlocked: _bool(json['is_blocked']),
    );
  }

  final String id;
  final String requestId;
  final String? jobId;
  final String? itemName;
  final String? approximateArea;
  final String counterpartId;
  final String counterpartName;
  final String counterpartRole;
  final ConversationStatus status;
  final String? lastMessage;
  final RepairMessageType lastMessageType;
  final bool lastMessageIsMine;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isBlocked;

  String get preview {
    final prefix = lastMessageIsMine ? 'You: ' : '';
    final body = lastMessage?.trim();
    if (body != null && body.isNotEmpty) {
      return '$prefix$body';
    }
    return '$prefix${switch (lastMessageType) {
      RepairMessageType.image => 'Image',
      RepairMessageType.document => 'Document',
      RepairMessageType.repairEvidence => 'Repair evidence',
      RepairMessageType.appointment => 'Appointment update',
      RepairMessageType.quote => 'Quote update',
      RepairMessageType.jobSystem => 'Job update',
      RepairMessageType.text => 'Start the conversation',
    }}';
  }
}

@immutable
class RepairMessage {
  const RepairMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.isMine,
    required this.type,
    required this.sentAt,
    this.body,
    this.attachmentBucket,
    this.attachmentPath,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSize,
    this.attachmentUrl,
    this.relatedQuoteId,
    this.relatedJobId,
    this.relatedAppointmentId,
    this.editedAt,
    this.deletedAt,
  });

  factory RepairMessage.fromJson(
    Map<String, Object?> json, {
    String? currentUserId,
    String? attachmentUrl,
  }) {
    final senderId = _string(json['sender_id']);
    return RepairMessage(
      id: _string(json['id']),
      conversationId: _string(json['conversation_id']),
      senderId: senderId,
      isMine: json.containsKey('is_mine')
          ? _bool(json['is_mine'])
          : senderId == currentUserId,
      type: RepairMessageType.fromDatabase(json['message_type']),
      body: _nullableString(json['body']),
      attachmentBucket: _nullableString(json['attachment_bucket']),
      attachmentPath: _nullableString(json['attachment_path']),
      attachmentName: _nullableString(json['attachment_name']),
      attachmentMimeType: _nullableString(json['attachment_mime_type']),
      attachmentSize: _nullableInt(json['attachment_size']),
      attachmentUrl: attachmentUrl,
      relatedQuoteId: _nullableString(json['related_quote_id']),
      relatedJobId: _nullableString(json['related_job_id']),
      relatedAppointmentId: _nullableString(json['related_appointment_id']),
      sentAt: _date(json['sent_at']) ?? DateTime.now(),
      editedAt: _date(json['edited_at']),
      deletedAt: _date(json['deleted_at']),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final bool isMine;
  final RepairMessageType type;
  final String? body;
  final String? attachmentBucket;
  final String? attachmentPath;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSize;
  final String? attachmentUrl;
  final String? relatedQuoteId;
  final String? relatedJobId;
  final String? relatedAppointmentId;
  final DateTime sentAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  bool get hasAttachment => attachmentPath != null;
  bool get isDeleted => deletedAt != null;
}

@immutable
class RepairAppointment {
  const RepairAppointment({
    required this.id,
    required this.conversationId,
    required this.requestId,
    required this.proposedBy,
    required this.proposedByMe,
    required this.kind,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.locationReleased,
    this.jobId,
    this.locationAddress,
    this.responseMessage,
    this.respondedAt,
  });

  factory RepairAppointment.fromJson(Map<String, Object?> json) {
    return RepairAppointment(
      id: _string(json['id']),
      conversationId: _string(json['conversation_id']),
      requestId: _string(json['request_id']),
      jobId: _nullableString(json['job_id']),
      proposedBy: _string(json['proposed_by']),
      proposedByMe: _bool(json['proposed_by_me']),
      kind: AppointmentKind.values.firstWhere(
        (value) => value.name == json['kind']?.toString(),
        orElse: () => AppointmentKind.inspection,
      ),
      status: AppointmentStatus.fromDatabase(json['status']),
      startsAt: _date(json['starts_at']) ?? DateTime.now(),
      endsAt: _date(json['ends_at']) ?? DateTime.now(),
      timezone: _string(json['timezone'], fallback: 'Europe/London'),
      locationAddress: _nullableString(json['location_address']),
      locationReleased: _bool(json['location_released']),
      responseMessage: _nullableString(json['response_message']),
      respondedAt: _date(json['responded_at']),
    );
  }

  final String id;
  final String conversationId;
  final String requestId;
  final String? jobId;
  final String proposedBy;
  final bool proposedByMe;
  final AppointmentKind kind;
  final AppointmentStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final String? locationAddress;
  final bool locationReleased;
  final String? responseMessage;
  final DateTime? respondedAt;
}

@immutable
class MessageAttachmentDraft {
  const MessageAttachmentDraft({
    required this.name,
    required this.mimeType,
    required this.bytes,
    required this.type,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
  final RepairMessageType type;

  int get size => bytes.length;
}

class MessagingFailure implements Exception {
  const MessagingFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _bool(Object? value) => switch (value) {
  final bool result => result,
  final num number => number != 0,
  final String text => text.toLowerCase() == 'true' || text == '1',
  _ => false,
};

int _int(Object? value) => _nullableInt(value) ?? 0;

int? _nullableInt(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text),
  _ => null,
};

DateTime? _date(Object? value) {
  if (value is DateTime) {
    return value;
  }
  return value == null ? null : DateTime.tryParse(value.toString());
}
