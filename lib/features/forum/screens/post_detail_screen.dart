import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forum_post_model.dart';
import '../models/forum_comment_model.dart';
import '../services/forum_service.dart';
import '../../../core/services/current_session.dart';

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

  late bool _isLiked;
  late int _likeCount;
  late bool _isBookmarked;
  late bool _isParticipating;
  late int _participantCount;
  late bool _isSolved;
  late String? _acceptedAnswerId;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likeCount;
    _isBookmarked = widget.post.isBookmarkedByMe;
    _isParticipating = widget.post.isParticipating;
    _participantCount = widget.post.participantCount;
    _isSolved = widget.post.isSolved;
    _acceptedAnswerId = widget.post.acceptedAnswerId;
    
    // Mark as read when opened
    _forumService.markAsRead(widget.post.id);
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isCommenting = true);
    try {
      await _forumService.addComment(widget.post.id, _commentController.text.trim());
      _commentController.clear();
      FocusScope.of(context).unfocus();
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
    try {
      await _forumService.toggleLike(widget.post.id, _isLiked);
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  Future<void> _toggleBookmark() async {
    try {
      await _forumService.toggleBookmark(widget.post.id, _isBookmarked);
      setState(() {
        _isBookmarked = !_isBookmarked;
      });
    } catch (e) {
      debugPrint('Bookmark error: $e');
    }
  }

  Future<void> _toggleParticipation() async {
    try {
      await _forumService.toggleWorkshopParticipation(widget.post.id, _isParticipating);
      setState(() {
        _isParticipating = !_isParticipating;
        _participantCount += _isParticipating ? 1 : -1;
      });
    } catch (e) {
      debugPrint('Participation error: $e');
    }
  }

  Future<void> _acceptAnswer(String commentId) async {
    try {
      await _forumService.acceptAnswer(widget.post.id, commentId);
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
    final isWorkshop = widget.post.category == 'Workshops';
    final isQnA = widget.post.category == 'Q&A';
    final isMyPost = widget.post.authorId == CurrentSession().user?.id;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.post.category, style: const TextStyle(color: Colors.black87, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Author info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      backgroundImage: widget.post.authorProfileImageUrl != null ? NetworkImage(widget.post.authorProfileImageUrl!) : null,
                      child: widget.post.authorProfileImageUrl == null 
                        ? Text(
                            widget.post.authorName.substring(0, 1).toUpperCase(),
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
                            Text(widget.post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (widget.post.authorRole == 'mentor') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.blue, size: 16),
                            ]
                          ],
                        ),
                        Text(
                          DateFormat('MMMM d, yyyy • h:mm a').format(widget.post.createdAt),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                if (widget.post.title.isNotEmpty) ...[
                  Text(
                    widget.post.title,
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
                  widget.post.content,
                  style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                // Image
                if (widget.post.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(widget.post.imageUrl!, width: double.infinity, fit: BoxFit.cover),
                  ),
                
                // Workshop specific card
                if (isWorkshop) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Workshop Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        if (widget.post.eventDate != null)
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                              const SizedBox(width: 8),
                              Text(DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(widget.post.eventDate!), style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        const SizedBox(height: 8),
                        if (widget.post.participantLimit != null)
                          Row(
                            children: [
                              const Icon(Icons.group, size: 16, color: Colors.black54),
                              const SizedBox(width: 8),
                              Text('$_participantCount / ${widget.post.participantLimit} Participants', style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final bool isPast = widget.post.eventDate != null && widget.post.eventDate!.isBefore(DateTime.now());
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isPast ? null : _toggleParticipation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPast ? Colors.grey.shade300 : (_isParticipating ? Colors.white : primaryColor),
                                  foregroundColor: isPast ? Colors.grey.shade600 : (_isParticipating ? Colors.red : Colors.white),
                                  elevation: 0,
                                  side: (!isPast && _isParticipating) ? const BorderSide(color: Colors.red) : null,
                                ),
                                child: Text(isPast ? 'Workshop Ended' : (_isParticipating ? 'Leave Workshop' : 'Join Workshop')),
                              ),
                            );
                          }
                        )
                      ],
                    ),
                  ),
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
                  future: _forumService.fetchComments(widget.post.id),
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
                                backgroundImage: comment.authorProfileImageUrl != null ? NetworkImage(comment.authorProfileImageUrl!) : null,
                                child: comment.authorProfileImageUrl == null 
                                  ? Text(comment.authorName.substring(0, 1), style: const TextStyle(fontSize: 12))
                                  : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if (comment.authorRole == 'mentor') ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, color: Colors.blue, size: 14),
                                        ],
                                        const Spacer(),
                                        Text(DateFormat('MMM d, h:mm a').format(comment.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
