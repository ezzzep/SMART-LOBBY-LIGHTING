import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';
import 'package:smart_lighting/screens/setup/setup_screen.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/services/service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  VerifyEmailScreenState createState() => VerifyEmailScreenState();
}

class VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isLoading = false;
  bool _isVerified = false;
  final AuthService _authService = AuthService();
  String? _role;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _checkEmailVerification(); // Start polling for email verification
  }

  Future<void> _fetchUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _role = userDoc.get('role') ?? 'Pending';
        });
      }
    }
  }

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No user is currently signed in.");
      }

      // Poll for email verification status
      while (user?.emailVerified != true) {
        await Future.delayed(const Duration(seconds: 3));
        await user?.reload(); // Safe to call if user is not null
        user = FirebaseAuth.instance.currentUser; // Refresh user object
        if (user == null) {
          throw Exception("User session expired during verification.");
        }
      }

      if (user?.emailVerified == true) {
        // Update role based on verification
        await _authService.checkEmailVerificationAndSetRole(userId: user!.uid);

        // Refresh role after assignment
        await _fetchUserRole();

        setState(() {
          _isVerified = true;
        });

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (!userDoc.exists) {
          throw Exception("User data not found in Firestore.");
        }

        bool isAdminApproved = _role == "Admin"
            ? await _authService.isAdminApproved(user!.uid)
            : true;

        if (_role == "Admin" && !isAdminApproved) {
          Fluttertoast.showToast(
            msg: "Wait for the admin to accept",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: Colors.black54,
            textColor: Colors.white,
            fontSize: 14.0,
          );
          return;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({'isVerified': true});

        Fluttertoast.showToast(
          msg: _role == "Admin"
              ? "Congratulations, you are now an Admin!"
              : "Email successfully verified!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );

        await Future.delayed(const Duration(seconds: 2)); // Wait for toast

        if (mounted) {
          // Redirect based on role
          if (_role == "Admin") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SetupScreen()),
            );
          } else {
            // For Students, go to SetupScreen in ESP32 IP input mode
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SetupScreen()),
            );
          }
        }
      } else {
        Fluttertoast.showToast(
          msg: "Email is not verified. Please check your email.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.reload(); // Safe to call with null-aware operator
      user = FirebaseAuth.instance.currentUser;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        Fluttertoast.showToast(
          msg: 'Verification email sent. Please check your inbox.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );
      } else {
        Fluttertoast.showToast(
          msg: 'Email is already verified.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error resending email: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _role == "Admin"
                  ? "A verification email has been sent to ${widget.email}. Please forward the verification link to an owner for approval."
                  : "A verification email has been sent to ${widget.email}. Please check your inbox and verify your email.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : _isVerified
                ? const Text('Email verified! Redirecting...')
                : ElevatedButton(
              onPressed: _checkEmailVerification,
              child: const Text('Check Verification Status'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _role == "Admin" ? null : _resendVerificationEmail,
              child: const Text('Resend Verification Email'),
            ),
          ],
        ),
      ),
    );
  }
}