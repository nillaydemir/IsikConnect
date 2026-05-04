import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/current_session.dart';
import '../../../core/models/app_user_model.dart';
import '../../profile/screens/profile_page.dart';
import '../../shared/screens/chat_screen.dart';
import '../../shared/screens/forum_screen.dart';
import '../../shared/screens/meetings_screen.dart';
import '../../shared/screens/create_meeting_screen.dart';

class HomePageMentor extends StatefulWidget {
  const HomePageMentor({super.key});

  @override
  State<HomePageMentor> createState() => _HomePageMentorState();
}

class _HomePageMentorState extends State<HomePageMentor> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _HomeTab(),
    ChatScreen(),
    ForumScreen(),
    MeetingsScreen(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Işık Connect',
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: primaryColor),
            onPressed: () {
              Navigator.pushNamed(context, '/announcements');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'Forum'),
            BottomNavigationBarItem(icon: Icon(Icons.videocam_rounded), label: 'Meetings'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// Reusable tab for Home body

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Map<String, dynamic>> _mentees = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMentees();
  }

  Future<void> _fetchMentees() async {
    final mentorId = CurrentSession().user?.id;
    if (mentorId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get students matched with this mentor
      final response = await Supabase.instance.client
          .from('students')
          .select('*, users(*)')
          .eq('matched_mentor_id', mentorId);

      setState(() {
        _mentees = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching mentees: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good Morning,',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    'Mentor',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.person, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Quick Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateMeetingScreen()),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create Meeting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          const Text('Upcoming Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildCardSection('No upcoming sessions.', Icons.event_available, []),
          
          const SizedBox(height: 32),
          const Text('My Mentees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildMenteesSection(),
        ],
      ),
    );
  }

  Widget _buildMenteesSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mentees.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'No mentees assigned yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _mentees.length,
      itemBuilder: (context, index) {
        final mentee = _mentees[index];
        final userData = mentee['users'];
        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color.fromARGB(255, 38, 55, 140).withValues(alpha: 0.1),
              child: Text(
                userData['first_name']?[0] ?? 'S',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 38, 55, 140)),
              ),
            ),
            title: Text(
              '${userData['first_name']} ${userData['last_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${userData['department']} - ${mentee['class_level']}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    targetUserId: mentee['id'],
                  ),
                ),
              );
            },
            trailing: IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Color.fromARGB(255, 38, 55, 140)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      targetUser: AppUser(
                        id: mentee['id'],
                        email: userData['email'] ?? '',
                        role: 'student',
                        name: '${userData['first_name']} ${userData['last_name']}',
                        createdAt: DateTime.now(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardSection(String title, IconData icon, List<dynamic> items) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          title, // Display the provided title (e.g. "No upcoming sessions.")
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

// Removed unused _PlaceholderTab
