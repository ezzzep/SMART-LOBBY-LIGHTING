import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:smart_lighting/screens/signup/signup_screen.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';

// Placeholder for SignupScreen (remains unchanged)
class Signup extends StatelessWidget {
  final String selectedRole;
  const Signup({super.key, required this.selectedRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$selectedRole Signup')),
      body: Center(child: Text('Signup Screen for $selectedRole')),
    );
  }
}

class UserRoleScreen extends StatelessWidget {
  const UserRoleScreen({super.key});

  void _handleStudentSelection(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Student role selected'),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SignupScreen(selectedRole: 'Student'),
          ),
        );
      }
    });
  }

  void _showAdminSignupDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const _AdminSignupDialog(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _sendAdminNotificationEmail({
    required String email,
    required String uid,
    required String requestedAt,
    String? verificationLink,
  }) async {
    const String serviceId = 'service_kikzfnd';
    const String templateId = 'template_ckmvwnl';
    const String publicKey = 'lphhsN_FaK6JjqV0I';
    const String privateKey = 'fwgpskCKiqLRhdYzMPJQ4';
    const String ownerEmail = 'smartlighting2025@gmail.com';

    try {
      await emailjs.send(
        serviceId,
        templateId,
        {
          'admin_email': email,
          'admin_uid': uid,
          'requested_at': requestedAt,
          'verification_link':
              verificationLink ?? 'No verification link available',
          'to_email': ownerEmail,
        },
        const emailjs.Options(
          publicKey: publicKey,
          privateKey: privateKey,
        ),
      );
      print('Email sent successfully to $ownerEmail');
      Fluttertoast.showToast(
        msg: 'Email sent successfully to owner',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      print('Failed to send email: $e');
      throw Exception('Failed to send email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[100]!,
              Colors.teal[100]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 32,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome to Smart Lighting',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please select your role to continue',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    RoleButton(
                      role: 'Admin',
                      icon: Icons.admin_panel_settings,
                      description: 'Manage and control the system',
                      onPressed: () => _showAdminSignupDialog(context),
                    ),
                    const SizedBox(height: 20),
                    RoleButton(
                      role: 'Student',
                      icon: Icons.school,
                      description: 'Access and interact with features',
                      onPressed: () => _handleStudentSelection(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSignupDialog extends StatefulWidget {
  const _AdminSignupDialog();

  @override
  _AdminSignupDialogState createState() => _AdminSignupDialogState();
}

class _AdminSignupDialogState extends State<_AdminSignupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'At least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'At least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'At least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'At least one number';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_]').hasMatch(value)) {
      return 'At least one special character';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Create Firebase account
        final userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user == null) {
          throw Exception('Failed to retrieve user');
        }

        // Generate email verification link
        String verificationLink = 'Verification email sent via Firebase';
        try {
          await user.sendEmailVerification();
        } catch (linkError) {
          print('Error sending verification email: $linkError');
          verificationLink = 'Failed to send verification email';
        }

        // Save user data to Firestore
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'email': _emailController.text.trim(),
            'uid': user.uid,
            'role': 'Admin',
            'createdAt': DateTime.now().toIso8601String(),
            'isFirstLogin': true,
            'isVerified': false,
          });
        } catch (firestoreError) {
          print('Firestore error: $firestoreError');
          Fluttertoast.showToast(
            msg:
                'Admin signup completed, but failed to save to Firestore: $firestoreError',
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }

        // Send email via EmailJS with verification link
        try {
          await UserRoleScreen()._sendAdminNotificationEmail(
            email: _emailController.text.trim(),
            uid: user.uid,
            requestedAt: DateTime.now().toIso8601String(),
            verificationLink: verificationLink,
          );
        } catch (emailError) {
          print('EmailJS error: $emailError');
          Fluttertoast.showToast(
            msg:
                'Admin signup completed, but failed to send email: $emailError',
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }

        if (context.mounted) {
          // Close the dialog
          Navigator.pop(context);
          // Navigate to LoginScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const Login(),
            ),
          );
        }
      } catch (e) {
        print('Signup error: $e');
        Fluttertoast.showToast(
          msg: 'Error: $e',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRect(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Admin Signup Request',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              softWrap: true,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Submit your details to request admin access',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        obscureText: !_isPasswordVisible,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 32),
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// RoleButton class remains unchanged
class RoleButton extends StatefulWidget {
  final String role;
  final IconData icon;
  final String description;
  final VoidCallback onPressed;

  const RoleButton({
    super.key,
    required this.role,
    required this.icon,
    required this.description,
    required this.onPressed,
  });

  @override
  State<RoleButton> createState() => _RoleButtonState();
}

class _RoleButtonState extends State<RoleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          semanticsLabel: '${widget.role} role',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
