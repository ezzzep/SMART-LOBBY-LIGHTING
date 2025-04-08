import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/systemStatus/temperatureStatus/temperature_status.dart';
import 'package:smart_lighting/common/widgets/systemStatus/humidityStatus/humidity_status.dart';
import 'package:smart_lighting/common/widgets/systemStatus/sensorsStatus/sensors_status.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _hasShownLcdError = false;
  bool _hasShownSensorsOff = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Status"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: DrawerWidget(authService: AuthService()),
      body: Consumer<ESP32Service>(
        builder: (context, esp32Service, child) {
          // Show SnackBars in a post-frame callback to avoid build-time calls
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (esp32Service.lastSensorData.contains("LCD:INACTIVE") && !_hasShownLcdError) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("LCD I2C is not connected or active"),
                  duration: Duration(seconds: 5),
                  backgroundColor: Colors.red,
                ),
              );
              _hasShownLcdError = true;
            } else if (esp32Service.lastSensorData.contains("LCD:ACTIVE") && _hasShownLcdError) {
              _hasShownLcdError = false;
            }

            if (!esp32Service.isSensorsOn && !_hasShownSensorsOff) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Sensors powered off - Manual Override"),
                  duration: Duration(seconds: 5),
                  backgroundColor: Colors.orange,
                ),
              );
              _hasShownSensorsOff = true;
            } else if (esp32Service.isSensorsOn && _hasShownSensorsOff) {
              _hasShownSensorsOff = false;
            }
          });

          if (esp32Service.isReconnecting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Reconnecting to ESP32...", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          } else if (!esp32Service.isConnected) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Disconnected from ESP32", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TemperatureStatus(
                    temperature: esp32Service.temperature,
                    isActive: esp32Service.isSensorsOn,
                    isManualOverride: esp32Service.isManualOverride,
                  ),
                  const SizedBox(height: 10),
                  HumidityStatus(
                    humidity: esp32Service.humidity,
                    isActive: esp32Service.isSensorsOn,
                    isManualOverride: esp32Service.isManualOverride,
                  ),
                  const SizedBox(height: 10),
                  _buildSensorsStatusGrid(esp32Service),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSensorsStatusGrid(ESP32Service esp32Service) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          SensorsStatus(
            key: ValueKey('AHT10_${esp32Service.isSensorsOn}_${esp32Service.isManualOverride}'),
            width: 150,
            height: 180,
            title: 'AHT10',
            subtitle: 'Temp and Humidity',
            isActive: esp32Service.isSensorsOn,
            isManualOverride: esp32Service.isManualOverride,
          ),
          SensorsStatus(
            key: ValueKey('PIR_${esp32Service.isSensorsOn}_${esp32Service.pirEnabled}_${esp32Service.isManualOverride}'),
            width: 170,
            height: 200,
            title: 'PIR SENSORS',
            subtitle: 'Motion Detection',
            isActive: esp32Service.isSensorsOn && esp32Service.pirEnabled,
            isManualOverride: esp32Service.isManualOverride,
          ),
          SensorsStatus(
            key: ValueKey('COOLER_${esp32Service.isManualOverride}'),
            width: 160,
            height: 190,
            title: 'COOLER',
            subtitle: 'Fan Cooling System',
            isActive: true, // Placeholder
            isManualOverride: esp32Service.isManualOverride,
          ),
          SensorsStatus(
            key: ValueKey('LIGHT_${esp32Service.isManualOverride}'),
            width: 180,
            height: 220,
            title: 'LIGHT BULBS',
            subtitle: 'Lobby Lighting',
            isActive: esp32Service.isManualOverride ? true : false,
            isManualOverride: esp32Service.isManualOverride,
          ),
        ],
      ),
    );
  }
}