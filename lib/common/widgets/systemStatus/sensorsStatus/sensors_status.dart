import 'package:flutter/material.dart';

class SensorsStatus extends StatelessWidget {
  final double width;
  final double height;
  final String title;
  final String subtitle;
  final bool isActive;

  const SensorsStatus({
    super.key,
    required this.width,
    required this.height,
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.5),
        boxShadow: [
          BoxShadow(
            offset: const Offset(3, 5),
            blurRadius: 12,
            spreadRadius: 3, // Darker shadow effect
            color: Colors.black.withOpacity(0.2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Centered content (title & subtitle)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Full-width status indicator at the bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12.5),
                bottomRight: Radius.circular(12.5),
              ),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'INACTIVE',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
