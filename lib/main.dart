import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smart_lighting/firebase_options.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/screens/verification/verify_email_screen.dart';
import 'package:smart_lighting/screens/onboarding/onboarding_screen.dart';
import 'package:smart_lighting/screens/setup/setup_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
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
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DateTime? _lastBackPressed;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final esp32Service = ESP32Service();
        esp32Service.init();
        return esp32Service;
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        home: WillPopScope(
          onWillPop: _onWillPop,
          child: FutureBuilder<bool>(
            future: _checkOnboardingStatus(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const Scaffold(
                  body: Center(child: Text('Error loading app')),
                );
              }
              final hasSeenOnboarding = snapshot.data ?? false;
              return hasSeenOnboarding
                  ? const AuthWrapper()
                  : const OnboardingScreen();
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    const maxDuration = Duration(seconds: 2);

    if (_lastBackPressed != null &&
        now.difference(_lastBackPressed!) <= maxDuration) {
      _lastBackPressed = null;
      return true;
    } else {
      _lastBackPressed = now;
      Fluttertoast.showToast(
        msg: "Press back again to exit",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      return false;
    }
  }

  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeenOnboarding') ?? false;
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

        final user = snapshot.data;
        if (user == null) {
          print("No user signed in, showing Login");
          return const Login();
        }

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
              print("Firestore error: ${firestoreSnapshot.error}");
              Fluttertoast.showToast(
                msg: "Error accessing user data. Please try again later.",
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.SNACKBAR,
                backgroundColor: Colors.black54,
                textColor: Colors.white,
                fontSize: 14.0,
              );
              return const Login();
            }

            if (!firestoreSnapshot.hasData || !firestoreSnapshot.data!.exists) {
              print("User ${user.uid} signed in but no Firestore data found");
              return const Login();
            }

            if (!user.emailVerified) {
              print(
                  "User ${user.email ?? 'unknown'} signed in, email not verified");
              return user.email != null
                  ? VerifyEmailScreen(email: user.email!)
                  : const Login();
            }

            final esp32Service = Provider.of<ESP32Service>(context);
            final role = firestoreSnapshot.data!.get('role') ?? 'Student';
            final bool isAdminApproved =
            role == "Admin"
                ? firestoreSnapshot.data!.get('isAdminApproved') ?? false
                : true;

            if (role == "Admin" && !isAdminApproved) {
              print(
                  "User ${user.email ?? 'unknown'} is an Admin but not yet approved");
              return user.email != null
                  ? VerifyEmailScreen(email: user.email!)
                  : const Login();
            }

            print(
                "User ${user.email ?? 'unknown'} signed in, email verified, role: $role, isConnected: ${esp32Service.isConnected}, esp32IP: ${esp32Service.esp32IP}");
            return esp32Service.isConnected
                ? const Home()
                : const SetupScreen();
          },
        );
      },
    );
  }
}