import 'package:flutter/material.dart';
import '../../forum/services/forum_service.dart';
import '../../forum/models/forum_post_model.dart';
import '../../forum/widgets/post_card.dart';
import '../../forum/screens/post_detail_screen.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: primaryColor),
        elevation: 0.5,
        actions: [
          StreamBuilder<List<ForumPost>>(
            stream: ForumService().getAllPostsStream(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Badge(
                  label: Text('$count'),
                  child: const Icon(Icons.notifications),
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<List<ForumPost>>(
        stream: ForumService().getAllPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No announcements yet.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
