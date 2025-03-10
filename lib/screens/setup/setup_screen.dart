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

  @override
  void initState() {
    super.initState();
    _loadLastWiFiCredentials();
    controller.initBLE();
  }

  @override
  void dispose() {
    controller.dispose();
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadLastWiFiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      ssidController.text = prefs.getString('lastSSID') ?? '';
      passwordController.text = prefs.getString('lastPassword') ?? '';
    });
  }

  Future<void> _saveWiFiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSSID', ssidController.text);
    await prefs.setString('lastPassword', passwordController.text);
    await prefs.setString('esp32IP', esp32IP ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup ESP32 Connection',
            style: TextStyle(color: Color(0xFFADD8E6))),
        backgroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFB6C1), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.0),
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
                        offset: Offset(0, 5))
                  ],
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wi-Fi Configuration',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFADD8E6))),
                    SizedBox(height: 20),
                    _buildTextField(ssidController, 'Wi-Fi SSID', Icons.wifi),
                    SizedBox(height: 16),
                    _buildTextField(
                        passwordController, 'Wi-Fi Password', Icons.lock,
                        obscure: true),
                    if (esp32IP != null) ...[
                      SizedBox(height: 16),
                      Text('ESP32 IP: $esp32IP',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD8BFD8))),
                    ],
                    SizedBox(height: 20),
                    _buildConnectButton(context),
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
        prefixIcon: Icon(icon, color: Color(0xFFADD8E6)),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildConnectButton(BuildContext context) {
    return ElevatedButton(
      onPressed: isConnecting
          ? null
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
                });
                await _saveWiFiCredentials();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Setup successful'),
                      backgroundColor: Color(0xFFD8BFD8),
                      duration: Duration(milliseconds: 500)),
                );
                // Navigate to Home screen after successful setup
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => Home(esp32IP: esp32IP)));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Setup failed: $e'),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(milliseconds: 500)),
                );
              } finally {
                setState(() => isConnecting = false);
              }
            },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Color(0xFFADD8E6),
        foregroundColor: Colors.white,
      ),
      child: isConnecting
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text('Setup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}

class ESP32Controller {
  String? esp32IP;
  BluetoothDevice? esp32Device;
  StreamSubscription<List<ScanResult>>? subscription;

  Future<void> initBLE() async {
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 20));
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

      await esp32Device!.connect(timeout: Duration(seconds: 20));
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

      await Future.delayed(Duration(seconds: 10));
      List<int> ipBytes = await configChar.read();
      esp32IP = String.fromCharCodes(ipBytes);

      if (esp32IP == null || esp32IP!.isEmpty)
        throw Exception("ESP32 IP not received");
    } catch (e) {
      rethrow;
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
