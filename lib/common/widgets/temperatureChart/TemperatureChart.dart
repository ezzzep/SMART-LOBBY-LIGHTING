import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'dart:html' if (dart.library.io) 'web_stubs.dart' as html;

class TemperatureChart extends StatefulWidget {
  final ESP32Service esp32Service;
  final List<FlSpot> tempData;
  final List<FlSpot> humidityData;

  const TemperatureChart({
    super.key,
    required this.esp32Service,
    required this.tempData,
    required this.humidityData,
  });

  @override
  State<TemperatureChart> createState() => _TemperatureChartState();
}

class _TemperatureChartState extends State<TemperatureChart> with AutomaticKeepAliveClientMixin {
  DateTime selectedDate = DateTime.now();
  List<FlSpot> currentTempData = [];
  List<FlSpot> currentHumidityData = [];
  Timer? _dataTimer;
  DateTime? startDate;
  DateTime? endDate;
  bool isFetchingHistory = false;
  bool isViewingHistoricalData = false;
  Database? _database;
  List<Map<String, dynamic>> hourlySummaries = [];
  DateTime? lastSummaryTime;
  
  // Add zoom control variables
  double tempMinX = 0;
  double tempMaxX = 86400;
  double tempMinY = 30;
  double tempMaxY = 45;
  double humidityMinX = 0;
  double humidityMaxX = 86400;
  double humidityMinY = 0;
  double humidityMaxY = 100;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initDatabase();
    _loadSavedHistoricalData();
    _startRealTimeDataFetch();
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    _database?.close();
    super.dispose();
  }

  Future<void> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, 'temp_humidity.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER,
            temperature REAL,
            humidity REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE summaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hour_start INTEGER,
            time_range TEXT,
            avg_temp REAL,
            avg_humidity REAL
          )
        ''');
      },
    );
  }

  Future<void> _loadSavedHistoricalData() async {
    final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final end = start.add(const Duration(days: 1));
    final data = await _loadDataForDateRange(start, end);
    final tempSpots = <FlSpot>[];
    final humiditySpots = <FlSpot>[];

    for (var record in data) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(record['timestamp'] * 1000);
      final seconds = (timestamp.millisecondsSinceEpoch - start.millisecondsSinceEpoch) / 1000.0;
      final temp = record['temperature']?.toDouble() ?? 0.0;
      final humid = record['humidity']?.toDouble() ?? 0.0;
      if (temp >= 30 && temp <= 45) {
        tempSpots.add(FlSpot(seconds, temp));
      }
      if (humid >= 0 && humid <= 100) {
        humiditySpots.add(FlSpot(seconds, humid));
      }
    }

    setState(() {
      currentTempData = _validateAndSortData(tempSpots, 30, 45);
      currentHumidityData = _validateAndSortData(humiditySpots, 0, 100);
      isViewingHistoricalData = true;
    });
    _loadHourlySummaries();
  }

  Future<List<Map<String, dynamic>>> _loadDataForDateRange(DateTime start, DateTime end) async {
    if (_database == null) return [];
    try {
      final startMs = start.millisecondsSinceEpoch ~/ 1000;
      final endMs = end.millisecondsSinceEpoch ~/ 1000;
      return await _database!.query(
        'data',
        where: 'timestamp >= ? AND timestamp <= ?',
        whereArgs: [startMs, endMs],
        orderBy: 'timestamp ASC',
      );
    } catch (e) {
      print('Error loading data for date range: $e');
      return [];
    }
  }

  void _startRealTimeDataFetch() {
    _dataTimer?.cancel();
    _dataTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!widget.esp32Service.isConnected || isViewingHistoricalData) return;
      
      final now = DateTime.now();
      final temp = widget.esp32Service.temperature;
      final humid = widget.esp32Service.humidity;
      
      if (temp > 0 && humid > 0) {
        final seconds = (now.millisecondsSinceEpoch - DateTime(now.year, now.month, now.day).millisecondsSinceEpoch) / 1000.0;
        
        if (mounted) {
          setState(() {
            currentTempData = _validateAndSortData([...currentTempData, FlSpot(seconds, temp)], 30, 45);
            currentHumidityData = _validateAndSortData([...currentHumidityData, FlSpot(seconds, humid)], 0, 100);
          });
        }
        
        await _saveDataPoint(temp, humid, now);
        _updateHourlySummary(now);
      }
    });
  }

  Future<void> _saveDataPoint(double temp, double humidity, DateTime timestamp) async {
    if (_database == null) return;
    try {
      await _database!.insert(
        'data',
        {
          'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
          'temperature': temp,
          'humidity': humidity,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error saving data point: $e');
    }
  }

  void _updateHourlySummary(DateTime now) async {
    if (_database == null) return;
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    if (lastSummaryTime == null || !lastSummaryTime!.isAtSameMomentAs(currentHour)) {
      final start = currentHour.subtract(const Duration(hours: 1));
      final end = currentHour;
      final data = await _loadDataForDateRange(start, end);

      final buckets = {
        '0–15': {'temp': <double>[], 'humid': <double>[]},
        '16–30': {'temp': <double>[], 'humid': <double>[]},
        '31–45': {'temp': <double>[], 'humid': <double>[]},
        '46–60': {'temp': <double>[], 'humid': <double>[]},
      };

      for (var record in data) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(record['timestamp'] * 1000);
        final minute = timestamp.minute;
        final temp = record['temperature']?.toDouble() ?? 0.0;
        final humid = record['humidity']?.toDouble() ?? 0.0;

        if (minute >= 0 && minute <= 15) {
          buckets['0–15']!['temp']!.add(temp);
          buckets['0–15']!['humid']!.add(humid);
        } else if (minute > 15 && minute <= 30) {
          buckets['16–30']!['temp']!.add(temp);
          buckets['16–30']!['humid']!.add(humid);
        } else if (minute > 30 && minute <= 45) {
          buckets['31–45']!['temp']!.add(temp);
          buckets['31–45']!['humid']!.add(humid);
        } else if (minute > 45 && minute <= 60) {
          buckets['46–60']!['temp']!.add(temp);
          buckets['46–60']!['humid']!.add(humid);
        }
      }

      for (var entry in buckets.entries) {
        final key = entry.key;
        final tempValues = entry.value['temp']!;
        final humidValues = entry.value['humid']!;
        final avgTemp = tempValues.isNotEmpty
            ? tempValues.reduce((a, b) => a + b) / tempValues.length
            : 0.0;
        final avgHumid = humidValues.isNotEmpty
            ? humidValues.reduce((a, b) => a + b) / humidValues.length
            : 0.0;

        await _database!.insert(
          'summaries',
          {
            'hour_start': start.millisecondsSinceEpoch ~/ 1000,
            'time_range': key,
            'avg_temp': avgTemp,
            'avg_humidity': avgHumid,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      lastSummaryTime = currentHour;
      _loadHourlySummaries();
    }
  }

  Map<String, double> _calculateAverages(List<FlSpot> data, DateTime selectedDate) {
    final Map<String, List<double>> buckets = {
      '0–15': [],
      '16–30': [],
      '31–45': [],
      '46–60': [],
    };

    for (var spot in data) {
      final seconds = spot.x.toInt();
      final minute = (seconds / 60).floor();
      if (minute >= 0 && minute <= 15) {
        buckets['0–15']!.add(spot.y);
      } else if (minute > 15 && minute <= 30) {
        buckets['16–30']!.add(spot.y);
      } else if (minute > 30 && minute <= 45) {
        buckets['31–45']!.add(spot.y);
      } else if (minute > 45 && minute <= 60) {
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

  void _resetData() {
    setState(() {
      currentTempData = _validateAndSortData(widget.esp32Service.tempData, 30, 45);
      currentHumidityData = _validateAndSortData(widget.esp32Service.humidityData, 0, 100);
      selectedDate = DateTime.now();
      startDate = null;
      endDate = null;
      isViewingHistoricalData = false;
    });
    _startRealTimeDataFetch();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data reset to real-time')),
    );
  }

  Future<void> _fetchHistoricalData() async {
    if (isFetchingHistory) return;
    setState(() {
      isFetchingHistory = true;
      isViewingHistoricalData = true;
    });

    try {
      final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final end = start.add(const Duration(days: 1));
      final cachedData = await _loadDataForDateRange(start, end);
      if (cachedData.isNotEmpty) {
        final tempSpots = <FlSpot>[];
        final humiditySpots = <FlSpot>[];
        for (var record in cachedData) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(record['timestamp'] * 1000);
          final seconds = (timestamp.millisecondsSinceEpoch - start.millisecondsSinceEpoch) / 1000.0;
          final temp = record['temperature']?.toDouble() ?? 0.0;
          final humid = record['humidity']?.toDouble() ?? 0.0;
          if (temp >= 30 && temp <= 45) {
            tempSpots.add(FlSpot(seconds, temp));
          }
          if (humid >= 0 && humid <= 100) {
            humiditySpots.add(FlSpot(seconds, humid));
          }
        }
        setState(() {
          currentTempData = _validateAndSortData(tempSpots, 30, 45);
          currentHumidityData = _validateAndSortData(humiditySpots, 0, 100);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loaded cached historical data')),
        );
        return;
      }

      final jsonData = await widget.esp32Service.fetchESP32History();
      List<FlSpot> tempSpots = [];
      List<FlSpot> humiditySpots = [];
      for (var record in jsonData) {
        DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(record['timestamp'] * 1000);
        if (timestamp.isBefore(start) || timestamp.isAfter(end)) {
          continue;
        }
        double temp = record['temp']?.toDouble() ?? 0.0;
        double humid = record['humid']?.toDouble() ?? 0.0;
        double seconds = (timestamp.millisecondsSinceEpoch - start.millisecondsSinceEpoch) / 1000.0;
        if (temp >= 30 && temp <= 45) {
          tempSpots.add(FlSpot(seconds, temp));
          await _saveDataPoint(temp, humid, timestamp);
        }
        if (humid >= 0 && humid <= 100) {
          humiditySpots.add(FlSpot(seconds, humid));
        }
      }
      setState(() {
        currentTempData = _validateAndSortData(tempSpots, 30, 45);
        currentHumidityData = _validateAndSortData(humiditySpots, 0, 100);
      });
      await widget.esp32Service.saveHistoricalData(selectedDate, currentTempData, currentHumidityData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historical data fetched successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching history: $e')),
      );
    } finally {
      setState(() {
        isFetchingHistory = false;
      });
    }
  }

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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hourlySummaries.isEmpty)
                        Text(
                          'No summary data available for this date',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Column(
                          children: [
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
                            ...hourlySummaries.map((summary) {
                              final timeRange = summary['time_range'] as String;
                              final temp = summary['avg_temp'] as double?;
                              final humidity = summary['avg_humidity'] as double?;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '$timeRange mins',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        temp != null ? temp.toStringAsFixed(1) : '-',
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
                                        humidity != null ? humidity.toStringAsFixed(1) : '-',
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

  Future<void> _downloadExcel() async {
    final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final end = start.add(const Duration(days: 1));
    final data = await _loadDataForDateRange(start, end);
    final summaries = await _database?.query(
      'summaries',
      where: 'hour_start >= ? AND hour_start < ?',
      whereArgs: [
        start.millisecondsSinceEpoch ~/ 1000,
        end.millisecondsSinceEpoch ~/ 1000,
      ],
    );

    if (data.isEmpty && (summaries?.isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet dataSheet = excelFile['Data'];
      excel.Sheet summarySheet = excelFile['Summaries'];

      final headerStyle = excel.CellStyle(
        fontSize: 14,
        bold: true,
        fontColorHex: excel.ExcelColor.white,
        backgroundColorHex: excel.ExcelColor.blue,
      );

      // Data Sheet
      dataSheet.cell(excel.CellIndex.indexByString('A1')).value =
          excel.TextCellValue('Timestamp');
      dataSheet.cell(excel.CellIndex.indexByString('B1')).value =
          excel.TextCellValue('Temperature (°C)');
      dataSheet.cell(excel.CellIndex.indexByString('C1')).value =
          excel.TextCellValue('Humidity (%)');
      dataSheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = headerStyle;
      dataSheet.cell(excel.CellIndex.indexByString('B1')).cellStyle = headerStyle;
      dataSheet.cell(excel.CellIndex.indexByString('C1')).cellStyle = headerStyle;

      final dataStyle = excel.CellStyle(
        fontSize: 12,
        numberFormat: excel.NumFormat.standard_2,
      );

      for (int i = 0; i < data.length; i++) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(data[i]['timestamp'] * 1000);
        final formattedTimestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);

        dataSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
            .value = excel.TextCellValue(formattedTimestamp);
        dataSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
            .value = excel.DoubleCellValue(data[i]['temperature']);
        dataSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
            .value = excel.DoubleCellValue(data[i]['humidity']);
        dataSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
            .cellStyle = dataStyle;
        dataSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
            .cellStyle = dataStyle;
        dataSheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
            .cellStyle = dataStyle;
      }

      dataSheet.setColumnWidth(0, 20.0);
      dataSheet.setColumnWidth(1, 15.0);
      dataSheet.setColumnWidth(2, 15.0);

      // Summary Sheet
      summarySheet.cell(excel.CellIndex.indexByString('A1')).value =
          excel.TextCellValue('Hour Start');
      summarySheet.cell(excel.CellIndex.indexByString('B1')).value =
          excel.TextCellValue('Time Range');
      summarySheet.cell(excel.CellIndex.indexByString('C1')).value =
          excel.TextCellValue('Avg Temp (°C)');
      summarySheet.cell(excel.CellIndex.indexByString('D1')).value =
          excel.TextCellValue('Avg Humidity (%)');
      summarySheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = headerStyle;
      summarySheet.cell(excel.CellIndex.indexByString('B1')).cellStyle = headerStyle;
      summarySheet.cell(excel.CellIndex.indexByString('C1')).cellStyle = headerStyle;
      summarySheet.cell(excel.CellIndex.indexByString('D1')).cellStyle = headerStyle;

      for (int i = 0; i < (summaries?.length ?? 0); i++) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch((summaries![i]['hour_start'] as int) * 1000);
        final formattedTimestamp = DateFormat('yyyy-MM-dd HH:mm').format(timestamp);

        summarySheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
            .value = excel.TextCellValue(formattedTimestamp);
        summarySheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
            .value = excel.TextCellValue(summaries[i]['time_range'] as String);
        summarySheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
            .value = excel.DoubleCellValue(summaries[i]['avg_temp'] as double);
        summarySheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
            .value = excel.DoubleCellValue(summaries[i]['avg_humidity'] as double);
        summarySheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
            .cellStyle = dataStyle;
        summarySheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
            .cellStyle = dataStyle;
        summarySheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
            .cellStyle = dataStyle;
        summarySheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
            .cellStyle = dataStyle;
      }

      summarySheet.setColumnWidth(0, 20.0);
      summarySheet.setColumnWidth(1, 15.0);
      summarySheet.setColumnWidth(2, 15.0);
      summarySheet.setColumnWidth(3, 15.0);

      final fileName =
          'TempHumidity_${DateFormat('yyyyMMdd').format(selectedDate)}.xlsx';

      final bytes = excelFile.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      if (kIsWeb) {
        try {
          final blob = html.Blob(
            [bytes],
            {'type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'},
          );
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel file downloaded: $fileName')),
          );
        } catch (e) {
          print('Error downloading file in web: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error downloading file: $e')),
          );
        }
      } else {
        bool permissionGranted = await _requestStoragePermission();
        if (!permissionGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
          return;
        }

        try {
          final directory = await getExternalStorageDirectory();
          if (directory == null) {
            throw Exception('Unable to access external storage directory');
          }
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel file saved to: $filePath')),
          );
        } catch (e) {
          print('Error saving file: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving file: $e')),
          );
        }
      }
    } catch (e) {
      print('Excel download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting Excel: $e')),
      );
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted && Platform.isAndroid) {
        status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
      }
      return status.isGranted;
    }
    return true;
  }

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
        startDate = null;
        endDate = null;
      });
      await _fetchHistoricalData();
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
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
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
        selectedDate = picked.start;
        isViewingHistoricalData = true;
      });
      await _fetchHistoricalData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final validTempData = _validateAndSortData(currentTempData, 30, 45);
    final validHumidityData = _validateAndSortData(currentHumidityData, 0, 100);

    double maxX = 86400; // 24 hours in seconds
    if (validTempData.isNotEmpty && validHumidityData.isNotEmpty) {
      final maxDataX = [
        validTempData.last.x,
        validHumidityData.last.x,
      ].reduce((a, b) => a > b ? a : b);
      maxX = (maxDataX / 3600).ceil() * 3600; // Round up to nearest hour
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    IconButton(
                      onPressed: () => _selectDateRange(context),
                      icon: const Icon(Icons.date_range, color: Colors.blueAccent),
                      tooltip: 'Select Date Range',
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
                    minX: tempMinX,
                    maxX: tempMaxX,
                    minY: tempMinY,
                    maxY: tempMaxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: validTempData.isNotEmpty
                            ? validTempData
                            : [FlSpot(0, 30), FlSpot(maxX, 30)],
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [Colors.redAccent, Colors.orangeAccent],
                        ),
                        barWidth: 3,
                        dotData: FlDotData(show: false),
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
                            final hours = (spot.x / 3600).floor();
                            final minutes = ((spot.x % 3600) / 60).floor();
                            final time = '$hours:${minutes.toString().padLeft(2, '0')}';
                            return LineTooltipItem(
                              '$time\n${spot.y.toStringAsFixed(1)} °C',
                              const TextStyle(color: Colors.white),
                            );
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                      touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                        if (event is FlPanEndEvent || event is FlTapUpEvent) {
                          setState(() {});
                        }
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (tempMaxY - tempMinY) / 5,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toStringAsFixed(0)}°C',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
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
                          interval: (tempMaxX - tempMinX) / 6,
                          getTitlesWidget: (value, meta) {
                            final hours = (value / 3600).floor();
                            return Text(
                              '$hours:00',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
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
                      drawVerticalLine: false,
                      horizontalInterval: (tempMaxY - tempMinY) / 5,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200],
                          strokeWidth: 1,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Humidity (%)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          humidityMinX = (humidityMinX + humidityMaxX) / 2 - (humidityMaxX - humidityMinX) / 4;
                          humidityMaxX = (humidityMinX + humidityMaxX) / 2 + (humidityMaxX - humidityMinX) / 4;
                        });
                      },
                      icon: const Icon(Icons.zoom_in, color: Colors.blueAccent),
                      tooltip: 'Zoom In',
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          humidityMinX = (humidityMinX + humidityMaxX) / 2 - (humidityMaxX - humidityMinX);
                          humidityMaxX = (humidityMinX + humidityMaxX) / 2 + (humidityMaxX - humidityMinX);
                        });
                      },
                      icon: const Icon(Icons.zoom_out, color: Colors.blueAccent),
                      tooltip: 'Zoom Out',
                    ),
                    IconButton(
                      onPressed: _resetZoom,
                      icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                      tooltip: 'Reset Zoom',
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
                    minX: humidityMinX,
                    maxX: humidityMaxX,
                    minY: humidityMinY,
                    maxY: humidityMaxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: validHumidityData.isNotEmpty
                            ? validHumidityData
                            : [FlSpot(0, 0), FlSpot(maxX, 0)],
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.cyanAccent],
                        ),
                        barWidth: 3,
                        dotData: FlDotData(show: false),
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
                            final hours = (spot.x / 3600).floor();
                            final minutes = ((spot.x % 3600) / 60).floor();
                            final time = '$hours:${minutes.toString().padLeft(2, '0')}';
                            return LineTooltipItem(
                              '$time\n${spot.y.toStringAsFixed(1)} %',
                              const TextStyle(color: Colors.white),
                            );
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                      touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                        if (event is FlPanEndEvent || event is FlTapUpEvent) {
                          setState(() {});
                        }
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (humidityMaxY - humidityMinY) / 5,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
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
                          interval: (humidityMaxX - humidityMinX) / 6,
                          getTitlesWidget: (value, meta) {
                            final hours = (value / 3600).floor();
                            return Text(
                              '$hours:00',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
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
                      drawVerticalLine: false,
                      horizontalInterval: (humidityMaxY - humidityMinY) / 5,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200],
                          strokeWidth: 1,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ElevatedButton(
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
                    elevation: 2,
                    shadowColor: Colors.blueAccent.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _resetData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    shadowColor: Colors.orangeAccent.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Reset Data',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _validateAndSortData(
      List<FlSpot> data, double minY, double maxY) {
    return data
        .where((spot) =>
    spot.x.isFinite &&
        spot.y.isFinite &&
        spot.y >= minY &&
        spot.y <= maxY &&
        spot.x >= 0 &&
        spot.x <= 86400)
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  Future<void> _loadHourlySummaries() async {
    if (_database == null) return;
    final summaries = await _database!.query(
      'summaries',
      where: 'hour_start >= ?',
      whereArgs: [(selectedDate.millisecondsSinceEpoch ~/ 1000) - 86400],
    );
    setState(() {
      hourlySummaries = summaries;
    });
  }

  void _resetZoom() {
    setState(() {
      tempMinX = 0;
      tempMaxX = 86400;
      tempMinY = 30;
      tempMaxY = 45;
      humidityMinX = 0;
      humidityMaxX = 86400;
      humidityMinY = 0;
      humidityMaxY = 100;
    });
  }
}