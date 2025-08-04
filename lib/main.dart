import 'package:flutter/material.dart';
import 'package:sensor_tools/barometer_screen.dart';
import 'package:sensor_tools/compass_screen.dart';
import 'package:sensor_tools/metal_detector_screen.dart';

void main() => runApp(const BarometerApp());

class BarometerApp extends StatefulWidget {
  const BarometerApp({super.key});

  @override
  State<BarometerApp> createState() => _BarometerAppState();
}

class _BarometerAppState extends State<BarometerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkModeEffective =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return MaterialApp(
      title: 'Sensor Tools',
      themeMode: _themeMode,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: MainScreen(
        onThemeToggle: _toggleTheme,
        isDarkModeEnabled: isDarkModeEffective,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkModeEnabled,
  });

  final ValueChanged<bool> onThemeToggle;
  final bool isDarkModeEnabled;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const BarometerScreen(),
      const CompassScreen(),
      const MetalDetectorScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkModeEnabled ? Icons.dark_mode : Icons.light_mode,
            ),
            onPressed: () {
              widget.onThemeToggle(!widget.isDarkModeEnabled);
            },
          ),
        ],
      ),
      body: Center(child: _screens[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: 'Sensor Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.navigation),
            label: 'Compass',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.router),
            label: 'Metal Detector',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue, // You can customize this
        onTap: _onItemTapped,
      ),
    );
  }
}
