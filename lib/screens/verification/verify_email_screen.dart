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
    _checkEmailVerification();
  }

  Future<void> _fetchUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: "No user is currently signed in.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      return;
    }

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

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No user is currently signed in.");
      }

      bool isEmailVerified = user.emailVerified;
      while (!isEmailVerified) {
        await Future.delayed(const Duration(seconds: 3));

        await user?.reload();
        user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception("User session expired during verification.");
        }




        if (user == null) {
          throw Exception("User session expired during verification.");
        }
        isEmailVerified = user.emailVerified;
      }

      if (isEmailVerified) {
        final String? userId = user?.uid;
        if (userId == null) throw Exception("User ID is null.");

        await _authService.checkEmailVerificationAndSetRole(userId: userId);
        await _fetchUserRole();

        setState(() {
          _isVerified = true;
        });

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (!userDoc.exists) {
          throw Exception("User data not found in Firestore.");
        }

        bool isAdminApproved = _role == "Admin"
            ? await _authService.isAdminApproved(userId)
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
            .doc(userId)
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

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SetupScreen()),
          );
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
      if (user == null) {
        Fluttertoast.showToast(
          msg: "No user is currently signed in.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );
        return;
      }

      await user.reload();
      user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Fluttertoast.showToast(
          msg: "User session expired.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );
        return;
      }

      if (!user.emailVerified) {
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
