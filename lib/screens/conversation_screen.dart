import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../models/chat_preview.dart';
import '../services/mock_backend.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversation,
    this.attachedParcelId,
  });

  final PreviewConversation conversation;
  final String? attachedParcelId;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final focus = FocusNode();
  PreviewMessage? replyTo;
  PreviewMessage? editing;
  String? _currentAttachedParcelId;

  @override
  void initState() {
    super.initState();
    _currentAttachedParcelId = widget.attachedParcelId;
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  void notice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    final parcelIdToSend = _currentAttachedParcelId;
    final isHubStaff = widget.conversation.isHubStaff;

    setState(() {
      if (editing != null) {
        editing!.text = text;
        editing!.edited = true;
      } else {
        widget.conversation.messages.add(
          PreviewMessage(
            text: text,
            isMine: true,
            time: DateTime.now(),
            parcelId: parcelIdToSend,
            reply: replyTo == null
                ? null
                : '${replyTo!.isMine ? 'You' : widget.conversation.name}: ${replyTo!.text}',
          ),
        );
      }
      editing = null;
      replyTo = null;
      input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    if (isHubStaff) {
      Future.delayed(const Duration(milliseconds: 400), () async {
        final reply = await MockBackend().sendHubMessage(
          message: text,
          parcelId: parcelIdToSend,
        );
        if (mounted) {
          setState(() {
            widget.conversation.messages.add(
              PreviewMessage(
                text: reply,
                isMine: false,
                time: DateTime.now(),
                parcelId: parcelIdToSend,
              ),
            );
          });
          if (scroll.hasClients) {
            scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        }
      });
    }
  }

  Future<void> actions(PreviewMessage message) async {
    if (message.unsent) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (message.isMine) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Unsend'),
                onTap: () => Navigator.pop(context, 'unsend'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'reply':
        setState(() {
          replyTo = message;
          editing = null;
        });
        focus.requestFocus();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) notice('Message copied');
      case 'edit':
        setState(() {
          editing = message;
          replyTo = null;
          input.text = message.text;
          input.selection = TextSelection.collapsed(offset: input.text.length);
        });
        focus.requestFocus();
      case 'unsend':
        setState(() {
          message.unsent = true;
          if (editing == message) {
            editing = null;
            input.clear();
          }
          if (replyTo == message) replyTo = null;
        });
      default:
        break;
    }
  }

  void attachments() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share with your conversation',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.plum,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final item in [
                    (Icons.photo_outlined, 'Gallery'),
                    (Icons.camera_alt_outlined, 'Camera'),
                    (Icons.insert_drive_file_outlined, 'File'),
                  ])
                    Column(
                      children: [
                        IconButton.filledTonal(
                          tooltip: item.$2,
                          onPressed: () {
                            Navigator.pop(context);
                            notice(
                              'Attachments aren’t connected in this preview.',
                            );
                          },
                          icon: Icon(item.$1),
                        ),
                        Text(item.$2, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  Column(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Attach Parcel',
                        onPressed: () async {
                          Navigator.pop(context);
                          final parcels = await MockBackend().getTodayRunParcels();
                          if (!context.mounted) return;
                          final selected = await showModalBottomSheet<String>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Select Parcel to Attach',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ),
                                  Flexible(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: parcels.length,
                                      itemBuilder: (ctx, i) {
                                        final p = parcels[i];
                                        return ListTile(
                                          leading: const Icon(Icons.inventory_2_outlined, color: AppColors.orange),
                                          title: Text('${p.id} · ${p.receiverName}'),
                                          subtitle: Text('${p.receiverAddress} · Stop #${p.stopOrder}'),
                                          onTap: () => Navigator.pop(ctx, p.id),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (selected != null && mounted) {
                            setState(() => _currentAttachedParcelId = selected);
                          }
                        },
                        icon: const Icon(Icons.inventory_2_outlined),
                      ),
                      const Text('Parcel ID', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Attachments will be available when messaging is connected.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final messages = conversation.messages;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ConversationAvatar(conversation: conversation, radius: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    conversation.description,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Conversation info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(conversation.name),
                content: const Text(
                  'This is a local chat preview. Messages are not delivered to anyone and reset when the app restarts. Long-press a message to reply, copy, edit, or unsend.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
              color: AppColors.softBackground,
              child: const Text(
                'Preview conversation · only visible to you',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const Center(child: Text('No messages yet. Say hello!'))
                  : ListView.builder(
                      controller: scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, reverseIndex) {
                        final index = messages.length - 1 - reverseIndex;
                        final m = messages[index];
                        final showDate =
                            index == 0 ||
                            chatDate(messages[index - 1].time) !=
                                chatDate(m.time);
                        return Column(
                          children: [
                            if (showDate)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  chatDate(m.time).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            Align(
                              alignment: m.isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * .76,
                                  ),
                                  child: GestureDetector(
                                    onLongPress: () => actions(m),
                                    onSecondaryTap: () => actions(m),
                                    child: Column(
                                      crossAxisAlignment: m.isMine
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 11,
                                          ),
                                          decoration: BoxDecoration(
                                            color: m.unsent
                                                ? AppColors.successSoft
                                                : m.isMine
                                                ? AppColors.terracotta
                                                : AppColors.white,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(
                                                20,
                                              ),
                                              topRight: const Radius.circular(
                                                20,
                                              ),
                                              bottomLeft: Radius.circular(
                                                m.isMine ? 20 : 5,
                                              ),
                                              bottomRight: Radius.circular(
                                                m.isMine ? 5 : 20,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (m.reply != null && !m.unsent)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: m.isMine
                                                        ? AppColors.white
                                                              .withValues(
                                                                alpha: .16,
                                                              )
                                                        : AppColors.cream,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: const Border(
                                                      left: BorderSide(
                                                        color: AppColors.plum,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    m.reply!,
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: m.isMine
                                                          ? AppColors.white
                                                          : AppColors.muted,
                                                    ),
                                                  ),
                                                ),
                                              if (m.parcelId != null && !m.unsent)
                                                Container(
                                                  margin: const EdgeInsets.only(bottom: 6),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: m.isMine
                                                        ? AppColors.white.withValues(alpha: 0.22)
                                                        : AppColors.softBackground,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: m.isMine
                                                          ? AppColors.white.withValues(alpha: 0.4)
                                                          : AppColors.border,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.inventory_2_outlined,
                                                        size: 12,
                                                        color: m.isMine
                                                            ? AppColors.white
                                                            : AppColors.terracotta,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Parcel #${m.parcelId}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: m.isMine
                                                              ? AppColors.white
                                                              : AppColors.plum,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              Text(
                                                m.unsent
                                                    ? 'You unsent a message'
                                                    : m.text,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.45,
                                                  fontStyle: m.unsent
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                                  color: m.unsent
                                                      ? AppColors.muted
                                                      : m.isMine
                                                      ? AppColors.white
                                                      : AppColors.plum,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            '${TimeOfDay.fromDateTime(m.time).format(context)}${m.edited && !m.unsent ? ' · Edited' : ''}${m.isMine && !m.unsent ? ' · Local' : ''}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (replyTo != null || editing != null)
              Container(
                padding: const EdgeInsets.only(left: 18),
                color: AppColors.softBackground,
                child: Row(
                  children: [
                    Icon(
                      editing != null ? Icons.edit_outlined : Icons.reply,
                      size: 18,
                      color: AppColors.terracotta,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            editing != null
                                ? 'Editing message'
                                : 'Replying to ${replyTo!.isMine ? 'yourself' : conversation.name}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            (editing ?? replyTo)!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: () => setState(() {
                        if (editing != null) input.clear();
                        editing = null;
                        replyTo = null;
                      }),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            if (_currentAttachedParcelId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppColors.pendingSoft,
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Attached: Parcel #$_currentAttachedParcelId',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _currentAttachedParcelId = null),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: AppColors.softBackground,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final qr in const [
                    "I'm outside",
                    "Receiver not answering",
                    "Wrong address",
                    "Need help",
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: ActionChip(
                        label: Text(
                          qr,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: AppColors.white,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        onPressed: () {
                          input.text = qr;
                          input.selection = TextSelection.collapsed(offset: qr.length);
                          send();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attachments',
                    onPressed: attachments,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.terracotta,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      focusNode: focus,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Type a message...',
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Add a smile',
                          icon: const Icon(
                            Icons.sentiment_satisfied_alt,
                            size: 21,
                          ),
                          onPressed: () {
                            final selection = input.selection;
                            final start = selection.isValid
                                ? selection.start
                                : input.text.length;
                            final end = selection.isValid
                                ? selection.end
                                : input.text.length;
                            final value = input.text.replaceRange(
                              start,
                              end,
                              '😊',
                            );
                            if (value.characters.length <= 4000) {
                              input.value = TextEditingValue(
                                text: value,
                                selection: TextSelection.collapsed(
                                  offset: start + '😊'.length,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: input,
                    builder: (context, value, child) => IconButton.filled(
                      tooltip: editing == null ? 'Send message' : 'Save edit',
                      onPressed: value.text.trim().isEmpty ? null : send,
                      icon: Icon(
                        editing == null
                            ? Icons.send_rounded
                            : Icons.check_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
