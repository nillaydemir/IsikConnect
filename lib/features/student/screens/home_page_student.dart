import 'package:flutter/material.dart';
import '../../profile/screens/profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/user_models.dart';
import '../../../core/services/matching_service.dart';
import '../../../core/services/current_session.dart';

class HomePageStudent extends StatefulWidget {
  const HomePageStudent({super.key});

  @override
  State<HomePageStudent> createState() => _HomePageStudentState();
}

class _HomePageStudentState extends State<HomePageStudent> {
  int _selectedIndex = 0;

  // The 5 tab pages using IndexedStack to preserve state
  final List<Widget> _pages = const [
    _HomeTab(),
    _MyMentorTab(),
    _PlaceholderTab(title: 'Available workshops'),
    _PlaceholderTab(title: 'Community discussions'),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(
      255,
      38,
      55,
      140,
    ); // User requested theme color

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light clean background
      appBar: AppBar(
        title: const Text(
          'Işık Connect',
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
        ),
        backgroundColor: Colors.white,
        elevation: 1, // Soft shadow
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
              color: Colors.black,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed, // Needed when items > 3
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'My Mentor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event),
              label: 'Workshops',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Forum'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// Reusable tab for Home body
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Welcome to Işık Connect',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          _buildCardSection('Upcoming Workshops', Icons.event_available),
        ],
      ),
    );
  }

  Widget _buildCardSection(String title, IconData icon) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 38, 55, 140),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: const Color.fromARGB(255, 38, 55, 140),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text(
                  'No items to show at the moment.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable placeholder component for other tabs
class _PlaceholderTab extends StatelessWidget {
  final String title;
  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _MyMentorTab extends StatefulWidget {
  const _MyMentorTab();

  @override
  State<_MyMentorTab> createState() => _MyMentorTabState();
}

class _MyMentorTabState extends State<_MyMentorTab> {
  Student? _currentStudent;
  Mentor? _matchedMentor;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentStudentAndMatch();
  }

  Future<void> _loadCurrentStudentAndMatch() async {
    final user = CurrentSession().user;
    if (user != null) {
      _currentStudent = Student(
        id: user.id,
        name: user.name ?? 'Unknown Student',
        email: user.email,
        department: user.department ?? '',
        classLevel: user.classLevel ?? '',
        requestedTopics: user.interests ?? [],
        availableDays: user.availableDays ?? [],
      );
      
      // Fetch persistent match from database
      await _fetchExistingMatch();
    }
  }

  Future<void> _fetchExistingMatch() async {
    if (_currentStudent == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('students')
          .select('matched_mentor_id, mentors(*, users(*))')
          .eq('id', _currentStudent!.id)
          .maybeSingle();

      if (response != null && response['mentors'] != null) {
        final mentorData = response['mentors'];
        final userData = mentorData['users'];
        
        _matchedMentor = Mentor(
          id: mentorData['id'],
          name: '${userData['first_name']} ${userData['last_name']}',
          email: userData['email'],
          department: userData['department'] ?? '',
          graduationYear: mentorData['graduation_year']?.toString() ?? '',
          skills: List<String>.from(mentorData['interests'] ?? []),
          company: mentorData['company'],
          jobTitle: mentorData['job_title'],
          maxCapacity: mentorData['max_students'] ?? 1,
          currentStudentsCount: mentorData['current_student_count'] ?? 0,
          availableDays: List<String>.from(mentorData['available_days'] ?? []),
        );
      }
    } catch (e) {
      print('Error fetching existing match: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _runMatching() async {
    if (_currentStudent == null) {
      setState(() {
        _errorMessage = "Could not load your student profile.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final matchingService = MatchingService();
      final bestMentor = await matchingService.findAndSaveMatch(_currentStudent!);

      setState(() {
        _matchedMentor = bestMentor;
        if (_matchedMentor == null) {
          _errorMessage = "No suitable mentor found right now. Please check your interests or available days and try again later.";
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error finding mentor: $e';
      });
      print('Matching error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _cancelMatch() async {
    if (_currentStudent == null || _matchedMentor == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Match'),
        content: Text('Are you sure you want to end your mentorship with ${_matchedMentor!.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Match'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final matchingService = MatchingService();
      await matchingService.cancelMatch(_currentStudent!.id, _matchedMentor!.id);
      
      setState(() {
        _matchedMentor = null;
        _errorMessage = "Match cancelled successfully.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cancelling match: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding the best mentor for you from the database...'),
          ],
        ),
      );
    }

    if (_matchedMentor == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'You don\'t have a mentor yet.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_currentStudent != null)
                Text(
                  'Click the button below to run the AI Matching Algorithm based on your department and interests: \n${_currentStudent!.requestedTopics.join(', ')}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _runMatching,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Find Mentor'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Assigned Mentor',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color.fromARGB(
                          255,
                          38,
                          55,
                          140,
                        ).withValues(alpha: 0.1),
                        child: Text(
                          _matchedMentor!.name.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 38, 55, 140),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _matchedMentor!.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_matchedMentor!.jobTitle ?? 'Mentor'} at ${_matchedMentor!.company ?? ''}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.school,
                    'Department',
                    _matchedMentor!.department,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.email, 'Email', _matchedMentor!.email),
                  const SizedBox(height: 16),
                  const Text(
                    'Mentor Skills',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _matchedMentor!.skills.map((skill) {
                      bool isMatch = _currentStudent?.requestedTopics.contains(
                        skill,
                      ) ?? false;
                      return Chip(
                        label: Text(skill),
                        backgroundColor: isMatch
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isMatch
                              ? Colors.green.shade700
                              : Colors.black87,
                          fontWeight: isMatch
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isMatch
                              ? Colors.green.shade200
                              : Colors.grey.shade300,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _cancelMatch,
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Cancel Match'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey.shade600)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}


