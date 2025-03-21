import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final ESP32Controller controller = ESP32Controller();
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? esp32IP;
  bool isConnecting = false;
  bool isConnected = false;
  bool isEspPoweredOff = false;
  bool isBleMode = false; // New flag to track BLE mode
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
    controller.initBLE();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    controller.dispose();
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      esp32IP = prefs.getString('esp32IP');
      isConnected = esp32IP != null && esp32IP!.isNotEmpty;
      if (!isConnected) {
        ssidController.text = prefs.getString('lastSSID') ?? '';
        passwordController.text = prefs.getString('lastPassword') ?? '';
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (esp32IP != null && esp32IP!.isNotEmpty) {
        // Check HTTP status if IP is available
        try {
          final response = await http
              .get(Uri.parse('http://$esp32IP/sensors'))
              .timeout(const Duration(seconds: 5));
          print('Flutter: Setup Screen HTTP Response Status: ${response.statusCode}');
          print('Flutter: Setup Screen Raw Response: ${response.body}');

          setState(() {
            if (response.statusCode == 200) {
              isEspPoweredOff = false;
              isConnected = true;
              isBleMode = false;
            } else {
              isEspPoweredOff = false; // Not off, just not in WiFi mode yet
              isConnected = false;
              _checkBleMode(); // Check if in BLE mode
            }
          });
        } catch (e) {
          print('Flutter: Error polling ESP32 in Setup Screen: $e');
          setState(() {
            isEspPoweredOff = false;
            isConnected = false;
          });
          _checkBleMode(); // Fallback to BLE check
        }
      } else {
        // No IP, check BLE mode
        _checkBleMode();
      }
    });
  }

  Future<void> _checkBleMode() async {
    bool espFound = false;
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await for (var scanResults in FlutterBluePlus.scanResults) {
        for (ScanResult r in scanResults) {
          if (r.device.name == "ESP32_PIR_Sensor") {
            espFound = true;
            break;
          }
        }
        if (espFound) break;
      }
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Flutter: BLE scan failed: $e');
    }

    setState(() {
      isBleMode = espFound;
      isEspPoweredOff = !espFound && !isConnected; // Off only if neither BLE nor HTTP works
      print('Flutter: ESP32 status - Powered off: $isEspPoweredOff, Connected: $isConnected, BLE Mode: $isBleMode');
    });
  }

  Future<void> _attemptReconnect() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedSSID = prefs.getString('lastSSID');
    String? savedPassword = prefs.getString('lastPassword');

    if (savedSSID == null || savedPassword == null) return;

    setState(() {
      isConnecting = true;
    });

    try {
      await controller.configureWiFi(savedSSID, savedPassword);
      setState(() {
        esp32IP = controller.esp32IP;
        isConnected = true;
        isEspPoweredOff = false;
        isBleMode = false;
      });
      await _saveWiFiCredentials();
      Fluttertoast.showToast(
        msg: "Reconnected to ESP32",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home(esp32IP: esp32IP)),
      );
    } catch (e) {
      print('Flutter: Auto-reconnect failed: $e');
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  Future<void> _saveWiFiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSSID', ssidController.text);
    await prefs.setString('lastPassword', passwordController.text);
    await prefs.setString('esp32IP', esp32IP ?? '');
  }

  Future<void> _disconnect() async {
    if (esp32IP != null) {
      try {
        final response = await http.get(Uri.parse('http://$esp32IP/restart'));
        if (response.statusCode == 200) {
          print('Flutter: ESP32 restart command sent');
          Fluttertoast.showToast(
            msg: "ESP32 restarting...",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      } catch (e) {
        print('Flutter: Error sending restart: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('esp32IP');
      setState(() {
        esp32IP = null;
        isConnected = false;
        isConnecting = false;
        isBleMode = true; // Assume BLE mode after restart
        ssidController.text = prefs.getString('lastSSID') ?? '';
        passwordController.text = prefs.getString('lastPassword') ?? '';
      });
      controller.initBLE();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup ESP32 Connection',
            style: TextStyle(color: Color(0xFFADD8E6))),
        backgroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFB6C1), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEspPoweredOff
                          ? 'ESP32 is powered off'
                          : (isConnected
                          ? 'You are already connected to ESP'
                          : 'Wi-Fi Configuration'),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFADD8E6)),
                    ),
                    const SizedBox(height: 20),
                    if (!isConnected && !isEspPoweredOff) ...[
                      _buildTextField(
                          ssidController, 'Wi-Fi SSID', Icons.wifi),
                      const SizedBox(height: 16),
                      _buildTextField(passwordController, 'Wi-Fi Password',
                          Icons.lock, obscure: true),
                    ],
                    if (esp32IP != null && !isEspPoweredOff) ...[
                      const SizedBox(height: 16),
                      Text('ESP32 IP: $esp32IP',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD8BFD8))),
                    ],
                    const SizedBox(height: 20),
                    if (!isEspPoweredOff) _buildActionButton(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFADD8E6)),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return ElevatedButton(
      onPressed: isConnecting
          ? null
          : (isConnected
          ? _disconnect
          : () async {
        setState(() => isConnecting = true);
        try {
          if (ssidController.text.isEmpty ||
              passwordController.text.isEmpty) {
            throw Exception("Please enter Wi-Fi SSID and password");
          }
          await controller.configureWiFi(
              ssidController.text, passwordController.text);
          setState(() {
            esp32IP = controller.esp32IP;
            isConnected = true;
            isEspPoweredOff = false;
            isBleMode = false;
          });
          await _saveWiFiCredentials();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Setup successful'),
                backgroundColor: Color(0xFFD8BFD8),
                duration: Duration(milliseconds: 500)),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => Home(esp32IP: esp32IP)),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Setup failed: $e'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(milliseconds: 500)),
          );
        } finally {
          setState(() => isConnecting = false);
        }
      }),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFFADD8E6),
        foregroundColor: Colors.white,
      ),
      child: isConnecting
          ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2))
          : Text(
        isConnected ? 'DISCONNECT' : 'SETUP',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ESP32Controller {
  String? esp32IP;
  BluetoothDevice? esp32Device;
  StreamSubscription<List<ScanResult>>? subscription;

  Future<void> initBLE() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));
    subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name == "ESP32_PIR_Sensor") {
          esp32Device = r.device;
          FlutterBluePlus.stopScan();
          subscription?.cancel();
          subscription = null;
          break;
        }
      }
    });
  }

  Future<void> configureWiFi(String ssid, String password) async {
    try {
      if (esp32Device == null) await initBLE();
      if (esp32Device == null) throw Exception("No ESP32 device found");

      await esp32Device!.connect(timeout: const Duration(seconds: 20));
      List<BluetoothService> services = await esp32Device!.discoverServices();

      BluetoothCharacteristic? configChar;
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.uuid.toString() == "74675807-4e0f-48a3-9ee8-d571dc87896e") {
            configChar = char;
            break;
          }
        }
        if (configChar != null) break;
      }

      if (configChar == null) throw Exception("Config characteristic not found");

      await configChar.setNotifyValue(true);
      String configString = "WIFI:$ssid:$password";
      await configChar.write(configString.codeUnits, withoutResponse: false);

      await Future.delayed(const Duration(seconds: 10));
      List<int> ipBytes = await configChar.read();
      esp32IP = String.fromCharCodes(ipBytes);

      if (esp32IP == null || esp32IP!.isEmpty)
        throw Exception("ESP32 IP not received");
    } catch (e) {
      throw e;
    } finally {
      await esp32Device?.disconnect();
    }
  }

  void dispose() {
    subscription?.cancel();
    esp32Device?.disconnect();
    subscription = null;
    esp32Device = null;
  }
}