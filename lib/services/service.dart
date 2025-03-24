import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';
import 'package:smart_lighting/screens/verification/verify_email_screen.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/common/widgets/activation/activation.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add this getter
  User? get currentUser => _auth.currentUser;

  // SIGN UP with Email Verification and Firestore Storage
  Future<void> signup({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification(); // Send email verification

        // Store user details in Firestore with isFirstLogin set to true
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'createdAt': DateTime.now(),
          'isVerified': false,
          'isFirstLogin': true, // Explicitly set for new users
        });

        // Show success message
        Fluttertoast.showToast(
          msg: "Verification email sent. Please check your inbox.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );

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
      String message;
      if (e.code == 'email-already-in-use') {
        message = 'An account already exists with this email.';
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

  // SIGN IN (Only allows verified users)
  Future<bool> signin({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user == null) {
        throw "User object is null after sign-in.";
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification(); // Resend verification email
        throw "unverified:Your email is not verified. A new verification link has been sent.";
      }

      // Fetch user data from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        throw "User data not found in Firestore.";
      }

      bool isFirstLogin = userDoc.get('isFirstLogin') ?? true;

      if (context.mounted) {
        if (isFirstLogin) {
          // New user: Go to ActivationScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ActivationScreen()),
          );
          // Update isFirstLogin to false
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'isFirstLogin': false});
        } else {
          // Existing user: Go directly to Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
          );
        }
      }
      return true; // ✅ Success
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        message = "No account found with this email.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password. Please try again.";
      } else {
        message = "Login failed. Please try again.";
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
      return false; // ❌ Failure
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

  // CHECK EMAIL VERIFICATION STATUS
  Future<void> checkEmailVerification(BuildContext context) async {
    User? user = _auth.currentUser;
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

    await user.reload(); // Refresh user state

    if (user.emailVerified) {
      // Update Firestore that user is verified
      await _firestore.collection('users').doc(user.uid).update({
        'isVerified': true,
      });

      // Check if this is the user's first login
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        Fluttertoast.showToast(
          msg: "User data not found in Firestore.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: Colors.black54,
          textColor: Colors.white,
          fontSize: 14.0,
        );
        return;
      }

      bool isFirstLogin = userDoc.get('isFirstLogin') ?? true;

      if (context.mounted) {
        if (isFirstLogin) {
          // First login after verification: Go to ActivationScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ActivationScreen()),
          );
          // Update isFirstLogin to false
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'isFirstLogin': false});
        } else {
          // Not first login: Go to Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
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
  }

  // SIGN OUT
  Future<void> signout({required BuildContext context}) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false, // Clear the navigation stack
      );
    }
  }
}
