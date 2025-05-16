import 'package:flutter/material.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/temperatureChart/TemperatureChart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

class DataChartScreen extends StatefulWidget {
  const DataChartScreen({super.key});

  @override
  State<DataChartScreen> createState() => _DataChartScreenState();
}

class _DataChartScreenState extends State<DataChartScreen> with AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final esp32Service = Provider.of<ESP32Service>(context);
    
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
          esp32Service: esp32Service,
          tempData: esp32Service.tempData,
          humidityData: esp32Service.humidityData,
        ),
      ),
    );
  }
}