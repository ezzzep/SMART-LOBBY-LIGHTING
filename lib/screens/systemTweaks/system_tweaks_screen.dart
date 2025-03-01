import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart'; // Import Home screen

class SystemTweaks extends StatelessWidget {
  const SystemTweaks({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Tweaks'),
        automaticallyImplyLeading: false, // Removes back button
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
      drawer: _buildDrawer(context), // Add Drawer here
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
                MaterialPageRoute(
                    builder: (context) => const Home()), // Navigate to Home
                (route) => false, // Remove all previous routes from stack
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
        Navigator.pop(context); // Close drawer
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
