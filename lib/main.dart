import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smart_lighting/firebase_options.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/screens/verification/verify_email_screen.dart'; // Added
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Added for toast messages

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Optional: Log success
    print("Firebase initialized successfully");
  } catch (e) {
    // Handle Firebase initialization errors
    print("Firebase initialization error: $e");
    Fluttertoast.showToast(
      msg: "Failed to initialize Firebase. Please check your connection.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.SNACKBAR,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ), // Optional: Add theme for consistency
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final User? user = snapshot.data;

        if (user != null) {
          // User is signed in, check Firestore data and email verification
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, firestoreSnapshot) {
              if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (firestoreSnapshot.hasError) {
                // Handle Firestore errors (e.g., PERMISSION_DENIED)
                print("Firestore error: ${firestoreSnapshot.error}");
                Fluttertoast.showToast(
                  msg: "Error accessing user data. Please try again later.",
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.SNACKBAR,
                  backgroundColor: Colors.black54,
                  textColor: Colors.white,
                  fontSize: 14.0,
                );
                return const Login(); // Redirect to Login on error
              }

              if (firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
                // User exists in Firestore, check email verification
                if (user.emailVerified) {
                  print("User ${user.email ?? 'unknown'} signed in, email verified, going to Home");
                  return const Home();
                } else {
                  print("User ${user.email ?? 'unknown'} signed in, email not verified");
                  // Navigate to VerifyEmailScreen if email is available
                  return user.email != null
                      ? VerifyEmailScreen(email: user.email!)
                      : const Login(); // Fallback to Login if no email
                }
              } else {
                print("User ${user.uid} signed in but no Firestore data found");
                return const Login(); // No Firestore data, back to Login
              }
            },
          );
        } else {
          // User is not signed in
          print("No user signed in, showing Login");
          return const Login();
        }
      },
    );
  }
}