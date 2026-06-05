import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/current_session.dart';
import '../../../core/services/api_service.dart';
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
  List<String> _selectedInterests = [];
  final TextEditingController _customInterestController = TextEditingController();
  Map<String, List<String>> _departmentInterests = {};
  int _maxStudents = 1;
  PlatformFile? _selectedNewImage;
  bool _shouldDeleteImage = false;

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
      _fetchLastLoginForTargetUser();
    } else if (widget.targetUserId != null) {
      _fetchUserById();
    } else {
      _user = CurrentSession().user!;
      _resetControllers();
      _fetchReviews();
    }
    _fetchDepartmentsAndInterests();
  }

  Future<void> _fetchLastLoginForTargetUser() async {
    if (!_isOwnProfile && CurrentSession().user?.role == 'admin') {
      try {
        final lastLoginRes = await ApiService().fetchLastLogin(_user.id);
        if (lastLoginRes['last_sign_in_at'] != null && mounted) {
          setState(() {
            _user = AppUser(
              id: _user.id,
              email: _user.email,
              role: _user.role,
              isApproved: _user.isApproved,
              isDeleted: _user.isDeleted,
              createdAt: _user.createdAt,
              name: _user.name,
              phone: _user.phone,
              availableDays: _user.availableDays,
              department: _user.department,
              classLevel: _user.classLevel,
              interests: _user.interests,
              graduationYear: _user.graduationYear,
              company: _user.company,
              jobTitle: _user.jobTitle,
              bio: _user.bio,
              profileImageUrl: _user.profileImageUrl,
              maxStudents: _user.maxStudents,
              lastSignInAt: DateTime.parse(lastLoginRes['last_sign_in_at'] as String),
            );
          });
        }
      } catch (e) {
        debugPrint('Error fetching last login: $e');
      }
    }
  }

  Future<void> _fetchDepartmentsAndInterests() async {
    try {
      final response = await ApiService().fetchDepartments();
      
      final Map<String, List<String>> fetchedData = {};
      for (var dept in response) {
        final deptName = dept['name'] as String;
        final interestsList = (dept['interests'] as List)
            .map((i) => i['name'] as String)
            .toList();
        fetchedData[deptName] = interestsList;
      }
      if (mounted) {
        setState(() {
          _departmentInterests = fetchedData;
        });
      }
    } catch (e) {
      debugPrint('Error fetching departments: $e');
    }
  }

  Future<void> _fetchUserById({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await ApiService().fetchUserById(widget.targetUserId!);
      
      final Map<String, dynamic> mergedData = Map<String, dynamic>.from(response);

      // Fetch last login from backend if the viewer is an admin
      if (!_isOwnProfile && CurrentSession().user?.role == 'admin') {
        try {
          final lastLoginRes = await ApiService().fetchLastLogin(widget.targetUserId!);
          if (lastLoginRes['last_sign_in_at'] != null) {
            mergedData['last_sign_in_at'] = lastLoginRes['last_sign_in_at'];
          }
        } catch (e) {
          debugPrint('Error fetching user_logins: $e');
        }
      }

      setState(() {
        _user = AppUser.fromJson(mergedData);
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

  Future<void> _refreshProfile() async {
    final List<Future> futures = [];
    if (widget.targetUserId != null) {
      futures.add(_fetchUserById(showLoading: false));
    } else {
      _user = CurrentSession().user!;
      _resetControllers();
      futures.add(_fetchReviews());
    }
    if (widget.targetUser != null) {
      futures.add(_fetchLastLoginForTargetUser());
    }
    futures.add(_fetchDepartmentsAndInterests());
    await Future.wait(futures);
  }

  Future<void> _fetchReviews() async {
    if (_user.role != 'mentor') {
      debugPrint('Not a mentor, skipping reviews fetch. Role: ${_user.role}');
      return;
    }

    try {
      debugPrint('Fetching reviews for mentor ID: ${_user.id}');
      final response = await ApiService().fetchMentorReviews(_user.id);

      debugPrint('Reviews fetched: ${response.length}');
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
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
    _selectedInterests = List<String>.from(_user.interests ?? []);
    _maxStudents = _user.maxStudents ?? 1;
    _selectedNewImage = null;
    _shouldDeleteImage = false;
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _selectedNewImage = result.files.first;
      });
    }
  }

  Future<void> _saveProfile() async {
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number cannot be empty.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final phoneRegex = RegExp(r'^[1-9]\d{9}$');
    if (!phoneRegex.hasMatch(phoneText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_shouldDeleteImage) {
        await ApiService().deleteProfileImage(_user.id);
        _shouldDeleteImage = false;
      }
      if (_selectedNewImage != null) {
        final apiService = ApiService();
        final uploadResponse = await apiService.uploadProfileImage(_user.id, _selectedNewImage!);
        if (uploadResponse['profileImageUrl'] != null) {
          _selectedNewImage = null;
        }
      }
      final names = _nameController.text.trim().split(' ');
      final firstName = names.isNotEmpty ? names[0] : '';
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      final Map<String, dynamic> updateData = {
        'firstName': firstName,
        'lastName': lastName,
        'phone': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'bio': _bioController.text.trim(),
      };

      if (_user.role == 'mentor') {
        updateData['company'] = _companyController.text.trim();
        updateData['jobTitle'] = _jobTitleController.text.trim();
        updateData['availableDays'] = _selectedDays;
        updateData['interests'] = _selectedInterests;
        updateData['maxStudents'] = _maxStudents;
      } else if (_user.role == 'student') {
        updateData['availableDays'] = _selectedDays;
        updateData['interests'] = _selectedInterests;
      }

      final freshResponse = await ApiService().updateProfile(_user.id, updateData);
      final Map<String, dynamic> mergedData = Map<String, dynamic>.from(freshResponse['user']);

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
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                backgroundImage: (_selectedNewImage == null && _shouldDeleteImage)
                    ? null
                    : (_selectedNewImage != null
                        ? (_selectedNewImage!.path != null
                            ? FileImage(File(_selectedNewImage!.path!))
                            : MemoryImage(_selectedNewImage!.bytes!) as ImageProvider)
                        : (_user.profileImageUrl != null 
                            ? NetworkImage(_user.profileImageUrl!) 
                            : null)),
                child: (_selectedNewImage == null && (_shouldDeleteImage || _user.profileImageUrl == null))
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
                  onTap: _showImageOptions,
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
        if (_user.role == 'mentor') ...[
          const SizedBox(height: 8),
          _buildBadgeWidget(_user.badge ?? '🌱 New Mentor'),
        ],
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const Divider(height: 32),
          _buildReadOnlyField(
            label: 'Email Address',
            value: _user.email,
            icon: Icons.email_outlined,
          ),
          if (!_isOwnProfile && CurrentSession().user?.role == 'admin') ...[
            const Divider(height: 32),
            _buildReadOnlyField(
              label: 'Last Sign In',
              value: _user.lastSignInAt != null
                  ? '${_user.lastSignInAt!.toLocal().day}/${_user.lastSignInAt!.toLocal().month}/${_user.lastSignInAt!.toLocal().year} ${_user.lastSignInAt!.toLocal().hour}:${_user.lastSignInAt!.toLocal().minute.toString().padLeft(2, '0')}'
                  : 'Never',
              icon: Icons.login_outlined,
            ),
          ],
          const Divider(height: 32),
          _buildField(
            label: 'Department',
            controller: _departmentController,
            icon: Icons.school_outlined,
            isEditable: false,
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
            const Divider(height: 32),
            _buildReadOnlyField(
              label: 'Graduation Year',
              value: _user.graduationYear ?? 'Not specified',
              icon: Icons.school,
            ),
            const Divider(height: 32),
            _isEditing
                ? _buildCounter(
                    label: 'Max Students',
                    value: _maxStudents,
                    onChanged: (val) => setState(() => _maxStudents = val),
                  )
                : _buildReadOnlyField(
                    label: 'Max Students',
                    value: _maxStudents.toString(),
                    icon: Icons.group,
                  ),
          ] else if (_user.role == 'student') ...[
            const Divider(height: 32),
            _buildReadOnlyField(
              label: 'Class Level',
              value: _user.classLevel ?? 'Not specified',
              icon: Icons.class_outlined,
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

  Widget _buildInterestsSection(Color primaryColor) {
    final currentDept = _departmentController.text.trim();
    String? matchedDept;
    for (var key in _departmentInterests.keys) {
      if (key.toLowerCase() == currentDept.toLowerCase()) {
        matchedDept = key;
        break;
      }
    }
    
    final availableInterests = matchedDept != null ? _departmentInterests[matchedDept]! : <String>[];
    final Set<String> displayInterests = _isEditing 
        ? {...availableInterests, ..._selectedInterests}
        : _selectedInterests.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star_outline, size: 20, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'Interests & Skills',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displayInterests.isEmpty && !_isEditing
            ? [Text('No interests specified', style: TextStyle(color: Colors.grey[400], fontSize: 14))]
            : displayInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return _isEditing 
                  ? FilterChip(
                      label: Text(interest, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedInterests.add(interest);
                          } else {
                            _selectedInterests.remove(interest);
                          }
                        });
                      },
                      selectedColor: primaryColor,
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? primaryColor : Colors.grey.shade300,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(interest, style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    );
              }).toList(),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customInterestController,
                  decoration: const InputDecoration(
                    labelText: 'Add Interest/Skill',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    fillColor: Colors.white,
                    filled: true,
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    final text = value.trim();
                    if (text.isNotEmpty) {
                      final isDuplicate = _selectedInterests.any((i) => i.toLowerCase() == text.toLowerCase());
                      if (!isDuplicate) {
                        setState(() {
                          _selectedInterests.add(text);
                          _customInterestController.clear();
                        });
                      } else {
                        _customInterestController.clear();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = _customInterestController.text.trim();
                  if (text.isNotEmpty) {
                    final isDuplicate = _selectedInterests.any((i) => i.toLowerCase() == text.toLowerCase());
                    if (!isDuplicate) {
                      setState(() {
                        _selectedInterests.add(text);
                        _customInterestController.clear();
                      });
                    } else {
                      _customInterestController.clear();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ]
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
    List<TextInputFormatter>? inputFormatters,
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
            inputFormatters: inputFormatters,
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

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
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
        Text(
          value.isEmpty ? 'Not specified' : value,
          style: TextStyle(
            fontSize: 16, 
            color: value.isEmpty || value == 'Not specified' ? Colors.grey[400] : const Color(0xFF0A1930),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCounter({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: value > 1 ? const Color.fromARGB(255, 38, 55, 140) : Colors.grey,
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_circle_outline),
                color: const Color.fromARGB(255, 38, 55, 140),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showImageOptions() {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    final hasPhoto = _selectedNewImage != null || (_user.profileImageUrl != null && !_shouldDeleteImage);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A1930),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: primaryColor),
                title: const Text('Choose Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete Photo', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedNewImage = null;
                      _shouldDeleteImage = true;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeWidget(String badge) {
    Color bgColor;
    Color textColor;
    
    if (badge.contains('👑')) {
      bgColor = Colors.amber.shade50;
      textColor = Colors.amber.shade900;
    } else if (badge.contains('⭐')) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade900;
    } else {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade900;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        badge,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: textColor,
        ),
      ),
    );
  }
}
