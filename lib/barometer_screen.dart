import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math'; // Import for the pow function

class BarometerScreen extends StatefulWidget {
  const BarometerScreen({super.key});

  @override
  State<BarometerScreen> createState() => _BarometerScreenState();
}

class _BarometerScreenState extends State<BarometerScreen> {
  double? _pressure;
  double? _altitude; // Added for altitude estimation
  StreamSubscription<BarometerEvent>? _barometerSubscription;

  // Standard sea-level pressure in hPa
  static const double _seaLevelPressure = 1013.25;

  @override
  void initState() {
    super.initState();
    // Listen to pressure sensor if available with faster sampling
    _barometerSubscription =
        barometerEventStream(
          samplingPeriod: SensorInterval.uiInterval, // 60ms updates (16Hz)
        ).listen(
          (BarometerEvent event) {
            if (mounted) {
              setState(() {
                _pressure = event.pressure;
                // Calculate altitude using the barometric formula (simplified)
                // h = 44330.8 * (1 - (P / P0)^(1/5.25588))
                _altitude =
                    44330.8 *
                    (1 - pow((_pressure! / _seaLevelPressure), (1 / 5.25588)));
              });
            }
          },
          onError: (e) {
            debugPrint("Sensor Tools error: $e");
          },
        );
  }

  @override
  void dispose() {
    _barometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pressureText = _pressure == null
        ? 'Waiting for sensor...'
        : 'Pressure: ${_pressure!.toStringAsFixed(2)} hPa';

    final altitudeText = _altitude == null
        ? ''
        : 'Altitude: ${_altitude!.toStringAsFixed(2)} m'; // Display altitude

    return Column(
      // Use Column to display both pressure and altitude
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(pressureText, style: const TextStyle(fontSize: 32)),
        if (_altitude != null) // Only show altitude if available
          Text(altitudeText, style: const TextStyle(fontSize: 24)),
      ],
    );
  }
}
