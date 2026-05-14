import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/current_session.dart';
import '../../../core/models/app_user_model.dart';
import '../../profile/screens/profile_page.dart';
import '../../shared/screens/chat_screen.dart';
import '../../shared/screens/meetings_screen.dart';
import '../../shared/screens/create_meeting_screen.dart';
import '../../shared/screens/forum_screen.dart';
import '../../forum/services/forum_service.dart';
import '../../forum/models/forum_post_model.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/services/message_service.dart';

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
          StreamBuilder<int>(
            stream: ForumService().getUnreadCountStream(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: primaryColor),
                    onPressed: () {
                      Navigator.pushNamed(context, '/announcements');
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
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
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(
              icon: StreamBuilder<int>(
                stream: MessageService().getUnreadCountStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Stack(
                    children: [
                      const Icon(Icons.chat_bubble_rounded),
                      if (count > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              label: 'Chat',
            ),
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
  List<Map<String, dynamic>> _upcomingMeetings = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMentees();
    _fetchUpcomingMeetings();
  }

  Future<void> _fetchUpcomingMeetings() async {
    try {
      final meetings = await MeetingService().getMeetings();
      final now = DateTime.now();
      setState(() {
        _upcomingMeetings = meetings.where((m) {
          if (m['meeting_date'] == null) return false;
          final date = DateTime.parse(m['meeting_date']);
          return date.isAfter(now);
        }).toList();
      });
    } catch (e) {
      print('Error fetching upcoming meetings: $e');
    }
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
    final user = CurrentSession().user;
    final userName = user?.name?.split(' ').first ?? 'Mentor';
    final profileImageUrl = user?.profileImageUrl;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Good Morning,',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    userName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl == null 
                  ? Text(
                      userName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 20),
                    )
                  : null,
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
          _upcomingMeetings.isEmpty 
            ? _buildCardSection('No upcoming sessions.', Icons.event_available, [])
            : _buildMeetingsList(),
          
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
              backgroundImage: userData['profile_image_url'] != null ? NetworkImage(userData['profile_image_url']) : null,
              child: userData['profile_image_url'] == null
                  ? Text(
                      userData['first_name']?[0] ?? 'S',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 38, 55, 140)),
                    )
                  : null,
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

  Widget _buildMeetingsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _upcomingMeetings.length > 3 ? 3 : _upcomingMeetings.length, // Show max 3 on home page
      itemBuilder: (context, index) {
        final meeting = _upcomingMeetings[index];
        final isWorkshop = meeting['meeting_type'] == 'Workshop';
        final date = DateTime.parse(meeting['meeting_date']).toLocal();
        final dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

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
              backgroundColor: isWorkshop ? Colors.orange.shade50 : Colors.blue.shade50,
              child: Icon(
                isWorkshop ? Icons.group : Icons.person,
                color: isWorkshop ? Colors.orange.shade700 : Colors.blue.shade700,
              ),
            ),
            title: Text(
              meeting['title'] ?? 'Meeting',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              dateStr,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWorkshop ? Colors.orange.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meeting['meeting_type'] ?? '',
                    style: TextStyle(
                      color: isWorkshop ? Colors.orange.shade700 : Colors.blue.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Meeting'),
                        content: const Text('Are you sure you want to delete this meeting?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
                        await MeetingService().deleteMeeting(meeting['id'].toString());
                        _fetchUpcomingMeetings();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Meeting deleted successfully.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Removed unused _PlaceholderTab
