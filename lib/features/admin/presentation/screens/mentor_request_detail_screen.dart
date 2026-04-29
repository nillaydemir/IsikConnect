import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/mentor_application_model.dart';
import '../../providers/admin_approvals_provider.dart';

class MentorRequestDetailScreen extends StatelessWidget {
  final MentorApplicationModel application;

  const MentorRequestDetailScreen({
    Key? key,
    required this.application,
  }) : super(key: key);

  void _showConfirmationDialog(BuildContext context, bool isApprove) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    
    showDialog(
      context: context,
      builder: (ctx) {
        final roleName = application.role.toUpperCase() == 'STUDENT' ? 'Student' : 'Mentor';
        return AlertDialog(
          title: Text(isApprove ? 'Approve $roleName' : 'Reject $roleName'),
          content: Text(
            isApprove 
              ? 'Are you sure you want to approve ${application.name} as a $roleName?'
              : 'Are you sure you want to reject ${application.name}\'s application?'
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? primaryColor : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              
              final provider = context.read<AdminApprovalsProvider>();
              
              // Show loading overlay
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(color: primaryColor)
                ),
              );

              if (isApprove) {
                await provider.approveApplication(application.id);
              } else {
                await provider.rejectApplication(application.id, 'Standard Rejection');
              }

              // Hide loading overlay
              if (context.mounted) {
                Navigator.pop(context);
                
                if (provider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
                  );
                } else {
                  final roleName = application.role.toUpperCase() == 'STUDENT' ? 'Student' : 'Mentor';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isApprove ? '$roleName approved successfully.' : 'Application rejected.'),
                      backgroundColor: isApprove ? Colors.green : Colors.grey.shade800,
                    ),
                  );
                  Navigator.pop(context); // Go back to list
                }
              }
            },
            child: Text(isApprove ? 'Approve' : 'Reject'),
          ),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Application Detail',
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(context, primaryColor),
            const SizedBox(height: 24),
            _buildInfoCard(
              context: context,
              title: 'Role & Background',
              content: '${application.role}\n${application.subTitle}',
              icon: Icons.work_outline,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context: context,
              title: 'Verification Document',
              content: application.documentUrl.isNotEmpty 
                ? 'Document has been uploaded by the applicant.' 
                : 'No document attached',
              icon: Icons.description_outlined,
              actionWidget: application.documentUrl.isNotEmpty
                ? OutlinedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(application.documentUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open document link')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View Document'),
                  )
                : null,
            ),
            const SizedBox(height: 100), // Space for bottom buttons
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showConfirmationDialog(context, false),
                  child: const Text('Reject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showConfirmationDialog(context, true),
                  child: const Text('Approve', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, Color primaryColor) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: primaryColor.withOpacity(0.1),
          backgroundImage: application.avatarUrl != null 
              ? NetworkImage(application.avatarUrl!) 
              : null,
          child: application.avatarUrl == null 
              ? Text(
                  application.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 40,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          application.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          application.email,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
    Widget? actionWidget,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 38, 55, 140),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
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
            const SizedBox(height: 16),
            Text(
              content,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            if (actionWidget != null) ...[
              const SizedBox(height: 16),
              actionWidget,
            ],
          ],
        ),
      ),
    );
  }

// Removed _buildExpertiseCard
}
