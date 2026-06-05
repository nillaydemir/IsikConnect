import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forum_post_model.dart';
import '../models/forum_comment_model.dart';
import '../services/forum_service.dart';
import 'create_post_screen.dart';
import '../../../core/services/current_session.dart';
import '../../../core/services/meeting_service.dart';
import '../../shared/screens/video_call_screen.dart';
import '../../../core/services/api_service.dart';

class PostDetailScreen extends StatefulWidget {
  final ForumPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _forumService = ForumService();
  bool _isCommenting = false;

  late ForumPost _currentPost;
  late bool _isLiked;
  late int _likeCount;
  // Removed _isParticipating and _participantCount as workshops are just announcements
  late bool _isSolved;
  late String? _acceptedAnswerId;

  Map<String, dynamic>? _linkedWorkshop;
  bool _loadingWorkshop = false;
  bool _processingWorkshopRegistration = false;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _isLiked = _currentPost.isLikedByMe;
    _likeCount = _currentPost.likeCount;
    // Removed participant logic
    _isSolved = _currentPost.isSolved;
    _acceptedAnswerId = _currentPost.acceptedAnswerId;
    
    // Mark as read when opened
    _forumService.markAsRead(_currentPost.id);

    if (_currentPost.category == 'Workshops' && _currentPost.meetingLink != null) {
      _loadLinkedWorkshop();
    }
  }

  Future<void> _loadLinkedWorkshop() async {
    if (_currentPost.meetingLink == null) return;
    setState(() => _loadingWorkshop = true);
    try {
      final details = await MeetingService().getMeetingDetails(_currentPost.meetingLink!);
      if (mounted) {
        setState(() {
          _linkedWorkshop = details;
        });
      }
    } catch (e) {
      debugPrint('Error loading linked workshop: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingWorkshop = false);
      }
    }
  }

  Future<void> _handleWorkshopRegistration(String meetingId, bool register) async {
    setState(() => _processingWorkshopRegistration = true);
    try {
      if (register) {
        await MeetingService().registerForWorkshop(meetingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully registered for workshop!'), backgroundColor: Colors.green));
        }
      } else {
        await MeetingService().unregisterFromWorkshop(meetingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully cancelled registration.'), backgroundColor: Colors.orange));
        }
      }
      _loadLinkedWorkshop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _processingWorkshopRegistration = false);
      }
    }
  }

  Future<void> _refreshPost() async {
    try {
      final response = await ApiService().fetchPostDetails(_currentPost.id);

      if (mounted) {
        setState(() {
          _currentPost = ForumPost.fromJson(response, CurrentSession().user!.id);
          _isLiked = _currentPost.isLikedByMe;
          _likeCount = _currentPost.likeCount;
          _isSolved = _currentPost.isSolved;
          _acceptedAnswerId = _currentPost.acceptedAnswerId;
        });
        if (_currentPost.category == 'Workshops' && _currentPost.meetingLink != null) {
          _loadLinkedWorkshop();
        }
      }
    } catch (e) {
      debugPrint('Error refreshing post: $e');
    }
  }

  Future<void> _editPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          initialCategory: _currentPost.category,
          editPost: _currentPost,
        ),
      ),
    );

    if (result == true) {
      _refreshPost();
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final isAdmin = CurrentSession().user?.role == 'admin';
        await _forumService.deletePost(_currentPost.id, isAdmin: isAdmin);
        if (!mounted) return;
        Navigator.pop(context, true); // Pop back to feed with true to refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting post: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final isAdmin = CurrentSession().user?.role == 'admin';
        await _forumService.deleteComment(commentId, isAdmin: isAdmin);
        setState(() {}); // Refresh comments list
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isCommenting = true);
    try {
      await _forumService.addComment(_currentPost.id, _commentController.text.trim());
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
      setState(() {}); // trigger rebuild to fetch new comments
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCommenting = false);
    }
  }

  Future<void> _toggleLike() async {
    final bool previousState = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      _currentPost.isLikedByMe = _isLiked;
      _currentPost.likeCount = _likeCount;
    });
    try {
      await _forumService.toggleLike(_currentPost.id, previousState);
    } catch (e) {
      setState(() {
        _isLiked = previousState;
        _likeCount += _isLiked ? 1 : -1;
        _currentPost.isLikedByMe = _isLiked;
        _currentPost.likeCount = _likeCount;
      });
      debugPrint('Like error: $e');
    }
  }



  // Removed _toggleParticipation logic since forum workshops are just announcements

  Future<void> _acceptAnswer(String commentId) async {
    try {
      await _forumService.acceptAnswer(_currentPost.id, commentId);
      setState(() {
        _isSolved = true;
        _acceptedAnswerId = commentId;
      });
    } catch (e) {
      debugPrint('Accept answer error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    final isQnA = _currentPost.category == 'Q&A';
    final isMyPost = _currentPost.authorId == CurrentSession().user?.id;
    final isAdmin = CurrentSession().user?.role == 'admin';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_currentPost.category, style: const TextStyle(color: Colors.black87, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (isMyPost || isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editPost();
                } else if (value == 'delete') {
                  _deletePost();
                }
              },
              itemBuilder: (context) => [
                if (isMyPost)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPost,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                // Author info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      backgroundImage: (_currentPost.isAuthorDeleted || _currentPost.authorProfileImageUrl == null) 
                        ? null 
                        : NetworkImage(_currentPost.authorProfileImageUrl!),
                      child: (_currentPost.isAuthorDeleted || _currentPost.authorProfileImageUrl == null)
                        ? Text(
                            _currentPost.isAuthorDeleted ? '?' : _currentPost.authorName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                          )
                        : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _currentPost.isAuthorDeleted ? 'Cancelled Account' : _currentPost.authorName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _currentPost.isAuthorDeleted ? Colors.grey.shade500 : Colors.black,
                                fontStyle: _currentPost.isAuthorDeleted ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                            if (_currentPost.isAuthorDeleted) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade200, width: 0.5),
                                ),
                                child: Text(
                                  'Closed Account',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else if (_currentPost.authorRole == 'mentor') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.blue, size: 16),
                            ]
                          ],
                        ),
                        Text(
                          DateFormat('MMMM d, yyyy • h:mm a').format(_currentPost.createdAt),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                if (_currentPost.title.isNotEmpty) ...[
                  Text(
                    _currentPost.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                ],

                // Q&A Solved Badge
                if (isQnA && _isSolved) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text('This question has an accepted answer', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Content
                Text(
                  _currentPost.content,
                  style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                // Image
                if (_currentPost.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(_currentPost.imageUrl!, width: double.infinity, fit: BoxFit.cover),
                  ),
                
                // Associated Workshop Card
                if (_currentPost.category == 'Workshops' && _currentPost.meetingLink != null) ...[
                  const SizedBox(height: 20),
                  _loadingWorkshop
                      ? const Center(child: CircularProgressIndicator())
                      : _linkedWorkshop == null
                          ? const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Linked workshop could not be loaded or was deleted by the host.'),
                              ),
                            )
                          : () {
                              final meeting = _linkedWorkshop!;
                              final meetingIdStr = meeting['id'].toString();
                              final String currentUserId = CurrentSession().user?.id ?? '';
                              
                              bool isHost = meeting['mentor_id'] == currentUserId;
                              bool isRegistered = meeting['is_registered'] == true;
                              bool isJoined = isHost || isRegistered;

                              final meetingDate = meeting['meeting_date'] != null
                                  ? DateTime.parse(meeting['meeting_date']).toLocal()
                                  : null;
                              final now = DateTime.now();

                              final isPast = meetingDate != null &&
                                  now.isAfter(meetingDate.add(const Duration(minutes: 10)));
                              final isTooEarly = meetingDate != null &&
                                  now.isBefore(meetingDate.subtract(const Duration(minutes: 10)));

                              final dateStr = meetingDate != null
                                  ? DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(meetingDate)
                                  : 'Unknown Date';

                              final mentorName = meeting['mentor'] != null
                                  ? '${meeting['mentor']['first_name']} ${meeting['mentor']['last_name']}'
                                  : 'Mentor';

                              return Card(
                                elevation: 3,
                                shadowColor: Colors.orange.withValues(alpha: 0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.orange.shade100, width: 1.5),
                                ),
                                color: Colors.orange.shade50.withValues(alpha: 0.3),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.event_available, color: Colors.orange.shade700, size: 22),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Associated Workshop',
                                                style: TextStyle(
                                                  color: Colors.orange.shade800,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (isRegistered)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Registered',
                                                style: TextStyle(
                                                  color: Colors.green.shade800,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        meeting['title'] ?? 'Workshop Session',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              dateStr,
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.face, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Instructor: $mentorName',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      if (isPast)
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey.shade200,
                                              disabledBackgroundColor: Colors.grey.shade200,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: const Text(
                                              'Time Limit',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                            ),
                                          ),
                                        )
                                      else if (!isHost && !isRegistered)
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _processingWorkshopRegistration
                                                ? null
                                                : () => _handleWorkshopRegistration(meetingIdStr, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange.shade600,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: _processingWorkshopRegistration
                                                ? const SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                  )
                                                : const Text('Register for Workshop', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        )
                                      else
                                        Column(
                                          children: [
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  if (!isJoined) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('You are not a participant in this workshop.')),
                                                    );
                                                    return;
                                                  }

                                                  if (isTooEarly) {
                                                    final validTime = meetingDate.subtract(const Duration(minutes: 10));
                                                    final timeStr = DateFormat('h:mm a').format(validTime);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('You can join the event at $timeStr.'),
                                                        backgroundColor: Colors.orange,
                                                      ),
                                                    );
                                                    return;
                                                  }

                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => VideoCallScreen(channelName: meetingIdStr),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isTooEarly ? Colors.orange.shade100 : primaryColor,
                                                  foregroundColor: isTooEarly ? Colors.orange.shade800 : Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                child: isTooEarly
                                                    ? Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          const Icon(Icons.lock_clock, size: 18),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            'Opens at ${DateFormat('h:mm a').format(meetingDate.subtract(const Duration(minutes: 10)))}',
                                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ],
                                                      )
                                                    : const Text('Join Meeting', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                            if (isRegistered && !isHost) ...[
                                              const SizedBox(height: 8),
                                              TextButton(
                                                onPressed: _processingWorkshopRegistration
                                                    ? null
                                                    : () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (context) => AlertDialog(
                                                            title: const Text('Cancel Registration'),
                                                            content: const Text('Are you sure you want to cancel your registration for this workshop?'),
                                                            actions: [
                                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                                              TextButton(
                                                                onPressed: () => Navigator.pop(context, true),
                                                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                                child: const Text('Cancel Registration'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirm == true) {
                                                          _handleWorkshopRegistration(meetingIdStr, false);
                                                        }
                                                      },
                                                child: const Text('Cancel Registration', style: TextStyle(color: Colors.redAccent)),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }(),
                ],
                const SizedBox(height: 24),
                const Divider(),

                // Interactions
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _toggleLike,
                      icon: Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: _isLiked ? primaryColor : Colors.grey.shade600),
                      label: Text('$_likeCount', style: TextStyle(color: Colors.grey.shade700)),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),

                // Comments List
                FutureBuilder<List<ForumComment>>(
                  future: _forumService.fetchComments(_currentPost.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Text('Error loading comments');
                    }
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return Text('No comments yet. Be the first to share your thoughts!', style: TextStyle(color: Colors.grey.shade500));
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      separatorBuilder: (c, i) => const Divider(height: 32),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final isAccepted = comment.isAccepted || comment.id == _acceptedAnswerId;

                        return Container(
                          padding: isAccepted ? const EdgeInsets.all(12) : null,
                          decoration: isAccepted ? BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ) : null,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: (comment.isAuthorDeleted || comment.authorProfileImageUrl == null) 
                                  ? null 
                                  : NetworkImage(comment.authorProfileImageUrl!),
                                child: (comment.isAuthorDeleted || comment.authorProfileImageUrl == null)
                                  ? Text(comment.isAuthorDeleted ? '?' : comment.authorName.substring(0, 1), style: const TextStyle(fontSize: 12))
                                  : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          comment.isAuthorDeleted ? 'Cancelled Account' : comment.authorName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: comment.isAuthorDeleted ? Colors.grey.shade500 : Colors.black,
                                            fontStyle: comment.isAuthorDeleted ? FontStyle.italic : FontStyle.normal,
                                          ),
                                        ),
                                        if (comment.isAuthorDeleted) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.red.shade200, width: 0.5),
                                            ),
                                            child: Text(
                                              'Closed Account',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ] else if (comment.authorRole == 'mentor') ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, color: Colors.blue, size: 14),
                                        ],
                                        const Spacer(),
                                        Text(DateFormat('MMM d, h:mm a').format(comment.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        if (comment.authorId == CurrentSession().user?.id || CurrentSession().user?.role == 'admin') ...[
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _deleteComment(comment.id),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(comment.content, style: const TextStyle(fontSize: 14)),
                                    
                                    if (isQnA && isMyPost && !_isSolved && !isAccepted)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => _acceptAnswer(comment.id),
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text('Accept Answer', style: TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
                                        ),
                                      ),
                                    if (isAccepted) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                                          const SizedBox(width: 4),
                                          Text('Accepted Answer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                        ],
                                      )
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
          
          // Comment Input Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isCommenting 
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                        icon: const Icon(Icons.send, color: primaryColor),
                        onPressed: _submitComment,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
