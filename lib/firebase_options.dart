import 'package:firebase_core/firebase_core.dart';

/// Configuracao do projeto Firebase da mesa.
/// Os valores vem do bloco `firebaseConfig` do app Web criado no console do Firebase.
/// (Essas chaves nao sao secretas: quem protege os dados sao as regras do Firestore.)
class FirebaseConfig {
  static const options = FirebaseOptions(
    apiKey: 'COLE_AQUI_apiKey',
    appId: 'COLE_AQUI_appId',
    messagingSenderId: 'COLE_AQUI_messagingSenderId',
    projectId: 'COLE_AQUI_projectId',
    authDomain: 'COLE_AQUI_authDomain',
    storageBucket: 'COLE_AQUI_storageBucket',
  );

  static bool get configurado => !options.apiKey.startsWith('COLE_AQUI');
}
