import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/services/current_session.dart';
import 'create_meeting_screen.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _meetingService = MeetingService();
  final String currentUserId = CurrentSession().user?.id ?? '';
  bool _isMentor = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    if (currentUserId.isEmpty) return;
    try {
      final userRes = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', currentUserId)
          .single();
      setState(() {
        _isMentor = userRes['role'] == 'mentor';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Meetings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          bottom: const TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Workshops'),
              Tab(text: 'My Meetings'),
            ],
          ),
          actions: [
            if (_isMentor)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: primaryColor),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateMeetingScreen()),
                  );
                  if (result == true) {
                    setState(() {}); // Refresh future builder
                  }
                },
              ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _meetingService.getMeetings(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error loading meetings: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No meetings found.'));
            }

            final allMeetings = snapshot.data!;

            return TabBarView(
              children: [
                _MeetingList(type: 'All', meetings: allMeetings, currentUserId: currentUserId),
                _MeetingList(
                  type: 'Workshops',
                  meetings: allMeetings.where((m) => m['meeting_type'] == 'Workshop').toList(),
                  currentUserId: currentUserId,
                ),
                _MeetingList(
                  type: 'My Meetings',
                  meetings: allMeetings.where((m) => m['mentor_id'] == currentUserId || m['student_id'] == currentUserId).toList(),
                  currentUserId: currentUserId,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MeetingList extends StatelessWidget {
  final String type;
  final List<Map<String, dynamic>> meetings;
  final String currentUserId;

  const _MeetingList({
    required this.type,
    required this.meetings,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    if (meetings.isEmpty) {
      return const Center(child: Text('No meetings here.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final isWorkshop = meeting['meeting_type'] == 'Workshop';
        final is1on1 = meeting['meeting_type'] == '1-on-1';
        
        // If current user is mentor, they host it. If current user is student, they either joined or it's their 1-1
        bool isMyMeeting = meeting['mentor_id'] == currentUserId || meeting['student_id'] == currentUserId;
        bool isJoined = isMyMeeting; 

        final dateStr = meeting['meeting_date'] != null 
          ? DateTime.parse(meeting['meeting_date']).toLocal().toString().substring(0, 16) 
          : 'Unknown Date';

        final mentorName = meeting['mentor'] != null 
          ? '${meeting['mentor']['first_name']} ${meeting['mentor']['last_name']}'
          : 'Mentor';
          
        final studentName = meeting['student'] != null
          ? '${meeting['student']['first_name']} ${meeting['student']['last_name']}'
          : 'Unknown Mentee';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isWorkshop ? Colors.orange.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        meeting['meeting_type'] ?? 'Meeting',
                        style: TextStyle(
                          color: isWorkshop ? Colors.orange.shade700 : Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  meeting['title'] ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('Host: $mentorName', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  ],
                ),
                if (is1on1 && (meeting['mentor_id'] == currentUserId || meeting['student_id'] == currentUserId)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('Mentee: $studentName', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isJoined ? 'You are already in this meeting' : 'Joined successfully!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isJoined ? Colors.grey.shade200 : primaryColor,
                      foregroundColor: isJoined ? Colors.black87 : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isJoined ? 'Joined' : 'Join Meeting',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
