import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:lite_rolling_switch/lite_rolling_switch.dart';
import 'package:smart_lighting/common/widgets/successCard/success_card.dart'; // Import SuccessCard

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isSwitchOn = false;
  bool showSuccess = false; // Controls when SuccessCard is shown

  void toggleSwitchPosition(bool state) {
    setState(() {
      isSwitchOn = state; // Update state when switch toggles
      showSuccess = false; // Reset success display initially
    });

    if (state) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            showSuccess = true; // Show success card after delay
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                await AuthService().signout(context: context);
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
                  ? const SuccessCard() // Show success after delay
                  : const Text(
                      "SYSTEM ACTIVATION",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      key: ValueKey("systemActivation"),
                    ),
            ),
            const SizedBox(height: 10),
            if (!showSuccess) // Hide switch when success is shown
              CustomLiteRollingSwitch(
                onSwitchChanged: toggleSwitchPosition,
              ),
          ],
        ),
      ),
    );
  }
}

// ✅ Updated CustomLiteRollingSwitch to adjust switch size

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
      width: 130, // Adjust width of the switch
      height: 42, // Adjust height of the switch
      child: LiteRollingSwitch(
        value: false, // Default switch state is OFF
        textOn: 'ON',
        textOff: 'OFF',
        colorOn: const Color(0xff0D6EFD),
        colorOff: const Color(0xff6A6A6A),
        textOnColor: Colors.white,
        textOffColor: Colors.white,
        iconOn: Icons.done,
        iconOff: Icons.remove_circle_outline,
        textSize: 14.0, // Adjust text size
        onChanged: (bool state) {
          widget.onSwitchChanged(state); // Call function when switch changes
        },
        onTap: () {},
        onDoubleTap: () {},
        onSwipe: () {},
      ),
    );
  }
}
