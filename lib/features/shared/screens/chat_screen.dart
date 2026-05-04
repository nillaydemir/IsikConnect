import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/current_session.dart';

class ConversationItem {
  final AppUser targetUser;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isUnread;

  ConversationItem({
    required this.targetUser,
    this.lastMessage,
    this.lastMessageTime,
    this.isUnread = false,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<ConversationItem> _conversations = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      final myId = CurrentSession().user!.id;
      final myRole = CurrentSession().user!.role;

      // 1. Fetch active matches
      final matchesResponse = await _supabase
          .from('matches')
          .select()
          .or('student_id.eq.$myId,mentor_id.eq.$myId')
          .eq('status', 'active');

      if (matchesResponse.isEmpty) {
        setState(() {
          _conversations = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Extract IDs of the other users
      List<String> otherUserIds = [];
      for (var match in matchesResponse) {
        if (match['student_id'] == myId) {
          otherUserIds.add(match['mentor_id']);
        } else {
          otherUserIds.add(match['student_id']);
        }
      }

      if (otherUserIds.isEmpty) {
        setState(() {
          _conversations = [];
          _isLoading = false;
        });
        return;
      }

      // 3. Fetch user details
      final usersResponse = await _supabase
          .from('users')
          .select()
          .inFilter('id', otherUserIds);

      final users = usersResponse.map((u) => AppUser.fromJson(u)).toList();

      // 4. Fetch last message for each conversation
      List<ConversationItem> convos = [];
      for (var user in users) {
        try {
          final msgResponse = await _supabase
              .from('messages')
              .select()
              .or('and(sender_id.eq.$myId,receiver_id.eq.${user.id}),and(sender_id.eq.${user.id},receiver_id.eq.$myId)')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          String? lastMsg;
          DateTime? lastMsgTime;
          bool isUnread = false; // Add real unread logic here if you add 'is_read' to messages table

          if (msgResponse != null) {
            lastMsg = msgResponse['content'];
            lastMsgTime = DateTime.parse(msgResponse['created_at']).toLocal();
          }

          convos.add(ConversationItem(
            targetUser: user,
            lastMessage: lastMsg,
            lastMessageTime: lastMsgTime,
            isUnread: isUnread,
          ));
        } catch (e) {
          debugPrint('Error fetching last message for ${user.id}: $e');
          convos.add(ConversationItem(targetUser: user));
        }
      }

      // 5. Sort by lastMessageTime descending
      convos.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1; // Put nulls at the bottom
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      setState(() {
        _conversations = convos;
      });
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0 && now.day == date.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Chats', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            backgroundColor: Colors.white,
            elevation: 0.5,
            centerTitle: false,
            floating: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.black87),
                onPressed: () {},
              ),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_conversations.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet.',
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Match with a mentor or student to start chatting!',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final convo = _conversations[index];
                  final targetUser = convo.targetUser;
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        (targetUser.name ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 20),
                      ),
                    ),
                    title: Text(
                      targetUser.name ?? 'Unknown User',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      convo.lastMessage ?? 'Tap to start conversation',
                      style: TextStyle(
                        color: convo.isUnread ? Colors.black87 : Colors.grey.shade600, 
                        fontSize: 13, 
                        fontWeight: convo.isUnread ? FontWeight.bold : FontWeight.normal
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (convo.lastMessageTime != null)
                          Text(
                            _formatTime(convo.lastMessageTime!),
                            style: TextStyle(
                              color: convo.isUnread ? primaryColor : Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: convo.isUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (convo.isUnread)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '1', // Dummy unread count
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          const SizedBox(height: 20), // Placeholder for alignment
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(targetUser: targetUser),
                        ),
                      ).then((_) {
                        // Refresh the list when coming back from chat detail
                        _fetchConversations();
                      });
                    },
                  );
                },
                childCount: _conversations.length,
              ),
            ),
        ],
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final AppUser targetUser;
  const ChatDetailScreen({super.key, required this.targetUser});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  late final String _myId;

  @override
  void initState() {
    super.initState();
    _myId = CurrentSession().user!.id;
    
    // Listen to messages table
    _messagesStream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((events) {
      // Filter client-side for our conversation
      return events.where((msg) {
        final sender = msg['sender_id'];
        final receiver = msg['receiver_id'];
        return (sender == _myId && receiver == widget.targetUser.id) ||
               (sender == widget.targetUser.id && receiver == _myId);
      }).toList();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    
    try {
      await _supabase.from('messages').insert({
        'sender_id': _myId,
        'receiver_id': widget.targetUser.id,
        'content': text,
        // created_at is handled by DB default now()
      });
      
      // Auto-scroll to bottom after sending
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              child: Text(
                (widget.targetUser.name ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.targetUser.name ?? 'Unknown User', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // "Schedule Meeting" quick action button above messages
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to schedule meeting (placeholder)
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: const Text('Schedule Meeting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                foregroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hi to ${widget.targetUser.name?.split(' ')[0]}!',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                // Schedule scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    return _buildMessageBubble(msg['content'], isMe, primaryColor);
                  },
                );
              },
            ),
          ),
          
          // Chat Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: primaryColor,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, Color primaryColor) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
