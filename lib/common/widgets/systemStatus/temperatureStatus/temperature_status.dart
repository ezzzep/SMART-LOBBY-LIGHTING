import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vector_math/vector_math_64.dart' as math;

class TemperatureStatus extends StatefulWidget {
  final double temperature;
  final bool isActive;
  final bool isManualOverride;

  const TemperatureStatus({
    super.key,
    required this.temperature,
    required this.isActive,
    required this.isManualOverride,
  });

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
  double previousTemperature = 0;
  bool isFetchingData = true;

  @override
  void initState() {
    super.initState();
    _radialProgressAnimationController =
        AnimationController(vsync: this, duration: fillDuration);

    _startAnimation(widget.temperature, widget.isActive, widget.isManualOverride);
    _radialProgressAnimationController.forward();
  }

  @override
  void didUpdateWidget(TemperatureStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.temperature != widget.temperature ||
        oldWidget.isActive != widget.isActive ||
        oldWidget.isManualOverride != widget.isManualOverride) {
      previousTemperature = oldWidget.temperature;
      _startAnimation(widget.temperature, widget.isActive, widget.isManualOverride);
      _radialProgressAnimationController.forward(from: 0.0);
    }
  }

  void _startAnimation(double temperature, bool isActive, bool isManualOverride) {
    setState(() {
      isFetchingData = !isActive || temperature <= 0.0;
    });

    double targetProgress = (isActive && !isManualOverride) ? (temperature / 50) * 360 : 0;
    double startProgress = (previousTemperature / 50) * 360;

    _progressAnimation = Tween(begin: startProgress, end: targetProgress)
        .animate(CurvedAnimation(
        parent: _radialProgressAnimationController, curve: Curves.easeIn))
      ..addListener(() {
        setState(() {
          progressDegrees = _progressAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _radialProgressAnimationController.dispose();
    super.dispose();
  }

  String getFormattedDate() {
    DateTime now = DateTime.now();
    return DateFormat('MMMM d, yyyy').format(now);
  }

  Color getCircleColor(double temperature, bool isActive, bool isManualOverride) {
    if (!isActive || isManualOverride || temperature <= 0.0) return Colors.grey;
    if (temperature <= 25) {
      return Colors.blue;
    } else if (temperature <= 30) {
      return Colors.yellow;
    } else {
      return Colors.red;
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
          gradient: LinearGradient(
            colors: widget.isActive && !widget.isManualOverride
                ? [Colors.red, Colors.yellow]
                : [Colors.grey[400]!, Colors.grey[600]!],
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
                Text(
                  widget.isManualOverride ? "Manual Override" : "Temperature",
                  style: const TextStyle(
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
            Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: RadialPainter(
                      progressDegrees,
                      getCircleColor(widget.temperature, widget.isActive, widget.isManualOverride)),
                  child: Container(
                    height: 90,
                    width: 90,
                  ),
                ),
                AnimatedOpacity(
                  opacity: progressDegrees > 5 || !widget.isActive || widget.isManualOverride ? 1.0 : 0.0,
                  duration: fadeInDuration,
                  child: Text(
                    widget.isManualOverride
                        ? "Override"
                        : widget.isActive
                        ? (isFetchingData
                        ? "Fetching..."
                        : "${widget.temperature.toStringAsFixed(1)}°C")
                        : "OFF",
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
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
      math.radians(progressInDegrees.clamp(0, 360)),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}