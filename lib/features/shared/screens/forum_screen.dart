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
  int _refreshCount = 0;

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

  void _onAddPressed() async {
    final role = CurrentSession().user?.role ?? 'student';
    String initialCategory = 'Q&A';
    
    if (role == 'mentor') {
      if (_tabController.index == 0) initialCategory = 'Announcements';
      if (_tabController.index == 2) initialCategory = 'Workshops';
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(initialCategory: initialCategory),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _refreshCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

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
        children: [
          _ForumList(category: 'Announcements', refreshTrigger: _refreshCount),
          _ForumList(category: 'Q&A', refreshTrigger: _refreshCount),
          _ForumList(category: 'Workshops', refreshTrigger: _refreshCount),
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

class _ForumList extends StatefulWidget {
  final String category;
  final int refreshTrigger;
  const _ForumList({required this.category, required this.refreshTrigger});

  @override
  State<_ForumList> createState() => _ForumListState();
}

class _ForumListState extends State<_ForumList> with AutomaticKeepAliveClientMixin {
  late Future<List<ForumPost>> _postsFuture;
  final _forumService = ForumService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  void _loadPosts() {
    _postsFuture = _forumService.fetchPosts(widget.category);
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loadPosts();
      });
    }
    await _postsFuture;
  }

  @override
  void didUpdateWidget(_ForumList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ForumPost>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Error loading posts: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No posts in ${widget.category} yet.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
                  );
                  _refresh();
                },
              );
            },
          );
        },
      ),
    );
  }
}
