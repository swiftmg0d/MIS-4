// Required packages:
// - flutter_map: for OpenStreetMap integration
// - table_calendar: for calendar view
// - geolocator: for location services
// - flutter_local_notifications: for reminders
// - http: for API communication (optional for routes)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  runApp(ExamScheduleApp());
}

class ExamScheduleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Schedule',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ExamScheduleHomePage(),
    );
  }
}

class ExamScheduleHomePage extends StatefulWidget {
  @override
  _ExamScheduleHomePageState createState() => _ExamScheduleHomePageState();
}

class _ExamScheduleHomePageState extends State<ExamScheduleHomePage> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  late FlutterLocalNotificationsPlugin _localNotificationsPlugin;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _initializeNotifications() {
    _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    _localNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _scheduleNotification(DateTime dateTime, String title) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotificationsPlugin.zonedSchedule(
      0,
      'Exam Reminder',
      title,
      tz.TZDateTime.from(dateTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _addMarker(LatLng position, String title) {
    setState(() {
      _markers.add(
        Marker(
          point: position,
          width: 40.0,
          height: 40.0,
          child: Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40.0,
          ),
        ),
      );
    });
  }

  Future<void> _getShortestRoute(LatLng start, LatLng end) async {
    final Uri url = Uri.parse('https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0]['geometry']['coordinates'];

      List<LatLng> polylinePoints = route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();

      setState(() {
        _markers.addAll([
          Marker(
            point: start,
            width: 40.0,
            height: 40.0,
            child: Icon(
              Icons.location_on,
              color: Colors.green,
              size: 40.0,
            ),
          ),
          Marker(
            point: end,
            width: 40.0,
            height: 40.0,
            child: Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 40.0,
            ),
          ),
        ]);
      });

      _mapController.move(start, 14.0); // Moves to starting point with zoom
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Schedule'),
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: (day) {
              return _events[day] ?? [];
            },
          ),
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(41.9981, 21.4254), // Example location
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: [
                    'a',
                    'b',
                    'c'
                  ],
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _events[_selectedDay] != null ? _events[_selectedDay]!.length : 0,
              itemBuilder: (context, index) {
                final event = _events[_selectedDay]![index];
                return ListTile(
                  title: Text(event['title']),
                  subtitle: Text(event['description']),
                  trailing: Icon(Icons.notifications),
                  onTap: () {
                    _scheduleNotification(event['dateTime'], event['title']);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          LatLng newPosition = LatLng(41.9981, 21.4254);
          String title = 'New Exam';
          String description = 'Exam description here';
          DateTime dateTime = DateTime.now().add(Duration(hours: 2));

          _addMarker(newPosition, title);
          setState(() {
            _events[_focusedDay] = _events[_focusedDay] ?? [];
            _events[_focusedDay]!.add({
              'title': title,
              'description': description,
              'dateTime': dateTime,
              'position': newPosition,
            });
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
