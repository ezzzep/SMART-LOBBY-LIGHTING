import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:provider/provider.dart';

class SystemTweaks extends StatefulWidget {
  const SystemTweaks({super.key});

  @override
  _SystemTweaksState createState() => _SystemTweaksState();
}

class _SystemTweaksState extends State<SystemTweaks>
    with SingleTickerProviderStateMixin {
  int _tempThreshold = 32; // Aligned with ESP32 default
  int _humidThreshold = 65; // Aligned with ESP32 default
  double _lightIntensity = 2;
  bool _isPirSensorOn = true;
  bool _isCoolerOn = true;

  bool _isEditingThreshold = false;
  bool _isEditingLightIntensity = false;

  late FixedExtentScrollController _tempController;
  late FixedExtentScrollController _humidController;

  final AuthService _authService = AuthService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    final esp32Service = Provider.of<ESP32Service>(context, listen: false);
    _tempThreshold = esp32Service.tempThreshold;
    _humidThreshold = esp32Service.humidThreshold;
    _lightIntensity = esp32Service.lightIntensity.toDouble();
    _isPirSensorOn = esp32Service.pirEnabled;
    _isCoolerOn = esp32Service.coolerEnabled;

    _tempController =
        FixedExtentScrollController(initialItem: _tempThreshold - 30);
    _humidController =
        FixedExtentScrollController(initialItem: _humidThreshold - 60);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    esp32Service.addListener(() => _checkCoolerRecommendation(esp32Service));
  }

  @override
  void dispose() {
    _tempController.dispose();
    _humidController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendConfigToESP32(ESP32Service esp32Service, {required bool sensorBasedLightControl}) async {
    try {
      await esp32Service.sendConfigToESP32(
        tempThreshold: _tempThreshold,
        humidThreshold: _humidThreshold,
        pirEnabled: _isPirSensorOn,
        lightIntensity: _lightIntensity.toInt(),
        isAutoMode: esp32Service.isAutoMode,
        coolerEnabled: _isCoolerOn,
        sensorBasedLightControl: sensorBasedLightControl,
      );
      if (!_isEditingLightIntensity && sensorBasedLightControl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved, lights controlled by sensors'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save config: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateLightIntensity(double value, ESP32Service esp32Service) async {
    setState(() {
      _lightIntensity = value;
    });
    try {
      await esp32Service.sendConfigToESP32(
        tempThreshold: _tempThreshold,
        humidThreshold: _humidThreshold,
        pirEnabled: _isPirSensorOn,
        lightIntensity: _lightIntensity.toInt(),
        isAutoMode: esp32Service.isAutoMode,
        coolerEnabled: _isCoolerOn,
        sensorBasedLightControl: false, // Direct control during edit
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update light intensity: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _checkCoolerRecommendation(ESP32Service esp32Service) {
    if (!esp32Service.coolerEnabled &&
        (esp32Service.temperature > esp32Service.tempThreshold ||
            esp32Service.humidity > esp32Service.humidThreshold)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Temperature or humidity high, turn on the cooler"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esp32Service = Provider.of<ESP32Service>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Tweaks'),
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: DrawerWidget(authService: _authService),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSystemModeRow(esp32Service),
              const SizedBox(height: 10),
              _buildAnimatedSensitivityThreshold(esp32Service),
              _buildAnimatedLightIntensitySlider(esp32Service),
              const SizedBox(height: 15),
              _buildAnimatedToggleSwitches(esp32Service),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemModeRow(ESP32Service esp32Service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildSystemModeToggle(esp32Service),
        ],
      ),
    );
  }

  Widget _buildSystemModeToggle(ESP32Service esp32Service) {
    return GestureDetector(
      onTap: () async {
        if (esp32Service.isManualOverride) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot change mode in Manual Override'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        bool newMode = !esp32Service.isAutoMode;
        setState(() {
          esp32Service.isAutoMode = newMode;
          if (newMode) {
            _isEditingThreshold = false;
            _isEditingLightIntensity = false;
            _isPirSensorOn = false; // PIR disabled in auto mode
            _isCoolerOn = true;
            _tempThreshold = 32; // ESP32 default
            _humidThreshold = 65; // ESP32 default
            _lightIntensity = 2; // ESP32 default in auto mode
            _tempController.jumpToItem(_tempThreshold - 30);
            _humidController.jumpToItem(_humidThreshold - 60);
          }
          _animationController.forward(from: 0.0);
        });
        await _sendConfigToESP32(esp32Service, sensorBasedLightControl: true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 118,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: esp32Service.isManualOverride
              ? Colors.orange
              : (esp32Service.isAutoMode ? Colors.blue : Colors.grey),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: esp32Service.isAutoMode
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  esp32Service.isManualOverride
                      ? "OVERRIDE"
                      : (esp32Service.isAutoMode ? "AUTO" : "MANUAL"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Align(
              alignment: esp32Service.isAutoMode
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 25,
                height: 25,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Center(
                  child: Text(
                    esp32Service.isManualOverride
                        ? "O"
                        : (esp32Service.isAutoMode ? "A" : "M"),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: esp32Service.isManualOverride
                          ? Colors.orange
                          : (esp32Service.isAutoMode
                          ? Color.fromRGBO(83, 166, 234, 1)
                          : Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSensitivityThreshold(ESP32Service esp32Service) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.yellow],
                  begin: Alignment.topLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    ignoring: esp32Service.isAutoMode ||
                        esp32Service.isManualOverride ||
                        !_isEditingThreshold,
                    child: Opacity(
                      opacity: (esp32Service.isAutoMode ||
                          esp32Service.isManualOverride ||
                          !_isEditingThreshold)
                          ? 0.5
                          : 1.0,
                      child: Column(
                        children: [
                          Transform.translate(
                            offset: const Offset(0, 14),
                            child: const Text(
                              'SENSITIVITY THRESHOLD',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildScrollPicker(
                                label: "TEMPERATURE",
                                min: 30,
                                max: 40,
                                value: _tempThreshold,
                                suffix: '°C',
                                controller: _tempController,
                                onValueChanged: (value) =>
                                    setState(() => _tempThreshold = value),
                              ),
                              _buildScrollPicker(
                                label: "HUMIDITY",
                                min: 60,
                                max: 80,
                                value: _humidThreshold,
                                suffix: '%',
                                controller: _humidController,
                                onValueChanged: (value) =>
                                    setState(() => _humidThreshold = value),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!esp32Service.isAutoMode && !esp32Service.isManualOverride)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildThresholdButton(esp32Service),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollPicker({
    required String label,
    required int min,
    required int max,
    required int value,
    required String suffix,
    required FixedExtentScrollController controller,
    required Function(int) onValueChanged,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 120,
          height: 103,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white54,
          ),
          child: ListWheelScrollView.useDelegate(
            itemExtent: 40,
            perspective: 0.002,
            physics: const FixedExtentScrollPhysics(),
            controller: controller,
            onSelectedItemChanged: (index) => onValueChanged(min + index),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: max - min + 1,
              builder: (context, index) {
                bool isSelected = (min + index) == value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(
                    isSelected ? 0 : (index < value - min ? -5 : 5),
                    0,
                    0,
                  ),
                  child: Center(
                    child: Text(
                      '${min + index}$suffix',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.red : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdButton(ESP32Service esp32Service) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      transform: Matrix4.identity()..scale(_isEditingThreshold ? 1.0 : 1.1),
      child: IconButton(
        onPressed: () async {
          setState(() {
            _isEditingThreshold = !_isEditingThreshold;
            _animationController.forward(from: 0.0);
          });
          if (!_isEditingThreshold) {
            await _sendConfigToESP32(esp32Service, sensorBasedLightControl: esp32Service.sensorBasedLightControl);
          }
        },
        icon: Icon(
          _isEditingThreshold ? Icons.save : Icons.edit,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildAnimatedLightIntensitySlider(ESP32Service esp32Service) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.yellow],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    ignoring: esp32Service.isAutoMode ||
                        esp32Service.isManualOverride ||
                        !_isEditingLightIntensity,
                    child: Opacity(
                      opacity: (esp32Service.isAutoMode ||
                          esp32Service.isManualOverride ||
                          !_isEditingLightIntensity)
                          ? 0.5
                          : 1.0,
                      child: Column(
                        children: [
                          Transform.translate(
                            offset: const Offset(0, 10),
                            child: const Text(
                              'LIGHT CIRCUITS INTENSITY',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Slider(
                            value: _lightIntensity,
                            min: 0,
                            max: 2,
                            divisions: 2,
                            activeColor: _lightIntensity == 0
                                ? Colors.white
                                : _lightIntensity == 1
                                ? Colors.yellow
                                : Colors.red,
                            inactiveColor: Colors.black26,
                            onChanged: esp32Service.isAutoMode ||
                                esp32Service.isManualOverride ||
                                !_isEditingLightIntensity
                                ? null
                                : (value) => _updateLightIntensity(value, esp32Service),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLightIntensityLabel("OFF", 0, Colors.white),
                              _buildLightIntensityLabel("LOW", 1, Colors.yellow),
                              _buildLightIntensityLabel("HIGH", 2, Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!esp32Service.isAutoMode && !esp32Service.isManualOverride)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        transform: Matrix4.identity()..scale(_isEditingLightIntensity ? 1.0 : 1.1),
                        child: IconButton(
                          onPressed: () async {
                            setState(() {
                              _isEditingLightIntensity = !_isEditingLightIntensity;
                              _animationController.forward(from: 0.0);
                            });
                            if (!_isEditingLightIntensity) {
                              await _sendConfigToESP32(esp32Service, sensorBasedLightControl: true);
                            }
                          },
                          icon: Icon(
                            _isEditingLightIntensity ? Icons.save : Icons.edit,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLightIntensityLabel(String text, double value, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: _lightIntensity == value ? color : Colors.white70,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildAnimatedToggleSwitches(ESP32Service esp32Service) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _animationController.value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToggleBox("COOLER", _isCoolerOn, (value) async {
                  if (!esp32Service.isAutoMode && !esp32Service.isManualOverride) {
                    setState(() => _isCoolerOn = value);
                    await _sendConfigToESP32(esp32Service, sensorBasedLightControl: esp32Service.sensorBasedLightControl);
                  }
                }, esp32Service),
                _buildToggleBox("PIR SENSOR", _isPirSensorOn, (value) async {
                  if (!esp32Service.isAutoMode && !esp32Service.isManualOverride) {
                    setState(() => _isPirSensorOn = value);
                    await _sendConfigToESP32(esp32Service, sensorBasedLightControl: esp32Service.sensorBasedLightControl);
                  }
                }, esp32Service),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleBox(String label, bool value, Function(bool) onChanged, ESP32Service esp32Service) {
    bool isEditable = !esp32Service.isManualOverride &&
        !(esp32Service.isAutoMode && label == "PIR SENSOR");
    return Container(
      width: 165,
      height: 140,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 1, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: isEditable ? () => onChanged(!value) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isEditable
                    ? (value ? Colors.green : Colors.red)
                    : Colors.grey,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: value ? Alignment.centerLeft : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        value ? "ON" : "OFF",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Text(
                          value ? "✔" : "✖",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isEditable
                                ? (value ? Colors.green : Colors.red)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: !isEditable ? 0.5 : 1.0,
            child: Text(
              esp32Service.isManualOverride
                  ? "Manual Override"
                  : (esp32Service.isAutoMode && label == "PIR SENSOR"
                  ? "Disabled in Auto"
                  : (esp32Service.isAutoMode ? "Controlled by Auto" : "")),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}