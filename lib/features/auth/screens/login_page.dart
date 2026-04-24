import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'IşıkConnect',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A1930), // Lacivert renk
                  ),
                ),
                const SizedBox(height: 60),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text.trim();
                    
                    if (email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an email and password.'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    // --- MOCK ADMIN CHECK ---
                    if (email == 'admin@isikconnect.edu.tr' && password == 'admin123') {
                      CurrentSession().user = AppUser.fromJson({
                        'id': 'mock-admin-id',
                        'email': 'admin@isikconnect.edu.tr',
                        'role': 'admin',
                        'created_at': DateTime.now().toIso8601String(),
                        'name': 'System Admin'
                      });
                      Navigator.pushReplacementNamed(context, '/admin');
                      return;
                    }
                    // ------------------------

                    try {
                      // Custom Login: Verify credentials entirely from public.users table
                      final userDoc = await Supabase.instance.client
                          .from('users')
                          .select()
                          .eq('email', email)
                          .maybeSingle();

                      if (userDoc == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User not found. Please register first.'), backgroundColor: Colors.red),
                        );
                      } else if (userDoc['password'] != password) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incorrect password.'), backgroundColor: Colors.red),
                        );
                      } else {
                        if (!context.mounted) return;
                        // Credentials are correct, navigate to app
                        CurrentSession().user = AppUser.fromJson(userDoc);
                        
                        // Proceed to corresponding home based on role
                        if (userDoc['role'] == 'mentor') {
                           Navigator.pushReplacementNamed(context, '/mentorHome');
                        } else if (userDoc['role'] == 'admin') {
                           Navigator.pushReplacementNamed(context, '/admin');
                        } else {
                           Navigator.pushReplacementNamed(context, '/studentHome');
                        }
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color.fromARGB(255, 38, 55, 140),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0A1930),
                  ),
                  child: const Text(
                    'If you dont have an account? Register',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
