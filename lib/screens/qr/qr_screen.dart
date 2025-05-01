import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:smart_lighting/services/service.dart';

class QRScreen extends StatelessWidget {
  final String googleDriveLink =
      'https://drive.google.com/drive/folders/1S9inXPp2lwqPoawhZmy4AZ35tUsi0y3a?usp=sharing';

  const QRScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download our App'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: DrawerWidget(authService: _authService),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 20.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const Text(
                'Scan to Get Our App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              QrImageView(
                data: googleDriveLink,
                version: QrVersions.auto,
                size: 250.0,
                gapless: false,
                backgroundColor: Colors.white,
                foregroundColor: Color.fromRGBO(83, 166, 234, 1),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: You will be redirected to Google Drive to install our app.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
