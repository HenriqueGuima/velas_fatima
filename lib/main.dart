// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp(this.prefs, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Candle App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CandleScreen(prefs),
    );
  }
}

class CandleScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const CandleScreen(this.prefs, {super.key});

  @override
  _CandleScreenState createState() => _CandleScreenState();
}

class _CandleScreenState extends State<CandleScreen> {
  List<bool> _candlesLit = [];
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    int candleCount = widget.prefs.getInt('candleCount') ?? 0;
    _candlesLit = List<bool>.generate(
        candleCount, (index) => widget.prefs.getBool('candle_$index') ?? false);

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = const DarwinInitializationSettings();
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

 for (int i = 0; i < _candlesLit.length; i++) {
      if (_candlesLit[i]) {
        var startTime = widget.prefs.getInt('startTime_$i') ?? DateTime.now().millisecondsSinceEpoch;
        var elapsedTime = DateTime.now().millisecondsSinceEpoch - startTime;
        if (elapsedTime >= const Duration(hours:50).inMilliseconds) {
          _sendBurnedOutNotification(i);
        } else {
          Future.delayed(Duration(milliseconds: const Duration(hours:50).inMilliseconds - elapsedTime), () {
            _sendBurnedOutNotification(i);
          });
        }
      }
    }
  }

  void _sendBurnedOutNotification(int index) async {
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
        'your channel id', 'your channel name',
        channelDescription: 'your channel description',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false);
    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      'Candle Burned Out',
      'Your candle has burned out!',
      platformChannelSpecifics,
      payload: 'item x',
    );
    setState(() {
      _candlesLit[index] = false;
      widget.prefs.setBool('candle_$index', false);
    });
  }

  void _lightCandle(int index) async {
    if (!_candlesLit[index]) {
      setState(() {
        _candlesLit[index] = true;
      });
      widget.prefs
          .setInt('startTime_$index', DateTime.now().millisecondsSinceEpoch);
      widget.prefs.setBool('candle_$index', true);
      Future.delayed(const Duration(hours:50), () {
        _sendBurnedOutNotification(index);
      });
    }
  }

  void _toggleCandle(int index) async {
    setState(() {
      _candlesLit[index] = !_candlesLit[index];
    });

    if (_candlesLit[index]) {
      widget.prefs
          .setInt('startTime_$index', DateTime.now().millisecondsSinceEpoch);
      widget.prefs.setBool('candle_$index', true);
      Future.delayed(const Duration(hours:50), () {
        _sendBurnedOutNotification(index);
      });
    } else {
      widget.prefs.setBool('candle_$index', false);
    }
  }

  void _addCandle() async {
    setState(() {
      _candlesLit.add(false);
    });
    widget.prefs.setInt('candleCount', _candlesLit.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Candle App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCandle,
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.5,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: _candlesLit.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _lightCandle(index),
            child: Image.asset(
              _candlesLit[index]
                  ? 'assets/lit_candle.png'
                  : 'assets/unlit_candle.png',
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}
