import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/temperatureChart/TemperatureChart.dart';

class DataChartScreen extends StatefulWidget {
  const DataChartScreen({super.key});

  @override
  State<DataChartScreen> createState() => _DataChartScreenState();
}

class _DataChartScreenState extends State<DataChartScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addObserver(this); // Add lifecycle observer to handle app resume
    _initializeService(); // Initialize service on startup
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _initializeService(); // Reinitialize service when app resumes
    }
  }

  void _initializeService() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized && mounted) {
        try {
          final esp32Service =
              Provider.of<ESP32Service>(context, listen: false);
          if (!esp32Service.isCollectingData) {
            esp32Service.startDataCollection();
            _showToast('Starting data collection...');
          }
          setState(() {
            _isInitialized = true;
          });
        } catch (e) {
          _showToast('Error initializing service: $e');
        }
      }
    });
  }

  void _showToast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    super.dispose();
  }

  void _resetChart() {
    try {
      final esp32Service = Provider.of<ESP32Service>(context, listen: false);
      esp32Service.resetDataCollection();
      _showToast('Starting new data collection...');
    } catch (e) {
      _showToast('Error resetting chart: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Charts'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Consumer<ESP32Service>(
            builder: (context, esp32Service, child) {
              if (esp32Service == null || !_isInitialized) {
                return const SizedBox
                    .shrink(); // Avoid rendering until initialized
              }
              if (!esp32Service.isCollectingData) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetChart,
                  tooltip: 'Start New Data Collection',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      drawer: DrawerWidget(authService: _authService),
      body: Consumer<ESP32Service>(
        builder: (context, esp32Service, child) {
          // Show loading indicator if service is not initialized or null
          if (!_isInitialized || esp32Service == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show toast for new data
          if (esp32Service.isCollectingData &&
              esp32Service.tempData.isNotEmpty &&
              esp32Service.humidityData.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Add toast logic if needed (e.g., notify new data point)
            });
          }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (esp32Service.isReconnecting)
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.orange.withOpacity(0.1),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          "Reconnecting to ESP32...",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!esp32Service.isConnected)
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.red.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, size: 20, color: Colors.red),
                        const SizedBox(width: 16),
                        Text(
                          "Disconnected from ESP32",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!esp32Service.isCollectingData)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Data collection completed. Click refresh to start new collection.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (esp32Service.isCollectingData)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Collecting data... ${esp32Service.elapsedSeconds ~/ 60} minutes ${esp32Service.elapsedSeconds % 60} seconds elapsed',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: TemperatureChart(
                    tempData: esp32Service.tempData,
                    humidityData: esp32Service.humidityData,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
