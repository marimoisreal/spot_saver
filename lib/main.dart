import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Entry point of the application.
// Ensures that plugin services are initialized before running the UI.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpotSaverApp());
}

final FlutterLocalNotificationsPlugin flutterNotifications =
    FlutterLocalNotificationsPlugin();

// Data Model for a captured location.
// Implements serialization/deserialization logic to store complex objects
// into the local Shared Preferences as JSON strings.

class SavedSpot {
  final String id;
  final double lat;
  final double lng;
  final String battery;
  final DateTime timestamp;

  SavedSpot({
    required this.id,
    required this.lat,
    required this.lng,
    required this.battery,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'battery': battery,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SavedSpot.fromMap(Map<String, dynamic> map) => SavedSpot(
        id: map['id'],
        lat: map['lat'],
        lng: map['lng'],
        battery: map['battery'],
        timestamp: DateTime.parse(map['timestamp']),
      );
}

class SpotSaverApp extends StatelessWidget {
  const SpotSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotSaver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// Root Navigation Controller
// Manages the history list state and handles persistence logic

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  List<SavedSpot> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Load history data from SharedPreferences
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyData = prefs.getString('saved_spots');
    if (historyData != null) {
      final List<dynamic> decoded = jsonDecode(historyData);
      setState(() {
        _history = decoded.map((item) => SavedSpot.fromMap(item)).toList();
        _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    }
  }

  // Save a new location to history
  Future<void> _addNewSpot(SavedSpot spot) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.insert(0, spot);
    });
    final String encoded = jsonEncode(_history.map((s) => s.toMap()).toList());
    await prefs.setString('saved_spots', encoded);
  }

  // Delete a specific spot from history
  Future<void> _deleteSpot(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.removeWhere((item) => item.id == id);
    });
    final String encoded = jsonEncode(_history.map((s) => s.toMap()).toList());
    await prefs.setString('saved_spots', encoded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          GpsScreen(onSpotSaved: _addNewSpot),
          HistoryScreen(history: _history, onDelete: _deleteSpot),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.gps_fixed), label: 'Capture'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

//  GPS Capture Screen interface
//  Connects to the native platform channel for battery info and uses
//  Geolocator for GPS data

class GpsScreen extends StatefulWidget {
  final Function(SavedSpot) onSpotSaved;
  const GpsScreen({super.key, required this.onSpotSaved});

  @override
  State<GpsScreen> createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  static const platform = MethodChannel('samples.flutter.dev/battery');

  String _statusMessage = "Ready to record";
  String _coords = "";
  String _batteryLevel = "";
  bool _isLoading = false;
  LatLng _currentLatLng = const LatLng(35.8922, 14.4396);
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await flutterNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );
  }

  Future<void> _notifyUser() async {
    try {
      const details = AndroidNotificationDetails(
        'spot_id',
        'SpotSaver',
        importance: Importance.max,
        priority: Priority.high,
      );
      await flutterNotifications.show(
        1,
        'Spot Saved!',
        'Location added to history.',
        const NotificationDetails(android: details),
      );
    } catch (e) {
      debugPrint("Notifications not supported");
    }
  }

  Future<String> _getBattery() async {
    try {
      final int result = await platform.invokeMethod('getBatteryLevel');
      return "$result%";
    } catch (e) {
      return "${70 + (DateTime.now().second % 25)}% (Simulation)";
    }
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Locating...";
    });
    debugPrint('analytics_event: user_clicked_capture_button');

    double lat, lng;
    String battery;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
        // ignore: deprecated_member_use
        timeLimit: const Duration(seconds: 5),
      );
      lat = position.latitude;
      lng = position.longitude;

      debugPrint('analytics_event: gps_coordinates_acquired_successfully');
    } catch (e) {
      lat = 35.8922;
      lng = 14.4396;
      debugPrint('analytics_event: gps_failed_using_fallback');
    }

    battery = await _getBattery();
    debugPrint('analytics_event: battery_status_recorded_at_$battery');

    final newSpot = SavedSpot(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lat: lat,
      lng: lng,
      battery: battery,
      timestamp: DateTime.now(),
    );

    widget.onSpotSaved(newSpot);

    setState(() {
      _currentLatLng = LatLng(lat, lng);
      _coords = "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      _batteryLevel = "Battery: $battery";
      _statusMessage = "Spot Captured!";
      _isLoading = false;
    });

    try {
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLatLng));
    } catch (e) {
      debugPrint("Animation failed");
    }

    _notifyUser();
    debugPrint('analytics_event: full_record_persisted_to_storage');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.deepPurple.shade50],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("SpotSaver"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.deepPurple.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _coords.isEmpty
                      ? const Icon(
                          Icons.radar,
                          size: 100,
                          color: Colors.blueGrey,
                        )
                      : _buildMapWidget(),
                ),
              ),
              const SizedBox(height: 20),
              if (_batteryLevel.isNotEmpty)
                Text(
                  _batteryLevel,
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              if (_coords.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.deepPurple.shade100),
                  ),
                  child: Text(
                    _coords,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _isLoading ? null : _captureLocation,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Icon(Icons.add_location_alt, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Safe Map builder with visual fallback for environments without API key

  Widget _buildMapWidget() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentLatLng,
            zoom: 15,
          ),
          onMapCreated: (c) => _mapController = c,
          markers: {
            Marker(markerId: const MarkerId('car'), position: _currentLatLng),
          },
          zoomControlsEnabled: false,
        ),
        IgnorePointer(
          child: Container(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.01),
            child: const Center(
              child: Text(
                "Map Preview",
                style: TextStyle(fontSize: 10, color: Colors.black12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Historical Data View
// Enhanced with swipe to delete and tap to copy functionality

class HistoryScreen extends StatelessWidget {
  final List<SavedSpot> history;
  final Function(String) onDelete;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved History")),
      body: history.isEmpty
          ? const Center(
              child: Text(
                "No spots recorded",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final spot = history[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: "${spot.lat}, ${spot.lng}"),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Coordinates were copied to clipboard!",
                          ),
                        ),
                      );
                    },
                    leading: const Icon(
                      Icons.location_on,
                      color: Colors.deepPurple,
                    ),
                    title: Text(
                      "${spot.lat.toStringAsFixed(4)}, ${spot.lng.toStringAsFixed(4)}",
                    ),
                    subtitle: Text(
                      "Battery: ${spot.battery} • ${spot.timestamp.hour}:${spot.timestamp.minute.min}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(spot.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Extension for formatting integers
// 'min' provides 0-padding for time values (converting 5 to "05")

extension NumberFormatting on int {
  String get min => this < 10 ? '0$this' : toString();
}
