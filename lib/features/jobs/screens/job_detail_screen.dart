import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../models/job_posting_model.dart';
import '../models/job_application_model.dart';
import '../services/job_service.dart';
import '../../../core/services/current_session.dart';
import 'create_edit_job_screen.dart';
import '../../../core/models/app_user_model.dart';
import '../../shared/screens/chat_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final JobPosting job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _jobService = JobService();
  bool _isLoading = false;
  PlatformFile? _selectedCV;
  
  // Student specific
  bool _hasApplied = false;
  JobApplication? _myApplication;

  // Creator specific
  List<JobApplication> _applicants = [];

  bool get _isCreator => 
      CurrentSession().user?.id == widget.job.mentorId || 
      CurrentSession().user?.role == 'admin';

  bool get _isStudent => CurrentSession().user?.role == 'student';

  Future<void> _messageUser(String userId, String userName) async {
    try {
      final userDoc = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      
      final targetUser = AppUser.fromJson(userDoc);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              targetUser: targetUser,
              isActiveMatch: true,
              label: 'Job',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isStudent) {
        final app = await _jobService.checkMyApplicationStatus(widget.job.id);
        setState(() {
          _myApplication = app;
          _hasApplied = app != null;
        });
      } else if (_isCreator) {
        final apps = await _jobService.fetchApplicationsForJob(widget.job.id);
        setState(() {
          _applicants = apps;
        });
      }
    } catch (e) {
      debugPrint('Error loading detail data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openDocument(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document uploaded.')),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document link.')),
        );
      }
    }
  }

  // --- Student: Apply Flow (UC13) ---
  void _showApplyBottomSheet() {
    // A1 - Preconditions check: Verify account/document
    final user = CurrentSession().user;
    final bool isApproved = user?.isApproved ?? false;

    if (!isApproved) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Unverified Account', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Your account is currently pending administrative approval or is unverified. You must have a completed, approved profile to apply for job postings.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color.fromARGB(255, 38, 55, 140))),
            ),
          ],
        ),
      );
      return;
    }

    _selectedCV = null; // Reset selection on open
    final TextEditingController coverNoteController = TextEditingController();
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Submit Application',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Your registered profile details (Name, Department, Class Level) and Student Document will be shared with the employer.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Text(
                'Attach Custom CV / Resume (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setBottomSheetState) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedCV != null ? Colors.green : Colors.grey.shade300,
                        width: _selectedCV != null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          _selectedCV != null ? Icons.check_circle : Icons.upload_file,
                          color: _selectedCV != null ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedCV != null
                                ? _selectedCV!.name
                                : 'Defaults to registered student document',
                            style: TextStyle(
                              color: _selectedCV != null ? Colors.black87 : Colors.grey[600],
                              fontSize: 13,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final result = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf'],
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setBottomSheetState(() {
                                _selectedCV = result.files.first;
                              });
                            }
                          },
                          child: Text(
                            _selectedCV != null ? 'Change' : 'Select PDF',
                            style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Cover Letter / Note (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: coverNoteController,
                maxLines: 4,
                cursorColor: primaryColor,
                decoration: InputDecoration(
                  hintText: 'Introduce yourself and summarize why you are a great fit for this role...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final note = coverNoteController.text.trim();
                        Navigator.pop(context);
                        
                        setState(() {
                          _isLoading = true;
                        });

                        try {
                          String? customCvUrl;
                          if (_selectedCV != null) {
                            customCvUrl = await _jobService.uploadCV(_selectedCV!);
                          }

                          await _jobService.applyForJob(
                            widget.job.id, 
                            note.isEmpty ? null : note,
                            cvUrl: customCvUrl,
                          );

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Successfully applied for this job!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Application failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          setState(() {
                            _isLoading = false;
                            _selectedCV = null; // Clear selection after apply
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Mentor: Accept/Reject Application (UC14) ---
  void _reviewApplicant(JobApplication application, bool approve) {
    final TextEditingController feedbackController = TextEditingController();
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    final String actionText = approve ? 'Accept' : 'Reject';
    final Color actionColor = approve ? Colors.green : Colors.redAccent;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$actionText Application',
          style: TextStyle(fontWeight: FontWeight.bold, color: actionColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to $actionText ${application.studentName}\'s application?'),
            const SizedBox(height: 16),
            const Text('Feedback (Optional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              cursorColor: primaryColor,
              decoration: InputDecoration(
                hintText: 'Provide instructions, comments, or rejection reasons...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
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
              final fb = feedbackController.text.trim();
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
              });

              try {
                await _jobService.updateApplicationStatus(
                  application.id,
                  approve ? 'accepted' : 'rejected',
                  fb.isEmpty ? null : fb,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Application ${approve ? "accepted" : "rejected"} successfully!'),
                    backgroundColor: actionColor,
                  ),
                );
                _loadData();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update application: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  // --- Mentor: Delete Listing (UC12) ---
  void _deleteListing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Posting'),
        content: const Text('Are you sure you want to permanently delete this job posting? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _jobService.deleteJobPosting(widget.job.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job posting deleted successfully.')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // --- BUILD METHS ---
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Job Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: _isCreator
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: primaryColor),
                  onPressed: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateEditJobScreen(existingJob: widget.job),
                      ),
                    );
                    if (res == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: _deleteListing,
                ),
              ]
            : null,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Colors.black12),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.job.isDeleted) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.red, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This job posting has been removed by the employer.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Job Title Card
                    _buildHeaderCard(),
                    const SizedBox(height: 24),

                    // Job details section
                    _buildSectionTitle('Job Description'),
                    _buildDetailCard(widget.job.description),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Requirements'),
                    _buildDetailCard(widget.job.requirements),
                    const SizedBox(height: 32),

                    // Dynamic footer based on role
                    if (_isStudent) _buildStudentSection(),
                    if (_isCreator) _buildCreatorSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    final dateStr = '${widget.job.createdAt.day}/${widget.job.createdAt.month}/${widget.job.createdAt.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.business_center, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.job.company,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaIcon(Icons.person_outline, 'Posted by ${widget.job.mentorName}'),
              _buildMetaIcon(Icons.calendar_today_outlined, dateStr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildDetailCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
      ),
    );
  }

  // --- Student Section widget ---
  Widget _buildStudentSection() {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    final bool isMentorDeactivated = !widget.job.isMentorApproved || widget.job.isMentorDeleted;

    if (isMentorDeactivated && !_hasApplied) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Text(
              "Mentor's profile is closed",
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.job.isDeleted && !_hasApplied) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Text(
            'Applications Closed (Posting Removed)',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (!_hasApplied) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _showApplyBottomSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Apply Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }

    final application = _myApplication!;
    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    switch (application.status) {
      case 'accepted':
        statusColor = Colors.green;
        statusTitle = 'Application Accepted';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusTitle = 'Application Declined';
        statusIcon = Icons.highlight_off;
        break;
      default:
        statusColor = primaryColor;
        statusTitle = 'Applied - Under Review';
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 10),
              Text(
                statusTitle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
          if (application.feedback != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: Colors.black12),
            const SizedBox(height: 16),
            const Text(
              'Employer Feedback:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              application.feedback!,
              style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
            ),
          ],
          if (application.status == 'accepted') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _messageUser(widget.job.mentorId, widget.job.company),
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                label: const Text('Message Mentor / Employer', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Creator Section widget ---
  Widget _buildCreatorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Applicants (${_applicants.length})'),
        if (_applicants.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No applications received yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _applicants.length,
            itemBuilder: (context, index) {
              final app = _applicants[index];
              return _buildApplicantCard(app);
            },
          ),
      ],
    );
  }

  Widget _buildApplicantCard(JobApplication app) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student summary
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    app.studentName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${app.studentDepartment ?? ""} - ${app.studentClassLevel ?? ""}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status indicator
                if (app.status != 'applied')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: app.status == 'accepted' 
                          ? Colors.green.withValues(alpha: 0.1) 
                          : Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      app.status.toUpperCase(),
                      style: TextStyle(
                        color: app.status == 'accepted' ? Colors.green : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Document link
            if (app.studentDocumentUrl != null) ...[
              GestureDetector(
                onTap: () => _openDocument(app.studentDocumentUrl),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'View Student Document / CV',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Cover note
            if (app.coverNote != null) ...[
              const Text(
                'Cover Letter:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                app.coverNote!,
                style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (app.status == 'applied')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewApplicant(app, false),
                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                      label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reviewApplicant(app, true),
                      icon: const Icon(Icons.check, color: Colors.white, size: 18),
                      label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              if (app.status == 'accepted') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _messageUser(app.studentId, app.studentName),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                    label: const Text('Message Student', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (app.feedback != null) ...[
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                const SizedBox(height: 12),
                Text(
                  'Your Feedback: "${app.feedback}"',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
