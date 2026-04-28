import 'package:flutter/material.dart';
import '../domain/models/mentor_application_model.dart';
import '../../../core/services/api_service.dart';

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
      final data = await ApiService().getPendingApplications();
      _pendingApplications = data.map((json) => MentorApplicationModel.fromJson(json)).toList();

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
      await ApiService().updateApplicationStatus(id, 'approved');
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
      await ApiService().updateApplicationStatus(id, 'rejected');
      _pendingApplications.removeWhere((app) => app.id == id);
      
    } catch (e) {
      _error = 'Failed to reject application.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
