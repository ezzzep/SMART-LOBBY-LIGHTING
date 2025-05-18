import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_scan/wifi_scan.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _espIpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isConnecting = false;
  bool _isChecking = true;
  bool _obscurePassword = true;
  List<String> _wifiNetworks = [];
  bool _isLoadingWiFi = false;
  String? _configuredSsid;
  bool _isWiFiConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    _loadWiFiNetworks();
    print('SetupScreen initialized');
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _espIpController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectionStatus() async {
    final esp32Service = Provider.of<ESP32Service>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    if (esp32Service.esp32IP != null && !esp32Service.isConnected) {
      await esp32Service.tryReconnect();
    }

    final wifiSsid = prefs.getString('lastSSID');
    if (mounted) {
      setState(() {
        _isWiFiConnected = wifiSsid != null && wifiSsid.isNotEmpty;
        _isChecking = false;
        if (!esp32Service.isConnected) {
          _ssidController.text = wifiSsid ?? '';
          _passwordController.text = prefs.getString('lastPassword') ?? '';
        }
      });
    }
    print('Connection status checked: isConnected=${esp32Service.isConnected}, isWiFiConnected=$_isWiFiConnected');
  }

  Future<void> _loadWiFiNetworks() async {
    setState(() => _isLoadingWiFi = true);
    try {
      final canScan = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canScan != CanStartScan.yes) {
        Fluttertoast.showToast(
          msg: 'Cannot start WiFi scan. Check permissions.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      final isScanning = await WiFiScan.instance.startScan();
      if (!isScanning) {
        Fluttertoast.showToast(
          msg: 'Failed to start WiFi scan.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      final canGetResults = await WiFiScan.instance.canGetScannedResults(askPermissions: true);
      if (canGetResults == CanGetScannedResults.yes) {
        final accessPoints = await WiFiScan.instance.getScannedResults();
        if (mounted) {
          setState(() {
            _wifiNetworks = accessPoints.map((ap) => ap.ssid).where((ssid) => ssid.isNotEmpty).toList();
          });
        }
      } else {
        Fluttertoast.showToast(
          msg: 'Cannot retrieve WiFi scan results. Check permissions.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error loading WiFi networks: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingWiFi = false);
      }
    }
    print('WiFi networks loaded: ${_wifiNetworks.length} networks');
  }

  Future<void> _saveWiFiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSSID', _ssidController.text);
    await prefs.setString('lastPassword', _passwordController.text);
    print('WiFi credentials saved: SSID=${_ssidController.text}');
  }

  Future<void> _configureWiFi(ESP32Service esp32Service) async {
    const String ip = '192.168.4.1'; // Default AP IP
    final ssid = _ssidController.text;
    final password = _passwordController.text;

    if (ssid.isEmpty) {
      Fluttertoast.showToast(
        msg: 'SSID cannot be empty',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      print('SSID empty');
      return;
    }

    // Show IP modal first
    setState(() {
      _espIpController.text = ''; // Clear IP field
    });
    print('Showing IP modal before POST request');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showIpModal(context, esp32Service);

        Fluttertoast.showToast(
          msg: 'WiFi credentials sent successfully. Please enter ESP32 IP.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        print('WiFi credentials processed successfully');
      }
    });

    setState(() => _isConnecting = true);
    try {
      print('Sending WiFi credentials to http://$ip/setWiFi');
      final response = await http
          .post(
        Uri.parse('http://$ip/setWiFi'),
        body: jsonEncode({
          'ssid': ssid,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json'},
      )
          .timeout(const Duration(seconds: 15));

      print('Response status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (e) {
          throw Exception('Failed to parse response JSON: $e');
        }

        if (data is Map && data['success'] == true) {
          await _saveWiFiCredentials();
          setState(() {
            _configuredSsid = ssid;
            _isWiFiConnected = true;
            // Optionally update IP if provided
            if (data['ip'] != null && data['ip'].isNotEmpty) {
              _espIpController.text = data['ip'];
            }
          });

        } else {
          throw Exception('WiFi setup failed: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode} - ${response.body}');
      }
    }  finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _testConnection(ESP32Service esp32Service) async {
    final ip = _espIpController.text;

    if (!isValidIp(ip)) {
      Fluttertoast.showToast(
        msg: 'Invalid ESP32 IP address',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      print('Invalid ESP32 IP: $ip');
      return;
    }

    setState(() => _isConnecting = true);
    try {
      print('Testing connection to http://$ip/sensors');
      final response = await http
          .get(Uri.parse('http://$ip/sensors'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await esp32Service.setESP32IP(ip);
        Fluttertoast.showToast(
          msg: 'Connected to ESP32.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        // Pop the modal and navigate to Home
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
                (route) => false,
          );
        }
        print('Connection successful, IP saved: $ip, navigated to Home');
      } else {
        throw Exception('Failed to connect: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Connection failed: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
      );
      print('Connection error: $e');
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  bool isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (var part in parts) {
      if (part.isEmpty) return false;
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  Future<void> _onRefresh() async {
    final esp32Service = Provider.of<ESP32Service>(context, listen: false);
    setState(() {
      _isChecking = true;
      _isConnecting = false;
    });

    if (esp32Service.esp32IP != null && !esp32Service.isConnected) {
      await esp32Service.tryReconnect();
    }

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }

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
    print('Refresh completed: isConnected=${esp32Service.isConnected}');
  }

  void _showIpModal(BuildContext context, ESP32Service esp32Service) {
    String? errorMessage;
    bool isValid = isValidIp(_espIpController.text);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Connect to ESP32',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _espIpController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      IpAddressInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'ESP32 IP Address',
                      hintText: 'xxx.xxx.xxx.xxx',
                      prefixIcon: const Icon(Icons.network_check, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      errorText: errorMessage,
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        errorMessage = isValidIp(value) ? null : 'Invalid IP (e.g., 192.168.1.1)';
                        isValid = isValidIp(value);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the IP address provided by the ESP32.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isConnecting || !isValid
                      ? null
                      : () async {
                    await _testConnection(esp32Service);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Connect',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
            child: FadeIn(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isChecking
                            ? 'Checking connection...'
                            : esp32Service.isConnected
                            ? 'You are connected to ESP32'
                            : 'Wi-Fi Configuration',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_isChecking || esp32Service.isReconnecting) ...[
                        const Center(child: CircularProgressIndicator()),
                      ] else if (!esp32Service.isConnected) ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'WiFi SSID',
                                  prefixIcon: const Icon(Icons.wifi, color: Colors.blue),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: _wifiNetworks.map((ssid) {
                                  return DropdownMenuItem<String>(
                                    value: ssid,
                                    child: Text(ssid.isEmpty ? 'Unknown' : ssid),
                                  );
                                }).toList()
                                  ..add(const DropdownMenuItem<String>(
                                    value: 'manual',
                                    child: Text('Enter manually'),
                                  )),
                                onChanged: (value) {
                                  if (value == 'manual') {
                                    _ssidController.clear();
                                  } else {
                                    _ssidController.text = value ?? '';
                                  }
                                },
                                hint: _isLoadingWiFi
                                    ? const Text('Scanning WiFi...')
                                    : const Text('Select WiFi Network'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _isLoadingWiFi ? null : _loadWiFiNetworks,
                              icon: Icon(
                                Icons.refresh,
                                color: _isLoadingWiFi ? Colors.grey : Colors.blue,
                              ),
                              tooltip: 'Refresh WiFi Networks',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _ssidController,
                          'WiFi SSID (if manual)',
                          Icons.wifi,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _passwordController,
                          'WiFi Password',
                          Icons.lock,
                          obscure: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.blue,
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
                            color: Colors.blue,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buildActionButton(context, esp32Service),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool obscure = false,
        Widget? suffixIcon,
        TextInputType? keyboardType,
      }) {
    return TextField(
      controller: controller,
      obscureText: obscure && _obscurePassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, ESP32Service esp32Service) {
    return ElevatedButton(
      onPressed: _isConnecting || esp32Service.isReconnecting || _isChecking
          ? null
          : (esp32Service.isConnected
          ? () async {
        setState(() => _isConnecting = true);
        try {
          await esp32Service.disconnect();
          if (mounted) {
            setState(() {
              _configuredSsid = null;
              _espIpController.clear();
              _isWiFiConnected = false;
            });
          }
          Fluttertoast.showToast(
            msg: "Disconnected from ESP32",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          print('Disconnected, reset to wifiConfig');
        } catch (e) {

          print('Disconnect error: $e');
        } finally {
          if (mounted) {
            setState(() => _isConnecting = false);
          }
        }
      }
          : () => _configureWiFi(esp32Service)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      child: _isConnecting || esp32Service.isReconnecting || _isChecking
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : Text(
        esp32Service.isConnected ? 'DISCONNECT' : 'Setup',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class IpAddressInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = '';
    int selectionIndex = newValue.selection.baseOffset;

    if (text.length > 12) {
      text = text.substring(0, 12);
    }

    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if ((i + 1) % 3 == 0 && i + 1 < text.length) {
        formatted += '.';
      }
    }

    // Adjust selection index
    int dotsBeforeSelection = formatted.substring(0, selectionIndex.clamp(0, formatted.length)).split('.').length - 1;
    int newSelectionIndex = selectionIndex + dotsBeforeSelection;
    if (formatted.length > oldValue.text.length && (formatted.endsWith('.') || formatted.length == 7 || formatted.length == 11)) {
      newSelectionIndex++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newSelectionIndex.clamp(0, formatted.length)),
    );
  }
}