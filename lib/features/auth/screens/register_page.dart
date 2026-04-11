import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _currentStep = 0;

  // -- Step 1: Common Info --
  final TextEditingController _nameController = TextEditingController();
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
  final Map<String, List<String>> _departmentInterests = {
    'Computer Engineering': [
      'Web Development',
      'Mobile Development',
      'AI / Machine Learning',
      'Data Science',
      'Backend Development',
    ],
    'Software Engineering': [
      'Web Development',
      'Mobile Development',
      'AI / Machine Learning',
      'Data Science',
      'Backend Development',
    ],
    'Industrial Engineering': [
      'Supply Chain',
      'Operations Research',
      'Data Analytics',
      'Quality Control',
    ],
    'Electrical and Electronics Engineering': [
      'Embedded Systems',
      'IoT',
      'Circuit Design',
      'Robotics',
    ],
    'Mechanical Engineering': [
      'CAD Design',
      'Thermodynamics',
      'Robotics',
      'Mechatronics',
    ],
    'Civil Engineering': [
      'Structural Engineering',
      'Construction Management',
      'Geotechnical',
    ],
    'Psychology': [
      'Clinical Psychology',
      'Cognitive Psychology',
      'Behavioral Science',
    ],
    'Mathematics': ['Applied Mathematics', 'Statistics', 'Cryptography'],
    'Physics': ['Quantum Physics', 'Astrophysics', 'Materials Science'],
    'Business Administration': [
      'Marketing',
      'Finance',
      'Human Resources',
      'Management',
    ],
    'International Trade and Finance': [
      'Global Markets',
      'Trade Policy',
      'Investment Banking',
    ],
    'Economics': ['Macroeconomics', 'Microeconomics', 'Econometrics'],
    'Architecture': ['Urban Design', 'Sustainable Architecture', 'Landscape'],
    'Interior Architecture and Environmental Design': [
      'Space Planning',
      'Furniture Design',
      'Lighting',
    ],
    'Nursing': ['Patient Care', 'Pediatrics', 'Public Health'],
  };

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
  final List<String> _maxStudentsList = ['1', '2', '3', '5', '10'];
  String? _selectedMaxStudents;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Basic validation
    if (_currentStep == 0) {
      if (_nameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required common information.'),
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
      // Final step -> Submit
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context); // Optional: go to homepage
      });
    }
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
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _currentStep == 3 ? 'Submit' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
              content: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'By clicking submit, you agree to our terms and conditions. Welcome to IşıkConnect!',
                ),
              ),
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
        _buildTextField('Full Name *', _nameController, Icons.person_outline),
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
          'Phone Number',
          _phoneController,
          Icons.phone_outlined,
          keyboardType: TextInputType.phone,
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
              ).withOpacity(0.15),
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
        });
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 38, 55, 140).withOpacity(0.05)
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
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: [
                const Icon(Icons.upload_file, size: 32, color: Colors.grey),
                const SizedBox(height: 8),
                const Text(
                  'Upload Graduation Document',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                TextButton(
                  onPressed: () {
                    /* File Picker placeholder */
                  },
                  child: const Text('Select File'),
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
          _buildDropdown(
            'Max Number of Students',
            _maxStudentsList,
            _selectedMaxStudents,
            (val) => setState(() => _selectedMaxStudents = val),
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
      value: _selectedDepartment,
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
      value: currentValue,
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
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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
    if (availableInterests.isEmpty) return const SizedBox.shrink();

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
          children: availableInterests.map((interest) {
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
              ).withOpacity(0.15),
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
}
