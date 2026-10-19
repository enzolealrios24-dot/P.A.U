import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/dice.dart';
import '../core/rules.dart';
import 'models.dart';

typedef Json = Map<String, dynamic>;

/// Acesso ao Firestore. Escritas nao sao aguardadas (fire-and-forget) para
/// funcionar offline: o Firestore guarda na fila e sincroniza depois.
class Repo {
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static String get uid => auth.currentUser!.uid;
  static String get nomeUsuario {
    final n = auth.currentUser?.displayName;
    if (n != null && n.trim().isNotEmpty) return n;
    return auth.currentUser?.email?.split('@').first ?? 'Agente';
  }

  static void Function(Object erro)? onErro;
  static void _w(Future<void> f) {
    f.catchError((Object e) {
      onErro?.call(e);
    });
  }

  // ---------------- Fichas ----------------
  static CollectionReference<Json> get chars => db.collection('characters');

  /// Todas as fichas que eu posso editar (minhas + das campanhas que mestro).
  static Stream<List<Ficha>> fichasEditaveis() => chars
      .where('editors', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Ficha(d.id, d.data())).toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase())));

  static Stream<List<Ficha>> minhasFichas() => fichasEditaveis()
      .map((l) => l.where((f) => f.ownerUid == uid).toList());

  static Stream<List<Ficha>> fichasDaCampanha(String cid) => fichasEditaveis()
      .map((l) => l.where((f) => f.campaignId == cid).toList());

  static Stream<Ficha?> ficha(String id) => chars.doc(id).snapshots().map(
      (s) => s.exists && s.data() != null ? Ficha(s.id, s.data()!) : null);

  static String criarFicha() {
    final ref = chars.doc();
    _w(ref.set(novaFicha(uid, nomeUsuario)));
    return ref.id;
  }

  static String duplicarFicha(Ficha f) {
    final ref = chars.doc();
    final m = Map<String, dynamic>.from(f.d);
    m['nome'] = '${f.nome} (cópia)';
    m['ownerUid'] = uid;
    m['editors'] = [uid];
    m['campaignId'] = null;
    m['criadoEm'] = DateTime.now().millisecondsSinceEpoch;
    _w(ref.set(m));
    return ref.id;
  }

  static void set(String id, String campo, dynamic valor) =>
      _w(chars.doc(id).update({campo: valor}));

  static void setVarios(String id, Json m) => _w(chars.doc(id).update(m));

  static void apagarFicha(String id) => _w(chars.doc(id).delete());

  static void vincularFicha(Ficha f, Campanha c) {
    final eds = <String>{f.ownerUid, c.masterUid}.toList();
    setVarios(f.id, {'campaignId': c.id, 'editors': eds});
  }

  static void desvincularFicha(Ficha f) {
    setVarios(f.id, {
      'campaignId': null,
      'editors': [f.ownerUid]
    });
  }

  // ---------------- Campanhas ----------------
  static CollectionReference<Json> get camps => db.collection('campaigns');

  static Stream<List<Campanha>> minhasCampanhas() => camps
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Campanha(d.id, d.data())).toList());

  static Stream<Campanha?> campanha(String id) => camps.doc(id).snapshots().map(
      (s) => s.exists && s.data() != null ? Campanha(s.id, s.data()!) : null);

  static String _gerarCodigo() {
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => abc[r.nextInt(abc.length)]).join();
  }

  static Future<String> criarCampanha(String nome) async {
    final ref = camps.doc();
    final codigo = _gerarCodigo();
    await ref.set({
      'nome': nome,
      'masterUid': uid,
      'joinCode': codigo,
      'memberUids': [uid],
      'members': {uid: nomeUsuario},
      'regras': {'determinacao': false, 'cargaBase': 0, 'cargaPorFor': 5},
      'combate': {'ativo': false, 'rodada': 1, 'turno': 0, 'ordem': []},
      'ledger': [],
      'missao': '',
      'criadoEm': DateTime.now().millisecondsSinceEpoch,
    });
    await db.collection('joinCodes').doc(codigo).set({'campaignId': ref.id});
    return ref.id;
  }

  static Future<String> entrarCampanha(String codigo) async {
    final c = codigo.trim().toUpperCase();
    final snap = await db.collection('joinCodes').doc(c).get();
    if (!snap.exists) throw 'Código de mesa não encontrado.';
    final cid = asStr(snap.data()?['campaignId']);
    await camps.doc(cid).update({
      'memberUids': FieldValue.arrayUnion([uid]),
      'members.$uid': nomeUsuario,
    });
    return cid;
  }

  static Future<void> sairCampanha(Campanha c) async {
    await camps.doc(c.id).update({
      'memberUids': FieldValue.arrayRemove([uid]),
      'members.$uid': FieldValue.delete(),
    });
  }

  static Future<void> removerMembro(Campanha c, String membro) async {
    await camps.doc(c.id).update({
      'memberUids': FieldValue.arrayRemove([membro]),
      'members.$membro': FieldValue.delete(),
    });
  }

  static Future<void> apagarCampanha(Campanha c) async {
    await db.collection('joinCodes').doc(c.joinCode).delete();
    await camps.doc(c.id).delete();
  }

  static void setCamp(String cid, Json m) => _w(camps.doc(cid).update(m));

  // ---------------- Rolagens ----------------
  static CollectionReference<Json> rolls(String cid) =>
      camps.doc(cid).collection('rolls');
  static CollectionReference<Json> gmRolls(String cid) =>
      camps.doc(cid).collection('gmrolls');

  static void registrarRolagem(String cid, Rolagem r,
      {String personagem = '', bool secreta = false}) {
    final col = secreta ? gmRolls(cid) : rolls(cid);
    _w(col.doc().set({
      ...r.toMap(),
      'uid': uid,
      'autor': nomeUsuario,
      'personagem': personagem,
      'at': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  static Stream<List<Json>> logRolagens(String cid, {bool secretas = false}) =>
      (secretas ? gmRolls(cid) : rolls(cid))
          .orderBy('at', descending: true)
          .limit(80)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());

  static Future<void> limparLog(String cid, {bool secretas = false}) async {
    final col = secretas ? gmRolls(cid) : rolls(cid);
    final s = await col.limit(400).get();
    final b = db.batch();
    for (final d in s.docs) {
      b.delete(d.reference);
    }
    await b.commit();
  }

  // ---------------- Mestre: ameacas, homebrew, notas ----------------
  static CollectionReference<Json> ameacas(String cid) =>
      camps.doc(cid).collection('threats');
  static CollectionReference<Json> homebrew(String cid) =>
      camps.doc(cid).collection('homebrew');
  static DocumentReference<Json> notasMestre(String cid) =>
      camps.doc(cid).collection('gm').doc('notas');

  static Stream<List<(String, Json)>> stream(CollectionReference<Json> col,
          {String ordem = 'nome'}) =>
      col.snapshots().map((s) {
        final l = s.docs.map((d) => (d.id, d.data())).toList();
        l.sort((a, b) => asStr(a.$2[ordem]).compareTo(asStr(b.$2[ordem])));
        return l;
      });

  static void salvarDoc(CollectionReference<Json> col, String? id, Json m) {
    if (id == null) {
      _w(col.doc().set(m));
    } else {
      _w(col.doc(id).set(m, SetOptions(merge: true)));
    }
  }

  static void apagarDoc(CollectionReference<Json> col, String id) =>
      _w(col.doc(id).delete());
}
