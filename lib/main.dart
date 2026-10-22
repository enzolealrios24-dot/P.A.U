import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/tema_app.dart';
import 'core/theme.dart';
import 'data/catalogo.dart';
import 'data/repo.dart';
import 'firebase_options.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'widgets/efeitos.dart';

final mensageiro = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Catalogo.instance.carregar();
  await TemaApp.carregar();
  await Texturas.carregar();
  String? erroInit;
  if (FirebaseConfig.configurado) {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      erroInit = '$e';
    }
  } else {
    erroInit =
        'O Firebase ainda não foi configurado (lib/firebase_options.dart).';
  }
  Repo.onErro = (e) {
    var msg = '$e';
    if (e is FirebaseException) msg = e.message ?? e.code;
    mensageiro.currentState
        ?.showSnackBar(SnackBar(content: Text('Erro ao salvar: $msg')));
  };
  runApp(CrisApp(erroInit: erroInit));
}

class CrisApp extends StatelessWidget {
  final String? erroInit;
  const CrisApp({super.key, this.erroInit});

  @override
  Widget build(BuildContext context) {
    // Trocar o tema recria o app inteiro com as cores novas.
    return ValueListenableBuilder<String>(
      valueListenable: TemaApp.atual,
      builder: (context, tema, _) => _app(tema),
    );
  }

  Widget _app(String tema) {
    return MaterialApp(
      key: ValueKey(tema),
      title: 'P.A.U',
      debugShowCheckedModeBanner: false,
      theme: temaCris(),
      scaffoldMessengerKey: mensageiro,
      home: erroInit != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(erroInit!, textAlign: TextAlign.center),
                ),
              ),
            )
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                return snap.data == null ? const TelaLogin() : const TelaInicio();
              },
            ),
    );
  }
}
