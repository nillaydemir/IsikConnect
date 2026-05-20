import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      // Fetch Support Tickets
      final ticketsResponse = await _supabase
          .from('support_tickets')
          .select('*, users(first_name, last_name, email)')
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
        final userData = ticket['users'];
        final userName = userData != null ? '${userData['first_name']} ${userData['last_name']}' : 'Unknown';
        final date = DateTime.parse(ticket['created_at']).toLocal();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(ticket['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Logic to mark as resolved could go here
                          },
                          child: const Text('Mark as Resolved'),
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
