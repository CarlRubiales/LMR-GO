import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class PreviewMessage {
  PreviewMessage({
    required this.text,
    required this.isMine,
    required this.time,
    this.reply,
    this.parcelId,
  });

  String text;
  final bool isMine;
  final DateTime time;
  final String? reply;
  final String? parcelId;
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

  final String name;
  final String description;
  final IconData icon;
  final List<PreviewMessage> messages;
  int unread;
  final bool isHubStaff;

  String get preview {
    if (messages.isEmpty) return 'Start a conversation';
    final last = messages.last;
    if (last.unsent) return 'Message unsent';
    return '${last.isMine ? 'You: ' : ''}${last.text}';
  }

  DateTime get updatedAt =>
      messages.isEmpty ? DateTime(2000) : messages.last.time;
}

List<PreviewConversation> createPreviewConversations() {
  final now = DateTime.now();
  final morning = now.subtract(const Duration(minutes: 5));
  return [
    PreviewConversation(
      name: 'Lumora Sorting Center · Hub Staff',
      description: 'Lumora Sorting Hub · Dispatch & Staff',
      icon: Icons.warehouse_rounded,
      isHubStaff: true,
      unread: 0,
      messages: [
        PreviewMessage(
          text:
              'Rider Dispatch: 5 assigned parcels for Route MNL-4 have been scanned into Bin Bay A-04. Please scan each parcel at the hub to verify before departure.',
          isMine: false,
          time: morning.subtract(const Duration(minutes: 20)),
        ),
        PreviewMessage(
          text: 'Understood. Heading to Bay A-04 now.',
          isMine: true,
          time: morning.subtract(const Duration(minutes: 15)),
        ),
        PreviewMessage(
          text:
              'Notice: Road closure reported near Boni Ave. Please follow alternate route on Shaw Blvd.',
          isMine: false,
          time: morning,
        ),
      ],
    ),
    PreviewConversation(
      name: 'Mango Tree Grocer',
      description: 'Store',
      icon: Icons.storefront_rounded,
      unread: 2,
      messages: [
        PreviewMessage(
          text: 'Hi! I’m your LMR GO courier for order RG-1842.',
          isMine: true,
          time: morning.subtract(const Duration(minutes: 8)),
        ),
        PreviewMessage(
          text: 'Hi there! We’re getting the last few items ready.',
          isMine: false,
          time: morning.subtract(const Duration(minutes: 6)),
        ),
        PreviewMessage(
          text: 'Great, I’ll meet you at the pickup counter.',
          isMine: true,
          time: morning.subtract(const Duration(minutes: 4)),
        ),
        PreviewMessage(
          text: 'Order is packed and ready for pickup.',
          isMine: false,
          time: morning,
        ),
        PreviewMessage(
          text: 'Please ask for Mia when you arrive. Thank you!',
          isMine: false,
          time: morning.add(const Duration(minutes: 1)),
        ),
      ],
    ),
    PreviewConversation(
      name: 'LMR GO Support',
      description: 'Rider support',
      icon: Icons.support_agent_rounded,
      messages: [
        PreviewMessage(
          text:
              'Welcome to LMR GO support. How can we help with your delivery?',
          isMine: false,
          time: now.subtract(const Duration(days: 1)),
        ),
      ],
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
