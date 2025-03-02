import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart'; // Import AuthService
import 'package:lite_rolling_switch/lite_rolling_switch.dart';
import 'package:smart_lighting/common/widgets/successCard/success_card.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isSwitchOn = false;
  bool showSuccess = false;
  final AuthService _authService = AuthService(); // Instantiate AuthService

  void toggleSwitchPosition(bool state) {
    setState(() {
      isSwitchOn = state;
      showSuccess = false;
    });

    if (state) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            showSuccess = true;
          });
        }
      });
    }
  }

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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('SMART LOBBY LIGHTING'),
            ),
            ListTile(
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('System Tweaks'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Account'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                await _authService.signOut(context: context); // Use instance
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: showSuccess
                  ? const SuccessCard()
                  : const Text(
                "SYSTEM ACTIVATION",
                style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                key: ValueKey("systemActivation"),
              ),
            ),
            const SizedBox(height: 10),
            if (!showSuccess)
              CustomLiteRollingSwitch(
                onSwitchChanged: toggleSwitchPosition,
              ),
          ],
        ),
      ),
    );
  }
}

class CustomLiteRollingSwitch extends StatefulWidget {
  final Function(bool) onSwitchChanged;

  const CustomLiteRollingSwitch({super.key, required this.onSwitchChanged});

  @override
  State<CustomLiteRollingSwitch> createState() =>
      _CustomLiteRollingSwitchState();
}

class _CustomLiteRollingSwitchState extends State<CustomLiteRollingSwitch> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 42,
      child: LiteRollingSwitch(
        value: false,
        textOn: 'ON',
        textOff: 'OFF',
        colorOn: const Color(0xff0D6EFD),
        colorOff: const Color(0xff6A6A6A),
        textOnColor: Colors.white,
        textOffColor: Colors.white,
        iconOn: Icons.done,
        iconOff: Icons.remove_circle_outline,
        textSize: 14.0,
        onChanged: (bool state) {
          widget.onSwitchChanged(state);
        },
        onTap: () {},
        onDoubleTap: () {},
        onSwipe: () {},
      ),
    );
  }
}