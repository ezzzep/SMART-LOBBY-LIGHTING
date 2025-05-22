// service_v2.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';
import 'package:smart_lighting/screens/verification/verify_email_screen.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Placeholder for owners' emails (replace with actual emails)
  final List<String> _ownerEmails = ["owner1@example.com", "owner2@example.com"];

  User? get currentUser => _auth.currentUser;

  Future<void> signup({
    required String email,
    required String password,
    required String role,
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
        // Generate a unique token for the verification process
        String verificationToken = Uuid().v4();

        // Store user data in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'role': 'Pending', // Initial role, updated upon verification
          'createdAt': DateTime.now(),
          'isVerified': false,
          'isFirstLogin': true,
          'isAdminRequest': role == "Admin", // Flag for Admin request
          'verificationToken': verificationToken,
        });

        // Send email verification based on role
        if (role == "Admin") {
          await user.sendEmailVerification();
          print(
              "Admin request for ${email}. Please forward the verification link to owners: ${_ownerEmails.join(', ')}");
          print("Verification link contains token: $verificationToken");
          Fluttertoast.showToast(
            msg:
                "Admin request sent. Please forward the verification link to owners for approval.",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: Colors.black54,
            textColor: Colors.white,
            fontSize: 14.0,
          );
        } else if (role == "Student") {
          await user.sendEmailVerification();
          Fluttertoast.showToast(
            msg: "Verification email sent. Please check your inbox.",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: Colors.black54,
            textColor: Colors.white,
            fontSize: 14.0,
          );
        }

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

      String role = userDoc.get('role') ?? 'Student';
      bool adminApproved = role == "Admin" ? await isAdminApproved(user.uid) : true;

      if (role == "Admin" && !adminApproved) {
        throw "Admin account not yet approved.";
      }

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
            MaterialPageRoute(builder: (context) => const Home()),
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

    String role = userDoc.get('role') ?? 'Student';
    bool adminApproved = role == "Admin" ? await isAdminApproved(user.uid) : true;

    if (user.emailVerified && adminApproved) {
      await _firestore.collection('users').doc(user.uid).update({
        'isVerified': true,
      });

      bool isFirstLogin = userDoc.get('isFirstLogin') ?? true;

      if (context.mounted) {
        if (isFirstLogin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
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
        msg: role == "Admin" && !adminApproved
            ? "Wait for the admin to accept your verification request."
            : "Email is not verified. Please check your email.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }

  Future<void> checkEmailVerificationAndSetRole({required String userId}) async {
    User? user = _auth.currentUser;
    if (user == null || !user.emailVerified) return;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final data = userDoc.data() as Map<String, dynamic>;
    final isAdminRequest = data['isAdminRequest'] ?? false;
    final email = user.email;

    if (isAdminRequest && _ownerEmails.contains(email)) {
      // If an owner verifies, set role to Admin
      await _firestore.collection('users').doc(userId).update({
        'role': 'Admin',
        'isVerified': true,
        'isAdminApproved': true,
      });
      Fluttertoast.showToast(
        msg: "Email verified. Admin role assigned.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    } else {
      // If not an owner or not an Admin request, set role to Student
      await _firestore.collection('users').doc(userId).update({
        'role': 'Student',
        'isVerified': true,
      });
      Fluttertoast.showToast(
        msg: "Email verified. Student role assigned.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }

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
    }
  }

  Future<void> updatePassword(String newPassword) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("No user is currently signed in.");
    }

    try {
      print('Updating password for user: ${user.email}');
      await user.updatePassword(newPassword);
      print('Password updated successfully');
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The new password is too weak.';
          break;
        case 'requires-recent-login':
          message = 'Please re-authenticate and try again.';
          break;
        case 'operation-not-allowed':
          message = 'Password updates are restricted in this Firebase project.';
          break;
        default:
          message = 'Failed to update password: ${e.message} (code: ${e.code})';
      }
      print('Update password error: $message');
      throw Exception(message);
    }
  }

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

  // Method to check if the admin request is approved
  Future<bool> isAdminApproved(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    return data['role'] == 'Admin';
  }

  // Method to get user role
  Future<String> getUserRole() async {
    User? user = _auth.currentUser;
    if (user == null) return "Student"; // Default role if user not found
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return "Student";
    return doc.get('role') ?? "Student";
  }
}

class ESP32Service extends ChangeNotifier {
  static final ESP32Service _instance = ESP32Service._internal();
  factory ESP32Service() => _instance;
  ESP32Service._internal() {
    init();
  }

  String? esp32IP;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  bool _isPolling = false;
  bool _isReconnecting = false;
  Timer? _debounceTimer;

  bool _pirSensorActive = false;
  List<String> _pirStatuses = List.filled(5, "NO MOTION");
  double _temperature = 0.0;
  double _humidity = 0.0;
  bool _isConnected = false;
  bool _isSensorsOn = true;
  bool _isAutoMode = true;
  bool _isManualOverride = false;
  String _lastSensorData = "";
  int _sensorOffCount = 0;
  String _relayStatus = "HIGH";
  String _coolerStatus = "ON";
  static const int _sensorOffThreshold = 3;

  int _tempThreshold = 32;
  int _humidThreshold = 65;
  bool _pirEnabled = true;
  int _lightIntensity = 2;
  bool _coolerEnabled = true;
  bool _sensorBasedLightControl = true;

  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  // Chart data management
  List<FlSpot> _tempData = [];
  List<FlSpot> _humidityData = [];
  bool _isCollectingData = false;
  Timer? _dataCollectionTimer;
  static const int _maxDataPoints = 3600; // Store up to 1 hour of data

  bool get pirSensorActive => _pirSensorActive;
  List<String> get pirStatuses => _pirStatuses;
  double get temperature => _temperature;
  double get humidity => _humidity;
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  bool get isSensorsOn => _isSensorsOn;
  bool get isAutoMode => _isAutoMode;
  bool get isManualOverride => _isManualOverride;
  String get lastSensorData => _lastSensorData;
  String get relayStatus => _relayStatus;
  String get coolerStatus => _coolerStatus;
  int get tempThreshold => _tempThreshold;
  int get humidThreshold => _humidThreshold;
  bool get pirEnabled => _pirEnabled;
  int get lightIntensity => _lightIntensity;
  bool get coolerEnabled => _coolerEnabled;
  bool get sensorBasedLightControl => _sensorBasedLightControl;
  int get elapsedSeconds => _elapsedSeconds;

  List<FlSpot> get tempData => _tempData;
  List<FlSpot> get humidityData => _humidityData;
  bool get isCollectingData => _isCollectingData;

  set pirSensorActive(bool value) {
    _pirSensorActive = value;
    _notifyWithDebounce();
  }

  set pirStatuses(List<String> value) {
    _pirStatuses = value;
    _notifyWithDebounce();
  }

  set temperature(double value) {
    _temperature = value;
    _notifyWithDebounce();
  }

  set humidity(double value) {
    _humidity = value;
    _notifyWithDebounce();
  }

  set isConnected(bool value) {
    _isConnected = value;
    if (!value && esp32IP != null && !_isReconnecting) startReconnection();
    _notifyWithDebounce();
  }

  set isReconnecting(bool value) {
    _isReconnecting = value;
    _notifyWithDebounce();
  }

  set isSensorsOn(bool value) {
    _isSensorsOn = value;
    _notifyWithDebounce();
  }

  set isAutoMode(bool value) {
    _isAutoMode = value;
    if (value) {
      _pirEnabled = false; // PIR disabled in auto mode
      _tempThreshold = 32; // Reset to ESP32 default
      _humidThreshold = 65; // Reset to ESP32 default
      _lightIntensity = 2; // Reset to ESP32 default
      _coolerEnabled = true; // Reset to ESP32 default
      _sensorBasedLightControl = true; // Sensor-based control in auto mode
    }
    _notifyWithDebounce();
  }

  set isManualOverride(bool value) {
    _isManualOverride = value;
    if (!value) {
      _sensorBasedLightControl = true; // Reset to sensor-based control
    }
    _notifyWithDebounce();
  }

  set relayStatus(String value) {
    _relayStatus = value;
    _notifyWithDebounce();
  }

  set coolerStatus(String value) {
    _coolerStatus = value;
    _notifyWithDebounce();
  }

  set tempThreshold(int value) {
    _tempThreshold = value;
    _notifyWithDebounce();
  }

  set humidThreshold(int value) {
    _humidThreshold = value;
    _notifyWithDebounce();
  }

  set pirEnabled(bool value) {
    if (!_isManualOverride) {
      _pirEnabled = value;
      _notifyWithDebounce();
    }
  }

  set lightIntensity(int value) {
    _lightIntensity = value;
    _notifyWithDebounce();
  }

  set coolerEnabled(bool value) {
    _coolerEnabled = value;
    _notifyWithDebounce();
  }

  set sensorBasedLightControl(bool value) {
    _sensorBasedLightControl = value;
    _notifyWithDebounce();
  }

  void _notifyWithDebounce() {
    _debounceTimer?.cancel();
    // Removed delay for real-time updates
    notifyListeners();
  }

  Future<void> init() async {
    await _loadESP32IP();
    if (esp32IP != null && esp32IP!.isNotEmpty && !isConnected) {
      await tryReconnect();
      if (!isConnected) startReconnection();
    }
    if (isConnected) _startPolling();
  }

  Future<void> _loadESP32IP() async {
    final prefs = await SharedPreferences.getInstance();
    esp32IP = prefs.getString('esp32IP');
  }

  Future<void> _saveESP32IP() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32IP',  ?? '');
  }

  Future<void> setESP32IP(String ip) async {
    esp32IP = ip;
    await _saveESP32IP();
    isConnected = true;
    isReconnecting = false;
    _reconnectTimer?.cancel();
    _startPolling();
    notifyListeners();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _isPolling = true;
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (esp32IP == null || !_isPolling) {
        timer.cancel();
        _isPolling = false;
        return;
      }
      try {
        final response = await http
            .get(Uri.parse('http://$esp32IP/sensors'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          if (!isConnected) {
            isConnected = true;
            Fluttertoast.showToast(msg: "Reconnected to ESP32");
          }
          String data = response.body.trim();
          _lastSensorData = data;
          _parseSensorData(data);
        } else {
          if (isConnected) {
            isConnected = false;
            Fluttertoast.showToast(msg: "ESP32 disconnected");
          }
        }
      } catch (e) {
        if (isConnected) {
          isConnected = false;
          Fluttertoast.showToast(msg: "ESP32 disconnected");
        }
      }
    });
  }

  void startReconnection() {
    if (esp32IP == null || esp32IP!.isEmpty || isConnected) return;

    _reconnectTimer?.cancel();
    isReconnecting = true;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (isConnected || esp32IP == null) {
        timer.cancel();
        isReconnecting = false;
        return;
      }
      try {
        final response = await http
            .get(Uri.parse('http://$esp32IP/sensors'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          isConnected = true;
          isReconnecting = false;
          _reconnectTimer?.cancel();
          _startPolling();
          Fluttertoast.showToast(msg: "Reconnected to ESP32");
        }
      } catch (e) {}
    });
  }

  Future<void> tryReconnect() async {
    if (esp32IP == null || esp32IP!.isEmpty || isConnected) return;

    isReconnecting = true;
    try {
      final response = await http
          .get(Uri.parse('http://$esp32IP/sensors'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        isConnected = true;
        isReconnecting = false;
        _reconnectTimer?.cancel();
        _startPolling();
        Fluttertoast.showToast(msg: "Connected to ESP32");
      }
    } catch (e) {
      startReconnection();
    } finally {
      isReconnecting = false;
    }
  }

  Future<void> disconnect() async {
    if (esp32IP != null) {
      try {
        final response = await http
            .get(Uri.parse('http://$esp32IP/disconnect'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          Fluttertoast.showToast(
              msg: "ESP32 disconnected and switched to AP mode");
        }
      } catch (e) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('esp32IP');
      esp32IP = null;
      _pollingTimer?.cancel();
      _reconnectTimer?.cancel();
      _isPolling = false;
      isConnected = false;
      isReconnecting = false;
      pirSensorActive = false;
      pirStatuses = List.filled(5, "NO MOTION");
      temperature = 0.0;
      humidity = 0.0;
      relayStatus = "HIGH";
      coolerStatus = "ON";
      _sensorBasedLightControl = true;
      _notifyWithDebounce();
    }
  }

  void _parseSensorData(String data) {
    if (data.startsWith("SENSORS:OFF")) {
      isSensorsOn = false;
      isManualOverride = true;
      isAutoMode = false;
      temperature = 0.0;
      humidity = 0.0;
      pirSensorActive = false;
      pirStatuses = List.filled(5, "NO MOTION");
      _sensorOffCount = 0;
      relayStatus = "HIGH";
      coolerStatus = coolerEnabled ? "ON" : "OFF";
      pirEnabled = false;
      _sensorBasedLightControl = true;
    } else {
      isSensorsOn = true;
    }

    List<String> parts = data.split(",");
    bool tempFound = false;
    bool humidFound = false;

    for (String part in parts) {
      if (part.startsWith("TEMP:")) {
        temperature = double.tryParse(part.split(":")[1]) ?? 0.0;
        tempFound = true;
      } else if (part.startsWith("HUMID:")) {
        humidity = double.tryParse(part.split(":")[1]) ?? 0.0;
        humidFound = true;
      } else if (part.startsWith("PIR:")) {
        String pirStatus = part.split(":")[1];
        if (pirStatus == "DISABLED") {
          pirSensorActive = false;
          pirStatuses = List.filled(5, "NO MOTION");
          pirEnabled = false;
        } else {
          List<String> pirStates = pirStatus.split(",");
          List<String> newStatuses = List.filled(5, "NO MOTION");
          bool anyMotion = false;
          for (int i = 0; i < pirStates.length && i < 5; i++) {
            List<String> stateParts = pirStates[i].split(":");
            if (stateParts.length == 2) {
              newStatuses[i] = stateParts[1];
              if (stateParts[1] == "MOTION") anyMotion = true;
            }
          }
          pirStatuses = newStatuses;
          pirSensorActive = anyMotion;
        }
      } else if (part.startsWith("MODE:")) {
        String mode = part.split(":")[1];
        if (mode == "MANUAL_OVERRIDE") {
          isManualOverride = true;
          isAutoMode = false;
          _sensorBasedLightControl = true;
        } else {
          isManualOverride = false;
          isAutoMode = mode == "AUTO";
          if (isAutoMode) {
            pirEnabled = false;
            tempThreshold = 32;
            humidThreshold = 65;
            lightIntensity = 2;
            coolerEnabled = true;
            _sensorBasedLightControl = true;
          }
        }
      } else if (part.startsWith("RELAYS:")) {
        relayStatus = part.split(":")[1];
      } else if (part.startsWith("COOLER:")) {
        coolerStatus = part.split(":")[1];
      }
    }

    if (tempFound && humidFound && temperature == 0.0 && humidity == 0.0) {
      _sensorOffCount++;
      if (_sensorOffCount >= _sensorOffThreshold) {
        isSensorsOn = false;
        isManualOverride = true;
        isAutoMode = false;
        pirSensorActive = false;
        pirStatuses = List.filled(5, "NO MOTION");
        relayStatus = "HIGH";
        coolerStatus = coolerEnabled ? "ON" : "OFF";
        pirEnabled = false;
        _sensorBasedLightControl = true;
      }
    } else if (temperature > 0.0 || humidity > 0.0) {
      _sensorOffCount = 0;
      if (isManualOverride && relayStatus != "HIGH") {
        isManualOverride = false;
        isAutoMode = true;
        pirEnabled = false;
        tempThreshold = 32;
        humidThreshold = 65;
        lightIntensity = 2;
        coolerEnabled = true;
        _sensorBasedLightControl = true;
      }
    }
    _notifyWithDebounce();
  }

  Future<void> sendConfigToESP32({
    required int tempThreshold,
    required int humidThreshold,
    required bool pirEnabled,
    required int lightIntensity,
    required bool isAutoMode,
    required bool coolerEnabled,
    required bool sensorBasedLightControl,
  }) async {
    if (esp32IP == null || !isConnected) throw Exception("ESP32 not connected");
    if (isManualOverride) {
      Fluttertoast.showToast(
          msg: "Cannot update config in Manual Override Mode");
      throw Exception("Cannot update config in Manual Override Mode");
    }

    // Enforce PIR disabled in auto mode
    if (!isManualOverride) {
      _pirEnabled = false;
    }

    try {
      final response = await http.post(
        Uri.parse('http://$esp32IP/config'),
        body: {
          'tempThreshold': tempThreshold.toString(),
          'humidThreshold': humidThreshold.toString(),
          'pirEnabled': pirEnabled.toString(),
          'lightIntensity': lightIntensity.toString(),
          'isAutoMode': isAutoMode.toString(),
          'coolerEnabled': coolerEnabled.toString(),
          'sensorBasedLightControl': sensorBasedLightControl.toString(),
        },
      );

      if (response.statusCode == 200) {
        this.tempThreshold = tempThreshold;
        this.humidThreshold = humidThreshold;
        this.pirEnabled = pirEnabled;
        this.lightIntensity = lightIntensity;
        this.isAutoMode = isAutoMode;
        this.coolerEnabled = coolerEnabled;
        this._sensorBasedLightControl = sensorBasedLightControl;
        Fluttertoast.showToast(msg: "Configuration updated on ESP32");
      } else {
        throw Exception('Failed to send config: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to update configuration: $e");
      await _syncWithESP32();
      throw Exception("Failed to update configuration: $e");
    }
  }

  Future<void> _syncWithESP32() async {
    if (esp32IP == null || !isConnected) return;
    try {
      final response = await http
          .get(Uri.parse('http://$esp32IP/sensors'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) _parseSensorData(response.body.trim());
    } catch (e) {}
  }

  void startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  void stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void resetElapsedTimer() {
    _elapsedSeconds = 0;
    notifyListeners();
  }

  void startDataCollection() {
    if (_isCollectingData) return; // Prevent multiple starts

    _tempData = [];
    _humidityData = [];
    _isCollectingData = true;
    startElapsedTimer();

    // Collect data every second
    _dataCollectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isConnected || !isSensorsOn) {
        return;
      }

      if (elapsedSeconds >= 3600) { // Stop after 1 hour
        _isCollectingData = false;
        timer.cancel();
        stopElapsedTimer();
        notifyListeners();
        return;
      }

      // Create new lists to trigger widget rebuilds
      List<FlSpot> newTempData = List.from(_tempData);
      List<FlSpot> newHumidityData = List.from(_humidityData);

      // Update temperature data
      if (temperature > 0 && temperature.isFinite) {
        newTempData.add(FlSpot(elapsedSeconds.toDouble(), temperature));
        if (newTempData.length > _maxDataPoints) {
          newTempData.removeAt(0);
        }
      }

      // Update humidity data
      if (humidity > 0 && humidity.isFinite) {
        newHumidityData.add(FlSpot(elapsedSeconds.toDouble(), humidity));
        if (newHumidityData.length > _maxDataPoints) {
          newHumidityData.removeAt(0);
        }
      }

      // Update instance variables with new lists
      _tempData = newTempData;
      _humidityData = newHumidityData;
      notifyListeners();
    });
  }

  void stopDataCollection() {
    _dataCollectionTimer?.cancel();
    _dataCollectionTimer = null;
    _isCollectingData = false;
    stopElapsedTimer();
    notifyListeners();
  }

  void resetDataCollection() {
    stopDataCollection();
    resetElapsedTimer();
    startDataCollection();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _debounceTimer?.cancel();
    _elapsedTimer?.cancel();
    _dataCollectionTimer?.cancel();
    _isPolling = false;
    super.dispose();
  }
}