import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/messaging/domain/entities/messaging_models.dart';
import 'package:fixbrief/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    required this.conversationId,
    this.initialConversation,
    super.key,
  });

  final String conversationId;
  final ConversationSummary? initialConversation;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  String? _lastReadMessageId;
  bool _sending = false;
  bool _typingSent = false;

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_typingSent) {
      unawaited(
        ref
            .read(messagingRepositoryProvider)
            .setTyping(widget.conversationId, typing: false),
      );
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider).asData?.value;
    final conversation =
        conversations
            ?.where((item) => item.id == widget.conversationId)
            .firstOrNull ??
        widget.initialConversation;
    final messages = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final appointments = ref.watch(
      conversationAppointmentsProvider(widget.conversationId),
    );
    final isTyping =
        ref
            .watch(counterpartTypingProvider(widget.conversationId))
            .asData
            ?.value ??
        false;

    ref.listen(
      conversationMessagesProvider(widget.conversationId),
      (previous, next) => next.whenData(_onMessagesChanged),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation?.counterpartName ?? 'Conversation',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isTyping ? 'Typing…' : conversation?.itemName ?? 'Repair request',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isTyping
                    ? Theme.of(context).colorScheme.primary
                    : context.glassColors.secondaryText,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ConversationAction>(
            tooltip: 'Conversation actions',
            onSelected: (action) => _handleAction(action, conversation),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _ConversationAction.report,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report member'),
                ),
              ),
              PopupMenuItem(
                value: conversation?.isBlocked == true
                    ? _ConversationAction.unblock
                    : _ConversationAction.block,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    conversation?.isBlocked == true
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                  ),
                  title: Text(
                    conversation?.isBlocked == true
                        ? 'Unblock member'
                        : 'Block member',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: FluidBackground(
        accent: LiquidGlassColors.computers,
        child: Column(
          children: [
            if (conversation?.isBlocked == true)
              _BlockedBanner(onUnblock: () => _setBlocked(false)),
            Expanded(
              child: messages.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading messages',
                  ),
                ),
                error: (error, stackTrace) => _MessageError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(
                    conversationMessagesProvider(widget.conversationId),
                  ),
                ),
                data: (items) => _MessageList(
                  controller: _scrollController,
                  messages: items,
                  appointments: appointments.asData?.value ?? const [],
                  onAppointmentResponse: _respondToAppointment,
                ),
              ),
            ),
            if (conversation?.isBlocked != true)
              _MessageComposer(
                controller: _messageController,
                enabled: !_sending,
                sending: _sending,
                onChanged: _onComposerChanged,
                onSend: _sendText,
                onAttachment: _pickAttachment,
                onAppointment: conversation == null
                    ? null
                    : () => _proposeAppointment(conversation),
              ),
          ],
        ),
      ),
    );
  }

  void _onMessagesChanged(List<RepairMessage> messages) {
    if (messages.isEmpty) {
      return;
    }
    final latestId = messages.last.id;
    if (_lastReadMessageId != latestId) {
      _lastReadMessageId = latestId;
      unawaited(
        ref
            .read(messagingRepositoryProvider)
            .markRead(widget.conversationId)
            .catchError((Object _) {}),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<void> _sendText() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    _messageController.clear();
    await _sendTyping(false);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .sendText(widget.conversationId, body);
    } on Object catch (error) {
      if (mounted) {
        _messageController.text = body;
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _onComposerChanged(String value) {
    _typingTimer?.cancel();
    if (value.trim().isEmpty) {
      unawaited(_sendTyping(false));
      return;
    }
    if (!_typingSent) {
      unawaited(_sendTyping(true));
    }
    _typingTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_sendTyping(false)),
    );
  }

  Future<void> _sendTyping(bool value) async {
    if (_typingSent == value) {
      return;
    }
    _typingSent = value;
    try {
      await ref
          .read(messagingRepositoryProvider)
          .setTyping(widget.conversationId, typing: value);
    } on Object {
      // Typing presence is intentionally best effort.
    }
  }

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<_AttachmentChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo or image'),
              subtitle: const Text('JPG, PNG, HEIC or WebP'),
              onTap: () => Navigator.pop(context, _AttachmentChoice.image),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Document'),
              subtitle: const Text('PDF, Word or text document'),
              onTap: () => Navigator.pop(context, _AttachmentChoice.document),
            ),
            ListTile(
              leading: const Icon(Icons.home_repair_service_outlined),
              title: const Text('Repair evidence'),
              subtitle: const Text('Attach evidence related to the fault'),
              onTap: () => Navigator.pop(context, _AttachmentChoice.evidence),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) {
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: choice == _AttachmentChoice.image
            ? FileType.image
            : choice == _AttachmentChoice.document
            ? FileType.custom
            : FileType.any,
        allowedExtensions: choice == _AttachmentChoice.document
            ? const ['pdf', 'doc', 'docx', 'txt', 'rtf']
            : null,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) {
        throw const MessagingFailure('The selected file could not be read.');
      }
      final mimeType =
          lookupMimeType(file.name, headerBytes: bytes) ??
          'application/octet-stream';
      final type = choice == _AttachmentChoice.image
          ? RepairMessageType.image
          : choice == _AttachmentChoice.evidence
          ? RepairMessageType.repairEvidence
          : RepairMessageType.document;
      setState(() => _sending = true);
      await ref
          .read(messagingRepositoryProvider)
          .sendAttachment(
            widget.conversationId,
            MessageAttachmentDraft(
              name: file.name,
              mimeType: mimeType,
              bytes: bytes,
              type: type,
            ),
          );
    } on Object catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _proposeAppointment(ConversationSummary conversation) async {
    var kind = AppointmentKind.inspection;
    var startsAt = DateTime.now().add(const Duration(days: 1));
    startsAt = DateTime(startsAt.year, startsAt.month, startsAt.day, 10);
    var durationMinutes = 60;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final kinds = conversation.jobId == null
              ? const [AppointmentKind.inspection]
              : AppointmentKind.values;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggest an appointment',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    conversation.jobId == null
                        ? 'Before quote acceptance, only an inspection can be arranged.'
                        : 'The other participant must confirm this proposal.',
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<AppointmentKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: kinds
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => kind = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(DateFormat.yMMMd().format(startsAt)),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate: startsAt,
                            );
                            if (date != null) {
                              setSheetState(() {
                                startsAt = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  startsAt.hour,
                                  startsAt.minute,
                                );
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(DateFormat.jm().format(startsAt)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(startsAt),
                            );
                            if (time != null) {
                              setSheetState(() {
                                startsAt = DateTime(
                                  startsAt.year,
                                  startsAt.month,
                                  startsAt.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: durationMinutes,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: const [30, 60, 90, 120]
                        .map(
                          (minutes) => DropdownMenuItem(
                            value: minutes,
                            child: Text('$minutes minutes'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => durationMinutes = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send proposal'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (submitted != true || !mounted) {
      return;
    }
    await _runBusy(() async {
      await ref
          .read(messagingRepositoryProvider)
          .proposeAppointment(
            conversationId: widget.conversationId,
            kind: kind,
            startsAt: startsAt,
            endsAt: startsAt.add(Duration(minutes: durationMinutes)),
            timezone: DateTime.now().timeZoneName,
          );
      _showNotice('Appointment proposal sent.');
    });
  }

  Future<void> _respondToAppointment(
    RepairAppointment appointment,
    AppointmentStatus status,
  ) async {
    final role = ref.read(authSessionControllerProvider).onboarding.role;
    var releaseLocation = false;
    if (status == AppointmentStatus.confirmed && role == UserRole.customer) {
      releaseLocation =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Share the appointment address?'),
              content: const Text(
                'Your exact saved address is private. Share it with this repair professional only for the confirmed appointment?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep private'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm and share'),
                ),
              ],
            ),
          ) ??
          false;
    }
    await _runBusy(() async {
      await ref
          .read(messagingRepositoryProvider)
          .respondToAppointment(
            appointmentId: appointment.id,
            status: status,
            releaseCustomerLocation: releaseLocation,
          );
      _showNotice('Appointment ${status.label.toLowerCase()}.');
    });
  }

  Future<void> _handleAction(
    _ConversationAction action,
    ConversationSummary? conversation,
  ) async {
    switch (action) {
      case _ConversationAction.report:
        await _showReportDialog();
      case _ConversationAction.block:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block this member?'),
            content: const Text(
              'Neither of you will be able to send messages. You can unblock them later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Block'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _setBlocked(true);
        }
      case _ConversationAction.unblock:
        await _setBlocked(false);
    }
  }

  Future<void> _setBlocked(bool blocked) async {
    await _runBusy(() async {
      await ref
          .read(messagingRepositoryProvider)
          .setBlocked(widget.conversationId, blocked: blocked);
      _showNotice(blocked ? 'Member blocked.' : 'Member unblocked.');
    });
  }

  Future<void> _showReportDialog() async {
    var reason = ReportReason.spam;
    var details = '';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Report member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ReportReason>(
                initialValue: reason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: ReportReason.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => reason = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 4,
                maxLength: 5000,
                onChanged: (value) => details = value,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) {
      return;
    }
    await _runBusy(() async {
      await ref
          .read(messagingRepositoryProvider)
          .reportUser(widget.conversationId, reason: reason, details: details);
      _showNotice('Report submitted for review.');
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showError(Object error) {
    final message = error is MessagingFailure
        ? error.message
        : error.toString();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showNotice(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.appointments,
    required this.onAppointmentResponse,
  });

  final ScrollController controller;
  final List<RepairMessage> messages;
  final List<RepairAppointment> appointments;
  final Future<void> Function(RepairAppointment, AppointmentStatus)
  onAppointmentResponse;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'This secure conversation is ready. Keep communication and appointment details in FixBrief.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    final appointmentById = {
      for (final appointment in appointments) appointment.id: appointment,
    };
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index == 0 ? null : messages[index - 1];
        final showDate =
            previous == null ||
            !DateUtils.isSameDay(previous.sentAt, message.sentAt);
        final appointment = message.relatedAppointmentId == null
            ? null
            : appointmentById[message.relatedAppointmentId];
        return Column(
          children: [
            if (showDate) _DateDivider(date: message.sentAt),
            _MessageBubble(message: message),
            if (appointment != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: _AppointmentCard(
                  appointment: appointment,
                  onResponse: (status) =>
                      onAppointmentResponse(appointment, status),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final RepairMessage message;

  @override
  Widget build(BuildContext context) {
    final systemMessage =
        message.type == RepairMessageType.appointment ||
        message.type == RepairMessageType.quote ||
        message.type == RepairMessageType.jobSystem;
    if (systemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_messageIcon(message.type), size: 16),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                message.body ?? 'Conversation update',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
        decoration: BoxDecoration(
          color: message.isMine
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.92)
              : context.glassColors.glassTint.withValues(alpha: 0.92),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isMine ? 20 : 6),
            bottomRight: Radius.circular(message.isMine ? 6 : 20),
          ),
          border: Border.all(
            color: message.isMine
                ? Colors.white.withValues(alpha: 0.12)
                : context.glassColors.glassBorder.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isDeleted)
              Text(
                'Message removed',
                style: TextStyle(
                  color: message.isMine
                      ? Colors.white70
                      : context.glassColors.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              )
            else ...[
              if (message.type == RepairMessageType.image &&
                  message.attachmentUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: CachedNetworkImage(
                    imageUrl: message.attachmentUrl!,
                    width: 260,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SizedBox(
                      width: 260,
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const SizedBox(
                      width: 260,
                      height: 100,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                )
              else if (message.hasAttachment)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _messageIcon(message.type),
                      color: message.isMine ? Colors.white : null,
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        message.attachmentName ?? 'Attachment',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: message.isMine ? Colors.white : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              if (message.body != null && message.body!.isNotEmpty) ...[
                if (message.hasAttachment) const SizedBox(height: 8),
                Text(
                  message.body!,
                  style: TextStyle(color: message.isMine ? Colors.white : null),
                ),
              ],
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  DateFormat.jm().format(message.sentAt.toLocal()),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: message.isMine
                        ? Colors.white70
                        : context.glassColors.secondaryText,
                  ),
                ),
                if (message.isMine) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_rounded,
                    size: 15,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _messageIcon(RepairMessageType type) => switch (type) {
    RepairMessageType.image => Icons.image_outlined,
    RepairMessageType.document => Icons.description_outlined,
    RepairMessageType.repairEvidence => Icons.home_repair_service_outlined,
    RepairMessageType.appointment => Icons.event_outlined,
    RepairMessageType.quote => Icons.request_quote_outlined,
    RepairMessageType.jobSystem => Icons.build_circle_outlined,
    RepairMessageType.text => Icons.chat_bubble_outline_rounded,
  };
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onResponse});

  final RepairAppointment appointment;
  final ValueChanged<AppointmentStatus> onResponse;

  @override
  Widget build(BuildContext context) {
    final canAnswer =
        appointment.status == AppointmentStatus.proposed &&
        !appointment.proposedByMe;
    final canCancel =
        appointment.status == AppointmentStatus.proposed &&
        appointment.proposedByMe;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_rounded),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${appointment.kind.label} appointment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                LiquidGlassStatusPill(
                  label: appointment.status.label,
                  status: switch (appointment.status) {
                    AppointmentStatus.confirmed => LiquidGlassStatus.success,
                    AppointmentStatus.declined ||
                    AppointmentStatus.cancelled ||
                    AppointmentStatus.noShow => LiquidGlassStatus.danger,
                    AppointmentStatus.completed => LiquidGlassStatus.info,
                    AppointmentStatus.proposed => LiquidGlassStatus.warning,
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat(
                'EEEE d MMMM, h:mm a',
              ).format(appointment.startsAt.toLocal()),
            ),
            Text(
              '${appointment.endsAt.difference(appointment.startsAt).inMinutes} minutes · ${appointment.timezone}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.glassColors.secondaryText,
              ),
            ),
            if (appointment.locationReleased &&
                appointment.locationAddress != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 19),
                  const SizedBox(width: 7),
                  Expanded(child: Text(appointment.locationAddress!)),
                ],
              ),
            ],
            if (canAnswer) ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onResponse(AppointmentStatus.declined),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onResponse(AppointmentStatus.confirmed),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ] else if (canCancel) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => onResponse(AppointmentStatus.cancelled),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel proposal'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onChanged,
    required this.onSend,
    required this.onAttachment,
    required this.onAppointment,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final VoidCallback? onAppointment;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LiquidGlassContainer(
        radius: 0,
        showShadow: true,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Attach evidence or document',
              onPressed: enabled ? onAttachment : null,
              icon: const Icon(Icons.attach_file_rounded),
            ),
            IconButton(
              tooltip: 'Suggest appointment',
              onPressed: enabled ? onAppointment : null,
              icon: const Icon(Icons.event_outlined),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 10000,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                textCapitalization: TextCapitalization.sentences,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message securely',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Send message',
              onPressed: enabled ? onSend : null,
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.onUnblock});

  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.glassColors.warningSurface.withValues(alpha: 0.98),
      child: SafeArea(
        top: false,
        child: ListTile(
          leading: const Icon(Icons.block_rounded),
          title: const Text('Messaging is blocked'),
          subtitle: const Text('Neither participant can send new messages.'),
          trailing: TextButton(
            onPressed: onUnblock,
            child: const Text('Unblock'),
          ),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        DateUtils.isSameDay(date.toLocal(), DateTime.now())
            ? 'Today'
            : DateFormat.yMMMd().format(date.toLocal()),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.glassColors.secondaryText,
        ),
      ),
    );
  }
}

class _MessageError extends StatelessWidget {
  const _MessageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_problem_rounded, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConversationAction { report, block, unblock }

enum _AttachmentChoice { image, document, evidence }
