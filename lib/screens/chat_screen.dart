import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../models/chat_preview.dart';
import '../widgets/app_page.dart';
import 'conversation_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.conversations,
    this.initialParcelId,
  });

  final List<PreviewConversation>? conversations;
  final String? initialParcelId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final fallbackConversations = createPreviewConversations();
  List<PreviewConversation> get conversations =>
      widget.conversations ?? fallbackConversations;
  final search = TextEditingController();
  bool unreadOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialParcelId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final hub = conversations.firstWhere(
          (c) => c.isHubStaff,
          orElse: () => conversations.first,
        );
        open(hub, attachedParcelId: widget.initialParcelId);
      });
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> open(
    PreviewConversation conversation, {
    String? attachedParcelId,
  }) async {
    setState(() => conversation.unread = 0);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          conversation: conversation,
          attachedParcelId: attachedParcelId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final visible =
        conversations
            .where(
              (c) =>
                  (!unreadOnly || c.unread > 0) &&
                  ('${c.name} ${c.preview}'.toLowerCase().contains(query)),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return AppPage(
      title: 'Messages',
      subtitle: 'Keep everyone in the loop',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(color: AppColors.plum, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inputIcon),
              hintText: 'Search conversations',
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(search.clear),
                      icon: const Icon(Icons.close, size: 18, color: AppColors.inputIcon),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: !unreadOnly,
                onSelected: (_) => setState(() => unreadOnly = false),
              ),
              ChoiceChip(
                label: const Text('Unread'),
                selected: unreadOnly,
                onSelected: (_) => setState(() => unreadOnly = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            EmptyCard(
              title: query.isNotEmpty
                  ? 'No conversations found'
                  : 'You’re all caught up',
              message: query.isNotEmpty
                  ? 'Try another name or message.'
                  : 'No unread messages.',
              icon: Icons.chat_bubble_outline_rounded,
            )
          else
            Card(
              margin: EdgeInsets.zero,
              color: AppColors.cream,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.line),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 82, endIndent: 16),
                itemBuilder: (context, index) {
                  final c = visible[index];
                  final date = chatDate(c.updatedAt);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    onTap: () => open(c),
                    leading: ConversationAvatar(conversation: c),
                    title: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.plum,
                        fontSize: 14,
                        fontWeight: c.unread > 0
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        c.isHubStaff ? 'Hub Dispatch · ${c.preview}' : c.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: c.unread > 0
                              ? AppColors.ink
                              : AppColors.muted,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          date == 'Today'
                              ? TimeOfDay.fromDateTime(c.updatedAt)
                                    .format(context)
                              : date,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (c.unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              '${c.unread}',
                              style: GoogleFonts.inter(
                                color: AppColors.cream,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 18),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blush1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: AppColors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Direct two-way channel connected to Central Sorting Hub staff & dispatch.',
                    style: GoogleFonts.inter(
                      color: AppColors.plum,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Chat preview · messages stay in this session',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
