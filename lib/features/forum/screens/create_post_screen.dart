import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/forum_post_model.dart';
import '../services/forum_service.dart';
import '../../../core/services/current_session.dart';
import '../../../core/services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  final String initialCategory;
  final ForumPost? editPost;

  const CreatePostScreen({super.key, required this.initialCategory, this.editPost});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late String _category;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  // Removed workshop specific controllers as it's now just an announcement


  bool _isLoading = false;
  PlatformFile? _selectedImage;
  bool _isImageCleared = false;

  List<Map<String, dynamic>> _myWorkshops = [];
  String? _selectedMeetingId;
  bool _loadingWorkshops = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (widget.editPost != null) {
      _titleController.text = widget.editPost!.title;
      _contentController.text = widget.editPost!.content;
      _category = widget.editPost!.category;
      _selectedMeetingId = widget.editPost!.meetingLink;
    }
    if (CurrentSession().user?.role == 'mentor') {
      _loadWorkshops();
    }
  }

  Future<void> _loadWorkshops() async {
    setState(() => _loadingWorkshops = true);
    try {
      final user = CurrentSession().user;
      if (user != null) {
        final allMeetings = await ApiService().getMeetings();
        final response = allMeetings
            .where((w) => w['mentor_id'] == user.id && w['meeting_type'] == 'Workshop')
            .toList();

        response.sort((a, b) {
          final aDate = a['meeting_date'] != null ? DateTime.parse(a['meeting_date']) : DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b['meeting_date'] != null ? DateTime.parse(b['meeting_date']) : DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });

        if (mounted) {
          setState(() {
            _myWorkshops = response;
            // Verify selected ID is valid in list
            if (_selectedMeetingId != null && !_myWorkshops.any((w) => w['id'].toString() == _selectedMeetingId)) {
              _selectedMeetingId = null;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading workshops: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingWorkshops = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result != null) {
      setState(() => _selectedImage = result.files.first);
    }
  }

  // Removed _selectDate and _selectTime methods

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in the content')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = widget.editPost?.imageUrl;
      
      if (_isImageCleared) {
        imageUrl = null;
      }
      
      if (_selectedImage != null) {
        imageUrl = await ApiService().uploadForumImage(_selectedImage!);
      }

      DateTime? eventDate;
      if (_category == 'Workshops' && _selectedMeetingId != null) {
        final matchedList = _myWorkshops.where((w) => w['id'].toString() == _selectedMeetingId).toList();
        if (matchedList.isNotEmpty && matchedList.first['meeting_date'] != null) {
          eventDate = DateTime.parse(matchedList.first['meeting_date']);
        }
      }

      if (widget.editPost != null) {
        await ForumService().updatePost(
          postId: widget.editPost!.id,
          category: _category,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrl: imageUrl,
          meetingLink: _selectedMeetingId,
          eventDate: eventDate,
        );
        if (!mounted) return;
        Navigator.pop(context, true); // Return true to trigger refresh
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post updated successfully!'), backgroundColor: Colors.green));
      } else {
        await ForumService().createPost(
          category: _category,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrl: imageUrl,
          eventDate: eventDate,
          meetingLink: _selectedMeetingId,
          participantLimit: null,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);
    final isMentor = CurrentSession().user?.role == 'mentor';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.editPost != null ? 'Edit Post' : 'Create Post', style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          if (!_isLoading)
            TextButton(
              onPressed: _submit,
              child: Text(widget.editPost != null ? 'Save' : 'Post', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Selector
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                if (isMentor) const DropdownMenuItem(value: 'Announcements', child: Text('Announcements')),
                const DropdownMenuItem(value: 'Q&A', child: Text('Q&A')),
                if (isMentor) const DropdownMenuItem(value: 'Workshops', child: Text('Workshops')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            if (_category == 'Workshops' && isMentor) ...[
              const SizedBox(height: 20),
              _loadingWorkshops
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedMeetingId,
                      decoration: InputDecoration(
                        labelText: 'Select Associated Workshop',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.class_outlined, color: primaryColor),
                      ),
                      items: _myWorkshops.map((w) {
                        final date = w['meeting_date'] != null
                            ? DateTime.parse(w['meeting_date']).toLocal()
                            : null;
                        final dateStr = date != null
                            ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                            : 'No Date';
                        return DropdownMenuItem<String>(
                          value: w['id'].toString(),
                          child: Text(
                            '${w['title']} ($dateStr)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedMeetingId = val);
                      },
                    ),
            ],
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              maxLines: null,
            ),
            const Divider(),

            // Removed workshop specific fields since it's just an announcement


            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: 'What do you want to share?',
                border: InputBorder.none,
              ),
              maxLines: null,
              minLines: 5,
            ),
            
            const SizedBox(height: 20),
            if (_selectedImage != null || (widget.editPost?.imageUrl != null && !_isImageCleared))
              Stack(
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                      image: (_selectedImage == null && widget.editPost?.imageUrl != null)
                          ? DecorationImage(
                              image: NetworkImage(widget.editPost!.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (_selectedImage != null)
                        ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                        : null,
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => setState(() {
                        _selectedImage = null;
                        _isImageCleared = true;
                      }),
                    ),
                  )
                ],
              ),
            
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text((_selectedImage == null && (widget.editPost?.imageUrl == null || _isImageCleared))
                  ? 'Add Image/Cover'
                  : 'Change Image'),
              style: ElevatedButton.styleFrom(
                foregroundColor: primaryColor,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
