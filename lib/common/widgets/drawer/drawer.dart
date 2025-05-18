import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/screens/setup/setup_screen.dart';
import 'package:smart_lighting/screens/systemTweaks/system_tweaks_screen.dart';
import 'package:smart_lighting/screens/accountSettings/account_settings.dart';
import 'package:smart_lighting/screens/qr/qr_screen.dart';
import 'package:smart_lighting/screens/survey/survey_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_lighting/screens/dataChart/data_chart_screen.dart';

class DrawerWidget extends StatefulWidget {
  final AuthService authService;

  const DrawerWidget({super.key, required this.authService});

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {
  Map<String, String>? _cachedUserInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    if (_cachedUserInfo == null) {
      setState(() => _isLoading = true);
      final userInfo = await _getUserInfo();
      setState(() {
        _cachedUserInfo = userInfo;
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>> _getUserInfo() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String role = userDoc.exists
          ? (userDoc.get('role')?.toString().capitalize() ?? 'Student')
          : 'Student';

      String userInfo = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email ?? 'Unknown User';

      return {'userInfo': userInfo, 'role': role};
    }
    return {'userInfo': 'Unknown User', 'role': 'Unknown'};
  }

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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                        color: Color.fromRGBO(83, 166, 234, 1)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _cachedUserInfo?['userInfo'] ?? 'Unknown User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Role: ${_cachedUserInfo?['role'] ?? 'Unknown'}',
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
                  _buildDrawerItem(Icons.line_axis, 'Data Charts', context,
                      const DataChartScreen()),
                  if (_cachedUserInfo?['role']?.toLowerCase() == 'admin') ...[
                    _buildDrawerItem(Icons.qr_code, 'Download our App', context,
                        const QRScreen()),
                    _buildDrawerItem(
                        Icons.feedback, 'Survey', context, const SurveyScreen()),
                  ],
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    onTap: () async {
                      await widget.authService.signout(context: context);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDrawerItem(
      IconData icon, String title, BuildContext context, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: Color.fromRGBO(83, 166, 234, 1)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
