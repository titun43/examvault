// =============================================================================
// ExamVault - Help & Support Screen
// In-app support chat. Replaces the old mailto: link flow.
//
// Two-pane layout:
//   1. Ticket list: shows the user's existing tickets (open ones first),
//      with a "New Conversation" button at the top.
//   2. Ticket detail: chat UI — user can send messages, see admin replies,
//      all in real-time via Firestore onSnapshot.
//
// Firestore:
//   - support_tickets/{ticketId}              (ticket metadata)
//   - support_tickets/{ticketId}/messages/{messageId}  (chat messages)
//
// Both the user-side (this screen) and the admin-side (admin panel Support
// section) read/write the same collections. Real-time onSnapshot on both
// sides means replies appear instantly.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/support_ticket_model.dart';
import '../../models/support_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const _TicketList(),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Please sign in to contact support.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header / contact hint
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(Icons.headset_mic, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How can we help?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Start a conversation and our team will reply as soon as possible.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // New conversation button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openNewTicketDialog(context, user.id,
                  user.name, user.email, user.phoneNumber),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'New Conversation',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        // Ticket list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('support_tickets')
                .where('userId', isEqualTo: user.id)
                .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load conversations. Check your connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final rawDocs = snapshot.data?.docs ?? [];
              // Sort client-side so OPEN conversations stay on top and
              // RESOLVED ones sink to the bottom. Within each group, newer
              // (updatedAt) first. This makes sure that once admin resolves a
              // ticket it no longer lingers at the top of the user's list.
              final docs = [...rawDocs]..sort((a, b) {
                  final ta = SupportTicketModel.fromFirestore(a);
                  final tb = SupportTicketModel.fromFirestore(b);
                  final aOpen = ta.status == TicketStatus.open;
                  final bOpen = tb.status == TicketStatus.open;
                  if (aOpen != bOpen) return aOpen ? -1 : 1;
                  return tb.updatedAt.compareTo(ta.updatedAt);
                });
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No conversations yet',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "New Conversation" above to send us a message.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final ticket = SupportTicketModel.fromFirestore(docs[i]);
                  return _TicketTile(ticket: ticket);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openNewTicketDialog(BuildContext context, String userId, String name,
      String? email, String? phone) {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('New Conversation'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      hintText: 'e.g. Payment not received',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a subject';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: messageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Message *',
                      hintText: 'Describe your issue...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a message';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final subject = subjectCtrl.text.trim();
                final text = messageCtrl.text.trim();
                Navigator.of(dialogCtx).pop();
                await _createTicket(
                    context, userId, name, email, phone, subject, text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  /// Creates a new ticket doc + initial user message, then navigates into
  /// the chat view. Errors show a SnackBar — the user can retry.
  Future<void> _createTicket(
    BuildContext context,
    String userId,
    String name,
    String? email,
    String? phone,
    String subject,
    String text,
  ) async {
    try {
      final now = DateTime.now();
      final ticketRef =
          await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': userId,
        'userName': name,
        'userEmail': email,
        'userPhone': phone,
        'subject': subject,
        'lastMessage': text,
        'lastSender': 'user',
        'status': 'open',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      // First message in the subcollection.
      await ticketRef.collection('messages').add({
        'sender': 'user',
        'text': text,
        'createdAt': Timestamp.fromDate(now),
      });
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _TicketChatScreen(ticketId: ticketRef.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start conversation. Please try again.'),
        ),
      );
    }
  }
}

class _TicketTile extends StatelessWidget {
  final SupportTicketModel ticket;
  const _TicketTile({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final isOpen = ticket.status == TicketStatus.open;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ticket.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            // Status chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isOpen
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isOpen ? 'Open' : 'Resolved',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isOpen ? Colors.orange : Colors.green,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  ticket.lastSender == 'admin'
                      ? Icons.support_agent
                      : ticket.lastSender == 'system'
                          ? Icons.info_outline
                          : Icons.person,
                  size: 12,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ticket.lastMessage.isEmpty
                        ? 'No messages yet'
                        : ticket.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(ticket.updatedAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _TicketChatScreen(ticketId: ticket.id),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// =============================================================================
// Chat Screen — opens one ticket, shows messages, lets user send more.
// =============================================================================

class _TicketChatScreen extends StatefulWidget {
  final String ticketId;
  const _TicketChatScreen({required this.ticketId});

  @override
  State<_TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<_TicketChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final now = DateTime.now();
      final ticketRef = FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId);
      await ticketRef.collection('messages').add({
        'sender': 'user',
        'text': text,
        'createdAt': Timestamp.fromDate(now),
      });
      // Denormalize preview + bump updatedAt.
      await ticketRef.update({
        'lastMessage': text,
        'lastSender': 'user',
        'updatedAt': Timestamp.fromDate(now),
        // Reopen if previously resolved — user is following up.
        'status': 'open',
      });
      _msgCtrl.clear();
      // Auto-scroll to bottom after send.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Ticket subject banner
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('support_tickets')
                .doc(widget.ticketId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || !snap.data!.exists) {
                return const SizedBox.shrink();
              }
              final ticket =
                  SupportTicketModel.fromFirestore(snap.data!);
              final isOpen = ticket.status == TicketStatus.open;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.subject,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? Colors.orange.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isOpen ? 'Open' : 'Resolved',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOpen ? Colors.orange : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .doc(widget.ticketId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('Could not load messages.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Send the first message below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                // Auto-scroll to bottom when new messages arrive.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final msg = SupportMessageModel.fromFirestore(docs[i]);
                    return _MessageBubble(message: msg);
                  },
                );
              },
            ),
          ),
          // Compose row — disabled if ticket is resolved.
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('support_tickets')
                .doc(widget.ticketId)
                .snapshots(),
            builder: (context, snap) {
              final isResolved = snap.hasData &&
                  snap.data!.exists &&
                  SupportTicketModel.fromFirestore(snap.data!).status ==
                      TicketStatus.resolved;
              return Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                      top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          enabled: !isResolved,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization:
                              TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: isResolved
                                ? 'This conversation is resolved. Start a new one if you need more help.'
                                : 'Type your message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: (isResolved || _sending) ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.send,
                                color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessageModel message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    // System messages (resolve / reopen events) render as a centered pill
    // so they read clearly as status events, not chat from either party.
    if (message.sender == MessageSender.system) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      );
    }
    final isUser = message.sender == MessageSender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primaryColor
              : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.support_agent,
                        size: 12, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Support Team',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isUser
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }
}
