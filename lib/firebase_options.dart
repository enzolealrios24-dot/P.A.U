import 'package:firebase_core/firebase_core.dart';

/// Configuracao do projeto Firebase da mesa.
/// Os valores vem do bloco `firebaseConfig` do app Web criado no console do Firebase.
/// (Essas chaves nao sao secretas: quem protege os dados sao as regras do Firestore.)
class FirebaseConfig {
  static const options = FirebaseOptions(
    apiKey: 'AIzaSyBB50jb6DYSjXGAmwcvT5urTmw2SYjdCrI',
    appId: '1:882747273134:web:0e9d17d3bcb0c04323a23f',
    messagingSenderId: '882747273134',
    projectId: 'ferramenta-op',
    authDomain: 'ferramenta-op.firebaseapp.com',
    storageBucket: 'ferramenta-op.firebasestorage.app',
  );

  static bool get configurado => !options.apiKey.startsWith('COLE_AQUI');
}
