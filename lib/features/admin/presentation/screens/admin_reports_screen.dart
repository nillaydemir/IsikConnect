import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/current_session.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchData();
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

  void _showMessageUserDialog(String targetUserId, String targetUserName) {
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

              try {
                await _supabase.from('messages').insert({
                  'sender_id': adminId,
                  'receiver_id': targetUserId,
                  'content': text,
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
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            tabs: const [
              Tab(text: 'Support Tickets'),
              Tab(text: 'Student Feedbacks'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _buildTicketsList(),
                      _buildReviewsList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    if (_supportTickets.isEmpty) {
      return const Center(child: Text('No support tickets found'));
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
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
                        'Kapanan Hesap',
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
                                : () => _showMessageUserDialog(targetUserId, userName),
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
      return const Center(child: Text('No feedbacks found'));
    }

    return ListView.builder(
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
    );
  }
}
