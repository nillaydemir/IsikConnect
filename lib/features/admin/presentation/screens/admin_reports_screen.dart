import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/screens/chat_screen.dart';
import '../../../../core/models/app_user_model.dart';

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
  final Map<String, TextEditingController> _noteControllers = {};
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch Support Tickets
      final ticketsResponse = await _supabase
          .from('support_tickets')
          .select('*, users(id, first_name, last_name, email, role, profile_image_url, created_at)')
          .order('created_at', ascending: false);

      // Fetch Reviews (Feedbacks)
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

  Future<void> _saveAdminNote(String ticketId, String note) async {
    setState(() => _isSavingNote = true);
    try {
      await _supabase.from('support_tickets').update({'admin_note': note}).eq('id', ticketId);
      final index = _supportTickets.indexWhere((t) => t['id'] == ticketId);
      if (index != -1) {
        setState(() {
          _supportTickets[index]['admin_note'] = note;
        });
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
    } finally {
      setState(() => _isSavingNote = false);
    }
  }

  Future<void> _markAsResolved(String ticketId) async {
    try {
      await _supabase.from('support_tickets').update({'status': 'resolved'}).eq('id', ticketId);
      final index = _supportTickets.indexWhere((t) => t['id'] == ticketId);
      if (index != -1) {
        setState(() {
          _supportTickets[index]['status'] = 'resolved';
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _supportTickets.length,
      itemBuilder: (context, index) {
        final ticket = _supportTickets[index];
        final ticketId = ticket['id'];
        final isResolved = ticket['status'] == 'resolved';
        final userData = ticket['users'];
        final userName = userData != null ? '${userData['first_name']} ${userData['last_name']}' : 'Unknown';
        final date = DateTime.parse(ticket['created_at']).toLocal();

        if (!_noteControllers.containsKey(ticketId)) {
          _noteControllers[ticketId] = TextEditingController(text: ticket['admin_note'] ?? '');
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isResolved ? Colors.green.shade50 : Colors.white,
          child: ExpansionTile(
            title: Row(
              children: [
                if (isResolved) const Icon(Icons.check_circle, color: Colors.green, size: 20),
                if (isResolved) const SizedBox(width: 8),
                Expanded(child: Text(ticket['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            subtitle: Text('From: $userName - ${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 12)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(ticket['message'] ?? '', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text('Admin Note (Private):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteControllers[ticketId],
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a private note for yourself or other admins...',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isSavingNote)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          ElevatedButton.icon(
                            onPressed: () => _saveAdminNote(ticketId, _noteControllers[ticketId]!.text),
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Save Note'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (userData != null)
                          TextButton.icon(
                            onPressed: () {
                              final appUser = AppUser.fromJson(userData);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatDetailScreen(targetUser: appUser),
                                ),
                              );
                            },
                            icon: const Icon(Icons.message),
                            label: const Text('Message User'),
                          )
                        else
                          const SizedBox(),
                        TextButton.icon(
                          onPressed: isResolved ? null : () => _markAsResolved(ticketId),
                          icon: Icon(isResolved ? Icons.check : Icons.check_circle_outline),
                          label: Text(isResolved ? 'Resolved' : 'Mark as Resolved'),
                          style: TextButton.styleFrom(
                            foregroundColor: isResolved ? Colors.green : Colors.grey.shade700,
                          ),
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
                    Text(
                      'To: $mentorName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'From: $studentName',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) => Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: i < rating ? Colors.amber : Colors.grey[200],
                  )),
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
