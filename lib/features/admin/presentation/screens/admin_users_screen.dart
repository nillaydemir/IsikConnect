import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/app_user_model.dart';
import '../../../profile/screens/profile_page.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<AppUser> _allUsers = [];
  List<AppUser> _filteredUsers = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('users')
          .select()
          .not('role', 'eq', 'admin')
          .order('created_at', ascending: false);

      final users = (response as List).map((u) => AppUser.fromJson(u)).toList();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final name = (user.name ?? '').toLowerCase();
        final email = user.email.toLowerCase();
        final role = user.role.toLowerCase();
        return name.contains(query) || email.contains(query) || role.contains(query);
      }).toList();
    });
  }

  Future<void> _handleUserDeactivation(String userId) async {
    try {
      final userRes = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      final role = userRes['role'] as String?;

      if (role == 'student') {
        final matches = await _supabase
            .from('matches')
            .select()
            .eq('student_id', userId)
            .eq('status', 'active');

        for (var match in matches) {
          final mentorId = match['mentor_id'] as String;
          await _supabase
              .from('matches')
              .update({'status': 'cancelled'})
              .eq('id', match['id']);

          final mentorRes = await _supabase
              .from('mentors')
              .select('current_student_count')
              .eq('id', mentorId)
              .maybeSingle();
          if (mentorRes != null) {
            int currentCount = mentorRes['current_student_count'] ?? 0;
            await _supabase.from('mentors').update({
              'current_student_count': currentCount > 0 ? currentCount - 1 : 0,
            }).eq('id', mentorId);
          }
        }

        await _supabase
            .from('students')
            .update({'matched_mentor_id': null})
            .eq('id', userId);

      } else if (role == 'mentor') {
        final matches = await _supabase
            .from('matches')
            .select()
            .eq('mentor_id', userId)
            .eq('status', 'active');

        for (var match in matches) {
          final studentId = match['student_id'] as String;
          await _supabase
              .from('matches')
              .update({'status': 'cancelled'})
              .eq('id', match['id']);

          await _supabase
              .from('students')
              .update({'matched_mentor_id': null})
              .eq('id', studentId);
        }

        await _supabase
            .from('mentors')
            .update({'current_student_count': 0})
            .eq('id', userId);
      }
    } catch (e) {
      debugPrint('Error handling match cancellations on user deactivation: $e');
    }
  }

  Future<void> _updateUserField(String userId, String field, dynamic value) async {
    try {
      await _supabase.from('users').update({field: value}).eq('id', userId);
      if (field == 'is_deleted' && value == true) {
        await _handleUserDeactivation(userId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully'), backgroundColor: Colors.green),
      );
      _fetchUsers();
    } catch (e) {
      debugPrint('Error updating user: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showDeactivationConfirmation(AppUser user) async {
    if (user.isDeleted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Account'),
        content: Text(
          'Are you sure you want to deactivate ${user.name ?? 'this user'}\'s account? They will immediately lose access to the platform and this action CANNOT be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _updateUserField(user.id, 'is_deleted', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 38, 55, 140);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users by name, email or role...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        _allUsers.isEmpty ? 'No users found' : 'No users match your search',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchUsers,
                      child: ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfilePage(targetUserId: user.id),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Opacity(
                                opacity: user.isDeleted ? 0.5 : 1.0,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                                    backgroundImage: user.profileImageUrl != null
                                        ? NetworkImage(user.profileImageUrl!)
                                        : null,
                                    child: user.profileImageUrl == null
                                        ? Text(
                                            (user.name ?? 'U')[0].toUpperCase(),
                                            style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    user.name ?? 'Unknown User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: user.isDeleted ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: user.isDeleted
                                                  ? Colors.red.withValues(alpha: 0.1)
                                                  : (user.role == 'mentor'
                                                      ? Colors.blue.withValues(alpha: 0.1)
                                                      : Colors.orange.withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              user.isDeleted ? 'DEACTIVATED' : user.role.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: user.isDeleted
                                                    ? Colors.red
                                                    : (user.role == 'mentor' ? Colors.blue : Colors.orange),
                                              ),
                                            ),
                                          ),
                                          if (user.isDeleted) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                user.role.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        user.isDeleted
                                            ? Icons.block
                                            : Icons.check_circle,
                                        color: user.isDeleted
                                            ? Colors.red
                                            : Colors.green,
                                        size: 20,
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                                        onSelected: (value) {
                                          if (value == 'view') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ProfilePage(targetUserId: user.id),
                                              ),
                                            );
                                          } else if (value == 'toggle_deactivate') {
                                            _showDeactivationConfirmation(user);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'view',
                                            child: ListTile(
                                              leading: Icon(Icons.person_outline),
                                              title: Text('View Details'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          if (!user.isDeleted)
                                            const PopupMenuItem(
                                              value: 'toggle_deactivate',
                                              child: ListTile(
                                                leading: Icon(Icons.block),
                                                title: Text('Deactivate Account'),
                                                contentPadding: EdgeInsets.zero,
                                                iconColor: Colors.red,
                                                textColor: Colors.red,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
