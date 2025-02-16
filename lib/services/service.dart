import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../screens/dashboard/dashboard_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/verification/verify_email_screen.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signup({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      // Try creating a new user
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Send email verification
        await user.sendEmailVerification();

        // Show success message
        Fluttertoast.showToast(
          msg: "Verification email sent. Please check your inbox.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );

        // Navigate to the verification screen
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyEmailScreen(email: email),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'email-already-in-use') {
        message = 'An account already exists with that email.';
      } else if (e.code == 'weak-password') {
        message = 'The password is too weak.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'This sign-up method is not enabled.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      } else {
        message = 'Signup failed. Please try again.';
      }

      if (context.mounted) {
        Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );
      }
    }
  }
  Future<bool> signin({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true; // ✅ Success
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Login failed: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      return false; // ❌ Failure
    }
  }

  Future<void> signout({required BuildContext context}) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Login()),
      );
    }
  }
}
