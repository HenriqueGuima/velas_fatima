import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velas_fatima/login_screen.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs));
}

final bool _kAutoConsume = Platform.isIOS || true;
const String _kConsumableId = 'consumable';
const String _kUpgradeId = 'upgrade';
const String _kSilverSubscriptionId = 'subscription_silver';
const String _kGoldSubscriptionId = 'subscription_gold';
const List<String> _kProductIds = <String>[
  _kConsumableId,
  _kUpgradeId,
  _kSilverSubscriptionId,
  _kGoldSubscriptionId,
];

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp(this.prefs, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velas de Fátima',
      theme: ThemeData(
        primarySwatch: const MaterialColor(0xFFFFC72E, {
          50: Color(0xFFFFF8E1),
          100: Color(0xFFFFECB3),
          200: Color(0xFFFFE082),
          300: Color(0xFFFFD54F),
          400: Color(0xFFFFCA28),
          500: Color(0xFFFFC72E),
          600: Color(0xFFFFC127),
          700: Color(0xFFFFB81F),
          800: Color(0xFFFFB317),
          900: Color(0xFFFFA308),
        }),
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
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<String> _notFoundIds = <String>[];
  List<ProductDetails> _products = <ProductDetails>[];
  List<PurchaseDetails> _purchases = <PurchaseDetails>[];
  List<String> _consumables = <String>[];
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _loading = true;
  String? _queryProductError;

  @override
  void initState() {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription =
        purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (Object error) {
      // handle error here.
    });
    initStoreInfo();

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

  Future<void> initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isAvailable = isAvailable;
        _products = <ProductDetails>[];
        _purchases = <PurchaseDetails>[];
        _notFoundIds = <String>[];
        _consumables = <String>[];
        _purchasePending = false;
        _loading = false;
      });
      return;
    }

    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    final ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    if (productDetailResponse.error != null) {
      setState(() {
        _queryProductError = productDetailResponse.error!.message;
        _isAvailable = isAvailable;
        _products = productDetailResponse.productDetails;
        _purchases = <PurchaseDetails>[];
        _notFoundIds = productDetailResponse.notFoundIDs;
        _consumables = <String>[];
        _purchasePending = false;
        _loading = false;
      });
      return;
    }

    if (productDetailResponse.productDetails.isEmpty) {
      setState(() {
        _queryProductError = null;
        _isAvailable = isAvailable;
        _products = productDetailResponse.productDetails;
        _purchases = <PurchaseDetails>[];
        _notFoundIds = productDetailResponse.notFoundIDs;
        _consumables = <String>[];
        _purchasePending = false;
        _loading = false;
      });
      return;
    }

    final List<String> consumables = await ConsumableStore.load();
    setState(() {
      _isAvailable = isAvailable;
      _products = productDetailResponse.productDetails;
      _notFoundIds = productDetailResponse.notFoundIDs;
      _consumables = consumables;
      _purchasePending = false;
      _loading = false;
    });
  }

  Future<void> consume(String id) async {
    await ConsumableStore.consume(id);
    final List<String> consumables = await ConsumableStore.load();
    setState(() {
      _consumables = consumables;
    });
  }

  Future<void> deliverProduct(PurchaseDetails purchaseDetails) async {
    // IMPORTANT!! Always verify purchase details before delivering the product.
    if (purchaseDetails.productID == _kConsumableId) {
      await ConsumableStore.save(purchaseDetails.purchaseID!);
      final List<String> consumables = await ConsumableStore.load();
      setState(() {
        _purchasePending = false;
        _consumables = consumables;
      });
    } else {
      setState(() {
        _purchases.add(purchaseDetails);
        _purchasePending = false;
      });
    }
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        showPendingUI();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            unawaited(deliverProduct(purchaseDetails));
          } else {
            _handleInvalidPurchase(purchaseDetails);
            return;
          }
        }
        if (Platform.isAndroid) {
          if (!_kAutoConsume && purchaseDetails.productID == _kConsumableId) {
            final InAppPurchaseAndroidPlatformAddition androidAddition =
                _inAppPurchase.getPlatformAddition<
                    InAppPurchaseAndroidPlatformAddition>();
            await androidAddition.consumePurchase(purchaseDetails);
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void showPendingUI() {
    setState(() {
      _purchasePending = true;
    });
  }

  void handleError(IAPError error) {
    setState(() {
      _purchasePending = false;
    });
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) {
    // IMPORTANT!! Always verify a purchase before delivering the product.
    // For the purpose of an example, we directly return true.
    return Future<bool>.value(true);
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    // handle invalid purchase here if valid verification failed.
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
                trailing: const Text('0.20€'),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmationDialog('white_candle');
                },
              ),
              ListTile(
                leading: Image.asset('assets/lit_red_candle.png',
                    width: 40, height: 40),
                title: const Text('Vela do Amor'),
                trailing: const Text('0.20€'),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmationDialog('red_candle');
                },
              ),
              ListTile(
                leading: Image.asset('assets/lit_green_candle.png',
                    width: 40, height: 40),
                title: const Text('Vela da Esperança'),
                trailing: const Text('0.20€'),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmationDialog('green_candle');
                },
              ),
              ListTile(
                leading: Image.asset('assets/lit_blue_candle.png',
                    width: 40, height: 40),
                title: const Text('Vela da Paz'),
                trailing: const Text('0.20€'),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmationDialog('blue_candle');
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

  void _confirmationDialog(String candleType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmação'),
          content: const Text('Deseja comprar a vela?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addCandle(candleType);
              },
              child: const Text('Sim'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Não'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Velas de Fátima'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/fatima.jpg'),
              fit: BoxFit.cover,
              alignment: Alignment.centerLeft,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.6), // adjust the opacity here
                BlendMode.dstATop,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
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
                  decoration: const BoxDecoration(
                      // border: Border.all(
                      //   color: Colors.black,
                      //   width: 1.0,
                      // ),
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

class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}

class ConsumableStore {
  static Future<List<String>> load() async {
    // Load consumables from storage (e.g. SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('consumables') ?? [];
  }

  static Future<void> save(String id) async {
    // Save consumables to storage (e.g. SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    List<String> consumables = prefs.getStringList('consumables') ?? [];
    consumables.add(id);
    await prefs.setStringList('consumables', consumables);
  }

  static Future<void> consume(String id) async {
    // Consume the consumable in your app
    final prefs = await SharedPreferences.getInstance();
    List<String> consumables = prefs.getStringList('consumables') ?? [];
    consumables.remove(id);
    await prefs.setStringList('consumables', consumables);
  }

  static Future<void> clear() async {
    // Clear consumables from storage (e.g. SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('consumables');
  }
}
