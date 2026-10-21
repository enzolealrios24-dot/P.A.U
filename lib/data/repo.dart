import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/dice.dart';
import '../core/rules.dart';
import 'imagens.dart';
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

  /// Meus agentes (as transformações aparecem dentro de cada agente).
  static Stream<List<Ficha>> minhasFichas() => fichasEditaveis().map((l) =>
      l.where((f) => f.ownerUid == uid && !f.eTransformacao).toList());

  /// Todas as fichas da mesa, transformações incluídas.
  static Stream<List<Ficha>> todasDaCampanha(String cid) => fichasEditaveis()
      .map((l) => l.where((f) => f.campaignId == cid).toList());

  /// Agentes da mesa como estão em jogo: quem está transformado aparece com a
  /// ficha da transformação.
  static Stream<List<Ficha>> fichasDaCampanha(String cid) =>
      todasDaCampanha(cid).map(emJogo);

  /// Só os agentes da mesa, sem as transformações.
  static Stream<List<Ficha>> agentesDaCampanha(String cid) =>
      todasDaCampanha(cid)
          .map((l) => l.where((f) => !f.eTransformacao).toList());

  static List<Ficha> emJogo(List<Ficha> l) {
    final porId = {for (final f in l) f.id: f};
    final saida = <Ficha>[];
    for (final f in l) {
      if (f.eTransformacao) continue;
      final t = porId[f.formaAtiva];
      saida.add(t != null && t.transformacaoDe == f.id ? t : f);
    }
    return saida;
  }

  /// Transformações de um agente (as que eu posso ver).
  static Stream<List<Ficha>> transformacoesDe(String agenteId) =>
      fichasEditaveis().map(
          (l) => l.where((f) => f.transformacaoDe == agenteId).toList());

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
    m.remove('crisId'); // a cópia não é mais atualizada pelo site do CRIS
    // a cópia começa sem transformações e com uma foto só dela
    for (final k in const ['transformacoes', 'formaAtiva', 'foto']) {
      m.remove(k);
    }
    m['ownerUid'] = uid;
    m['editors'] = [uid];
    m['campaignId'] = null;
    m['criadoEm'] = DateTime.now().millisecondsSinceEpoch;
    _w(ref.set(m));
    if (f.foto.isNotEmpty) {
      Imagens.copiar(f.foto).then((id) {
        if (id != null) set(ref.id, 'foto', id);
      });
    }
    return ref.id;
  }

  // ---------------- Transformações ----------------
  // Uma transformação é uma ficha completa e separada, ligada ao agente pelo
  // campo transformacaoDe. O agente guarda em "transformacoes" o id de cada
  // uma e em "formaAtiva" a que está em uso. PV, PE/PD e SAN podem ser
  // divididos: o que muda numa ficha é repetido na outra.

  /// Campos de cada recurso que agente e transformação podem dividir.
  static const camposRecurso = {
    'pv': ['pvAtual', 'pvTemp', 'pvTempMax'],
    'pe': ['peAtual', 'pdAtual', 'peTemp', 'peTempMax'],
    'san': ['sanAtual'],
  };

  /// Ao criar: o corpo muda (PV próprio), a mente é a mesma (PE/PD e SAN).
  static const compartilhaPadrao = {'pv': false, 'pe': true, 'san': true};

  /// Cria uma transformação do agente. [copiar] começa igual ao agente;
  /// senão, começa como uma ficha nova, só com a progressão dele.
  static String criarTransformacao(Ficha agente,
      {required bool copiar, String nome = ''}) {
    final ref = chars.doc();
    final Json m;
    if (copiar) {
      m = Map<String, dynamic>.from(agente.d);
      for (final k in const [
        'crisId', 'crisImportadoEm', 'transformacoes', 'formaAtiva', 'quadro',
        'foto',
      ]) {
        m.remove(k);
      }
    } else {
      m = novaFicha(uid, agente.jogador);
      for (final k in const [
        'classe', 'nex', 'nivel', 'estagio', 'modoSanidade', 'modoProgressao',
        'sanAtual', 'peAtual', 'pdAtual',
      ]) {
        if (agente.d.containsKey(k)) m[k] = agente.d[k];
      }
    }
    m['nome'] = nome.isEmpty ? '${agente.nome} (transformado)' : nome;
    m['transformacaoDe'] = agente.id;
    m['compartilha'] = compartilhaPadrao;
    m['ownerUid'] = uid;
    m['editors'] = [uid];
    m['campaignId'] = null;
    m['criadoEm'] = DateTime.now().millisecondsSinceEpoch;
    _w(ref.set(m));
    // a transformação acompanha o agente na mesa
    if (agente.campaignId != null) {
      setVarios(ref.id,
          {'campaignId': agente.campaignId, 'editors': agente.editors});
    }
    set(agente.id, 'transformacoes.${ref.id}', compartilhaPadrao);
    return ref.id;
  }

  /// Transforma o agente (ou volta ao normal com null).
  static void transformar(String agenteId, String? transformacaoId) =>
      set(agenteId, 'formaAtiva', transformacaoId);

  static void mudarCompartilha(Ficha t, Json divide) {
    set(t.id, 'compartilha', divide);
    final de = t.transformacaoDe;
    if (de != null) set(de, 'transformacoes.${t.id}', divide);
  }

  /// Apaga a ficha e o que é só dela: a foto e, num agente, as
  /// transformações. [agente] é o agente de uma transformação, se já lido.
  static void apagarFichaCompleta(Ficha f, {Ficha? agente}) {
    apagarFicha(f.id);
    Imagens.apagar(f.foto);
    for (final t in f.transformacoes.keys) {
      apagarFicha(t);
    }
    final de = f.transformacaoDe;
    if (de != null) {
      setVarios(de, {
        'transformacoes.${f.id}': FieldValue.delete(),
        if (agente == null || agente.formaAtiva == f.id) 'formaAtiva': null,
      });
    }
  }

  /// Grava PV/PE/SAN/PD e repete nas fichas ligadas que dividem o recurso
  /// (agente e transformações).
  static void mudarRecursos(Ficha f, Json m) {
    setVarios(f.id, m);
    for (final (id, campos) in _ligadas(f, m.keys)) {
      setVarios(id, {for (final k in campos) k: m[k]});
    }
  }

  static List<(String, List<String>)> _ligadas(
      Ficha f, Iterable<String> campos) {
    List<String> divididos(Map<String, dynamic> cfg) => [
          for (final k in campos)
            if (camposRecurso.entries
                .any((e) => cfg[e.key] == true && e.value.contains(k)))
              k,
        ];
    final de = f.transformacaoDe;
    if (de != null) {
      final l = divididos(f.compartilha);
      return l.isEmpty ? const [] : [(de, l)];
    }
    return [
      for (final e in f.transformacoes.entries)
        if (divididos(asMap(e.value)).isNotEmpty)
          (e.key, divididos(asMap(e.value))),
    ];
  }

  /// Grava uma ficha já montada (agente trazido do site do CRIS).
  static String importarFicha(Json m) {
    final ref = chars.doc();
    _w(ref.set(m));
    return ref.id;
  }

  /// Atualiza com os dados novos do site uma ficha que já veio de lá,
  /// mantendo dono, editores, mesa, data de criação e o que só existe no app.
  static void atualizarFichaImportada(Ficha f, Json m) {
    final novo = Map<String, dynamic>.from(m);
    for (final k in const [
      'ownerUid', 'editors', 'campaignId', 'criadoEm', 'condicoes', 'escolhas',
      'afinidade', 'modoProgressao', 'estagio',
    ]) {
      novo.remove(k);
    }
    _w(chars.doc(f.id).update(novo));
  }

  static void set(String id, String campo, dynamic valor) =>
      _w(chars.doc(id).update({campo: valor}));

  static void setVarios(String id, Json m) => _w(chars.doc(id).update(m));

  /// Muda PV, PE, SAN ou PD. Quando o valor cai (dano, custo de ritual),
  /// os pontos temporários são gastos antes: PV temporário para PV e PE/PD
  /// temporário para PE ou PD.
  static void mudarPontos(Ficha f, String campo, int novo) {
    const temporario = {
      'pvAtual': 'pvTemp',
      'peAtual': 'peTemp',
      'pdAtual': 'peTemp',
    };
    final temp = temporario[campo];
    final atual = asInt(f.d[campo]);
    final t = temp == null ? 0 : asInt(f.d[temp]);
    if (temp == null || novo >= atual || t <= 0) {
      mudarRecursos(f, {campo: novo});
      return;
    }
    final perda = atual - novo;
    final doTemp = perda < t ? perda : t;
    mudarRecursos(f, {
      campo: atual - (perda - doTemp),
      temp: t - doTemp,
      if (t - doTemp == 0) '${temp}Max': 0,
    });
  }

  /// Ajusta PV ou PE/PD temporários ('pvTemp' ou 'peTemp'). A barra cresce
  /// até o maior valor ganho e volta a zero quando eles acabam.
  static void mudarTemporario(Ficha f, String temp, int novo) {
    final v = novo < 0 ? 0 : novo;
    final max = asInt(f.d['${temp}Max']);
    mudarRecursos(f, {
      temp: v,
      '${temp}Max': v == 0 ? 0 : (v > max ? v : max),
    });
  }

  static void apagarFicha(String id) => _w(chars.doc(id).delete());

  /// As transformações vão e saem da mesa junto com o agente.
  static void vincularFicha(Ficha f, Campanha c) {
    final eds = <String>{f.ownerUid, c.masterUid}.toList();
    for (final id in [f.id, ...f.transformacoes.keys]) {
      setVarios(id, {'campaignId': c.id, 'editors': eds});
    }
  }

  static void desvincularFicha(Ficha f) {
    for (final id in [f.id, ...f.transformacoes.keys]) {
      setVarios(id, {
        'campaignId': null,
        'editors': [f.ownerUid]
      });
    }
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
      'regras': {
        'determinacao': false,
        'progressao': 'nex',
        'cargaBase': 0,
        'cargaPorFor': 5
      },
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
