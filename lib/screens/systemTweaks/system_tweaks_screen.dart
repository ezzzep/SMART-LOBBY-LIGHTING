import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/screens/setup/setup_screen.dart';

class SystemTweaks extends StatefulWidget {
  const SystemTweaks({super.key});

  @override
  _SystemTweaksState createState() => _SystemTweaksState();
}

class _SystemTweaksState extends State<SystemTweaks> {
  int _temperature = 37; // Default TEMP
  int _humidity = 80; // Default HUMI

  void _increaseTemperature() {
    if (_temperature < 45) {
      setState(() => _temperature++);
    }
  }

  void _decreaseTemperature() {
    if (_temperature > 35) {
      setState(() => _temperature--);
    }
  }

  void _increaseHumidity() {
    if (_humidity < 90) {
      setState(() => _humidity++);
    }
  }

  void _decreaseHumidity() {
    if (_humidity > 30) {
      setState(() => _humidity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Tweaks'),
        automaticallyImplyLeading: false,
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
      body: Column(
        children: [
          _buildSensitivityThreshold(), // Sensitivity Threshold Box
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Sensitivity Threshold UI
  Widget _buildSensitivityThreshold() {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      height: 190, // Adjusted Height
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 250, 68, 55),
            Color.fromARGB(255, 36, 144, 232)
          ], // Red to Blue Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'SENSITIVITY THRESHOLD',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCounter('TEMPERATURE', _temperature, _increaseTemperature,
                  _decreaseTemperature),
              _buildCounter(
                  'HUMIDITY', _humidity, _increaseHumidity, _decreaseHumidity),
            ],
          ),
        ],
      ),
    );
  }

  /// Counter UI (TEMP & HUMI) - Adjusted size to fit screen properly
  Widget _buildCounter(String label, int value, VoidCallback onIncrease,
      VoidCallback onDecrease) {
    return Column(
      children: [
        // Label (TEMP / HUMI) with White Color
        Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 5),

        // Main Container for Value & Counter
        Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 228, 220, 220),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              // Value Box (Optimized size)
              Container(
                width: 80, // Adjusted width
                height: 55, // Adjusted height
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.white,
                ),
                child: Text(
                  label == "TEMPERATURE" ? "$value°C" : "$value%", // Add units
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ),

              const SizedBox(width: 6), // Spacing between value and counter

              // Up & Down Counter Box
              Column(
                children: [
                  // Increase Button
                  Container(
                    width: 45, // Adjusted Width
                    height: 28, // Adjusted Height
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.white,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_drop_up,
                          size: 22, color: Colors.black),
                      padding: EdgeInsets.zero,
                      onPressed: onIncrease,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Decrease Button
                  Container(
                    width: 45, // Adjusted Width
                    height: 28, // Adjusted Height
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.white,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_drop_down,
                          size: 22, color: Colors.black),
                      padding: EdgeInsets.zero,
                      onPressed: onDecrease,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
          _buildDrawerItem(Icons.home, 'System Status', context, const Home()),
          _buildDrawerItem(Icons.settings, 'System Tweaks', context, null),
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
              await AuthService().signout(context: context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Home()),
                (route) => false,
              );
            },
          ),
        ],
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        }
      },
    );
  }
}
