import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _currentStep = 0;
  bool _isLoading = false;

  // -- Step 1: Common Info --
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final List<String> _selectedDays = [];

  // -- Step 2: Role Selection --
  String? _selectedRole; // 'Student' or 'Mentor'

  // -- Step 3: Role Details
  Map<String, List<String>> _departmentInterests = {};

  String? _selectedDepartment;
  final List<String> _selectedInterests = [];

  // Student specific
  final List<String> _classLevels = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];
  String? _selectedClassLevel;

  // Mentor specific
  final List<String> _gradYears = List.generate(
    27,
    (index) => (2000 + index).toString(),
  );
  String? _selectedGradYear;
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  int _selectedMaxStudents = 1;
  final TextEditingController _customInterestController =
      TextEditingController();

  // File picking
  String? _selectedFileName;
  String? _selectedFilePath;
  dynamic
  _selectedPlatformFile; // Store PlatformFile for cross-platform support
  bool _kvkkApproved = false;

  @override
  void initState() {
    super.initState();
    _fetchDepartmentsAndInterests();
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _customInterestController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Basic validation
    if (_currentStep == 0) {
      if (_firstNameController.text.isEmpty ||
          _lastNameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required common information.'),
          ),
        );
        return;
      }
      final phoneText = _phoneController.text.trim();
      if (phoneText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your phone number.')),
        );
        return;
      }
      final phoneRegex = RegExp(r'^[1-9]\d{9}$');
      if (!phoneRegex.hasMatch(phoneText)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid 10-digit phone number.'),
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a role to continue.')),
        );
        return;
      }
      if (_selectedRole == 'Student') {
        final email = _emailController.text.trim().toLowerCase();
        if (!email.endsWith('@isik.edu.tr')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Students must register with an @isik.edu.tr email address.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } else if (_currentStep == 2) {
      if (_selectedDepartment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your department.')),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      if (!_kvkkApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please read and approve the KVKK Consent Text to complete registration.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      _submitRegistration();
    }
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final rawPassword = _passwordController.text.trim();
      final password = sha256.convert(utf8.encode(rawPassword)).toString();
      final role = _selectedRole?.toLowerCase() ?? 'student';

      if (role == 'mentor') {
        if (_selectedFilePath == null) {
          throw 'Please upload your graduation document.';
        }

        final apiService = ApiService();

        // 1. Prepare payload (Mentors API might still expect full_name, so we merge them here temporarily)
        final Map<String, dynamic> payload = {
          'full_name':
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          'email': email,
          'password': password,
          'phone': _phoneController.text.trim(),
          'available_days': _selectedDays,
          'department': _selectedDepartment,
          'graduation_year': _selectedGradYear,
          'company': _companyController.text.trim(),
          'job_title': _jobTitleController.text.trim(),
          'max_students': _selectedMaxStudents,
          'interests': _selectedInterests,
        };

        // 2. Call backend API with both data and file in a single multipart request
        final result = await apiService.registerMentor(
          payload,
          _selectedPlatformFile,
        );

        if (result['message'] != null && result['id'] != null) {
          if (!mounted) return;
          _showSuccessDialog();
        } else {
          throw result['message'] ?? 'Registration failed.';
        }
      } else {
        if (!email.toLowerCase().endsWith('@isik.edu.tr')) {
          throw 'Students must register with an @isik.edu.tr email address.';
        }

        if (_selectedPlatformFile == null) {
          throw 'Please upload your student document (Student Certificate).';
        }

        final apiService = ApiService();

        final Map<String, dynamic> payload = {
          'full_name':
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          'email': email,
          'password': password, // Already hashed above!
          'phone': _phoneController.text.trim(),
          'available_days': _selectedDays,
          'department': _selectedDepartment,
          'class_level': _selectedClassLevel,
          'interests': _selectedInterests,
        };

        final result = await apiService.registerStudent(
          payload,
          _selectedPlatformFile,
        );

        if (result['message'] != null && result['id'] != null) {
          if (!mounted) return;
          _showSuccessDialog();
        } else {
          throw result['message'] ?? 'Student registration failed.';
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(
              Icons.mark_email_unread,
              color: Color.fromARGB(255, 38, 55, 140),
            ),
            SizedBox(width: 8),
            Text(
              'Verify Your Email',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Registration successful!\n\n'
          'A verification link has been sent to your email address. '
          'Please verify your email to activate your account.\n\n'
          'Once verified, your documents will be reviewed by the admin. '
          'You will be able to log in after admin approval.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to login screen
            },
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 38, 55, 140),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context); // Go back to login
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey[50], // Very light grey background for a clean modern look
      appBar: AppBar(
        title: const Text(
          'Register',
          style: TextStyle(
            color: Color.fromARGB(255, 38, 55, 140),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 38, 55, 140)),
      ),
      body: SafeArea(
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _nextStep,
          onStepCancel: _cancelStep,
          physics: const ClampingScrollPhysics(),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading && _currentStep == 3
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _currentStep == 3 ? 'Submit' : 'Continue',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: details.onStepCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: const Color.fromARGB(
                            255,
                            38,
                            55,
                            140,
                          ),
                          side: const BorderSide(
                            color: Color.fromARGB(255, 38, 55, 140),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text(
                'Common Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildCommonInfo(),
            ),
            Step(
              title: const Text(
                'Role Selection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildRoleSelection(),
            ),
            Step(
              title: const Text(
                'Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _selectedRole == 'Student'
                  ? _buildStudentForm()
                  : (_selectedRole == 'Mentor'
                        ? _buildMentorForm()
                        : const Text('Please select a role first.')),
            ),
            Step(
              title: const Text(
                'Final Review',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              isActive: _currentStep >= 3,
              content: _buildFinalReview(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommonInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'First Name *',
                _firstNameController,
                Icons.person_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                'Last Name *',
                _lastNameController,
                Icons.person_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Email *',
          _emailController,
          Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Password *',
          _passwordController,
          Icons.lock_outline,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Phone Number *',
          _phoneController,
          Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Available Days',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _daysOfWeek.map((day) {
            final isSelected = _selectedDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(day);
                  } else {
                    _selectedDays.remove(day);
                  }
                });
              },
              backgroundColor: Colors.white,
              selectedColor: const Color.fromARGB(
                255,
                38,
                55,
                140,
              ).withValues(alpha: 0.15),
              checkmarkColor: const Color.fromARGB(255, 38, 55, 140),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color.fromARGB(255, 38, 55, 140)
                    : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color.fromARGB(255, 38, 55, 140)
                      : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(child: _buildRoleCard('Student', Icons.school)),
          const SizedBox(width: 16),
          Expanded(child: _buildRoleCard('Mentor', Icons.work)),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String role, IconData icon) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
          // Reset dependent fields when role switches
          _selectedDepartment = null;
          _selectedInterests.clear();
          _selectedFileName = null;
          _selectedFilePath = null;
          _selectedPlatformFile = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 38, 55, 140).withValues(alpha: 0.05)
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color.fromARGB(255, 38, 55, 140)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected
                  ? const Color.fromARGB(255, 38, 55, 140)
                  : Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            Text(
              role,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected
                    ? const Color.fromARGB(255, 38, 55, 140)
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedFileName != null
                    ? const Color.fromARGB(255, 38, 55, 140)
                    : Colors.grey.shade300,
                style: BorderStyle.solid,
                width: _selectedFileName != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: [
                Icon(
                  _selectedFileName != null
                      ? Icons.check_circle
                      : Icons.upload_file,
                  size: 32,
                  color: _selectedFileName != null ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFileName ?? 'Upload Student Certificate',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () async {
                    if (!kIsWeb &&
                        (Platform.isLinux ||
                            Platform.isWindows ||
                            Platform.isMacOS)) {
                      // Desktop specific check if needed
                    }

                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                      withData: true,
                    );

                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      setState(() {
                        _selectedFileName = file.name;
                        _selectedPlatformFile = file;
                        _selectedFilePath = file.path;
                      });
                    }
                  },
                  child: Text(
                    _selectedFileName != null ? 'Change File' : 'Select File',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDepartmentDropdown(),
          const SizedBox(height: 16),
          _buildDropdown(
            'Class Level',
            _classLevels,
            _selectedClassLevel,
            (val) => setState(() => _selectedClassLevel = val),
          ),
          const SizedBox(height: 24),
          _buildDynamicInterestsSection('Interests'),
        ],
      ),
    );
  }

  Widget _buildMentorForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedFileName != null
                    ? const Color.fromARGB(255, 38, 55, 140)
                    : Colors.grey.shade300,
                style: BorderStyle.solid,
                width: _selectedFileName != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: [
                Icon(
                  _selectedFileName != null
                      ? Icons.check_circle
                      : Icons.upload_file,
                  size: 32,
                  color: _selectedFileName != null ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFileName ?? 'Upload Graduation Document',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () async {
                    if (!kIsWeb &&
                        (Platform.isLinux ||
                            Platform.isWindows ||
                            Platform.isMacOS)) {
                      // Desktop specific check if needed
                    }

                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                      withData: true,
                    );

                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      setState(() {
                        _selectedFileName = file.name;
                        _selectedPlatformFile = file;
                        _selectedFilePath = file.path;
                      });
                    }
                  },
                  child: Text(
                    _selectedFileName != null ? 'Change File' : 'Select File',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            'Graduation Year',
            _gradYears,
            _selectedGradYear,
            (val) => setState(() => _selectedGradYear = val),
          ),
          const SizedBox(height: 16),
          _buildDepartmentDropdown(),
          const SizedBox(height: 16),
          _buildTextField(
            'Current Company',
            _companyController,
            Icons.business,
          ),
          const SizedBox(height: 16),
          _buildTextField('Job Title', _jobTitleController, Icons.work_outline),
          const SizedBox(height: 16),
          _buildCounter(
            label: 'Max Number of Students',
            value: _selectedMaxStudents,
            onChanged: (val) => setState(() => _selectedMaxStudents = val),
          ),
          const SizedBox(height: 24),
          _buildDynamicInterestsSection('Mentorship Areas'),
        ],
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Department',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.white,
      ),
      initialValue: _selectedDepartment,
      isExpanded: true,
      items: _departmentInterests.keys.map((String dept) {
        return DropdownMenuItem<String>(
          value: dept,
          child: Text(dept, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedDepartment = val;
          _selectedInterests.clear(); // Reset interests when department changes
        });
      },
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> options,
    String? currentValue,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      initialValue: currentValue,
      isExpanded: true,
      items: options.map((String opt) {
        return DropdownMenuItem<String>(value: opt, child: Text(opt));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        fillColor: Colors.white,
        filled: true,
      ),
    );
  }

  Widget _buildDynamicInterestsSection(String label) {
    if (_selectedDepartment == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Please select a department to see $label.',
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final availableInterests = _departmentInterests[_selectedDepartment] ?? [];

    // Combine predefined interests and any custom ones the user already added
    final Set<String> displayInterests = {
      ...availableInterests,
      ..._selectedInterests,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displayInterests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest),
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
              backgroundColor: Colors.white,
              selectedColor: const Color.fromARGB(
                255,
                38,
                55,
                140,
              ).withValues(alpha: 0.15),
              checkmarkColor: const Color.fromARGB(255, 38, 55, 140),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color.fromARGB(255, 38, 55, 140)
                    : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color.fromARGB(255, 38, 55, 140)
                      : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customInterestController,
                decoration: const InputDecoration(
                  labelText: 'Add Custom Field/Interest',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onSubmitted: (value) {
                  final text = value.trim();
                  if (text.isNotEmpty) {
                    final isDuplicate = _selectedInterests.any(
                      (i) => i.toLowerCase() == text.toLowerCase(),
                    );
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
                  final isDuplicate = _selectedInterests.any(
                    (i) => i.toLowerCase() == text.toLowerCase(),
                  );
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
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
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
                color: value > 1
                    ? const Color.fromARGB(255, 38, 55, 140)
                    : Colors.grey,
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

  Widget _buildFinalReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You are almost done! Please review and accept the consent terms below to submit your registration application.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _kvkkApproved,
              onChanged: (bool? value) {
                setState(() {
                  _kvkkApproved = value ?? false;
                });
              },
              activeColor: const Color.fromARGB(255, 38, 55, 140),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _kvkkApproved = !_kvkkApproved;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      children: [
                        const TextSpan(text: 'I have read and agree to the '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: _showKvkkDialog,
                            child: const Text(
                              'KVKK Consent Text',
                              style: TextStyle(
                                color: Color.fromARGB(255, 38, 55, 140),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showKvkkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'KVKK Consent Text',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'IşıkConnect - KVKK / Personal Data Protection Consent Text',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),
                Text(
                  'In accordance with the Law on the Protection of Personal Data No. 6698 ("KVKK"), your personal data collected through the IşıkConnect mobile application (name, surname, email, phone number, academic department, and student/graduation documents you upload) will be processed by the IşıkConnect administration as the data controller within the scope specified below:\n\n'
                  '1. Purposes of Data Processing: Creation of user accounts, management of student and mentor matching processes, ensuring platform security, and performing academic verifications.\n\n'
                  '2. Transfer of Data: Your collected personal data will never be shared with third parties, except for authorized public institutions and organizations to fulfill legal obligations.\n\n'
                  '3. Method of Data Collection: Data is collected through digital means via the registration form and the documents you upload.\n\n'
                  '4. Your Rights: Pursuant to Article 11 of the KVKK, you have the right to apply to the data controller at any time to learn whether your personal data is being processed, and request correction or deletion of your data.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color.fromARGB(255, 38, 55, 140),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
