import 'package:smart_lighting/screens/login/login_screen.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

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
        _passwordError = "Include at least one uppercase letter";
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
      await AuthService().signup(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        context: context,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup failed: \$e")),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: _signin(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Center(
                child: Text(
                  'Register Account',
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
          obscureText: true,
          decoration: InputDecoration(
            filled: true,
            hintText: '••••••••',
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
          ),
        ),
      ],
    );
  }

  Widget _signupButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff0D6EFD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 60),
        elevation: 0,
      ),
      onPressed: _isLoading ? null : _handleSignup,
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text("Sign Up", style: TextStyle(color: Color(0xffF7F7F9))),
    );
  }

  Widget _signin(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                  fontWeight: FontWeight.bold),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => Login()),
                  );
                },
            ),
          ],
        ),
      ),
    );
  }
}
