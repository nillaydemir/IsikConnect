import 'package:flutter/material.dart';
import '../../profile/screens/profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/user_models.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/matching_service.dart';
import '../../../core/services/current_session.dart';
import '../../shared/screens/chat_screen.dart';
import '../../shared/screens/forum_screen.dart';
import '../../shared/screens/meetings_screen.dart';

class HomePageStudent extends StatefulWidget {
  const HomePageStudent({super.key});

  @override
  State<HomePageStudent> createState() => _HomePageStudentState();
}

class _HomePageStudentState extends State<HomePageStudent> {
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

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
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
                    'Student',
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
          
          // Next Session Card
          const Text('Next Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color.fromARGB(255, 38, 55, 140), Color.fromARGB(255, 60, 80, 180)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color.fromARGB(255, 38, 55, 140).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('1-on-1 Mentorship', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                const Text('Career Guidance & Portfolio Review', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    const Text('Today, 2:00 PM', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const Spacer(),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white,
                      child: Text('M', style: TextStyle(color: Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // My Mentor Section embedded
          const Text('My Mentor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const SizedBox(
            height: 400, // Constrain height for the embedded widget
            child: _MyMentorTab(),
          ),
          
          const SizedBox(height: 32),
          const Text('Recommended Workshops', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) {
                return Container(
                  width: 240,
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 20),
                      ),
                      const Spacer(),
                      const Text('Flutter State Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Tomorrow, 5:00 PM', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
        final mentorId = mentorData['id'];

        // Fetch ratings separately to bypass missing FK relationship
        double avgRating = 0.0;
        int reviewCount = 0;
        try {
          final reviewsRes = await Supabase.instance.client
              .from('reviews')
              .select('rating')
              .eq('mentor_id', mentorId);
          
          if (reviewsRes.isNotEmpty) {
            final sum = reviewsRes.fold<num>(0, (prev, r) => prev + (r['rating'] as num));
            avgRating = sum / reviewsRes.length;
            reviewCount = reviewsRes.length;
          }
        } catch (e) {
          print('Warning: Could not fetch reviews for mentor: $e');
        }

        _matchedMentor = Mentor(
          id: mentorId,
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
          avgRating: avgRating,
          reviewCount: reviewCount,
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

  void _showRatingDialog() {
    if (_matchedMentor == null) return;

    int selectedRating = 5;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Rate Your Mentor', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How was your experience with ${_matchedMentor!.name}?', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 40,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your feedback (optional)',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final studentId = CurrentSession().user?.id;
                if (studentId == null) return;

                try {
                  await Supabase.instance.client.from('reviews').insert({
                    'mentor_id': _matchedMentor!.id,
                    'student_id': studentId,
                    'rating': selectedRating,
                    'comment': commentController.text.trim(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: Colors.green),
                    );
                    _fetchExistingMatch(); // Refresh to update rating in UI
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving review: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
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
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(
                            targetUserId: _matchedMentor!.id,
                          ),
                        ),
                      );
                    },
                    child: Row(
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
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              if (_matchedMentor!.reviewCount > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      _matchedMentor!.avgRating.toStringAsFixed(1),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      ' (${_matchedMentor!.reviewCount} reviews)',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'New Mentor',
                                  style: TextStyle(color: Colors.blue.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  targetUser: AppUser(
                                    id: _matchedMentor!.id,
                                    email: _matchedMentor!.email,
                                    role: 'mentor',
                                    name: _matchedMentor!.name,
                                    createdAt: DateTime.now(),
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Chat', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color.fromARGB(255, 38, 55, 140),
                            side: const BorderSide(color: Color.fromARGB(255, 38, 55, 140)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showRatingDialog,
                          icon: const Icon(Icons.star_outline, size: 18),
                          label: const Text('Rate', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber.shade800,
                            side: BorderSide(color: Colors.amber.shade800),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfilePage(
                                  targetUserId: _matchedMentor!.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_outline, size: 18),
                          label: const Text('Profile', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
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


