import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../core/models/user_models.dart';
import '../../../core/services/matching_service.dart';

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
    _ProfileTab(),
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
  // Dummy Logged In Student
  late Student _currentStudent;
  Mentor? _matchedMentor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Simulate logged in student who selected specific department and interests
    _currentStudent = Student(
      id: 's1',
      name: 'Nilay Demir',
      email: 'nilay@isik.edu.tr',
      department: 'Computer Engineering',
      classLevel: '3rd Year',
      requestedTopics: ['Mobile Development', 'AI / Machine Learning'],
    );
  }

  void _runMatching() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Dummy mentors in the system
    List<Mentor> mentors = [
      Mentor(
        id: 'm1',
        name: 'Ahmet Yılmaz',
        email: 'ahmet@company.com',
        department: 'Software Engineering',
        graduationYear: '2020',
        skills: ['Web Development', 'Backend Development'],
        company: 'Tech Corp',
        jobTitle: 'Backend Developer',
        maxCapacity: 3,
      ),
      Mentor(
        id: 'm2',
        name: 'Elif Şahin',
        email: 'elif@startup.io',
        department: 'Computer Engineering',
        graduationYear: '2019',
        skills: ['UI/UX'],
        company: 'Flutter Innovators',
        jobTitle: 'Mobile Lead',
        maxCapacity: 2,
      ),
      Mentor(
        id: 'm3',
        name: 'Can Aydın',
        email: 'can@data.com',
        department: 'Computer Engineering',
        graduationYear: '2021',
        skills: ['Mobile Development', 'AI / Machine Learning'],
        company: 'DataTech',
        jobTitle: 'Data Engineer',
        maxCapacity: 1,
      ),
    ];

    final matchingService = MatchingService();
    final results = matchingService.assignMentors([_currentStudent], mentors);

    setState(() {
      _matchedMentor = results[_currentStudent];
      _isLoading = false;
    });
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
            Text('Finding the best mentor for you...'),
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
              Text(
                'Click the button below to run the AI Matching Algorithm based on your department and interests: \n${_currentStudent.requestedTopics.join(', ')}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
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
                      bool isMatch = _currentStudent.requestedTopics.contains(
                        skill,
                      );
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.message),
                      label: const Text('Message Mentor'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color.fromARGB(255, 38, 55, 140),
                        side: const BorderSide(
                          color: Color.fromARGB(255, 38, 55, 140),
                        ),
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

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _isUploading = false;
  String? _uploadStatus;

  Future<void> _uploadDocument() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isUploading = true;
          _uploadStatus = 'Uploading document...';
        });

        File file = File(result.files.single.path!);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        
        // Ensure you have a 'documents' bucket in Supabase
        await Supabase.instance.client.storage
            .from('documents')
            .upload(fileName, file);

        final documentUrl = Supabase.instance.client.storage
            .from('documents')
            .getPublicUrl(fileName);

        // Assume the user is logged in, use their real ID or a dummy UUID for now
        final dummyUserId = Supabase.instance.client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';

        await Supabase.instance.client.from('applications').insert({
          'user_id': dummyUserId,
          'role': 'student',
          'document_url': documentUrl,
          'status': 'pending',
        });

        setState(() {
          _isUploading = false;
          _uploadStatus = 'Document uploaded successfully! Application pending.';
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Error uploading: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Student Verification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To access all features and get matched with mentors, please upload your student certificate (Öğrenci Belgesi).',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),
                  if (_uploadStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _uploadStatus!,
                        style: TextStyle(
                            color: _uploadStatus!.contains('Error') ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadDocument,
                      icon: _isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : const Icon(Icons.upload_file),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload Öğrenci Belgesi'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

