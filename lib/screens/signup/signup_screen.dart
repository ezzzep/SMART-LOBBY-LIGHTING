import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_lighting/screens/verification/verify_email_screen.dart';

class SignupScreen extends StatefulWidget {
  final String selectedRole;

  const SignupScreen({super.key, required this.selectedRole});

  @override
  State<SignupScreen> createState() => _SignupState();
}

class _SignupState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    setState(() {
      _emailError = value.isEmpty
          ? "Email is required"
          : (!emailRegex.hasMatch(value) ? "Enter a valid email" : null);
    });
  }

  void _validatePassword(String value) {
    final hasUppercase = RegExp(r'[A-Z]');
    final hasLowercase = RegExp(r'[a-z]');
    final hasNumber = RegExp(r'\d');
    final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>_]');

    setState(() {
      if (value.isEmpty) {
        _passwordError = "Password is required";
      } else if (value.length < 8 || value.length > 15) {
        _passwordError = "Password must be 8-15 characters";
      } else if (!hasUppercase.hasMatch(value)) {
        _passwordError = "Include at least one uppercase letter";
      } else if (!hasLowercase.hasMatch(value)) {
        _passwordError = "Include at least one lowercase letter";
      } else if (!hasNumber.hasMatch(value)) {
        _passwordError = "Include at least one number";
      } else if (!hasSpecialChar.hasMatch(value)) {
        _passwordError = "Include at least one special character";
      } else {
        _passwordError = null;
      }
    });
  }

  Future<void> _handleSignup() async {
    if (_emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);

    try {
      // Perform signup via AuthService
      await _authService.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: widget.selectedRole,
        context: context,
      );

      // Get the current user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && widget.selectedRole == 'Admin' && mounted) {
        // Check if a pending admin request already exists
        final docRef = FirebaseFirestore.instance
            .collection('pending_admins')
            .doc(user.uid);
        final doc = await docRef.get();
        if (!doc.exists) {
          // Create a pending admin request
          await docRef.set({
            'email': user.email,
            'uid': user.uid,
            'requestedAt': FieldValue.serverTimestamp(),
          });
          // Show feedback to the user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin request submitted. Awaiting approval.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Optional: Notify user if request already exists
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin request already submitted.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (mounted) {
        // Show success for non-admin roles
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${widget.selectedRole} account created successfully.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Navigate to VerifyEmailScreen after signup, passing the email
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(
              email: _emailController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Signup failed: $e",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 14.0,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Center(
                child: Text(
                  'Register as ${widget.selectedRole}',
                  style: GoogleFonts.raleway(
                    textStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
              _emailAddress(),
              const SizedBox(height: 20),
              _password(),
              const SizedBox(height: 50),
              _signupButton(),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _signin(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          onChanged: _validateEmail,
          decoration: InputDecoration(
            filled: true,
            hintText: 'yourname@example.com',
            hintStyle: const TextStyle(color: Color(0xff6A6A6A), fontSize: 14),
            fillColor: const Color(0xffF7F7F9),
            errorText: _emailError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _emailError == null && _emailController.text.isNotEmpty
                    ? Colors.green
                    : (_emailError != null ? Colors.red : Colors.grey),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _password() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          onChanged: _validatePassword,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            filled: true,
            hintText: '@Test1234',
            hintStyle: const TextStyle(color: Color(0xff6A6A6A), fontSize: 14),
            fillColor: const Color(0xffF7F7F9),
            errorText: _passwordError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _passwordError == null &&
                        _passwordController.text.isNotEmpty
                    ? Colors.green
                    : (_passwordError != null ? Colors.red : Colors.grey),
                width: 2,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
      ],
    );
  }

  Widget _signupButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(83, 166, 234, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 60),
        elevation: 0,
      ),
      onPressed: _isLoading ? null : _handleSignup,
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              "Sign Up",
              style: TextStyle(color: Color(0xffF7F7F9)),
            ),
    );
  }

  Widget _signin(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            const TextSpan(
              text: "Already have an account? ",
              style: TextStyle(color: Color(0xff6A6A6A), fontSize: 16),
            ),
            TextSpan(
              text: "Log In",
              style: const TextStyle(
                color: Color(0xff1A1D1E),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                  );
                },
            ),
          ],
        ),
      ),
    );
  }
}