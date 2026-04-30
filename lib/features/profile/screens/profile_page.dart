import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/current_session.dart';
import '../../../core/services/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late AppUser _user;
  bool _isEditing = false;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  List<String> _selectedDays = [];

  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _user = CurrentSession().user!;
    _resetControllers();
  }

  void _resetControllers() {
    _nameController.text = _user.name ?? '';
    _phoneController.text = _user.phone ?? '';
    _departmentController.text = _user.department ?? '';
    _bioController.text = _user.bio ?? '';
    _companyController.text = _user.company ?? '';
    _jobTitleController.text = _user.jobTitle ?? '';
    _selectedDays = List<String>.from(_user.availableDays ?? []);
  }

  Future<void> _pickAndUploadImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final apiService = ApiService();
        final response = await apiService.uploadProfileImage(_user.id, result.files.first);
        
        if (response['profileImageUrl'] != null) {
          setState(() {
            final updatedUser = AppUser(
              id: _user.id,
              email: _user.email,
              role: _user.role,
              createdAt: _user.createdAt,
              isApproved: _user.isApproved,
              name: _user.name,
              phone: _user.phone,
              department: _user.department,
              bio: _user.bio,
              profileImageUrl: response['profileImageUrl'],
              interests: _user.interests,
              availableDays: _user.availableDays,
              classLevel: _user.classLevel,
              graduationYear: _user.graduationYear,
              company: _user.company,
              jobTitle: _user.jobTitle,
              maxStudents: _user.maxStudents,
            );
            _user = updatedUser;
            CurrentSession().user = updatedUser;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final names = _nameController.text.trim().split(' ');
      final firstName = names.isNotEmpty ? names[0] : '';
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      final apiService = ApiService();
      final response = await apiService.updateProfile(_user.id, {
        'firstName': firstName,
        'lastName': lastName,
        'phone': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'bio': _bioController.text.trim(),
        'company': _companyController.text.trim(),
        'jobTitle': _jobTitleController.text.trim(),
        'availableDays': _selectedDays,
      });

      if (response['user'] != null) {
        setState(() {
          final Map<String, dynamic> mergedData = Map<String, dynamic>.from(response['user']);
          
          // Flatten as we do in Login
          Map<String, dynamic>? extractData(dynamic data) {
            if (data == null) return null;
            if (data is List && data.isNotEmpty) return Map<String, dynamic>.from(data.first);
            if (data is Map) return Map<String, dynamic>.from(data);
            return null;
          }

          if (mergedData['role'] == 'student') {
            final studentData = extractData(mergedData['students']);
            if (studentData != null) mergedData.addAll(studentData);
          } else if (mergedData['role'] == 'mentor') {
            final mentorData = extractData(mergedData['mentors']);
            if (mentorData != null) mergedData.addAll(mentorData);
          }

          final updatedUser = AppUser.fromJson(mergedData);
          _user = updatedUser;
          CurrentSession().user = updatedUser;
          _isEditing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: primaryColor),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() => _isEditing = false);
                _resetControllers();
              },
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildHeader(primaryColor),
                  const SizedBox(height: 32),
                  _buildInfoSection(primaryColor),
                  const SizedBox(height: 32),
                  if (_isEditing)
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: CircleAvatar(
                radius: 64,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                backgroundImage: _user.profileImageUrl != null 
                    ? NetworkImage(_user.profileImageUrl!) 
                    : null,
                child: _user.profileImageUrl == null 
                    ? Text(
                        (_user.name ?? 'U').substring(0, 1).toUpperCase(),
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: primaryColor),
                      )
                    : null,
              ),
            ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _user.name ?? 'Unnamed User',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0A1930)),
        ),
        Text(
          _user.role.toUpperCase(),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildInfoSection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(
            label: 'Full Name',
            controller: _nameController,
            icon: Icons.person_outline,
            isEditable: _isEditing,
          ),
          const Divider(height: 32),
          _buildField(
            label: 'Phone Number',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            isEditable: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          const Divider(height: 32),
          _buildField(
            label: 'Department',
            controller: _departmentController,
            icon: Icons.school_outlined,
            isEditable: _isEditing,
          ),
          const Divider(height: 32),
          _buildField(
            label: 'About Me',
            controller: _bioController,
            icon: Icons.info_outline,
            isEditable: _isEditing,
            maxLines: 5,
          ),
          if (_user.role == 'mentor') ...[
            const Divider(height: 32),
            _buildField(
              label: 'Company',
              controller: _companyController,
              icon: Icons.business,
              isEditable: _isEditing,
            ),
            const Divider(height: 32),
            _buildField(
              label: 'Job Title',
              controller: _jobTitleController,
              icon: Icons.work_outline,
              isEditable: _isEditing,
            ),
          ],
          const Divider(height: 32),
          _buildDaysSection(primaryColor),
        ],
      ),
    );
  }

  Widget _buildDaysSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 20, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'Available Days',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isEditing)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allDays.map((day) {
              final isSelected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(day, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
                selectedColor: primaryColor,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedDays.isEmpty 
              ? [Text('No days specified', style: TextStyle(color: Colors.grey[400], fontSize: 14))]
              : _selectedDays.map((day) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(day, style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                )).toList(),
          ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditable,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color.fromARGB(255, 38, 55, 140)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isEditable)
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
              hintText: 'Enter your $label',
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
            style: const TextStyle(fontSize: 16, color: Color(0xFF0A1930), fontWeight: FontWeight.w500),
          )
        else
          Text(
            controller.text.isEmpty ? 'Not specified' : controller.text,
            style: TextStyle(
              fontSize: 16, 
              color: controller.text.isEmpty ? Colors.grey[400] : const Color(0xFF0A1930),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}
