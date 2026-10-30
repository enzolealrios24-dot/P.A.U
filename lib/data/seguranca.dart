import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'repo.dart';

// Barreiras da conta: senha que não seja fácil de adivinhar nem tenha vazado,
// a lista dos aparelhos que entraram e o "desconectar os outros", que as
// regras do Firestore cumprem no servidor (firestore.rules, sessaoValida).

/// O que a senha nova tem de ruim (bloqueio) e quão forte ela é.
class AvaliacaoSenha {
  /// Por que a senha não serve; null quando serve.
  final String? bloqueio;

  /// 0 não serve, 1 aceitável, 2 boa, 3 forte.
  final int forca;
  const AvaliacaoSenha(this.forca, [this.bloqueio]);

  bool get serve => bloqueio == null;
  String get rotulo => const ['Fraca', 'Aceitável', 'Boa', 'Forte'][forca];
}

const _maisUsadas = {
  'senha', 'password', 'pass', 'qwerty', 'abc', 'abcd', 'admin', 'welcome',
  'iloveyou', 'teamo', 'amor', 'brasil', 'flamengo', 'corinthians',
  'palmeiras', 'saopaulo', 'vasco', 'gremio', 'cruzeiro', 'santos', 'dragon',
  'monkey', 'minecraft', 'pokemon', 'naruto', 'batman', 'ordem', 'paranormal',
  'ordemparanormal', 'ordorealitas', 'cris', 'pau', 'agente',
};

const _sequencias = [
  '0123456789012', 'abcdefghijklmnopqrstuvwxyz', 'qwertyuiopasdfghjklzxcvbnm',
];

/// Confere a senha sem sair do aparelho. [email] e [nome] entram para
/// recusar senhas feitas com eles.
AvaliacaoSenha avaliarSenha(String senha, {String email = '', String nome = ''}) {
  if (senha.isEmpty) return const AvaliacaoSenha(0, 'Digite uma senha.');
  if (senha.length < 8) return const AvaliacaoSenha(0, 'Use pelo menos 8 caracteres.');
  final s = senha.toLowerCase();
  if (RegExp(r'^(.)\1+$').hasMatch(s)) {
    return const AvaliacaoSenha(0, 'Não repita o mesmo caractere.');
  }
  for (final q in _sequencias) {
    if (q.contains(s) || q.split('').reversed.join().contains(s)) {
      return const AvaliacaoSenha(0, 'Não use sequências como 12345678 ou qwerty.');
    }
  }
  // "senha123", "Flamengo2024!": a palavra comum com números e símbolos
  final miolo = s.replaceAll(RegExp(r'[^a-zà-ü]'), '');
  if (miolo.isEmpty) {
    return const AvaliacaoSenha(0, 'Use letras também, não só números e símbolos.');
  }
  if (_maisUsadas.contains(miolo)) {
    return const AvaliacaoSenha(0, 'Essa é das senhas mais usadas. Escolha outra.');
  }
  final pedacos = [
    email.split('@').first.toLowerCase(),
    ...nome.toLowerCase().split(RegExp(r'\s+')),
  ].where((p) => p.length >= 4);
  if (pedacos.any(s.contains)) {
    return const AvaliacaoSenha(0, 'Não use seu nome nem seu e-mail na senha.');
  }
  var tipos = 0;
  for (final r in [RegExp('[a-z]'), RegExp('[A-Z]'), RegExp('[0-9]'), RegExp('[^a-zA-Z0-9]')]) {
    if (r.hasMatch(senha)) tipos++;
  }
  final pontos = senha.length + 2 * (tipos - 1);
  return AvaliacaoSenha(pontos >= 16 ? 3 : pontos >= 12 ? 2 : 1);
}

/// Quantas vezes a senha apareceu em vazamentos conhecidos (Have I Been
/// Pwned). Só os 5 primeiros caracteres do SHA-1 dela saem do aparelho; a
/// resposta traz centenas de finais parecidos e a comparação é feita aqui.
/// null quando não deu para consultar (sem internet).
Future<int?> vezesQueVazou(String senha, {http.Client? cliente}) async {
  final hash = sha1.convert(utf8.encode(senha)).toString().toUpperCase();
  final c = cliente ?? http.Client();
  try {
    final r = await c
        .get(Uri.parse('https://api.pwnedpasswords.com/range/${hash.substring(0, 5)}'),
            headers: {'Add-Padding': 'true'})
        .timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final fim = hash.substring(5);
    for (final linha in const LineSplitter().convert(r.body)) {
      final p = linha.split(':');
      if (p.length == 2 && p[0].trim() == fim) return int.tryParse(p[1].trim()) ?? 1;
    }
    return 0;
  } catch (_) {
    return null;
  } finally {
    if (cliente == null) c.close();
  }
}

/// Avaliação completa de uma senha nova: as regras daqui e os vazamentos.
Future<AvaliacaoSenha> conferirSenhaNova(String senha, {String email = '', String nome = ''}) async {
  final a = avaliarSenha(senha, email: email, nome: nome);
  if (!a.serve) return a;
  final n = await vezesQueVazou(senha);
  if (n != null && n > 0) {
    return AvaliacaoSenha(0,
        'Essa senha já apareceu em vazamentos de outros sites (${n == 1 ? '1 vez' : '$n vezes'}). '
        'Quem tenta invadir contas testa essas primeiro: escolha outra.');
  }
  return a;
}

/// O momento (segundos desde 1970) em que esta sessão entrou com a senha,
/// lido do token do Firebase. É o mesmo número que as regras comparam.
int? inicioDoToken(String token) {
  try {
    final p = token.split('.')[1];
    final dados = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(p))));
    final t = dados['auth_time'];
    return t is int ? t : int.tryParse('$t');
  } catch (_) {
    return null;
  }
}

/// Um aparelho que entrou na conta.
class Aparelho {
  final String id;
  final String nome;
  final String plataforma;

  /// Quando entrou com a senha (segundos desde 1970).
  final int desde;
  final DateTime? ultimoUso;
  const Aparelho(this.id, this.nome, this.plataforma, this.desde, this.ultimoUso);

  factory Aparelho.de(String id, Map<String, dynamic> d) => Aparelho(
        id,
        '${d['nome'] ?? 'Aparelho'}',
        '${d['plataforma'] ?? ''}',
        (d['desde'] as num?)?.toInt() ?? 0,
        (d['ultimo'] as Timestamp?)?.toDate(),
      );

  DateTime get entrou => DateTime.fromMillisecondsSinceEpoch(desde * 1000);
}

class Seguranca {
  static FirebaseAuth get _auth => Repo.auth;
  static DocumentReference<Map<String, dynamic>> get _perfil =>
      Repo.db.collection('users').doc(Repo.uid);
  static CollectionReference<Map<String, dynamic>> get _aparelhos =>
      _perfil.collection('aparelhos');

  /// Aviso de senha fraca da conta aberta (o motivo), para pedir a troca.
  static final avisoSenha = ValueNotifier<String?>(null);

  static String _chaveAviso(String uid) => 'pau.senhaFraca.$uid';

  /// Lê o aviso guardado neste aparelho para a conta aberta.
  static Future<void> carregarAviso() async {
    final p = await SharedPreferences.getInstance();
    avisoSenha.value = p.getString(_chaveAviso(Repo.uid));
  }

  /// Depois de entrar: se a senha usada é fraca ou já vazou, guarda o aviso.
  static Future<void> conferirSenhaDoLogin(String senha, String email) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final a = await conferirSenhaNova(senha, email: email, nome: Repo.nomeUsuario);
    final p = await SharedPreferences.getInstance();
    if (a.serve) {
      await p.remove(_chaveAviso(uid));
      if (_auth.currentUser?.uid == uid) avisoSenha.value = null;
    } else {
      await p.setString(_chaveAviso(uid), a.bloqueio!);
      if (_auth.currentUser?.uid == uid) avisoSenha.value = a.bloqueio;
    }
  }

  /// Identificador deste aparelho, sorteado na primeira vez.
  static Future<String> idDoAparelho() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('pau.aparelho');
    if (id == null) {
      final r = Random.secure();
      const letras = 'abcdefghijklmnopqrstuvwxyz0123456789';
      id = List.generate(20, (_) => letras[r.nextInt(letras.length)]).join();
      await p.setString('pau.aparelho', id);
    }
    return id;
  }

  static Future<(String, String)> _descreverAparelho() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final fab = a.manufacturer.isEmpty
            ? ''
            : '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)} ';
        final modelo = '$fab${a.model}'.trim();
        return (a.name.isNotEmpty && a.name != a.model ? '${a.name} ($modelo)' : modelo, 'android');
      }
      if (Platform.isWindows) {
        final w = await info.windowsInfo;
        return ('Computador ${w.computerName}', 'windows');
      }
    } catch (_) {}
    return ('Aparelho ${Platform.operatingSystem}', Platform.operatingSystem);
  }

  /// Quando esta sessão entrou com a senha (segundos desde 1970).
  static Future<int?> inicioDaSessao({bool renovar = false}) async {
    final t = await _auth.currentUser?.getIdToken(renovar);
    return t == null ? null : inicioDoToken(t);
  }

  /// Anota este aparelho na lista da conta (com o último uso).
  static Future<void> registrarAparelho() async {
    final desde = await inicioDaSessao();
    if (desde == null) return;
    final (nome, plataforma) = await _descreverAparelho();
    await _aparelhos.doc(await idDoAparelho()).set({
      'nome': nome,
      'plataforma': plataforma,
      'desde': desde,
      'ultimo': FieldValue.serverTimestamp(),
    });
  }

  /// Os aparelhos que entraram na conta, do uso mais recente ao mais antigo.
  static Stream<List<Aparelho>> aparelhos() => _aparelhos.snapshots().map((s) {
        final l = [for (final d in s.docs) Aparelho.de(d.id, d.data())];
        l.sort((a, b) => (b.ultimoUso ?? b.entrou).compareTo(a.ultimoUso ?? a.entrou));
        return l;
      });

  /// Até quando as sessões foram cortadas (segundos desde 1970), ou 0.
  static Stream<int> cortadasAte() => Repo.perfilDoJogador(Repo.uid)
      .map((d) => (d['revogado'] as num?)?.toInt() ?? 0);

  /// Pede a senha de novo ao Firebase: a sessão passa a contar de agora.
  static Future<void> confirmarSenha(String senha) async {
    final u = _auth.currentUser!;
    await u.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: u.email!, password: senha));
  }

  /// Desconecta todos os outros aparelhos: as regras passam a recusar
  /// qualquer sessão que entrou antes desta. Chame depois de [confirmarSenha].
  static Future<void> desconectarOutros() async {
    final desde = await inicioDaSessao(renovar: true);
    if (desde == null) throw 'Não foi possível ler a sua sessão. Saia e entre de novo.';
    // a sessão precisa ser a mais nova, ou quem entrou depois dela ficaria
    final agora = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if ((agora - desde).abs() > 600) {
      throw 'A sessão deste aparelho não foi renovada. Saia da conta, entre de novo e tente outra vez.';
    }
    // reabre a conexão com o token novo: com o antigo, este aparelho também
    // seria recusado assim que o corte valesse
    await Repo.db.disableNetwork();
    await Repo.db.enableNetwork();
    await _perfil.set({'revogado': desde}, SetOptions(merge: true));
    await registrarAparelho();
  }

  /// Troca a senha e desconecta os outros aparelhos.
  static Future<void> trocarSenha(String atual, String nova) async {
    await confirmarSenha(atual);
    await _auth.currentUser!.updatePassword(nova);
    await desconectarOutros();
    final p = await SharedPreferences.getInstance();
    await p.remove(_chaveAviso(Repo.uid));
    avisoSenha.value = null;
  }

  static String _chaveVistos(String uid) => 'pau.aparelhosVistos.$uid';

  /// Entradas de outros aparelhos que este ainda não mostrou. Na primeira
  /// vez, só anota as que já existiam.
  static Future<List<Aparelho>> entradasNovas(List<Aparelho> todos) async {
    final p = await SharedPreferences.getInstance();
    final chave = _chaveVistos(Repo.uid);
    final eu = await idDoAparelho();
    final guardado = p.getString(chave);
    final vistos = guardado == null
        ? null
        : (jsonDecode(guardado) as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
    final novas = [
      if (vistos != null)
        for (final a in todos)
          if (a.id != eu && a.desde > (vistos[a.id] ?? 0)) a,
    ];
    await p.setString(chave, jsonEncode({for (final a in todos) a.id: a.desde}));
    return novas;
  }
}
