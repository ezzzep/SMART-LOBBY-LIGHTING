import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/services/service.dart'; // For AuthService
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final ESP32Controller controller = ESP32Controller();
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String? esp32IP;
  bool isConnecting = false;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    controller.initBLE();
  }

  @override
  void dispose() {
    controller.dispose();
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectionStatus() async {
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
        title: const Text(
          'Setup ESP32 Connection',
          style: TextStyle(color: Colors.black),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: DrawerWidget(authService: _authService),
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
                        blurRadius: 20,
                        offset: const Offset(1, 2))
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? 'You are already connected to ESP'
                          : 'Wi-Fi Configuration',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                    const SizedBox(height: 20),
                    if (!isConnected) ...[
                      _buildTextField(ssidController, 'Wi-Fi SSID', Icons.wifi),
                      const SizedBox(height: 16),
                      _buildTextField(
                          passwordController, 'Wi-Fi Password', Icons.lock,
                          obscure: true),
                    ],
                    if (esp32IP != null) ...[
                      const SizedBox(height: 16),
                      Text('ESP32 IP: $esp32IP',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue)),
                    ],
                    const SizedBox(height: 20),
                    _buildActionButton(context),
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
        prefixIcon: Icon(icon, color: Colors.blue),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      child: isConnecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(
              isConnected ? 'DISCONNECT' : 'Setup',
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

      if (configChar == null)
        throw Exception("Config characteristic not found");

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
