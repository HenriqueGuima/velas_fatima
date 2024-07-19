import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velas_fatima/google_login.dart';
import 'package:velas_fatima/login_screen.dart';

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
      title: 'Velas de Fátima',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // home: CandleScreen(prefs),
      home: LoginScreen(prefs),
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
  List<Map<String, dynamic>> _candles = [];
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    int candleCount = widget.prefs.getInt('candleCount') ?? 0;
    _candles = List<Map<String, dynamic>>.generate(
        candleCount,
        (index) => {
              'lit': widget.prefs.getBool('candle_$index') ?? false,
              'type': widget.prefs.getString('candle_type_$index') ??
                  'unlit_candle',
            });

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = const DarwinInitializationSettings();
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    for (int i = 0; i < _candles.length; i++) {
      if (_candles[i]['lit']) {
        var startTime = widget.prefs.getInt('startTime_$i') ??
            DateTime.now().millisecondsSinceEpoch;
        var elapsedTime = DateTime.now().millisecondsSinceEpoch - startTime;
        if (elapsedTime >= const Duration(hours: 50).inMilliseconds) {
          _sendBurnedOutNotification(i);
        } else {
          Future.delayed(
              Duration(
                  milliseconds: const Duration(hours: 50).inMilliseconds -
                      elapsedTime), () {
            _sendBurnedOutNotification(i);
          });
        }
      }
    }
  }

  void _sendBurnedOutNotification(int index) async {
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
        'Velas Fátima', 'velas_fatima',
        channelDescription: 'App Velas de Fátima',
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
      'Uma vela apagou-se!',
      'Carregue nela de novo para a acender!',
      platformChannelSpecifics,
      payload: 'item x',
    );
    setState(() {
      _candles[index]['lit'] = false;
      widget.prefs.setBool('candle_$index', false);
    });
  }

  void _lightCandle(int index) async {
    if (!_candles[index]['lit']) {
      setState(() {
        _candles[index]['lit'] = true;
      });
      widget.prefs
          .setInt('startTime_$index', DateTime.now().millisecondsSinceEpoch);
      widget.prefs.setBool('candle_$index', true);
      Future.delayed(const Duration(hours: 50), () {
        _sendBurnedOutNotification(index);
      });
    }
  }

  void _showCandleDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Escolha uma vela'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Image.asset('assets/lit_white_candle.png',
                    width: 40, height: 40),
                title: const Text('Vela branca'),
                onTap: () {
                  Navigator.of(context).pop();
                  _addCandle('white_candle');
                },
              ),
              ListTile(
                leading: Image.asset('assets/lit_red_candle.png',
                    width: 40, height: 40),
                title: const Text('Vela do Amor'),
                onTap: () {
                  Navigator.of(context).pop();
                  _addCandle('red_candle');
                },
              ),
              ListTile(
                leading: Image.asset('assets/lit_green_candle.png',
                    width: 40, height: 40),
                title: const Text('Vela da Esperança'),
                onTap: () {
                  Navigator.of(context).pop();
                  _addCandle('green_candle');
                },
              ),
              ListTile(
                leading: Image.asset('assets/lit_blue_candle.png',
                    width: 40, height: 40),
                title: const Text('Vela da Paz'),
                onTap: () {
                  Navigator.of(context).pop();
                  _addCandle('blue_candle');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _addCandle(String candleType) async {
    setState(() {
      _candles.add({'lit': false, 'type': candleType});
    });
    int newIndex = _candles.length - 1;
    widget.prefs.setInt('candleCount', _candles.length);
    widget.prefs.setBool('candle_$newIndex', false);
    widget.prefs.setString('candle_type_$newIndex', candleType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Velas de Fátima'),
      ),
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.0, // Make each grid item square
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: _candles.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _lightCandle(index),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black,
                      width: 1.0,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.0, // Ensure the container is square
                    child: Image.asset(
                      _candles[index]['lit']
                          ? 'assets/lit_${_candles[index]['type']}.png'
                          : 'assets/${_candles[index]['type']}.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 16.0,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _showCandleDialog,
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
