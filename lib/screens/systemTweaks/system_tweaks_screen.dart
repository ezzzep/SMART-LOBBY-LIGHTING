import 'package:flutter/material.dart';
import 'package:smart_lighting/services/service.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';

class SystemTweaks extends StatefulWidget {
  const SystemTweaks({super.key});

  @override
  _SystemTweaksState createState() => _SystemTweaksState();
}

class _SystemTweaksState extends State<SystemTweaks> {
  int _temperature = 37;
  int _humidity = 80;
  double _lightIntensity = 1;

  bool _isCoolerOn = false;
  bool _isPirSensorOn = true;
  bool _isSystemModeOn = false;
  bool _isEditingThreshold = false;
  bool _isEditingIntensity = false;

  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Tweaks'),
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: DrawerWidget(authService: _authService),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSystemModeRow(),
              const SizedBox(height: 10),
              _buildSensitivityThreshold(),
              _buildLightIntensitySlider(),
              const SizedBox(height: 15),
              _buildToggleSwitches(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemModeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildSystemModeToggle(),
        ],
      ),
    );
  }

  Widget _buildSystemModeToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSystemModeOn = !_isSystemModeOn;
        });
      },
      child: Container(
        width: 118,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _isSystemModeOn ? Colors.blue : Colors.grey,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: _isSystemModeOn
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _isSystemModeOn ? "AUTO" : "MANUAL",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Align(
              alignment: _isSystemModeOn
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
                    _isSystemModeOn ? "A" : "M",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _isSystemModeOn ? Colors.blue : Colors.grey,
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

  Widget _buildSensitivityThreshold() {
    return Container(
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
            ignoring: _isSystemModeOn || !_isEditingThreshold,
            child: Opacity(
              opacity: (_isSystemModeOn || !_isEditingThreshold) ? 0.5 : 1.0,
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
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: _buildScrollPicker(
                            "TEMPERATURE", 35, 45, _temperature, (value) {
                          setState(() => _temperature = value);
                        }),
                      ),
                      Expanded(
                        child: _buildScrollPicker("HUMIDITY", 30, 90, _humidity,
                            (value) {
                          setState(() => _humidity = value);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!_isSystemModeOn)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    if (!_isEditingThreshold) {
                      _isEditingIntensity = false;
                    }
                    _isEditingThreshold = !_isEditingThreshold;
                  });
                },
                icon: Icon(
                  _isEditingThreshold ? Icons.save : Icons.edit,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollPicker(
      String label, int min, int max, int value, Function(int) onChanged) {
    List<String> values = List.generate(max - min + 1,
        (index) => "${min + index}${label == 'TEMPERATURE' ? '°C' : '%'}");

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white)),
          const SizedBox(height: 10),
          Container(
            width: 145,
            height: 103,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white54,
            ),
            child: ListWheelScrollView.useDelegate(
              itemExtent: 50,
              perspective: 0.002,
              physics: (_isSystemModeOn || !_isEditingThreshold)
                  ? const NeverScrollableScrollPhysics()
                  : const FixedExtentScrollPhysics(),
              controller: FixedExtentScrollController(initialItem: value - min),
              onSelectedItemChanged: (index) {
                if (!_isSystemModeOn && _isEditingThreshold) {
                  setState(() => onChanged(min + index));
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: values.length,
                builder: (context, index) {
                  bool isSelected = (min + index) == value;
                  return Center(
                    child: Text(
                      values[index],
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.red : Colors.black,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightIntensitySlider() {
    return Container(
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
            ignoring: _isSystemModeOn || !_isEditingIntensity,
            child: Opacity(
              opacity: (_isSystemModeOn || !_isEditingIntensity) ? 0.5 : 1.0,
              child: Column(
                children: [
                  Transform.translate(
                    offset: const Offset(0, 10),
                    child: const Text(
                      'LIGHT INTENSITY',
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
                    onChanged: (_isSystemModeOn || !_isEditingIntensity)
                        ? null
                        : (value) {
                            setState(() {
                              _lightIntensity = value;
                            });
                          },
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLightIntensityLabel("LOW", 0, Colors.white),
                      _buildLightIntensityLabel("MID", 1, Colors.yellow),
                      _buildLightIntensityLabel("HIGH", 2, Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!_isSystemModeOn)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    if (!_isEditingIntensity) {
                      _isEditingThreshold = false;
                    }
                    _isEditingIntensity = !_isEditingIntensity;
                  });
                },
                icon: Icon(
                  _isEditingIntensity ? Icons.save : Icons.edit,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
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

  Widget _buildToggleSwitches() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToggleBox("COOLER", _isCoolerOn, (value) {
          if (!_isSystemModeOn) {
            setState(() {
              _isCoolerOn = value;
            });
          }
        }),
        _buildToggleBox("PIR SENSOR", _isPirSensorOn, (value) {
          if (!_isSystemModeOn) {
            setState(() {
              _isPirSensorOn = value;
            });
          }
        }),
      ],
    );
  }

  Widget _buildToggleBox(String label, bool value, Function(bool) onChanged) {
    return IgnorePointer(
      ignoring: _isSystemModeOn,
      child: Opacity(
        opacity: _isSystemModeOn ? 0.5 : 1.0,
        child: Container(
          width: 165,
          height: 140,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 1,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: _isSystemModeOn ? null : () => onChanged(!value),
                child: Container(
                  width: 100,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: value ? Colors.green : Colors.red,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: value
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
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
                        alignment: value
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 30,
                          height: 30,
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
                                color: value ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
