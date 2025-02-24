// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velas_fatima/google_login.dart';
import 'package:velas_fatima/main.dart';

class LoginScreen extends StatelessWidget {
  final SharedPreferences prefs;

  const LoginScreen(this.prefs, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar com Google'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Bem vindo à app Velas de Fátima',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await GoogleLogin().signIn();

                try {
                  if (await GoogleLogin().isSignedIn()) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyApp(prefs),
                      ),
                    );
                  } else {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CandleScreen(prefs),
                      ),
                    );
                    print('Not signed in');
                  }
                  // print('Not signed in');
                } catch (e) {
                  print('Error signing in: $e');
                } finally {
                  print('Signing in');
                }
              },
              child: const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}

// void main() {
//   runApp(MaterialApp(
//     home: LoginScreen(prefs),
//   ));
// }
