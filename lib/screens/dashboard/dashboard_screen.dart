import 'package:smart_lighting/services/service.dart';
import 'package:flutter/material.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
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
      drawer: Container(
        width: 270, // Set custom width to make it smaller
        decoration: BoxDecoration(
          color: Colors.white, // Background color
          borderRadius: BorderRadius.horizontal(
              right: Radius.circular(16)), // Rounded right edges
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: Offset(2, 0), // Shadow on the right
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
              _buildDrawerItem(Icons.home, 'Home', context),
              _buildDrawerItem(Icons.settings, 'System Tweaks', context),
              _buildDrawerItem(Icons.account_circle, 'Account', context),
              const Divider(), // Add a divider for separation
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign Out',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                onTap: () async {
                  await AuthService().signout(context: context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function for drawer items
  Widget _buildDrawerItem(IconData icon, String title, BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }
}
