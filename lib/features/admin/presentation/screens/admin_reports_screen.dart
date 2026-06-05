import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/current_session.dart';
import '../../../../core/services/matching_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _supportTickets = [];
  List<Map<String, dynamic>> _reviews = [];

  // Statistics Dashboard State
  int _studentCount = 0;
  int _mentorCount = 0;
  int _workshopCount = 0;
  int _ticketCount = 0;
  int _openTicketCount = 0;
  int _activeMatchCount = 0;
  List<Map<String, dynamic>> _activeMatches = [];
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchStats();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final ticketsResponse = await _supabase
          .from('support_tickets')
          .select('*, users(first_name, last_name, email, id, is_deleted)')
          .order('created_at', ascending: false);

      final reviewsResponse = await _supabase
          .from('reviews')
          .select('*, mentor:mentors(users(first_name, last_name)), student:students(users(first_name, last_name))')
          .order('created_at', ascending: false);

      setState(() {
        _supportTickets = List<Map<String, dynamic>>.from(ticketsResponse);
        _reviews = List<Map<String, dynamic>>.from(reviewsResponse);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final sRes = await _supabase.from('users').select('id').eq('role', 'student').eq('is_deleted', false);
      final mRes = await _supabase.from('users').select('id').eq('role', 'mentor').eq('is_deleted', false);
      final wRes = await _supabase.from('forum_posts').select('id').eq('category', 'Workshops');
      final tRes = await _supabase.from('support_tickets').select('id');
      final otRes = await _supabase.from('support_tickets').select('id').not('status', 'eq', 'resolved');
      
      int activeMatchesCount = 0;
      List<Map<String, dynamic>> activeMatchesList = [];
      try {
        final amtRes = await _supabase
            .from('matches')
            .select('id, mentor_id, student_id, mentors(users(first_name, last_name, email, profile_image_url)), students(users(first_name, last_name, email, profile_image_url))')
            .eq('status', 'active');
        activeMatchesList = List<Map<String, dynamic>>.from(amtRes);
        activeMatchesCount = activeMatchesList.length;
      } catch (e) {
        debugPrint('Error fetching active matches list: $e');
      }

      if (mounted) {
        setState(() {
          _studentCount = sRes.length;
          _mentorCount = mRes.length;
          _workshopCount = wRes.length;
          _ticketCount = tRes.length;
          _openTicketCount = otRes.length;
          _activeMatchCount = activeMatchesCount;
          _activeMatches = activeMatchesList;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching statistics: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _saveNote(String ticketId, String note) async {
    try {
      await _supabase
          .from('support_tickets')
          .update({'admin_note': note})
          .eq('id', ticketId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markAsResolved(String ticketId, int index) async {
    try {
      await _supabase
          .from('support_tickets')
          .update({'status': 'resolved'})
          .eq('id', ticketId);
      setState(() {
        _supportTickets[index]['status'] = 'resolved';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket marked as resolved.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMessageUserDialog(String targetUserId, String targetUserName, [String? originalMessage]) {
    final TextEditingController messageController = TextEditingController();
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Message $targetUserName',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: messageController,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Type your reply...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final text = messageController.text.trim();
              if (text.isEmpty) return;

              final adminId = CurrentSession().user?.id;
              if (adminId == null) return;

              Navigator.pop(ctx);

              final finalContent = (originalMessage != null && originalMessage.trim().isNotEmpty)
                  ? 'Replying to: "${originalMessage.trim()}"\n\n$text'
                  : text;

              try {
                await _supabase.from('messages').insert({
                  'sender_id': adminId,
                  'receiver_id': targetUserId,
                  'content': finalContent,
                  'is_read': false,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Message sent to $targetUserName.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending message: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            tabs: const [
              Tab(text: 'System Dashboard'),
              Tab(text: 'Support Tickets'),
              Tab(text: 'Student Feedbacks'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStatsTab(),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTicketsList(),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildReviewsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchData();
        await _fetchStats();
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'System Activity Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time overview of the platform performance, engagements, and user actions.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Users Summary Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Students',
                  value: '$_studentCount',
                  icon: Icons.school_outlined,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Mentors',
                  value: '$_mentorCount',
                  icon: Icons.supervisor_account_outlined,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Forum & Mentorship Summary
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Workshops',
                  value: '$_workshopCount',
                  icon: Icons.event_note_outlined,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Active Matches',
                  value: '$_activeMatchCount',
                  icon: Icons.handshake_outlined,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Support Tickets Summary
          _buildStatCard(
            title: 'Support Tickets',
            value: '$_openTicketCount Open / $_ticketCount Total',
            icon: Icons.confirmation_number_outlined,
            color: Colors.red,
            isWide: true,
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Pairings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 38, 55, 140).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_activeMatches.length} Pairs',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color.fromARGB(255, 38, 55, 140),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivePairingsList(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isWide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTicketsList() {
    if (_supportTickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Center(child: Text('No support tickets found')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _supportTickets.length,
        itemBuilder: (context, index) {
          final ticket = _supportTickets[index];
          final userData = ticket['users'];
          final isUserDeleted = userData != null && userData['is_deleted'] == true;
          final userName = userData != null
              ? '${userData['first_name']} ${userData['last_name']}'
              : 'Unknown';
          final targetUserId = ticket['user_id'] as String?;
          final date = DateTime.parse(ticket['created_at']).toLocal();
          final isResolved = ticket['status'] == 'resolved';
          final noteController = TextEditingController(text: ticket['admin_note'] ?? '');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isResolved
                  ? const BorderSide(color: Colors.green, width: 1.5)
                  : BorderSide(color: Colors.grey.shade200),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket['subject'] ?? 'No Subject',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isResolved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 13, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Resolved',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Row(
                children: [
                  Text(
                    isUserDeleted 
                        ? 'From: Cancelled Account · ${date.day}/${date.month}/${date.year}'
                        : 'From: $userName · ${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isUserDeleted ? Colors.grey.shade500 : Colors.black87,
                      fontStyle: isUserDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  if (isUserDeleted) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200, width: 0.5),
                      ),
                      child: Text(
                        'Closed Account',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(ticket['message'] ?? '', style: const TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(height: 16),
                      const Text('Admin Note (Private):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add a private note for yourself or other admins...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Save Note'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: () => _saveNote(ticket['id'], noteController.text.trim()),
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Message User'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color.fromARGB(255, 38, 55, 140),
                            ),
                            onPressed: (targetUserId == null || isUserDeleted)
                                ? null
                                : () => _showMessageUserDialog(targetUserId, userName, ticket['message'] as String?),
                          ),
                          TextButton.icon(
                            icon: Icon(
                              isResolved ? Icons.check_circle : Icons.check_circle_outline,
                              size: 18,
                              color: isResolved ? Colors.green : Colors.grey,
                            ),
                            label: Text(
                              isResolved ? 'Resolved' : 'Mark as Resolved',
                              style: TextStyle(
                                color: isResolved ? Colors.green : Colors.grey.shade600,
                                fontWeight: isResolved ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            onPressed: isResolved
                                ? null
                                : () => _markAsResolved(ticket['id'], index),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Center(child: Text('No feedbacks found')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _reviews.length,
        itemBuilder: (context, index) {
          final review = _reviews[index];

          String mentorName = 'Unknown';
          try {
            final mUser = review['mentor']['users'];
            mentorName = '${mUser['first_name']} ${mUser['last_name']}';
          } catch (_) {}

          String studentName = 'Unknown';
          try {
            final sUser = review['student']['users'];
            studentName = '${sUser['first_name']} ${sUser['last_name']}';
          } catch (_) {}

          final rating = review['rating'] as int;
          final date = DateTime.parse(review['created_at']).toLocal();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('To: $mentorName', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('From: $studentName', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: i < rating ? Colors.amber : Colors.grey[200],
                      ),
                    ),
                  ),
                  if (review['comment'] != null && review['comment'].isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      review['comment'],
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEndPairingDialog(
      String studentId, String mentorId, String studentName, String mentorName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Mentorship Pairing', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to end the pairing between student "$studentName" and mentor "$mentorName"? This will set the match status to cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Pairing', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await MatchingService().cancelMatch(studentId, mentorId, 'admin');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pairing ended successfully.'), backgroundColor: Colors.green),
          );
        }
        await _fetchStats();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error ending pairing: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildActivePairingsList() {
    if (_activeMatches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.handshake_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'No active pairings at the moment.',
                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activeMatches.length,
      itemBuilder: (context, index) {
        final match = _activeMatches[index];
        final studentId = match['student_id'] as String? ?? '';
        final mentorId = match['mentor_id'] as String? ?? '';

        final mentorData = match['mentors'] as Map<String, dynamic>?;
        final mentorUser = mentorData != null ? mentorData['users'] as Map<String, dynamic>? : null;
        final mentorName = mentorUser != null ? '${mentorUser['first_name']} ${mentorUser['last_name']}' : 'Unknown Mentor';
        final mentorEmail = mentorUser != null ? mentorUser['email'] ?? '' : '';
        final mentorPhoto = mentorUser != null ? mentorUser['profile_image_url'] as String? : null;

        final studentData = match['students'] as Map<String, dynamic>?;
        final studentUser = studentData != null ? studentData['users'] as Map<String, dynamic>? : null;
        final studentName = studentUser != null ? '${studentUser['first_name']} ${studentUser['last_name']}' : 'Unknown Student';
        final studentEmail = studentUser != null ? studentUser['email'] ?? '' : '';
        final studentPhoto = studentUser != null ? studentUser['profile_image_url'] as String? : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Student Info
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.orange.withAlpha(25),
                        backgroundImage: studentPhoto != null ? NetworkImage(studentPhoto) : null,
                        child: studentPhoto == null
                            ? Text(
                                studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                            ),
                            Text(
                              studentName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              studentEmail,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Link Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(Icons.swap_horiz_rounded, color: primaryColor.withAlpha(120), size: 24),
                ),

                // Mentor Info
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.withAlpha(25),
                        backgroundImage: mentorPhoto != null ? NetworkImage(mentorPhoto) : null,
                        child: mentorPhoto == null
                            ? Text(
                                mentorName.isNotEmpty ? mentorName[0].toUpperCase() : 'M',
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mentor',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                            ),
                            Text(
                              mentorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              mentorEmail,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'end_pairing') {
                      _showEndPairingDialog(studentId, mentorId, studentName, mentorName);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'end_pairing',
                      child: ListTile(
                        leading: Icon(Icons.link_off, color: Colors.red, size: 18),
                        title: Text('End Pairing', style: TextStyle(color: Colors.red, fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
