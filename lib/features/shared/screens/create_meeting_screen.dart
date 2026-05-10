import 'package:flutter/material.dart';
import '../../../core/services/meeting_service.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _titleController = TextEditingController();
  final _capacityController = TextEditingController();
  final _meetingService = MeetingService();
  
  String _selectedType = '1-on-1';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  List<Map<String, dynamic>> _mentees = [];
  String? _selectedMenteeId;
  bool _isLoadingMentees = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchMentees();
  }

  Future<void> _fetchMentees() async {
    try {
      final mentees = await _meetingService.getMentees();
      setState(() {
        _mentees = mentees;
        if (_mentees.isNotEmpty) {
          _selectedMenteeId = _mentees.first['id'];
        }
        _isLoadingMentees = false;
      });
    } catch (e) {
      setState(() => _isLoadingMentees = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load mentees: $e')),
        );
      }
    }
  }

  Future<void> _createMeeting() async {
    if (_titleController.text.isEmpty || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (_selectedType == '1-on-1' && _selectedMenteeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mentee for 1-on-1 meeting')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      int? capacity;
      if (_selectedType == 'Workshop') {
        capacity = int.tryParse(_capacityController.text) ?? 10;
      }

      await _meetingService.createMeeting(
        title: _titleController.text.trim(),
        type: _selectedType,
        date: _selectedDate!,
        time: _selectedTime!,
        studentId: _selectedType == '1-on-1' ? _selectedMenteeId : null,
        capacity: capacity,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create meeting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Meeting', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meeting Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            // Title
            _buildLabel('Meeting Title'),
            const SizedBox(height: 8),
            _buildTextField(_titleController, 'Enter meeting title'),
            const SizedBox(height: 20),
            
            // Type
            _buildLabel('Meeting Type'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  items: ['1-on-1', 'Workshop'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedType = newValue!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Mentee Selection (If 1-on-1)
            if (_selectedType == '1-on-1') ...[
              _buildLabel('Select Mentee'),
              const SizedBox(height: 8),
              if (_isLoadingMentees)
                const Center(child: CircularProgressIndicator())
              else if (_mentees.isEmpty)
                const Text('You have no active mentees. Matches required.', style: TextStyle(color: Colors.red))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMenteeId,
                      isExpanded: true,
                      items: _mentees.map((mentee) {
                        return DropdownMenuItem<String>(
                          value: mentee['id'],
                          child: Text('${mentee['first_name']} ${mentee['last_name']}'),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedMenteeId = newValue;
                        });
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
            
            // Date & Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Date'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate == null 
                                    ? 'Select Date' 
                                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Time'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => _selectedTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime == null 
                                    ? 'Select Time' 
                                    : _selectedTime!.format(context),
                                style: TextStyle(color: _selectedTime == null ? Colors.grey : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Capacity (If workshop)
            if (_selectedType == 'Workshop') ...[
              _buildLabel('Capacity'),
              const SizedBox(height: 8),
              _buildTextField(_capacityController, 'Number of attendees', keyboardType: TextInputType.number),
              const SizedBox(height: 20),
            ],
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createMeeting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Meeting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 14),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color.fromARGB(255, 38, 55, 140)),
        ),
      ),
    );
  }
}
