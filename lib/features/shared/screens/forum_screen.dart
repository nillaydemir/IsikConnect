import 'package:flutter/material.dart';
import '../../forum/services/forum_service.dart';
import '../../forum/models/forum_post_model.dart';
import '../../forum/widgets/post_card.dart';
import '../../forum/screens/create_post_screen.dart';
import '../../forum/screens/post_detail_screen.dart';
import '../../../core/services/current_session.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAddPressed() {
    final role = CurrentSession().user?.role ?? 'student';
    String initialCategory = 'Q&A';
    
    if (role == 'mentor') {
      if (_tabController.index == 0) initialCategory = 'Announcements';
      if (_tabController.index == 2) initialCategory = 'Workshops';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(initialCategory: initialCategory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    final role = CurrentSession().user?.role ?? 'student';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Community Forum', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Announcements'),
            Tab(text: 'Q&A'),
            Tab(text: 'Workshops'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ForumList(category: 'Announcements'),
          _ForumList(category: 'Q&A'),
          _ForumList(category: 'Workshops'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPressed,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ForumList extends StatelessWidget {
  final String category;
  const _ForumList({required this.category});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ForumPost>>(
      stream: ForumService().getPostsStream(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No posts in $category yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
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
    );
  }
}
