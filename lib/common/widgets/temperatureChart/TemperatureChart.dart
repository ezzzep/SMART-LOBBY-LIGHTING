// temperaturechart_v7.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:smart_lighting/services/service.dart';

import 'web_stubs.dart' if (dart.library.html) 'dart:html' as html;

class TemperatureChart extends StatefulWidget {
  final List<FlSpot> tempData;
  final List<FlSpot> humidityData;

  const TemperatureChart({
    super.key,
    required this.tempData,
    required this.humidityData,
  });

  @override
  State<TemperatureChart> createState() => _TemperatureChartState();
}

class _TemperatureChartState extends State<TemperatureChart>
    with SingleTickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  List<FlSpot> currentTempData = [];
  List<FlSpot> currentHumidityData = [];
  Timer? _hourlyTimer;
  Timer? _animationTimer;
  double _animationProgress = 0.0;
  List<FlSpot> _previousTempData = [];
  List<FlSpot> _previousHumidityData = [];
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Initialize with provided data
    currentTempData = List.from(widget.tempData);
    currentHumidityData = List.from(widget.humidityData);
    _previousTempData = List.from(widget.tempData);
    _previousHumidityData = List.from(widget.humidityData);

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.addListener(() {
      setState(() {
        _animationProgress = _animation.value;
      });
    });
  }

  @override
  void didUpdateWidget(TemperatureChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tempData != oldWidget.tempData ||
        widget.humidityData != oldWidget.humidityData) {
      // Store previous data before updating
      _previousTempData = List.from(currentTempData);
      _previousHumidityData = List.from(currentHumidityData);
      currentTempData = List.from(widget.tempData);
      currentHumidityData = List.from(widget.humidityData);
      // Animate the transition to new data
      _animateDataTransition();
    }
  }

  void _animateDataTransition() {
    _animationController.reset();
    _animationController.forward();
  }

  List<FlSpot> _interpolateData(
      List<FlSpot> newData, List<FlSpot> oldData, double progress) {
    if (newData.isEmpty && oldData.isEmpty) return [];
    if (newData.isEmpty) return List.from(oldData);
    if (oldData.isEmpty) return List.from(newData);

    List<FlSpot> interpolated = [];
    int maxLength = max(newData.length, oldData.length);

    for (int i = 0; i < maxLength; i++) {
      FlSpot oldSpot = i < oldData.length ? oldData[i] : oldData.last;
      FlSpot newSpot = i < newData.length ? newData[i] : newData.last;

      double x = oldSpot.x + (newSpot.x - oldSpot.x) * progress;
      double y = oldSpot.y + (newSpot.y - oldSpot.y) * progress;
      interpolated.add(FlSpot(x, y));
    }

    return interpolated;
  }

  @override
  void dispose() {
    _hourlyTimer?.cancel();
    _animationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // Helper function to validate and sort FlSpot data
  List<FlSpot> _validateAndSortData(List<FlSpot> data, double minY, double maxY) {
    return data
        .where((spot) =>
            spot.x.isFinite &&
            spot.y.isFinite &&
            spot.y >= minY &&
            spot.y <= maxY)
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  // Calculate average data per 15-minute interval
  Map<String, double> _calculateAverages(List<FlSpot> data, DateTime selectedDate) {
    final Map<String, List<double>> buckets = {
      '0–15': [],
      '16–30': [],
      '31–45': [],
      '46–60': [],
    };

    for (var spot in data) {
      if (spot.x >= 0 && spot.x <= 15 * 60) {
        buckets['0–15']!.add(spot.y);
      } else if (spot.x > 15 * 60 && spot.x <= 30 * 60) {
        buckets['16–30']!.add(spot.y);
      } else if (spot.x > 30 * 60 && spot.x <= 45 * 60) {
        buckets['31–45']!.add(spot.y);
      } else if (spot.x > 45 * 60 && spot.x <= 60 * 60) {
        buckets['46–60']!.add(spot.y);
      }
    }

    final Map<String, double> averages = {};
    buckets.forEach((key, values) {
      if (values.isNotEmpty) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        averages[key] = avg;
      }
    });

    return averages;
  }

  // Show combined summary modal with real-time clock for today only
  void _showSummaryModal(BuildContext context, Map<String, double> tempAverages,
      Map<String, double> humidityAverages) {
    final formattedDate = DateFormat('MMMM d, yyyy').format(selectedDate);
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with conditional real-time clock
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent, Colors.redAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Temperature & Humidity Summary',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    isToday
                        ? StreamBuilder(
                            stream: Stream.periodic(const Duration(seconds: 1),
                                (_) => DateTime.now()),
                            builder: (context, snapshot) {
                              final time = snapshot.hasData
                                  ? DateFormat('HH:mm:ss')
                                      .format(snapshot.data as DateTime)
                                  : '00:00:00';
                              return Text(
                                time,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          )
                        : const Text(
                            '-',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tempAverages.isEmpty && humidityAverages.isEmpty)
                        Text(
                          'No data available for this date',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Column(
                          children: [
                            // Table Header
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Time',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Temp (°C)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Humidity (%)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            // Table Rows
                            ...['0–15', '16–30', '31–45', '46–60'].map((time) {
                              final temp = tempAverages[time];
                              final humidity = humidityAverages[time];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '$time mins',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        temp != null
                                            ? temp.toStringAsFixed(1)
                                            : '-',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        humidity != null
                                            ? humidity.toStringAsFixed(1)
                                            : '-',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // Buttons (Download Excel and Close)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _downloadExcel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                        shadowColor: Colors.green.withOpacity(0.3),
                      ),
                      child: const Text(
                        'Download Excel',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Download Excel file with temperature and humidity data
  Future<void> _downloadExcel() async {
    final validTempData = _validateAndSortData(currentTempData, 30, 45);
    final validHumidityData = _validateAndSortData(currentHumidityData, 30, 80);

    if (validTempData.isEmpty || validHumidityData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    // Create Excel file
    var excelFile = excel.Excel.createExcel();
    excel.Sheet sheet = excelFile['Sheet1'];

    // Add headers
    sheet.cell(excel.CellIndex.indexByString('A1')).value =
        excel.TextCellValue('Timestamp');
    sheet.cell(excel.CellIndex.indexByString('B1')).value =
        excel.TextCellValue('Temperature (°C)');
    sheet.cell(excel.CellIndex.indexByString('C1')).value =
        excel.TextCellValue('Humidity (%)');

    // Combine data by minute
    for (int i = 0; i < validTempData.length; i++) {
      final minute = validTempData[i].x.toInt();
      final timestamp = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        0,
        minute ~/ 60,
      );
      final formattedTimestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);

      sheet
          .cell(
              excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
          .value = excel.TextCellValue(formattedTimestamp);
      sheet
          .cell(
              excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
          .value = excel.DoubleCellValue(validTempData[i].y);
      sheet
          .cell(
              excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
          .value = excel.DoubleCellValue(validHumidityData[i].y);
    }

    // File name with date
    final fileName =
        'TempHumidity_${DateFormat('yyyyMMdd').format(selectedDate)}.xlsx';

    try {
      final bytes = excelFile.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      if (kIsWeb) {
        // Web: Download file
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel file downloaded: $fileName')),
        );
      } else {
        // Mobile: Save to device storage
        bool permissionGranted = await _requestStoragePermission();
        if (!permissionGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
          return;
        }

        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel file saved to: $filePath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting Excel: $e')),
      );
    }
  }

  // Request storage permission for mobile
  Future<bool> _requestStoragePermission() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
    return true; // No permission needed for web
  }

  // Show date picker and update selected date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.grey,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final validTempData = _validateAndSortData(currentTempData, 30, 45);
    final validHumidityData = _validateAndSortData(currentHumidityData, 30, 80);

    // Debug print for humidity data
    if (kDebugMode) {
      print('Humidity Data: ${validHumidityData.length} points');
      print('Sample Humidity Points: ${validHumidityData.take(5).toList()}');
    }

    // Calculate time intervals for x-axis (max 60 minutes)
    final maxX = 3600.0; // 60 minutes in seconds
    const interval = 15 * 60.0; // 15-minute intervals in seconds

    // Filter spots for highlighted dots at 0, 15, 30, 45, 60 minutes
    List<FlSpot> getHighlightedSpots(List<FlSpot> data, bool isHumidity) {
      const highlightTimes = [0.0, 15 * 60, 30 * 60, 45 * 60, 60 * 60];
      List<FlSpot> highlighted = [];
      for (var time in highlightTimes) {
        var closestSpot = data.firstWhere(
          (spot) => (spot.x - time).abs() < 1.0,
          orElse: () => FlSpot(time.toDouble(), data.isNotEmpty ? data.last.y.toDouble() : 30.0),
        );
        highlighted.add(closestSpot);
      }
      return highlighted;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Temperature Chart with Date and Calendar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Temperature (°C)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                ),
                Row(
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(selectedDate),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(Icons.calendar_today,
                          color: Colors.blueAccent),
                      tooltip: 'Select Date',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                        shadowColor: Colors.blueAccent.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 245,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: maxX,
                    minY: 30,
                    maxY: 45,
                    lineBarsData: [
                      LineChartBarData(
                        spots: validTempData.isNotEmpty
                            ? validTempData
                            : [FlSpot(0, 30), FlSpot(maxX, 30)],
                        isCurved: true,
                        curveSmoothness: 0.5, // Increased for smoother curve
                        gradient: const LinearGradient(
                          colors: [Colors.redAccent, Colors.orangeAccent],
                        ),
                        barWidth: 4, // Increased for thicker, smoother line
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (spot, barData) {
                            // Highlight only at 0, 15, 30, 45, 60 minutes
                            return [0, 15 * 60, 30 * 60, 45 * 60, 60 * 60]
                                .any((time) => (spot.x - time).abs() < 1.0);
                          },
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.redAccent,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.redAccent.withOpacity(0.2),
                              Colors.orangeAccent.withOpacity(0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final minutes = (spot.x / 60).floor();
                            final seconds = (spot.x % 60).floor();
                            return LineTooltipItem(
                              '${minutes}m ${seconds}s: ${spot.y.toStringAsFixed(1)} °C',
                              const TextStyle(color: Colors.white),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 3,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if ([30, 33, 36, 39, 42, 45]
                                .contains(value.toInt())) {
                              return Text(
                                '${value.toStringAsFixed(0)}°C',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            final minutes = (value / 60).floor();
                            if ([0, 15, 30, 45, 60].contains(minutes)) {
                              return Text(
                                '$minutes min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      verticalInterval: interval,
                      horizontalInterval: 3,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200],
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200],
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Humidity Chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Humidity (%)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
          ),
          SizedBox(
            height: 245,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: maxX,
                    minY: 30,
                    maxY: 80,
                    lineBarsData: [
                      LineChartBarData(
                        spots: validHumidityData.isNotEmpty
                            ? validHumidityData
                            : [FlSpot(0, 30), FlSpot(maxX, 30)],
                        isCurved: true,
                        curveSmoothness: 0.5, // Increased for smoother curve
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.cyanAccent],
                        ),
                        barWidth: 4, // Increased for thicker, smoother line
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (spot, barData) {
                            // Highlight only at 0, 15, 30, 45, 60 minutes
                            return [0, 15 * 60, 30 * 60, 45 * 60, 60 * 60]
                                .any((time) => (spot.x - time).abs() < 1.0);
                          },
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.blueAccent,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent.withOpacity(0.2),
                              Colors.cyanAccent.withOpacity(0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final minutes = (spot.x / 60).floor();
                            final seconds = (spot.x % 60).floor();
                            return LineTooltipItem(
                              '${minutes}m ${seconds}s: ${spot.y.toStringAsFixed(1)} %',
                              const TextStyle(color: Colors.white),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 10,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if ([30, 40, 50, 60, 70, 80]
                                .contains(value.toInt())) {
                              return Text(
                                '${value.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            final minutes = (value / 60).floor();
                            if ([0, 15, 30, 45, 60].contains(minutes)) {
                              return Text(
                                '$minutes min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      verticalInterval: interval,
                      horizontalInterval: 10,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200],
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200],
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Summary Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ElevatedButton(
              onPressed: () {
                final tempAverages =
                    _calculateAverages(validTempData, selectedDate);
                final humidityAverages =
                    _calculateAverages(validHumidityData, selectedDate);
                _showSummaryModal(context, tempAverages, humidityAverages);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}