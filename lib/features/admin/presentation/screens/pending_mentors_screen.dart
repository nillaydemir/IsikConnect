import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_approvals_provider.dart';
import '../widgets/mentor_request_card.dart';
import 'mentor_request_detail_screen.dart';

class PendingMentorsScreen extends StatefulWidget {
  const PendingMentorsScreen({Key? key}) : super(key: key);

  @override
  State<PendingMentorsScreen> createState() => _PendingMentorsScreenState();
}

class _PendingMentorsScreenState extends State<PendingMentorsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminApprovalsProvider>().loadPendingApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Removed Scaffold & AppBar to integrate smoothly into AdminMainScreen's body
    return Consumer<AdminApprovalsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.pendingApplications.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 38, 55, 140)));
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(provider.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadPendingApplications(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.pendingApplications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text(
                  'Great! No pending approvals.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color.fromARGB(255, 38, 55, 140),
          onRefresh: () => provider.loadPendingApplications(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            itemCount: provider.pendingApplications.length,
            itemBuilder: (context, index) {
              final application = provider.pendingApplications[index];
              return MentorRequestCard(
                application: application,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MentorRequestDetailScreen(
                        application: application,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
