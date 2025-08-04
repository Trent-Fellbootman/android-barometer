import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'dart:math';

class MetalDetectorScreen extends StatefulWidget {
  const MetalDetectorScreen({super.key});

  @override
  State<MetalDetectorScreen> createState() => _MetalDetectorScreenState();
}

class _MetalDetectorScreenState extends State<MetalDetectorScreen> {
  double? _magneticStrength;
  double _baselineStrength = 0.0;
  bool _isCalibrating = true;
  bool _metalDetected = false;
  final List<double> _recentReadings = [];
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  // Detection parameters
  static const int _calibrationSamples = 50;
  static const double _detectionThreshold = 15.0; // μT above baseline
  static const int _smoothingWindow = 5;

  Timer? _vibrationTimer;
  DateTime? _lastVibration;

  @override
  void initState() {
    super.initState();
    _startCalibration();
  }

  void _startCalibration() {
    setState(() {
      _isCalibrating = true;
      _recentReadings.clear();
    });

    _magnetometerSubscription =
        magnetometerEventStream(
          samplingPeriod: SensorInterval.gameInterval, // 20ms updates (50Hz)
        ).listen(
          (MagnetometerEvent event) {
            if (mounted) {
              final strength = sqrt(
                event.x * event.x + event.y * event.y + event.z * event.z,
              );

              if (_isCalibrating) {
                _recentReadings.add(strength);

                if (_recentReadings.length >= _calibrationSamples) {
                  // Calculate baseline as average of calibration readings
                  _baselineStrength =
                      _recentReadings.reduce((a, b) => a + b) /
                      _recentReadings.length;
                  setState(() {
                    _isCalibrating = false;
                    _recentReadings.clear();
                  });
                }
              } else {
                // Add to smoothing window
                _recentReadings.add(strength);
                if (_recentReadings.length > _smoothingWindow) {
                  _recentReadings.removeAt(0);
                }

                // Calculate smoothed strength
                final smoothedStrength =
                    _recentReadings.reduce((a, b) => a + b) /
                    _recentReadings.length;
                final deviation = smoothedStrength - _baselineStrength;

                setState(() {
                  _magneticStrength = smoothedStrength;
                  _metalDetected = deviation > _detectionThreshold;
                });

                // Trigger vibration if metal detected
                if (_metalDetected) {
                  _triggerVibration(deviation);
                }
              }
            }
          },
          onError: (e) {
            debugPrint("Magnetometer error: $e");
          },
        );
  }

  void _triggerVibration(double deviation) async {
    final now = DateTime.now();

    // Limit vibration frequency to avoid overwhelming
    if (_lastVibration != null &&
        now.difference(_lastVibration!).inMilliseconds < 100) {
      return;
    }

    _lastVibration = now;

    // Check if vibration is available
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // Variable duration based on deviation strength
      int duration = ((deviation / _detectionThreshold) * 200)
          .clamp(50, 500)
          .round();

      Vibration.vibrate(duration: duration);
    }
  }

  void _recalibrate() {
    _startCalibration();
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  Color _getDetectionColor(double? strength) {
    if (strength == null || _isCalibrating) return Colors.grey;

    final deviation = strength - _baselineStrength;
    if (deviation < 5) return Colors.green;
    if (deviation < 10) return Colors.yellow;
    if (deviation < _detectionThreshold) return Colors.orange;
    return Colors.red;
  }

  String _getDetectionText() {
    if (_isCalibrating) return 'CALIBRATING...';
    if (_metalDetected) return 'METAL DETECTED!';
    return 'SCANNING...';
  }

  @override
  Widget build(BuildContext context) {
    final currentStrength = _magneticStrength ?? 0.0;
    final deviation = _isCalibrating
        ? 0.0
        : currentStrength - _baselineStrength;
    final detectionColor = _getDetectionColor(_magneticStrength);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status indicator
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: detectionColor.withOpacity(0.2),
              border: Border.all(color: detectionColor, width: 4),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _metalDetected ? Icons.warning : Icons.search,
                    size: 60,
                    color: detectionColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _getDetectionText(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: detectionColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Magnetic strength display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Magnetic Strength',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currentStrength.toStringAsFixed(2)} μT',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isCalibrating) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Baseline: ${_baselineStrength.toStringAsFixed(2)} μT',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Deviation: ${deviation >= 0 ? '+' : ''}${deviation.toStringAsFixed(2)} μT',
                      style: TextStyle(
                        color: deviation > _detectionThreshold
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Detection strength bar
          if (!_isCalibrating) ...[
            Text(
              'Detection Level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (deviation / (_detectionThreshold * 2)).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(detectionColor),
              minHeight: 8,
            ),
            const SizedBox(height: 20),
          ],

          // Calibration progress or controls
          if (_isCalibrating) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              'Calibrating... ${_recentReadings.length}/$_calibrationSamples',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'Keep the device away from metal objects',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _recalibrate,
              icon: const Icon(Icons.refresh),
              label: const Text('Recalibrate'),
            ),
            const SizedBox(height: 10),
            Text(
              'Tip: Move the device slowly over surfaces to detect metal objects',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
