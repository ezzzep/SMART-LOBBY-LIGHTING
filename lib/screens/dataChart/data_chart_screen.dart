// data_chart_screen_v2.dart
import 'package:flutter/material.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/temperatureChart/TemperatureChart.dart';
import 'package:provider/provider.dart';

class DataChartScreen extends StatefulWidget {
  const DataChartScreen({super.key});

  @override
  State<DataChartScreen> createState() => _DataChartScreenState();
}

class _DataChartScreenState extends State<DataChartScreen> {
  final AuthService _authService = AuthService();
  bool _isInitialized = false;

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        final esp32Service = Provider.of<ESP32Service>(context, listen: false);
        if (!esp32Service.isCollectingData) {
          esp32Service.startDataCollection();
          _showToast('Starting data collection...');
        }
        _isInitialized = true;
      }
    });
  }

  @override
  void dispose() {
    // Keep data collection running across navigation
    super.dispose();
  }

  void _resetChart() {
    final esp32Service = Provider.of<ESP32Service>(context, listen: false);
    esp32Service.resetDataCollection();
    _showToast('Starting new data collection...');
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
          // Show toast for new data
          if (esp32Service.isCollectingData &&
              esp32Service.tempData.isNotEmpty &&
              esp32Service.humidityData.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
             
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