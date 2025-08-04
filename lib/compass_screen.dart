import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import 'package:vector_math/vector_math.dart' hide Colors;

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  double? _heading; // Device heading relative to magnetic north (0-360°)
  double? _trueHeading; // Device heading relative to true north (0-360°)
  double? _magneticStrength;
  List<double> _magnetometerValues = [0, 0, 0];
  List<double> _accelerometerValues = [0, 0, 0];
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Magnetic declination: the angle between magnetic north and true north
  // Positive values mean magnetic north is east of true north
  // This should be set based on your location - you can find it online
  // For now, using 0° (can be updated later based on location)
  static const double _magneticDeclination = 0.0;

  @override
  void initState() {
    super.initState();

    // Listen to accelerometer for tilt compensation
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          (AccelerometerEvent event) {
            if (mounted) {
              setState(() {
                _accelerometerValues = [event.x, event.y, event.z];
                _calculateTiltCompensatedHeading();
              });
            }
          },
          onError: (e) {
            debugPrint("Accelerometer error: $e");
          },
        );

    // Listen to magnetometer sensor with fast sampling for responsive compass
    _magnetometerSubscription =
        magnetometerEventStream(
          samplingPeriod: SensorInterval.gameInterval, // 20ms updates (50Hz)
        ).listen(
          (MagnetometerEvent event) {
            if (mounted) {
              setState(() {
                _magnetometerValues = [event.x, event.y, event.z];

                // Calculate magnetic field strength
                _magneticStrength = sqrt(
                  event.x * event.x + event.y * event.y + event.z * event.z,
                );

                _calculateTiltCompensatedHeading();
              });
            }
          },
          onError: (e) {
            debugPrint("Magnetometer error: $e");
          },
        );
  }

  void _calculateTiltCompensatedHeading() {
    // Only calculate if we have both magnetometer and accelerometer data
    if (_magnetometerValues.every((v) => v != 0) &&
        _accelerometerValues.every((v) => v != 0)) {
      // Create Vector3 objects for cleaner vector math
      final magnetic = Vector3(
        _magnetometerValues[0],
        _magnetometerValues[1],
        _magnetometerValues[2],
      );
      final gravity = Vector3(
        _accelerometerValues[0],
        _accelerometerValues[1],
        _accelerometerValues[2],
      );

      // Normalize gravity vector
      final gravityNormalized = gravity.normalized();
      if (gravityNormalized.length == 0) return; // Avoid division by zero

      // Project magnetic field vector onto horizontal plane
      // Projection formula: v_proj = v - (v · n)n where n is the gravity unit vector
      final magneticHorizontal =
          magnetic - gravityNormalized * magnetic.dot(gravityNormalized);

      // Device forward vector (Y-axis) in device coordinates
      final deviceForward = Vector3(0, 1, 0);

      // Project device forward vector onto horizontal plane
      final forwardHorizontal =
          deviceForward -
          gravityNormalized * deviceForward.dot(gravityNormalized);

      // Check if device is pointing straight up/down
      if (forwardHorizontal.length == 0) return;

      // Normalize both horizontal vectors
      final forwardNormalized = forwardHorizontal.normalized();
      final magneticNormalized = magneticHorizontal.normalized();

      // Check if there's horizontal magnetic field
      if (magneticNormalized.length == 0) return;

      // Calculate angle between normalized vectors - simple!
      // dot product = cos(θ), cross product magnitude = sin(θ)
      final cross = forwardNormalized.cross(magneticNormalized);
      final cosTheta = forwardNormalized.dot(magneticNormalized);
      final sinTheta = cross.dot(gravityNormalized); // signed sin component

      // assert that cosTheta ** 2 + sinTheta ** 2 == 1 to a precision of 1e-5
      assert((cosTheta * cosTheta + sinTheta * sinTheta - 1).abs() < 1e-5);

      // atan2(sin, cos) gives us the signed angle directly
      double magneticHeading = atan2(sinTheta, cosTheta) * (180 / pi);

      // Normalize to 0-360 degrees
      magneticHeading = (magneticHeading % 360 + 360) % 360;

      _heading = magneticHeading;

      // Calculate true heading by applying magnetic declination
      _trueHeading = magneticHeading + _magneticDeclination;

      // Normalize true heading to 0-360 degrees
      _trueHeading = (_trueHeading! % 360 + 360) % 360;
    }
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  String _getCardinalDirection(double heading) {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];

    int index = ((heading + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  @override
  Widget build(BuildContext context) {
    final magneticHeadingText = _heading == null
        ? 'Waiting for sensor...'
        : 'Magnetic: ${_heading!.toStringAsFixed(1)}°';

    final trueHeadingText = _trueHeading == null
        ? ''
        : 'True: ${_trueHeading!.toStringAsFixed(1)}°';

    final directionText = _trueHeading == null
        ? ''
        : _getCardinalDirection(_trueHeading!);

    final strengthText = _magneticStrength == null
        ? ''
        : 'Magnetic Strength: ${_magneticStrength!.toStringAsFixed(2)} μT';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Compass Rose Visual
        if (_heading != null)
          Container(
            width: 200,
            height: 200,
            margin: const EdgeInsets.all(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Compass rose (directions + needle) - rotate together to stay fixed in space
                Transform.rotate(
                  angle: -_trueHeading! * (pi / 180),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Expanded(child: SizedBox()),
                          Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'N',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment
                                          .bottomCenter, // Start from center
                                      end: Alignment.topCenter, // Point to N
                                      colors: [Colors.white, Colors.red],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Expanded(child: SizedBox()), // Center space
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'S',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(child: SizedBox()),
                        ],
                      ),
                      Column(
                        children: [
                          Expanded(child: SizedBox()),
                          Row(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'W',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(child: SizedBox()), // Center space
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'E',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Heading text
        Text(magneticHeadingText, style: const TextStyle(fontSize: 28)),

        if (trueHeadingText.isNotEmpty)
          Text(trueHeadingText, style: const TextStyle(fontSize: 28)),

        // Cardinal direction
        if (directionText.isNotEmpty)
          Text(
            directionText,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),

        const SizedBox(height: 20),

        // Magnetic strength
        if (strengthText.isNotEmpty)
          Text(strengthText, style: const TextStyle(fontSize: 16)),

        // Raw magnetometer values (for debugging/interest)
        if (_magnetometerValues.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Raw Magnetometer (μT):',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  'X: ${_magnetometerValues[0].toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Y: ${_magnetometerValues[1].toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Z: ${_magnetometerValues[2].toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
