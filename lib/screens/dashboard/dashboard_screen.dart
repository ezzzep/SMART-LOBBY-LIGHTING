import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/systemStatus/temperatureStatus/temperature_status.dart';
import 'package:smart_lighting/common/widgets/systemStatus/humidityStatus/humidity_status.dart';
import 'package:smart_lighting/common/widgets/systemStatus/sensorsStatus/sensors_status.dart';
import 'package:smart_lighting/screens/systemTweaks/system_tweaks_screen.dart';
import 'package:smart_lighting/screens/setup/setup_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Home extends StatefulWidget {
  final String? esp32IP;

  const Home({super.key, this.esp32IP});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool pirSensorActive = false;
  double temperature = 0.0;
  double humidity = 0.0;
  bool isFetchingData = true;
  final AuthService _authService = AuthService();
  Timer? _timer;
  String? esp32IP;

  @override
  void initState() {
    super.initState();
    _loadESP32IP();
    if (widget.esp32IP != null) {
      esp32IP = widget.esp32IP;
      _startPolling();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadESP32IP() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      esp32IP = prefs.getString('esp32IP') ?? widget.esp32IP;
    });
    if (esp32IP != null && esp32IP!.isNotEmpty) {
      _startPolling();
    } else {
      setState(() {
        isFetchingData = false;
        temperature = 0.0;
        humidity = 0.0;
      });
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (esp32IP == null) {
        setState(() {
          isFetchingData = false;
          temperature = 0.0;
          humidity = 0.0;
        });
        return;
      }

      try {
        final response = await http.get(Uri.parse('http://$esp32IP/sensors'));
        if (response.statusCode == 200) {
          String data = response.body.trim();
          _parseSensorData(data);
          setState(() {
            isFetchingData = false;
          });
        } else {
          setState(() {
            isFetchingData = true;
            temperature = 0.0;
            humidity = 0.0;
          });
        }
      } catch (e) {
        setState(() {
          isFetchingData = true;
          temperature = 0.0;
          humidity = 0.0;
        });
      }
    });
  }

  void _parseSensorData(String data) {
    setState(() {
      pirSensorActive = true;
      if (data.startsWith("ERROR")) {
        temperature = 0.0;
        humidity = 0.0;
      } else {
        List<String> parts = data.split(",");
        for (String part in parts) {
          if (part.startsWith("TEMP:")) {
            temperature = double.tryParse(part.split(":")[1]) ?? 0.0;
          } else if (part.startsWith("HUMID:")) {
            humidity = double.tryParse(part.split(":")[1]) ?? 0.0;
          } else if (part.startsWith("PIR:")) {
            String pirStatus = part.split(":")[1];
            if (pirStatus == "MOTION DETECTED") {
              Fluttertoast.showToast(
                msg: "Motion Detected!",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
              );
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Status"),
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
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              isFetchingData
                  ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Fetching data...",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : const SizedBox.shrink(),
              TemperatureStatus(temperature: temperature),
              const SizedBox(height: 10),
              HumidityStatus(humidity: humidity),
              const SizedBox(height: 10),
              _buildSensorsStatusGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'SMART LOBBY LIGHTING',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            _buildDrawerItem(Icons.home, 'System Status', context, null),
            _buildDrawerItem(
                Icons.settings, 'System Tweaks', context, const SystemTweaks()),
            _buildDrawerItem(Icons.wifi, 'Setup', context, SetupScreen()),
            _buildDrawerItem(Icons.account_circle, 'Account', context, null),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              onTap: () async {
                await _authService.signout(context: context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      IconData icon, String title, BuildContext context, Widget? screen) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        if (screen != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        }
      },
    );
  }

  Widget _buildSensorsStatusGrid() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          const SensorsStatus(
            width: 150,
            height: 180,
            title: 'BME280',
            subtitle: 'Temp and Humidity',
            isActive: true,
          ),
          SensorsStatus(
            width: 170,
            height: 200,
            title: 'PIR SENSORS',
            subtitle: 'Motion Detection',
            isActive: pirSensorActive,
          ),
          const SensorsStatus(
            width: 160,
            height: 190,
            title: 'COOLER',
            subtitle: 'Fan Cooling System',
            isActive: true,
          ),
          const SensorsStatus(
            width: 180,
            height: 220,
            title: 'LIGHT BULBS',
            subtitle: 'Lobby Lighting',
            isActive: false,
          ),
        ],
      ),
    );
  }
}