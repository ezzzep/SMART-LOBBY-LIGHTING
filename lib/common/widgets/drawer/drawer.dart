import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/screens/dashboard/dashboard_screen.dart';
import 'package:smart_lighting/screens/setup/setup_screen.dart';
import 'package:smart_lighting/screens/systemTweaks/system_tweaks_screen.dart';
import 'package:smart_lighting/screens/accountSettings/account_settings.dart';
import 'package:smart_lighting/screens/qr/qr_screen.dart';
import 'package:smart_lighting/screens/survey/survey_screen.dart';

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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration:
                  const BoxDecoration(color: Color.fromRGBO(83, 166, 234, 1)),
              child: FutureBuilder(
                future: _getUserInfo(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  } else if (snapshot.hasError || !snapshot.hasData) {
                    return const Text(
                      'User Not Found',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    );
                  } else {
                    String userInfo = snapshot.data as String;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          userInfo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
            _buildDrawerItem(
                Icons.home, 'System Status', context, const Home()),
            _buildDrawerItem(
                Icons.settings, 'System Tweaks', context, const SystemTweaks()),
            _buildDrawerItem(Icons.wifi, 'Setup', context, const SetupScreen()),
            _buildDrawerItem(Icons.account_circle, 'Account', context,
                const AccountSettings()),
            _buildDrawerItem(
                Icons.qr_code, 'Download our App', context, const QRScreen()),
            _buildDrawerItem(
                Icons.feedback, 'Survey', context, const SurveyScreen()),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              onTap: () async {
                await authService.signout(context: context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getUserInfo() async {
    final user = authService.currentUser;
    if (user != null) {
      return user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email ?? 'Unknown User';
    }
    return 'Unknown User';
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
