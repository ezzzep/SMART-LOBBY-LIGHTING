// service.dart
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
        await user.sendEmailVerification();

        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'createdAt': DateTime.now(),
          'isVerified': false,
          'isFirstLogin': true,
        });

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

  // SIGN IN (Only allows verified users, updates Firestore email if changed)
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
        await user.sendEmailVerification();
        throw "unverified:Your email is not verified. A new verification link has been sent.";
      }

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        throw "User data not found in Firestore.";
      }

      // Update Firestore email if it differs (e.g., after verifyBeforeUpdateEmail)
      String firestoreEmail = userDoc.get('email') ?? '';
      if (firestoreEmail != user.email) {
        await _firestore.collection('users').doc(user.uid).update({
          'email': user.email,
        });
        print('Updated Firestore email to match Firebase Auth: ${user.email}');
      }

      bool isFirstLogin = userDoc.get('isFirstLogin') ?? true;

      if (context.mounted) {
        if (isFirstLogin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ActivationScreen()),
          );
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'isFirstLogin': false});
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
          );
        }
      }
      return true;
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
      return false;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Login failed: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      return false;
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

    await user.reload();

    if (user.emailVerified) {
      await _firestore.collection('users').doc(user.uid).update({
        'isVerified': true,
      });

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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ActivationScreen()),
          );
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'isFirstLogin': false});
        } else {
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
        (route) => false,
      );
    }
  }

  // REAUTHENTICATE USER
  Future<void> reauthenticate(String password) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("No user is currently signed in.");
    }

    try {
      print('Reauthenticating user: ${user.email}');
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      print('Reauthentication successful');
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'wrong-password') {
        message = 'Incorrect password. Please try again.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      } else {
        message = 'Re-authentication failed: ${e.message} (code: ${e.code})';
      }
      print('Reauthentication error: $message');
      throw Exception(message);
    }
  }

  // UPDATE EMAIL (Using verifyBeforeUpdateEmail)
  Future<void> updateEmail(String newEmail) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("No user is currently signed in.");
    }

    try {
      print('Current email: ${user.email}');
      print('Sending verification email to update to: $newEmail');
      await user.verifyBeforeUpdateEmail(newEmail);
      print(
          'Verification email sent to $newEmail. Email will update once verified.');
      // Firestore update happens on next sign-in
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already in use by another account.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'requires-recent-login':
          message = 'Please re-authenticate and try again.';
          break;
        case 'operation-not-allowed':
          message = 'Email updates are restricted in this Firebase project.';
          break;
        default:
          message =
              'Failed to send verification email: ${e.message} (code: ${e.code})';
      }
      print('Update email error: $message');
      throw Exception(message);
    } catch (e) {
      print('Unexpected error in updateEmail: $e');
      throw Exception('Failed to update email: $e');
    }
  }

  // DELETE ACCOUNT
  Future<void> deleteAccount() async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("No user is currently signed in.");
    }

    try {
      print('Deleting Firestore data for user: ${user.uid}');
      await _firestore.collection('users').doc(user.uid).delete();
      print('Firestore data deleted');
      await user.delete();
      print('User deleted from Firebase Auth');
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'requires-recent-login') {
        message = 'Please re-authenticate and try again.';
      } else {
        message = 'Failed to delete account: ${e.message} (code: ${e.code})';
      }
      print('Delete account error: $message');
      throw Exception(message);
    }
  }
}
