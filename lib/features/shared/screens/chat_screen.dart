import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/current_session.dart';
import '../../../core/services/message_service.dart';
import '../../../core/services/matching_service.dart';
import '../../../core/services/api_service.dart';
import 'dart:async';

class ConversationItem {
  final AppUser targetUser;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isActiveMatch;
  final String? label;

  ConversationItem({
    required this.targetUser,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isActiveMatch = true,
    this.label,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isLoading = true;
  List<ConversationItem> _conversations = [];
  StreamSubscription? _conversationsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    // Listen for real-time changes
    _conversationsSubscription = MessageService()
        .getConversationsChangedStream()
        .listen((_) {
          _fetchConversations(showLoading: false);
        });
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchConversations({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await ApiService().fetchConversations();
      
      List<ConversationItem> convos = [];
      for (var item in response) {
        final Map<String, dynamic> convoJson = Map<String, dynamic>.from(item);
        final targetUser = AppUser.fromJson(convoJson['targetUser']);
        final lastMsg = convoJson['lastMessage'] as String?;
        final lastMsgTimeStr = convoJson['lastMessageTime'] as String?;
        final lastMsgTime = lastMsgTimeStr != null ? DateTime.parse(lastMsgTimeStr).toLocal() : null;
        final unreadCount = convoJson['unreadCount'] as int? ?? 0;
        final isActive = convoJson['isActiveMatch'] as bool? ?? false;
        final label = convoJson['label'] as String?;

        convos.add(
          ConversationItem(
            targetUser: targetUser,
            lastMessage: lastMsg,
            lastMessageTime: lastMsgTime,
            unreadCount: unreadCount,
            isActiveMatch: isActive,
            label: label,
          ),
        );
      }

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
      body: RefreshIndicator(
        onRefresh: () => _fetchConversations(showLoading: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
            title: const Text(
              'Chats',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0.5,
            centerTitle: false,
            floating: true,
            automaticallyImplyLeading: false,
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
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Match with a mentor or student to start chatting!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final convo = _conversations[index];
                final targetUser = convo.targetUser;

                final isAdminChat = targetUser.role == 'admin';
                final displayName = isAdminChat ? 'IşıkConnect Support' : (targetUser.name ?? 'Unknown User');

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: isAdminChat
                        ? Colors.blue.shade100
                        : primaryColor.withValues(alpha: 0.1),
                    backgroundImage: (!isAdminChat && targetUser.profileImageUrl != null)
                        ? NetworkImage(targetUser.profileImageUrl!)
                        : null,
                    child: isAdminChat
                        ? Icon(Icons.support_agent, color: Colors.blue.shade700, size: 26)
                        : (targetUser.profileImageUrl == null
                            ? Text(
                                (targetUser.name ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  fontSize: 20,
                                ),
                              )
                            : null),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isAdminChat && convo.label != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: convo.label == 'Job'
                                ? Colors.teal.shade50
                                : (convo.label == 'Mentee' || convo.label == 'Mentor')
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: convo.label == 'Job'
                                  ? Colors.teal.shade200
                                  : (convo.label == 'Mentee' || convo.label == 'Mentor')
                                      ? Colors.blue.shade200
                                      : Colors.grey.shade300,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            convo.label!,
                            style: TextStyle(
                              color: convo.label == 'Job'
                                  ? Colors.teal.shade800
                                  : (convo.label == 'Mentee' || convo.label == 'Mentor')
                                      ? Colors.blue.shade800
                                      : Colors.grey.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    convo.lastMessage ?? 'Tap to start conversation',
                    style: TextStyle(
                      color: convo.unreadCount > 0
                          ? Colors.black87
                          : Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: convo.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
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
                            color: convo.unreadCount > 0
                                ? primaryColor
                                : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: convo.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (convo.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${convo.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 20),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          targetUser: targetUser,
                          isActiveMatch: convo.isActiveMatch,
                          label: convo.label,
                        ),
                      ),
                    ).then((_) {
                      _fetchConversations();
                    });
                  },
                );
              }, childCount: _conversations.length),
            ),
        ],
      ),
    ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final AppUser targetUser;
  final bool isActiveMatch;
  final String? label;
  const ChatDetailScreen({
    super.key,
    required this.targetUser,
    this.isActiveMatch = true,
    this.label,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
 
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  late final StreamController<List<Map<String, dynamic>>> _messagesStreamController;
  StreamSubscription? _messagesSubscription;
  late final String _myId;
 
  StreamSubscription? _matchSubscription;
  StreamSubscription? _userSubscription;
  bool _isMatchActive = true;
  bool _isTargetUserDeleted = false;
 
  @override
  void initState() {
    super.initState();
    _myId = CurrentSession().user!.id;
    _isMatchActive = widget.isActiveMatch;
 
    _messagesStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
    _messagesStream = _messagesStreamController.stream;
 
    _initMessagesStream();
    _markMessagesAsRead();
    _initSubscriptions();
  }
 
  void _initMessagesStream() {
    Future<void> refresh() async {
      try {
        final msgs = await ApiService().fetchChat(widget.targetUser.id);
        if (!_messagesStreamController.isClosed) {
          _messagesStreamController.add(msgs);
        }
      } catch (e) {
        debugPrint('Error fetching chat messages: $e');
      }
    }
 
    refresh();
 
    _messagesSubscription = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .handleError((e) => debugPrint('Realtime messages stream error: $e'))
        .listen((_) => refresh());
  }
 
  void _initSubscriptions() {
    Future<void> updateStatus() async {
      try {
        final status = await ApiService().checkConnectionStatus(widget.targetUser.id);
        if (mounted) {
          setState(() {
            _isMatchActive = status['isActiveMatch'] ?? false;
            _isTargetUserDeleted = status['isTargetUserDeleted'] ?? false;
          });
        }
      } catch (e) {
        debugPrint('Error checking connection status: $e');
      }
    }
 
    updateStatus();
 
    _matchSubscription = _supabase
        .from('matches')
        .stream(primaryKey: ['id'])
        .handleError((e) => debugPrint('Realtime matches stream error: $e'))
        .listen((_) => updateStatus());
 
    _userSubscription = _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', widget.targetUser.id)
        .handleError((e) => debugPrint('Realtime users stream error: $e'))
        .listen((_) => updateStatus());
  }
 
  Future<void> _markMessagesAsRead() async {
    try {
      await ApiService().markMessagesAsRead(widget.targetUser.id);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }
 
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _matchSubscription?.cancel();
    _userSubscription?.cancel();
    _messagesSubscription?.cancel();
    _messagesStreamController.close();
    super.dispose();
  }
 
  Future<void> _showEndMentorshipDialog() async {
    final myRole = CurrentSession().user!.role;
    String warningMessage = 'Are you sure you want to end your mentorship with ${widget.targetUser.name}? This action cannot be undone.';
    
    if (myRole == 'student') {
      try {
        final cancelledCount = await MatchingService().getCancelledMatchCount(_myId);
        final remainingRights = 2 - cancelledCount;
        
        if (remainingRights > 1) {
          warningMessage += '\n\nIf you cancel, you will have $remainingRights matching rights remaining for this academic year (starting September).';
        } else if (remainingRights == 1) {
          warningMessage += '\n\nWARNING: This is your last cancellation right! If you cancel this match, you will NOT be able to match with a new mentor until September.';
        } else {
          warningMessage += '\n\nWARNING: You have 0 matching rights left! If you cancel this match, you will NOT be able to match with a new mentor until September.';
        }
      } catch (e) {
        debugPrint('Error fetching remaining rights: $e');
      }
    } else if (myRole == 'mentor') {
      try {
        final cancelledCount = await MatchingService().getMentorCancelledMatchCount(_myId);
        
        final mentorRes = await ApiService().fetchUserById(_myId);
        final maxStudents = mentorRes['max_students'] as int? ?? 1;
        final limit = maxStudents * 2;
        final remainingRights = limit - cancelledCount;
 
        if (remainingRights > 1) {
          warningMessage += '\n\nIf you cancel, you will have $remainingRights matching cancellation rights remaining for this academic year (starting September).';
        } else if (remainingRights == 1) {
          warningMessage += '\n\nWARNING: This is your last cancellation right! If you cancel this match, you will NOT be able to receive new student assignments until September.';
        } else {
          warningMessage += '\n\nWARNING: You have reached your cancellation limit! If you cancel this match, the system will NOT match you with a new student until September.';
        }
      } catch (e) {
        debugPrint('Error calculating mentor limit: $e');
        warningMessage += '\n\nNote: Your cancellation limit for this academic year is twice your maximum capacity.';
      }
    }
 
    if (!mounted) return;
 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Mentorship'),
        content: Text(warningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _endMentorship();
            },
            child: const Text(
              'End Mentorship',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
 
  void _showDeleteChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this chat? This action cannot be undone and all message history will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteChat();
            },
            child: const Text(
              'Delete Chat',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
 
  Future<void> _deleteChat() async {
    try {
      await ApiService().deleteChat(widget.targetUser.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred while deleting the chat.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
 
  Future<void> _endMentorship() async {
    try {
      final myRole = CurrentSession().user!.role;
      final studentId = myRole == 'mentor' ? widget.targetUser.id : _myId;
      final mentorId = myRole == 'mentor' ? _myId : widget.targetUser.id;
 
      await MatchingService().cancelMatch(studentId, mentorId, myRole);
 
      await ApiService().sendMessage(
        widget.targetUser.id,
        'Mentorship ended by ${myRole == 'mentor' ? 'mentor' : 'student'}.',
      );
 
      if (mounted) {
        Navigator.pop(context); // Go back to chats list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mentorship ended successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error ending mentorship: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred while ending the mentorship.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
 
  Future<void> _sendMessage() async {
    if (!_isMatchActive || _isTargetUserDeleted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot send messages because the match has been terminated or the user has been deleted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
 
    _messageController.clear();
 
    try {
      await ApiService().sendMessage(widget.targetUser.id, text);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
          ),
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
    final isAdminChat = widget.targetUser.role == 'admin';
    final displayName = isAdminChat ? 'IşıkConnect Support' : (widget.targetUser.name ?? 'Unknown User');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isAdminChat
                  ? Colors.blue.shade100
                  : primaryColor.withValues(alpha: 0.1),
              backgroundImage: (!isAdminChat && widget.targetUser.profileImageUrl != null)
                  ? NetworkImage(widget.targetUser.profileImageUrl!)
                  : null,
              child: isAdminChat
                  ? Icon(Icons.support_agent, color: Colors.blue.shade700, size: 16)
                  : (widget.targetUser.profileImageUrl == null
                      ? Text(
                          (widget.targetUser.name ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 14,
                          ),
                        )
                      : null),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isAdminChat && widget.label != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.label == 'Job'
                            ? Colors.teal.shade50
                            : (widget.label == 'Mentee' || widget.label == 'Mentor')
                                ? Colors.blue.shade50
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.label == 'Job'
                              ? Colors.teal.shade200
                              : (widget.label == 'Mentee' || widget.label == 'Mentor')
                                  ? Colors.blue.shade200
                                  : Colors.grey.shade300,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        widget.label!,
                        style: TextStyle(
                          color: widget.label == 'Job'
                              ? Colors.teal.shade800
                              : (widget.label == 'Mentee' || widget.label == 'Mentor')
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 'end_mentorship') {
                _showEndMentorshipDialog();
              } else if (value == 'delete_chat') {
                _showDeleteChatDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              if (_isMatchActive && !_isTargetUserDeleted)
                const PopupMenuItem(
                  value: 'end_mentorship',
                  child: Text(
                    'End Mentorship',
                    style: TextStyle(color: Colors.red),
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'delete_chat',
                  child: Text(
                    'Delete Chat',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    return _buildMessageBubble(
                      msg['content'],
                      isMe,
                      primaryColor,
                    );
                  },
                );
              },
            ),
          ),

          // Chat Input or Disabled Message
          if (_isMatchActive && !_isTargetUserDeleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
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
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              color: Colors.grey[200],
              child: SafeArea(
                top: false,
                child: Text(
                  isAdminChat
                      ? 'This is a support message. You cannot reply.'
                      : _isTargetUserDeleted
                          ? 'This user has deleted their account. You can no longer send messages.'
                          : 'This mentorship match has been terminated. You can no longer send messages.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
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
