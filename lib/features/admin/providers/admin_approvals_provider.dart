import 'package:flutter/material.dart';
import '../domain/models/mentor_application_model.dart';

class AdminApprovalsProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  List<MentorApplicationModel> _pendingApplications = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<MentorApplicationModel> get pendingApplications => _pendingApplications;

  AdminApprovalsProvider() {
    loadPendingApplications();
  }

  Future<void> loadPendingApplications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Mock Data
      _pendingApplications = [
        MentorApplicationModel(
          id: '1',
          name: 'Jane Doe',
          email: 'jane.doe@example.com',
          university: 'Isik University',
          department: 'Computer Engineering',
          expertiseAreas: ['Flutter', 'Firebase', 'UI/UX'],
          bio: 'I am a senior student with 2 years of freelance experience in mobile app development.',
          motivation: 'I want to help junior students avoid the mistakes I made when I first started learning Flutter.',
          applicationDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
        MentorApplicationModel(
          id: '2',
          name: 'John Smith',
          email: 'john.smith@example.com',
          university: 'Isik University',
          department: 'Software Engineering',
          expertiseAreas: ['Node.js', 'Express', 'MongoDB'],
          bio: 'Backend developer passionate about scalable systems.',
          motivation: 'I love teaching and sharing my knowledge about system design and backend architecture.',
          applicationDate: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ];
    } catch (e) {
      _error = 'Failed to load applications. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveApplication(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Update mock state
      _pendingApplications.removeWhere((app) => app.id == id);
      
    } catch (e) {
      _error = 'Failed to approve application.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectApplication(String id, String reason) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Update mock state
      _pendingApplications.removeWhere((app) => app.id == id);
      
    } catch (e) {
      _error = 'Failed to reject application.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
