import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:provider/provider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool isConnecting = false;
  bool isChecking = true;
  bool _obscurePassword = true; // For password visibility toggle

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  @override
  void dispose() {
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectionStatus() async {
    final esp32Service = Provider.of<ESP32Service>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    if (esp32Service.esp32IP != null && !esp32Service.isConnected) {
      await esp32Service.tryReconnect();
    }

    setState(() {
      isChecking = false;
      if (!esp32Service.isConnected) {
        ssidController.text = prefs.getString('lastSSID') ?? '';
        passwordController.text = prefs.getString('lastPassword') ?? '';
      }
    });
  }

  Future<void> _saveWiFiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSSID', ssidController.text);
    await prefs.setString('lastPassword', passwordController.text);
  }

  Future<void> _onRefresh() async {
    final esp32Service = Provider.of<ESP32Service>(context, listen: false);
    setState(() {
      isChecking = true;
      isConnecting = false;
    });

    if (esp32Service.esp32IP != null && !esp32Service.isConnected) {
      await esp32Service.tryReconnect();
    }

    setState(() {
      isChecking = false;
    });

    if (esp32Service.isConnected) {
      Fluttertoast.showToast(
        msg: "Connection refreshed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } else {
      Fluttertoast.showToast(
        msg: "Failed to reconnect, try again or reset",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ESP32Service>(
      builder: (context, esp32Service, child) {
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
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isChecking
                          ? 'Checking connection...'
                          : esp32Service.isConnected
                              ? 'You are already connected to ESP'
                              : esp32Service.isReconnecting
                                  ? 'Reconnecting to ESP32...'
                                  : 'Wi-Fi Configuration',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(83, 166, 234, 1)),
                    ),
                    const SizedBox(height: 20),
                    if (isChecking || esp32Service.isReconnecting) ...[
                      const Center(child: CircularProgressIndicator()),
                    ] else if (!esp32Service.isConnected) ...[
                      _buildTextField(ssidController, 'Wi-Fi SSID', Icons.wifi),
                      const SizedBox(height: 16),
                      _buildTextField(
                        passwordController,
                        'Wi-Fi Password',
                        Icons.lock,
                        obscure: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Color.fromRGBO(83, 166, 234, 1),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ],
                    if (esp32Service.esp32IP != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'ESP32 IP: ${esp32Service.esp32IP}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color.fromRGBO(83, 166, 234, 1)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildActionButton(context, esp32Service),
                    if (!esp32Service.isConnected &&
                        esp32Service.esp32IP != null) ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: isConnecting ||
                                esp32Service.isReconnecting ||
                                isChecking
                            ? null
                            : () async {
                                setState(() => isConnecting = true);
                                try {
                                  await esp32Service.forceBLEMode();
                                  Fluttertoast.showToast(
                                    msg: "ESP32 reset to BLE mode",
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                  );
                                } catch (e) {
                                  Fluttertoast.showToast(
                                    msg: "Failed to reset ESP32: $e",
                                    toastLength: Toast.LENGTH_LONG,
                                    gravity: ToastGravity.BOTTOM,
                                  );
                                } finally {
                                  setState(() => isConnecting = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Force BLE Mode',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscure = false, Widget? suffixIcon}) {
    return TextField(
      controller: controller,
      obscureText: obscure && _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color.fromRGBO(83, 166, 234, 1)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, ESP32Service esp32Service) {
    return ElevatedButton(
      onPressed: isConnecting || esp32Service.isReconnecting || isChecking
          ? null
          : (esp32Service.isConnected
              ? () async {
                  setState(() => isConnecting = true);
                  try {
                    await esp32Service.disconnect();
                    Fluttertoast.showToast(
                      msg: "Disconnected from ESP32",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  } catch (e) {
                    Fluttertoast.showToast(
                      msg: "Failed to disconnect: $e",
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.BOTTOM,
                    );
                  } finally {
                    setState(() => isConnecting = false);
                  }
                }
              : () async {
                  setState(() => isConnecting = true);
                  try {
                    if (ssidController.text.isEmpty ||
                        passwordController.text.isEmpty) {
                      throw Exception("Please enter Wi-Fi SSID and password");
                    }
                    await esp32Service.configureWiFi(
                        ssidController.text, passwordController.text);
                    await _saveWiFiCredentials();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Setup successful'),
                          backgroundColor: Color(0xFFD8BFD8),
                          duration: Duration(milliseconds: 500)),
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const Home()),
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
        backgroundColor: Color.fromRGBO(83, 166, 234, 1),
        foregroundColor: Colors.white,
      ),
      child: isConnecting || esp32Service.isReconnecting || isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(
              esp32Service.isConnected ? 'DISCONNECT' : 'Setup',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}
