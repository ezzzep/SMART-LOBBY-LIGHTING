import 'package:flutter/material.dart';

class SuccessCard extends StatelessWidget {
  const SuccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(255, 0, 0, 0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large check icon inside the box
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color.fromARGB(255, 12, 199, 18),
            size: 80, // Increased size
          ),
          const SizedBox(height: 10), // Space between icon and text
          const Text(
            'SUCCESSFULLY ACTIVATED!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
