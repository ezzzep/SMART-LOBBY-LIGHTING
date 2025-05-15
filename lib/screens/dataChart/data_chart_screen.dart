import 'package:flutter/material.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/temperatureChart/TemperatureChart.dart';
import 'package:fl_chart/fl_chart.dart';

class DataChartScreen extends StatelessWidget {
  const DataChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    // Example data
    final List<FlSpot> tempData = [
      FlSpot(0, 24),
      FlSpot(1, 25),
      FlSpot(2, 27),
      FlSpot(3, 26),
      FlSpot(4, 28),
    ];

    final List<FlSpot> humidityData = [
      FlSpot(0, 60),
      FlSpot(1, 62),
      FlSpot(2, 65),
      FlSpot(3, 63),
      FlSpot(4, 66),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Charts'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: DrawerWidget(authService: _authService),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TemperatureChart(
          tempData: tempData,
          humidityData: humidityData,
        ),
      ),
    );
  }
}
