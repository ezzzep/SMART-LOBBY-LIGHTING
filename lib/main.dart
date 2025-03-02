import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smart_lighting/firebase_options.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
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
          // User is signed in, check Firestore data
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
                return const Login(); // Redirect to Login on error
              }

              if (firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
                // User exists in Firestore, check email verification
                if (user.emailVerified) {
                  print("User ${user.email} signed in, email verified, going to Home");
                  return const Home();
                } else {
                  print("User ${user.email} signed in, email not verified");
                  // Uncomment and use VerifyEmailScreen if you have it
                  // return VerifyEmailScreen(email: user.email!);
                  return const Login(); // For now, redirect to Login
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