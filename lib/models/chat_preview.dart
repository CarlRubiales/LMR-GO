import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class PreviewMessage {
  PreviewMessage({
    required this.text,
    required this.isMine,
    required this.time,
    this.reply,
    this.parcelId,
    this.id,
    this.senderName,
    this.isRead = false,
  });

  String text;
  final bool isMine;
  final DateTime time;
  final String? reply;
  final String? parcelId;
  final int? id;
  final String? senderName;
  bool isRead;
  bool edited = false;
  bool unsent = false;
}

class PreviewConversation {
  PreviewConversation({
    required this.name,
    required this.description,
    required this.icon,
    required this.messages,
    this.unread = 0,
    this.isHubStaff = false,
  });

  String name;
  String description;
  final IconData icon;
  final List<PreviewMessage> messages;
  int unread;
  final bool isHubStaff;

  String get preview {
    if (messages.isEmpty) return 'Tap to message your Branch Sorting Hub';
    final last = messages.last;
    if (last.unsent) return 'Message unsent';
    return '${last.isMine ? 'You: ' : ''}${last.text}';
  }

  DateTime get updatedAt =>
      messages.isEmpty ? DateTime.now() : messages.last.time;
}

List<PreviewConversation> createPreviewConversations() {
  return [
    PreviewConversation(
      name: 'Branch Sorting Hub · Operations & Dispatch',
      description: 'Direct two-way channel with your assigned Hub',
      icon: Icons.warehouse_rounded,
      isHubStaff: true,
      unread: 0,
      messages: [],
    ),
  ];
}

String chatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return 'Today';
  if (day == DateTime(now.year, now.month, now.day - 1)) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}${date.year == now.year ? '' : ', ${date.year}'}';
}

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.conversation,
    this.radius = 25,
  });
  final PreviewConversation conversation;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.blush1;
    Color iconColor = AppColors.orange;

    if (conversation.isHubStaff) {
      bg = AppColors.plum;
      iconColor = AppColors.cream;
    } else if (conversation.description == 'Rider support') {
      bg = AppColors.plum;
      iconColor = AppColors.cream;
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Icon(
        conversation.icon,
        size: radius,
        color: iconColor,
      ),
    );
  }
}
