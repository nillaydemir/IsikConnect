import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/forum_service.dart';
import '../../../core/services/current_session.dart';

class CreatePostScreen extends StatefulWidget {
  final String initialCategory;

  const CreatePostScreen({super.key, required this.initialCategory});

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

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
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

    // Removed eventDate validation since forum workshops are just announcements

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      
      if (_selectedImage != null) {
        final bytes = _selectedImage!.bytes;
        final path = _selectedImage!.path;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name.replaceAll(' ', '_')}';
        
        if (bytes != null) {
           await Supabase.instance.client.storage.from('forum-images').uploadBinary(fileName, bytes);
        } else if (path != null) {
           await Supabase.instance.client.storage.from('forum-images').upload(fileName, File(path));
        }
        
        imageUrl = Supabase.instance.client.storage.from('forum-images').getPublicUrl(fileName);
      }

      await ForumService().createPost(
        category: _category,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        imageUrl: imageUrl,
        eventDate: null,
        meetingLink: null,
        participantLimit: null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created successfully!'), backgroundColor: Colors.green));
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
        title: const Text('Create Post', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          if (!_isLoading)
            TextButton(
              onPressed: _submit,
              child: const Text('Post', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
            if (_selectedImage != null)
              Stack(
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                    ),
                    child: const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  )
                ],
              ),
            
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_selectedImage == null ? 'Add Image/Cover' : 'Change Image'),
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
