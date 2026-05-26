import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/services/current_session.dart';
import 'create_meeting_screen.dart';
import 'video_call_screen.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => MeetingsScreenState();
}

class MeetingsScreenState extends State<MeetingsScreen> {
  final _meetingService = MeetingService();
  final String currentUserId = CurrentSession().user?.id ?? '';
  bool _isMentor = false;
  late Future<List<Map<String, dynamic>>> _meetingsFuture;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _meetingsFuture = _meetingService.getMeetings();
  }

  void fetchMeetings() {
    setState(() {
      _meetingsFuture = _meetingService.getMeetings();
    });
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
          title: const Text(
            'Meetings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          bottom: const TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Workshops'),
              Tab(text: '1-on-1'),
              Tab(text: 'Past'),
            ],
          ),
          actions: [
            if (_isMentor)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: primaryColor),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateMeetingScreen(),
                    ),
                  );
                  if (result == true) {
                    fetchMeetings();
                  }
                },
              ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _meetingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Text('Error loading meetings: ${snapshot.error}'),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No meetings found.'));
            }

            final allMeetings = snapshot.data!;
            final now = DateTime.now();

            final upcomingMeetings = allMeetings.where((m) {
              if (m['meeting_date'] == null) return false;
              return DateTime.parse(m['meeting_date']).isAfter(now);
            }).toList();

            final pastMeetings = allMeetings.where((m) {
              if (m['meeting_date'] == null) return false;
              return DateTime.parse(m['meeting_date']).isBefore(now);
            }).toList();

            pastMeetings.sort((a, b) {
              final dateA = DateTime.parse(a['meeting_date']);
              final dateB = DateTime.parse(b['meeting_date']);
              return dateB.compareTo(dateA);
            });

            return TabBarView(
              children: [
                _MeetingList(
                  type: 'Workshops',
                  meetings: upcomingMeetings
                      .where((m) => m['meeting_type'] == 'Workshop')
                      .toList(),
                  currentUserId: currentUserId,
                  onRefresh: fetchMeetings,
                ),
                _MeetingList(
                  type: '1-on-1',
                  meetings: upcomingMeetings
                      .where((m) =>
                          m['meeting_type'] == '1-on-1' &&
                          (m['mentor_id'] == currentUserId ||
                              m['student_id'] == currentUserId))
                      .toList(),
                  currentUserId: currentUserId,
                  onRefresh: fetchMeetings,
                ),
                _MeetingList(
                  type: 'Past',
                  meetings: pastMeetings
                      .where((m) =>
                          m['meeting_type'] == 'Workshop' ||
                          (m['meeting_type'] == '1-on-1' &&
                              (m['mentor_id'] == currentUserId ||
                                  m['student_id'] == currentUserId)))
                      .toList(),
                  currentUserId: currentUserId,
                  onRefresh: fetchMeetings,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MeetingList extends StatefulWidget {
  final String type;
  final List<Map<String, dynamic>> meetings;
  final String currentUserId;
  final VoidCallback onRefresh;

  const _MeetingList({
    required this.type,
    required this.meetings,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  State<_MeetingList> createState() => _MeetingListState();
}

class _MeetingListState extends State<_MeetingList> {
  final _meetingService = MeetingService();
  final Set<String> _processingMeetings = {};

  Future<void> _handleRegister(String meetingId) async {
    setState(() {
      _processingMeetings.add(meetingId);
    });
    try {
      await _meetingService.registerForWorkshop(meetingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully registered for workshop!')),
        );
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to register: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingMeetings.remove(meetingId);
        });
      }
    }
  }

  Future<void> _handleUnregister(String meetingId) async {
    setState(() {
      _processingMeetings.add(meetingId);
    });
    try {
      await _meetingService.unregisterFromWorkshop(meetingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully unregistered from workshop.')),
        );
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unregister: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingMeetings.remove(meetingId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
      },
      color: primaryColor,
      child: widget.meetings.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 150),
                Center(
                  child: Text(
                    'No meetings here.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: widget.meetings.length,
      itemBuilder: (context, index) {
        final meeting = widget.meetings[index];
        final meetingIdStr = meeting['id'].toString();
        final isWorkshop = meeting['meeting_type'] == 'Workshop';
        final is1on1 = meeting['meeting_type'] == '1-on-1';

        // For 1-on-1s, only host and specific mentee can join.
        // For Workshops, host can join, students must be registered.
        bool isHost = meeting['mentor_id'] == widget.currentUserId;
        bool isJoined = false;
        bool isRegistered = meeting['is_registered'] == true;

        if (isWorkshop) {
          isJoined = isHost || isRegistered;
        } else {
          isJoined = isHost || meeting['student_id'] == widget.currentUserId;
        }

        final meetingDate = meeting['meeting_date'] != null
            ? DateTime.parse(meeting['meeting_date']).toLocal()
            : null;
        final now = DateTime.now();

        final isPast =
            meetingDate != null &&
            now.isAfter(meetingDate.add(const Duration(minutes: 10)));
        final isTooEarly =
            meetingDate != null &&
            now.isBefore(meetingDate.subtract(const Duration(minutes: 10)));

        final dateStr = meetingDate != null
            ? '${meetingDate.day.toString().padLeft(2, '0')}/${meetingDate.month.toString().padLeft(2, '0')}/${meetingDate.year} ${meetingDate.hour.toString().padLeft(2, '0')}:${meetingDate.minute.toString().padLeft(2, '0')}'
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isWorkshop
                            ? Colors.orange.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        meeting['meeting_type'] ?? 'Meeting',
                        style: TextStyle(
                          color: isWorkshop
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                      Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (isHost && !isPast) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_calendar,
                              color: primaryColor,
                              size: 20,
                            ),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              DateTime selectedDate = meetingDate ?? DateTime.now();
                              TimeOfDay selectedTime = meetingDate != null
                                  ? TimeOfDay(hour: meetingDate.hour, minute: meetingDate.minute)
                                  : TimeOfDay.now();

                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );

                              if (date == null) return;

                              if (context.mounted) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                
                                if (time == null) return;
                                
                                try {
                                  await _meetingService.updateMeeting(meetingIdStr, date, time);
                                  widget.onRefresh();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Meeting updated successfully.')),
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
                        if (isHost) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Meeting'),
                                  content: const Text(
                                    'Are you sure you want to delete this meeting?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  await _meetingService.deleteMeeting(
                                    meetingIdStr,
                                  );
                                  widget.onRefresh();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Meeting deleted successfully.',
                                        ),
                                      ),
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  meeting['title'] ?? 'No Title',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Host: $mentorName',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (is1on1 &&
                    (meeting['mentor_id'] == widget.currentUserId ||
                        meeting['student_id'] == widget.currentUserId)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Mentee: $studentName',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (isPast)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Etkinlik geçmiştir.',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Süresi Doldu',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else if (isWorkshop && !isHost && !isRegistered)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _processingMeetings.contains(meetingIdStr)
                          ? null
                          : () => _handleRegister(meetingIdStr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _processingMeetings.contains(meetingIdStr)
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Register for Workshop',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!isJoined) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'You are not a participant in this meeting.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (isTooEarly) {
                              final validTime = meetingDate.subtract(
                                const Duration(minutes: 10),
                              );
                              final timeStr =
                                  '${validTime.hour.toString().padLeft(2, '0')}:${validTime.minute.toString().padLeft(2, '0')}';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Etkinliğe saat $timeStr itibariyle giriş yapabilirsiniz.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VideoCallScreen(channelName: meetingIdStr),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTooEarly
                                ? Colors.orange.shade100
                                : primaryColor,
                            foregroundColor: isTooEarly
                                ? Colors.orange.shade800
                                : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isTooEarly
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock_clock, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Opens at ${meetingDate.subtract(const Duration(minutes: 10)).hour.toString().padLeft(2, '0')}:${meetingDate.subtract(const Duration(minutes: 10)).minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Join Meeting',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      if (isWorkshop && isRegistered && !isHost) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _processingMeetings.contains(meetingIdStr)
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Cancel Registration'),
                                      content: const Text(
                                        'Are you sure you want to cancel your registration for this workshop?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('No'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Cancel Registration'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    _handleUnregister(meetingIdStr);
                                  }
                                },
                          child: _processingMeetings.contains(meetingIdStr)
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Cancel Registration',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
  }
}
