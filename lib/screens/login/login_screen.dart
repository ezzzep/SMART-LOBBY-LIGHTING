import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smart_lighting/screens/signup/signup_screen.dart';
import 'package:smart_lighting/services/service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  bool _passwordHasError = false;

  final AuthService _authService = AuthService();

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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _emailAddress(),
                    const SizedBox(height: 20),
                    _password(),
                    const SizedBox(height: 50),
                    _signin(context),
                  ],
                ),
              ),
            ),
            _signup(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/login/smart_lighting_icon.png',
          width: 260,
          height: 260,
          fit: BoxFit.cover,
        ),
      ],
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
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            filled: true,
            hintText: 'Enter your email',
            hintStyle: const TextStyle(
              color: Color(0xff6A6A6A),
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            fillColor: const Color(0xffF7F7F9),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
            errorText: _emailError,
            enabledBorder: OutlineInputBorder(
              borderSide: _emailError != null
                  ? const BorderSide(color: Colors.red, width: 1.5)
                  : BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: _emailError != null
                  ? const BorderSide(color: Colors.red, width: 1.5)
                  : const BorderSide(color: Colors.blue, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onChanged: (_) => setState(() {
            _emailError = null;
            _passwordHasError = false;
          }),
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
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          obscureText: _obscurePassword,
          controller: _passwordController,
          decoration: InputDecoration(
            filled: true,
            hintText: 'Enter your password',
            hintStyle: const TextStyle(
              color: Color(0xff6A6A6A),
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            fillColor: const Color(0xffF7F7F9),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: _passwordHasError
                  ? const BorderSide(color: Colors.red, width: 1.5)
                  : BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: _passwordHasError
                  ? const BorderSide(color: Colors.red, width: 1.5)
                  : const BorderSide(color: Colors.blue, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            errorText: _passwordError,
            errorStyle: const TextStyle(color: Colors.red),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onChanged: (_) => setState(() {
            _passwordError = null;
            _passwordHasError = false;
          }),
        ),
      ],
    );
  }

  Widget _signin(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff0D6EFD),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        minimumSize: const Size(double.infinity, 60),
        elevation: 0,
      ),
      onPressed: _isLoading
          ? null
          : () async {
        setState(() {
          _emailError = null;
          _passwordError = null;
          _passwordHasError = false;
        });

        if (_emailController.text.trim().isEmpty) {
          setState(() => _emailError = "Please enter your email.");
          return;
        }

        if (_passwordController.text.trim().isEmpty) {
          setState(() {
            _passwordError = "Please enter your password.";
            _passwordHasError = true;
          });
          return;
        }

        setState(() => _isLoading = true);

        // Use AuthService to handle sign-in
        bool success = await _authService.signin(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          context: context,
        );

        if (!success) {
          setState(() {
            _emailError = "Login failed. Please try again.";
          });
        }

        setState(() => _isLoading = false);
      },
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text("Sign In", style: TextStyle(color: Colors.white)),
    );
  }

  Widget _signup(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            const TextSpan(
              text: "New User? ",
              style: TextStyle(
                color: Color(0xff6A6A6A),
                fontWeight: FontWeight.normal,
                fontSize: 16,
              ),
            ),
            TextSpan(
              text: "Create Account",
              style: const TextStyle(
                color: Color(0xff1A1D1E),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Signup(),
                    ),
                  );
                },
            ),
          ],
        ),
      ),
    );
  }
}