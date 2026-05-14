import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/current_session.dart';
import '../../../core/services/api_service.dart';
import '../../shared/screens/chat_screen.dart';
import 'settings_screen.dart';

class ProfilePage extends StatefulWidget {
  final AppUser? targetUser;
  final String? targetUserId;
  const ProfilePage({super.key, this.targetUser, this.targetUserId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late AppUser _user = AppUser(
    id: '',
    email: '',
    role: '',
    name: '...',
    createdAt: DateTime.now(),
  );
  bool _isEditing = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _reviews = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  List<String> _selectedDays = [];
  List<String> _editableInterests = [];
  final TextEditingController _interestController = TextEditingController();

  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  bool get _isOwnProfile {
    final currentId = CurrentSession().user?.id;
    if (widget.targetUser == null && widget.targetUserId == null) return true;
    if (widget.targetUser != null && widget.targetUser!.id == currentId) return true;
    if (widget.targetUserId != null && widget.targetUserId == currentId) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.targetUser != null) {
      _user = widget.targetUser!;
      _resetControllers();
      _fetchReviews();
    } else if (widget.targetUserId != null) {
      _fetchUserById();
    } else {
      _user = CurrentSession().user!;
      _resetControllers();
      _fetchReviews();
    }
  }

  Future<void> _fetchUserById() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', widget.targetUserId!)
          .single();
      
      setState(() {
        _user = AppUser.fromJson(response);
        _resetControllers();
        _fetchReviews();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchReviews() async {
    if (_user.role != 'mentor') {
      print('Not a mentor, skipping reviews fetch. Role: ${_user.role}');
      return;
    }

    try {
      print('Fetching reviews for mentor ID: ${_user.id}');
      // Try to fetch via students join first, if that fails, try direct users join
      final response = await Supabase.instance.client
          .from('reviews')
          .select('*, students(users(first_name, last_name, profile_image_url))')
          .eq('mentor_id', _user.id)
          .order('created_at', ascending: false);

      print('Reviews fetched: ${response.length}');
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching reviews: $e');
      // Fallback for cases where FK might be different
      try {
        final response = await Supabase.instance.client
            .from('reviews')
            .select('*, users!student_id(first_name, last_name, profile_image_url)')
            .eq('mentor_id', _user.id)
            .order('created_at', ascending: false);
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(response);
        });
      } catch (e2) {
         print('Fallback fetch also failed: $e2');
      }
    }
  }

  void _resetControllers() {
    _nameController.text = _user.name ?? '';
    _phoneController.text = _user.phone ?? '';
    _departmentController.text = _user.department ?? '';
    _bioController.text = _user.bio ?? '';
    _companyController.text = _user.company ?? '';
    _jobTitleController.text = _user.jobTitle ?? '';
    _selectedDays = List<String>.from(_user.availableDays ?? []);
    _editableInterests = List<String>.from(_user.interests ?? []);
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

      // 1. Update basic user info
      await Supabase.instance.client.from('users').update({
        'first_name': firstName,
        'last_name': lastName,
        'phone': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'bio': _bioController.text.trim(),
      }).eq('id', _user.id);

      // 2. Update role-specific info
      if (_user.role == 'mentor') {
        await Supabase.instance.client.from('mentors').update({
          'company': _companyController.text.trim(),
          'job_title': _jobTitleController.text.trim(),
          'available_days': _selectedDays,
          'interests': _editableInterests,
        }).eq('id', _user.id);
      } else if (_user.role == 'student') {
        await Supabase.instance.client.from('students').update({
          'interests': _editableInterests,
          'available_days': _selectedDays,
        }).eq('id', _user.id);
      }

      // 3. Fetch fresh user data to update UI and session
      final freshResponse = await Supabase.instance.client
          .from('users')
          .select('*, mentors(*), students(*)')
          .eq('id', _user.id)
          .single();

      final Map<String, dynamic> mergedData = Map<String, dynamic>.from(freshResponse);
      if (mergedData['role'] == 'student' && mergedData['students'] != null) {
        final s = mergedData['students'];
        mergedData.addAll(s is List ? s.first : s);
      } else if (mergedData['role'] == 'mentor' && mergedData['mentors'] != null) {
        final m = mergedData['mentors'];
        mergedData.addAll(m is List ? m.first : m);
      }

      setState(() {
        _user = AppUser.fromJson(mergedData);
        CurrentSession().user = _user;
        _isEditing = false;
        _resetControllers();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red),
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
        title: Text(_isLoading ? 'Loading...' : (_isOwnProfile ? 'My Profile' : '${_user.name}\'s Profile'), style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isOwnProfile) ...[
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.settings, color: primaryColor),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  if (result == 'edit') {
                    setState(() => _isEditing = true);
                  }
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  setState(() => _isEditing = false);
                  _resetControllers();
                },
              ),
          ]
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
                  if (_isEditing && _isOwnProfile)
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
                    if (_user.role == 'mentor') ...[
                      const SizedBox(height: 32),
                      _buildReviewsSection(primaryColor),
                    ],
                  ],
                ),
              ),
      );
    }

    Widget _buildReviewsSection(Color primaryColor) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_outline_rounded, size: 20, color: primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Student Reviews',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (_reviews.isNotEmpty)
                  Text(
                    '${_reviews.length} total',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_reviews.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reviews.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  // Handle both nested student->user join and direct user join
                  Map<String, dynamic>? userData;
                  if (review['students'] != null && review['students']['users'] != null) {
                    userData = review['students']['users'];
                  } else if (review['users'] != null) {
                    userData = review['users'];
                  }
                  
                  final studentName = userData != null 
                      ? '${userData['first_name']} ${userData['last_name']}'
                      : 'Student';
                  final rating = review['rating'] as int;
                  final comment = review['comment'] as String?;
                  final date = DateTime.parse(review['created_at']).toLocal();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: primaryColor.withValues(alpha: 0.1),
                                backgroundImage: userData?['profile_image_url'] != null 
                                    ? NetworkImage(userData!['profile_image_url']) 
                                    : null,
                                child: userData?['profile_image_url'] == null 
                                    ? Text(studentName[0].toUpperCase(), style: TextStyle(fontSize: 10, color: primaryColor))
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (starIndex) => Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: starIndex < rating ? Colors.amber : Colors.grey[200],
                        )),
                      ),
                      if (comment != null && comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          comment,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
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
        if (_user.role == 'mentor' && _reviews.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                (_reviews.fold<double>(0, (prev, r) => prev + (r['rating'] as int)) / _reviews.length).toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                ' (${_reviews.length} reviews)',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ],
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
          const Divider(height: 32),
          _buildInterestsSection(primaryColor),
        ],
      ),
    );
  }

  Widget _buildInterestsSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label_outline, size: 20, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'Interests & Skills',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isEditing) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _interestController,
                  decoration: InputDecoration(
                    hintText: 'Add interest (e.g. Flutter)',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (value) => _addInterest(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addInterest,
                icon: Icon(Icons.add_circle, color: primaryColor, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _editableInterests.map((interest) {
            return Chip(
              label: Text(interest, style: const TextStyle(fontSize: 12)),
              backgroundColor: primaryColor.withValues(alpha: 0.05),
              side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
              onDeleted: _isEditing ? () {
                setState(() {
                  _editableInterests.remove(interest);
                });
              } : null,
              deleteIcon: _isEditing ? const Icon(Icons.close, size: 14) : null,
            );
          }).toList(),
        ),
        if (!_isEditing && _editableInterests.isEmpty)
          Text('No interests added yet.', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontStyle: FontStyle.italic)),
      ],
    );
  }

  void _addInterest() {
    final interest = _interestController.text.trim();
    if (interest.isNotEmpty && !_editableInterests.contains(interest)) {
      setState(() {
        _editableInterests.add(interest);
        _interestController.clear();
      });
    }
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
