import 'package:flutter/material.dart';
import 'package:lite_rolling_switch/lite_rolling_switch.dart';

import 'package:smart_lighting/screens/setup/setup_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool isActivated = false;
  bool isDisabled = false;
  bool isActivating = false;

  void _activateSystem() {
    setState(() {
      isActivated = true;
      isDisabled = true;
      isActivating = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => SetupScreen()), // Removed const
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Scaffold(
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "SYSTEM ACTIVATION",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                IgnorePointer(
                  ignoring: isDisabled, // Disable switch interaction
                  child: LiteRollingSwitch(
                    value: isActivated,
                    textOn: 'ON',
                    textOff: 'OFF',
                    colorOn: const Color(0xff0D6EFD),
                    colorOff: const Color(0xFF292929),
                    textOnColor: Colors.white,
                    textOffColor: Colors.white,
                    iconOn: Icons.done,
                    iconOff: Icons.remove_circle_outline,
                    textSize: 16.0,
                    onChanged: (bool state) {
                      if (state) {
                        _activateSystem();
                      }
                    },
                    onTap: () {},
                    onDoubleTap: () {},
                    onSwipe: () {},
                  ),
                ),
                const SizedBox(height: 20),
                if (isActivating)
                  const Text(
                    "System activating, please wait...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
