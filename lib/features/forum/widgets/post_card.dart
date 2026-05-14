import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forum_post_model.dart';
import '../services/forum_service.dart';

class PostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onTap;

  const PostCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    final bool isWorkshop = post.category == 'Workshops';
    final bool isQnA = post.category == 'Q&A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workshop Image Cover (if any)
            if (isWorkshop && post.imageUrl != null)
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(post.imageUrl!),
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
                        backgroundImage: post.authorProfileImageUrl != null ? NetworkImage(post.authorProfileImageUrl!) : null,
                        child: post.authorProfileImageUrl == null 
                          ? Text(
                              post.authorName.substring(0, 1).toUpperCase(),
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
                              Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              if (post.authorRole == 'mentor') ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blue, size: 14),
                              ]
                            ],
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(post.createdAt),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Q&A Solved Badge
                      if (isQnA && post.isSolved)
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
                  if (post.title.isNotEmpty) ...[
                    Text(
                      post.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Post Content / Description
                  Text(
                    post.content,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    maxLines: isWorkshop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Workshop specifics
                  if (isWorkshop && post.eventDate != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, h:mm a').format(post.eventDate!),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13),
                        ),
                        const Spacer(),
                        if (post.participantLimit != null)
                           Text('${post.participantCount}/${post.participantLimit} Joined', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ],

                  // Tags
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: post.tags.map((tag) => Container(
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
                        onTap: () => ForumService().toggleLike(post.id, post.isLikedByMe),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              Icon(
                                post.isLikedByMe ? Icons.thumb_up : Icons.thumb_up_alt_outlined, 
                                size: 18, 
                                color: post.isLikedByMe ? primaryColor : Colors.grey.shade600
                              ),
                              const SizedBox(width: 4),
                              Text('${post.likeCount}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: onTap, // Opens post detail for comments
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              Icon(Icons.comment_outlined, size: 18, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text('${post.commentCount}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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
