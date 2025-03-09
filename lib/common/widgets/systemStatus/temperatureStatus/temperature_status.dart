import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vector_math/vector_math_64.dart' as math;

class TemperatureStatus extends StatefulWidget {
  const TemperatureStatus({super.key});

  @override
  State<TemperatureStatus> createState() => _TemperatureStatusState();
}

class _TemperatureStatusState extends State<TemperatureStatus>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _radialProgressAnimationController;
  late Animation<double> _progressAnimation;
  final Duration fadeInDuration = const Duration(milliseconds: 500);
  final Duration fillDuration = const Duration(seconds: 2);
  double progressDegrees = 0;
  final double temperature =
      32; // Example temperature (replace with real-time data)

  @override
  void initState() {
    super.initState();
    _radialProgressAnimationController =
        AnimationController(vsync: this, duration: fillDuration);

    // Convert temperature (0 to 50°C) into degrees (0 to 360°)
    _progressAnimation = Tween(begin: 0.0, end: (temperature / 50) * 360)
        .animate(CurvedAnimation(
            parent: _radialProgressAnimationController, curve: Curves.easeIn))
      ..addListener(() {
        setState(() {
          progressDegrees = _progressAnimation.value;
        });
      });

    _radialProgressAnimationController.forward();
  }

  String getFormattedDate() {
    DateTime now = DateTime.now();
    return DateFormat('MMMM d, yyyy').format(now);
  }

  Color getCircleColor(double temperature) {
    if (temperature <= 25) {
      return Colors.blue; // Cool
    } else if (temperature <= 30) {
      return Colors.yellow; // Moderate
    } else {
      return Colors.red; // Hot
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    String todayDate = getFormattedDate();

    return Center(
      child: Container(
        width: 320,
        height: 130,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.red, Colors.yellow], // Red to Yellow gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Temperature",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const Text(
                  "For Today",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                Text(
                  todayDate,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            CustomPaint(
              painter:
                  RadialPainter(progressDegrees, getCircleColor(temperature)),
              child: Container(
                height: 90,
                width: 90,
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  opacity: progressDegrees > 5 ? 1.0 : 0.0,
                  duration: fadeInDuration,
                  child: Text(
                    "$temperature°C",
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class RadialPainter extends CustomPainter {
  final double progressInDegrees;
  final Color progressColor;

  RadialPainter(this.progressInDegrees, this.progressColor);

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = Offset(size.width / 2, size.height / 2);

    Paint backgroundPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    canvas.drawCircle(center, size.width / 2, backgroundPaint);

    Paint progressPaint = Paint()
      ..color = progressColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width / 2),
      math.radians(-90),
      math.radians(progressInDegrees),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
