import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forum_post_model.dart';
import '../services/forum_service.dart';

class PostCard extends StatefulWidget {
  final ForumPost post;
  final Future<void> Function() onTap;

  const PostCard({super.key, required this.post, required this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likeCount;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _isLiked = widget.post.isLikedByMe;
      _likeCount = widget.post.likeCount;
    }
  }

  Future<void> _toggleLike() async {
    final bool previousState = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      widget.post.isLikedByMe = _isLiked;
      widget.post.likeCount = _likeCount;
    });
    try {
      await ForumService().toggleLike(widget.post.id, previousState);
    } catch (e) {
      setState(() {
        _isLiked = previousState;
        _likeCount += _isLiked ? 1 : -1;
        widget.post.isLikedByMe = _isLiked;
        widget.post.likeCount = _likeCount;
      });
      debugPrint('Like error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    final bool isWorkshop = widget.post.category == 'Workshops';
    final bool isQnA = widget.post.category == 'Q&A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await widget.onTap();
          // Re-sync state from widget.post which might have been mutated in detail screen
          setState(() {
            _isLiked = widget.post.isLikedByMe;
            _likeCount = widget.post.likeCount;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workshop Image Cover (if any)
            if (isWorkshop && widget.post.imageUrl != null)
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(widget.post.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
            // Card Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Info Row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                        backgroundImage: (widget.post.isAuthorDeleted || widget.post.authorProfileImageUrl == null) 
                          ? null 
                          : NetworkImage(widget.post.authorProfileImageUrl!),
                        child: (widget.post.isAuthorDeleted || widget.post.authorProfileImageUrl == null) 
                          ? Text(
                              widget.post.isAuthorDeleted ? '?' : widget.post.authorName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                            )
                          : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.post.isAuthorDeleted 
                                  ? 'Cancelled Account' 
                                  : widget.post.authorName, 
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 14,
                                  color: widget.post.isAuthorDeleted ? Colors.grey.shade500 : Colors.black,
                                  fontStyle: widget.post.isAuthorDeleted ? FontStyle.italic : FontStyle.normal,
                                )
                              ),
                              if (widget.post.isAuthorDeleted) ...[
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
                              ] else if (widget.post.authorRole == 'mentor') ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blue, size: 14),
                              ]
                            ],
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(widget.post.createdAt),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Q&A Solved Badge
                      if (isQnA && widget.post.isSolved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text('Solved', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Post Title
                  if (widget.post.title.isNotEmpty) ...[
                    Text(
                      widget.post.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Post Content / Description
                  Text(
                    widget.post.content,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    maxLines: isWorkshop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Removed Workshop specifics from card

                  // Tags
                  if (widget.post.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: widget.post.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('#$tag', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  
                  // Interactions Row
                  Row(
                    children: [
                      InkWell(
                        onTap: _toggleLike,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              Icon(
                                _isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, 
                                size: 18, 
                                color: _isLiked ? primaryColor : Colors.grey.shade600
                              ),
                              const SizedBox(width: 4),
                              Text('$_likeCount', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () async {
                          await widget.onTap();
                          setState(() {
                            _isLiked = widget.post.isLikedByMe;
                            _likeCount = widget.post.likeCount;
                          });
                        }, // Opens post detail for comments
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              Icon(Icons.comment_outlined, size: 18, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text('${widget.post.commentCount}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
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
