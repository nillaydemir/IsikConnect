import 'package:flutter/material.dart';
import '../models/job_posting_model.dart';
import '../services/job_service.dart';

class CreateEditJobScreen extends StatefulWidget {
  final JobPosting? existingJob;

  const CreateEditJobScreen({super.key, this.existingJob});

  @override
  State<CreateEditJobScreen> createState() => _CreateEditJobScreenState();
}

class _CreateEditJobScreenState extends State<CreateEditJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobService = JobService();

  late final TextEditingController _titleController;
  late final TextEditingController _companyController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _requirementsController;

  bool _isLoading = false;
  bool get _isEditMode => widget.existingJob != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingJob?.title ?? '');
    _companyController = TextEditingController(text: widget.existingJob?.company ?? '');
    _descriptionController = TextEditingController(text: widget.existingJob?.description ?? '');
    _requirementsController = TextEditingController(text: widget.existingJob?.requirements ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditMode) {
        await _jobService.updateJobPosting(
          widget.existingJob!.id,
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          requirements: _requirementsController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job posting updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        await _jobService.createJobPosting(
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          requirements: _requirementsController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job posting published successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save job posting: $e'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Job Posting' : 'Post Career Opportunity',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Colors.black12),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.business_center, color: primaryColor, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  _isEditMode ? 'Refine Listing' : 'Reach Talented Students',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isEditMode
                                  ? 'Update the details below to polish the career or internship posting.'
                                  : 'Publish job openings, project collaborations, or internship opportunities for Işık University students.',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title Field
                      _buildTextField(
                        controller: _titleController,
                        label: 'Job Title',
                        hint: 'e.g., Software Engineering Intern, Junior Analyst',
                        icon: Icons.title,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Job title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Company Field
                      _buildTextField(
                        controller: _companyController,
                        label: 'Company Name',
                        hint: 'e.g., Google, Boyner, Startup Inc.',
                        icon: Icons.business,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Company name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Description Field
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Job Description',
                        hint: 'Detail the role, responsibilities, team environment, and what a typical day looks like...',
                        icon: Icons.description,
                        maxLines: 6,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Job description is required';
                          }
                          if (value.trim().length < 20) {
                            return 'Please write a description of at least 20 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Requirements Field
                      _buildTextField(
                        controller: _requirementsController,
                        label: 'Requirements & Qualifications',
                        hint: 'List expected skills, coding languages, graduation status, department, and other requirements...',
                        icon: Icons.assignment_turned_in,
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requirements are required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 36),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: primaryColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _isEditMode ? 'Save Changes' : 'Publish Opportunity',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          cursorColor: primaryColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: primaryColor.withValues(alpha: 0.6), size: 22),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
