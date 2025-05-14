import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/screens/setup/setup_screen.dart';
import 'package:smart_lighting/screens/systemTweaks/system_tweaks_screen.dart';
import 'package:smart_lighting/screens/accountSettings/account_settings.dart';
import 'package:smart_lighting/screens/qr/qr_screen.dart';
import 'package:smart_lighting/screens/survey/survey_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DrawerWidget extends StatelessWidget {
  final AuthService authService;

  const DrawerWidget({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
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
        child: FutureBuilder(
          future: _getUserInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            String role = snapshot.hasData
                ? (snapshot.data as Map<String, String>)['role'] ?? 'Student'
                : 'Student';
            bool isAdmin = role.toLowerCase() == 'admin';

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                      color: Color.fromRGBO(83, 166, 234, 1)),
                  child: snapshot.hasError || !snapshot.hasData
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Unknown User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Role: Unknown',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              (snapshot.data
                                      as Map<String, String>)['userInfo'] ??
                                  'Unknown User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Role: $role',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                ),
                _buildDrawerItem(
                    Icons.home, 'System Status', context, const Home()),
                _buildDrawerItem(Icons.settings, 'System Tweaks', context,
                    const SystemTweaks()),
                _buildDrawerItem(
                    Icons.wifi, 'Setup', context, const SetupScreen()),
                _buildDrawerItem(Icons.account_circle, 'Account', context,
                    const AccountSettings()),
                if (isAdmin)
                  _buildDrawerItem(Icons.qr_code, 'Download our App', context,
                      const QRScreen()),
                _buildDrawerItem(
                    Icons.feedback, 'Survey', context, const SurveyScreen()),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  onTap: () async {
                    await authService.signout(context: context);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, String>> _getUserInfo() async {
    final user = authService.currentUser;
    if (user != null) {
      // Fetch user document from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Get role, default to 'Student' if not found
      String role = userDoc.exists
          ? (userDoc.get('role')?.toString().capitalize() ?? 'Student')
          : 'Student';

      // Get display name or email
      String userInfo = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email ?? 'Unknown User';

      // Return map with user info and role
      return {'userInfo': userInfo, 'role': role};
    }
    return {'userInfo': 'Unknown User', 'role': 'Unknown'};
  }

  Widget _buildDrawerItem(
      IconData icon, String title, BuildContext context, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: Color.fromRGBO(83, 166, 234, 1)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
    );
  }
}

// Extension to capitalize the role string
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
