import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cris_ficha/core/dano.dart';
import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/core/theme.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/screens/campaign/campaign_screen.dart';
import 'package:cris_ficha/screens/master/ameacas.dart';
import 'package:cris_ficha/screens/sheet/rolar.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => Catalogo.instance.carregar());

  group('resistências das ameaças', () {
    test('os livros', () {
      final r = ResistenciasAmeaca.doTexto(
          'Resistências: Balístico, corte e perfuração 5; Sangue 10; Energia 20 • Vulnerabilidades: Morte e fogo');
      expect([for (final t in ['balistico', 'corte', 'perfuracao', 'impacto', 'sangue', 'energia']) r.rdContra(t)],
          [5, 5, 5, 0, 10, 20]);
      expect(r.danoSofrido(10, 'fogo'), 20);
      expect(r.danoSofrido(10, 'corte'), 5);
      expect(r.danoSofrido(10, 'corte', metade: true), 0);

      final exceto = ResistenciasAmeaca.doTexto('Imunidades: Dano (exceto Conhecimento) e todas as condições');
      expect(exceto.imuneA('corte'), isTrue);
      expect(exceto.imuneA('conhecimento'), isFalse);

      final morte = ResistenciasAmeaca.doTexto('Imunidades: Atordoado, paralisias, dano e efeitos de Morte');
      expect(morte.imuneA('morte'), isTrue);
      expect(morte.imuneA('corte'), isFalse);

      expect(ResistenciasAmeaca.doTexto('Resistências: Dano 30').rdContra('fogo'), 30);
      expect(ResistenciasAmeaca.doTexto('Resistências: RD 5').rdContra('corte'), 5);
      expect(ResistenciasAmeaca.doTexto('Imunidades: Dano balístico').imuneA('balistico'), isTrue);
      expect(ResistenciasAmeaca.doTexto('Imunidades: Dano balístico').imuneA('corte'), isFalse);
    });

    test('anotadas pelo mestre, sem rótulo', () {
      final r = ResistenciasAmeaca.doTexto('Corte 5, Fogo 10');
      expect(r.rdContra('corte'), 5);
      expect(r.rdContra('fogo'), 10);
      expect(r.rdContra('impacto'), 0);
    });

    test('toda ameaça dos livros com resistência anotada tem RD', () {
      for (final a in Catalogo.instance.ameacas) {
        final texto = asStr(a['resistencias']);
        if (texto.isEmpty) continue;
        final r = ResistenciasAmeaca.doTexto(asStr(ameacaDoLivro(a)['resistencias']));
        expect(r.rd, isNotEmpty, reason: '${a['nome']}: $texto');
      }
      for (final a in Catalogo.instance.ameacas) {
        final texto = asStr(a['vulnerabilidades']);
        if (texto.isEmpty) continue;
        expect(ResistenciasAmeaca.doTexto('Vulnerabilidades: $texto').vulneravel, isNotEmpty, reason: texto);
      }
    });
  });

  testWidgets('o ataque do agente leva o alvo para o mestre', (tester) async {
    final db = FakeFirebaseFirestore();
    Repo.dbTeste = db;
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'jogador', displayName: 'Jo'));
    final camp = Campanha('c1', {
      'combate': {
        'ativo': true,
        'ordem': [
          {'id': 'o1', 'tipo': 'ameaca', 'ref': 't1', 'nome': 'Bêbado Local', 'valor': 10},
        ],
      },
    });
    final f = Ficha('a1', {...novaFicha('jogador', 'Jo'), 'nome': 'Rafa', 'alvo': 'o1'});
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    CtxFicha(f, camp).rolarAtaque(ctx, {'nome': 'Faca', 'dano': '1d4', 'tipoDano': 'Corte ou perfuração'});
    await tester.pump(const Duration(seconds: 3));
    final r = (await db.collection('campaigns').doc('c1').collection('rolls').get()).docs.single.data();
    expect(r['alvo'], 'o1');
    expect(r['fichaId'], 'a1');
    expect(asMap(r['golpe'])['tiposDano'], ['corte', 'perfuracao']);
    expect(r['titulo'], contains('contra Bêbado Local'));
  });

  test('a área do ritual vem do alvo ou do texto da forma', () {
    expect(areaDoRitual('Área: nuvem de 6m de raio', ''), 'Área: nuvem de 6m de raio');
    expect(areaDoRitual('1 ser', ''), '');
    expect(areaDoRitual('1 ser', 'Explosão de 6m de raio ao seu redor com 8d8+8. Requer 3º círculo.'),
        'Explosão de 6m de raio ao seu redor com 8d8+8');
    expect(areaDoRitual('1 pessoa', 'Todos os alvos no alcance. Requer 3º círculo.'), 'Todos os alvos no alcance');
    expect(areaDoRitual('1 ser', 'Sem resistência, 3d8+3.'), '');
  });

  testWidgets('o ritual em área vai ao mestre mesmo sem alvo marcado', (tester) async {
    final db = FakeFirebaseFirestore();
    Repo.dbTeste = db;
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'jogador', displayName: 'Jo'));
    final camp = Campanha('c1', {
      'combate': {
        'ativo': true,
        'ordem': [
          {'id': 'o1', 'tipo': 'ameaca', 'ref': 't1', 'nome': 'Bêbado Local', 'valor': 10},
          {'id': 'o2', 'tipo': 'agente', 'ref': 'a1', 'nome': 'Rafa', 'valor': 8},
        ],
      },
    });
    final dados = {...novaFicha('jogador', 'Jo'), 'nome': 'Rafa', 'peAtual': 20};
    await db.collection('characters').doc('a1').set(dados);
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final ritual = {
      'nome': 'Poeira da Podridão',
      'elemento': 'Morte',
      'circulo': 1,
      'alvo': 'Área: nuvem de 6m de raio',
      'resistencia': 'Fortitude reduz à metade',
      'dano': '4d8',
      'resumo': 'Ao conjurar e a cada turno, 4d8 de Morte na área; quem falha fica fraco.',
    };
    CtxFicha(Ficha('a1', dados), camp).conjurar(ctx, ritual, forma: 'Padrão');
    // um ritual só em si mesmo não vai ao mestre
    CtxFicha(Ficha('a1', dados), camp)
        .conjurar(ctx, {'nome': 'Arma Atroz', 'elemento': 'Sangue', 'alvo': '1 arma corpo a corpo'}, forma: 'Padrão');
    await tester.pump(const Duration(seconds: 3));
    final rs = [for (final d in (await db.collection('campaigns').doc('c1').collection('rolls').get()).docs) d.data()];
    final golpes = rs.where((r) => r['golpe'] != null).toList();
    expect(rs, hasLength(2));
    expect(golpes, hasLength(1));
    final r = golpes.single;
    expect(r['alvo'], '');
    expect(r['participantes'], ['o1', 'o2']);
    final g = asMap(r['golpe']);
    expect(g['area'], 'Área: nuvem de 6m de raio');
    expect(g['tiposDano'], ['morte']);
    expect(g['condicoes'], ['Fraco']);
  });

  testWidgets('o mestre vê se acertou e aplica o dano na ameaça', (tester) async {
    final camp = await _abrirDano(tester, ordem: [
      _ameaca('o1', 't1', 'Bêbado Local'),
      _agente('o2', 'a1', 'Rafa'),
    ], ameacas: {
      't1': {'nome': 'Bêbado Local', 'pv': 10, 'pvMax': 10, 'defesa': 12, 'resistencias': 'Resistências: Corte 2'},
    }, registros: {
      'acerto': _ataque(15, 2, alvo: 'o1'),
      'erro': _ataque(5, 1, alvo: 'o1'),
      // um combate antigo: o alvo não está mais na ordem
      'antigo': _ataque(18, 0, alvo: 'velho'),
    });

    expect(find.text('2 para conferir'), findsOneWidget);
    expect(find.textContaining('Ataque 15  acertou', findRichText: true), findsOneWidget);
    expect(find.textContaining('errou (Defesa 12)', findRichText: true), findsOneWidget);
    expect(find.textContaining('dano 6 corte · RD 2 · sofre 4', findRichText: true), findsOneWidget);
    expect(find.text('Aplicar dano'), findsOneWidget);

    await tester.tap(find.text('Aplicar dano'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(asInt((await camp.collection('threats').doc('t1').get()).data()!['pv']), 6);
    final marcas = (await camp.collection('gm').doc('danos').get()).data()!;
    expect(asMap(marcas['acerto'])['estado'], 'aplicado');

    await tester.tap(find.text('Dispensar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RESOLVIDOS'), findsOneWidget);
    expect(find.text('Aplicar dano'), findsNothing);
  });

  testWidgets('ritual em área: o mestre escolhe quem está nela e cada um resiste', (tester) async {
    final camp = await _abrirDano(tester, ordem: [
      _ameaca('o1', 't1', 'Bêbado Local'),
      _ameaca('o2', 't2', 'Cão Raivoso'),
      _agente('o3', 'a1', 'Rafa'),
    ], ameacas: {
      // um passa sempre na Fortitude, o outro falha sempre
      't1': {'nome': 'Bêbado Local', 'pv': 50, 'pvMax': 50, 'defesa': 12, 'pericias': 'Fortitude 1d20+100'},
      't2': {
        'nome': 'Cão Raivoso',
        'pv': 50,
        'pvMax': 50,
        'defesa': 10,
        'pericias': 'Percepção 1d20 • Fortitude 1d20-50',
        'resistencias': 'Vulnerabilidades: Sangue',
      },
    }, registros: {
      'nuvem': {
        ..._ataque(3, 1, alvo: ''),
        'participantes': ['o1', 'o2', 'o3'],
        'danoTotal': 20,
        'golpe': {
          'acao': 'ritual',
          'nome': 'Nuvem de Sangue',
          'forma': 'Padrão',
          'tiposDano': ['sangue'],
          'dt': 20,
          'resistencia': 'Fortitude reduz à metade',
          'area': 'Área: nuvem de 6m de raio',
          'efeito': 'Quem falha fica fraco.',
          'condicoes': ['Fraco'],
        },
      },
    });

    expect(find.text('Escolha quem está na área.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Bêbado Local'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilterChip, 'Cão Raivoso'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Rolar Fortitude (2 alvos)'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Bêbado Local: −10 PV (metade)', findRichText: true), findsOneWidget);
    expect(find.textContaining('passou, metade', findRichText: true), findsOneWidget);
    expect(find.textContaining('Cão Raivoso: −40 PV (vulnerável: dobro) · Fraco', findRichText: true), findsOneWidget);
    expect(find.text('−50 PV em 2 alvos · Fraco em 1 alvo'), findsOneWidget);

    await tester.ensureVisible(find.text('Aplicar dano'));
    await tester.pump();
    await tester.tap(find.text('Aplicar dano'));
    await tester.pump(const Duration(milliseconds: 300));
    final t1 = (await camp.collection('threats').doc('t1').get()).data()!;
    final t2 = (await camp.collection('threats').doc('t2').get()).data()!;
    expect(asInt(t1['pv']), 40);
    expect(asStrList(t1['condicoes']), isEmpty);
    expect(asInt(t2['pv']), 10);
    expect(asStrList(t2['condicoes']), ['Fraco']);
  });

  testWidgets('a esquiva do agente atingido entra na Defesa', (tester) async {
    await _abrirDano(tester, ordem: [
      _ameaca('o1', 't1', 'Bêbado Local'),
      _agente('o2', 'a1', 'Rafa'),
      _agente('o3', 'a2', 'Bia'),
    ], ameacas: {
      't1': {'nome': 'Bêbado Local', 'pv': 10, 'pvMax': 10, 'defesa': 12},
    }, fichas: {
      'a2': {
        'pericias': {
          'Reflexos': {'grau': 5},
        },
      },
    }, registros: {
      'amigo': {
        ..._ataque(13, 1, alvo: 'o3'),
        'golpe': {'acao': 'ataque', 'nome': 'Faca', 'tiposDano': ['corte'], 'corpo': true},
      },
    });

    expect(find.textContaining('Ataque 13  acertou', findRichText: true), findsOneWidget);
    final esquiva = find.textContaining('Esquivou (Defesa');
    expect(esquiva, findsOneWidget);
    await tester.tap(esquiva);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('com esquiva)', findRichText: true), findsOneWidget);
    expect(find.text('Errou: sem dano'), findsOneWidget);
  });
}

Map<String, dynamic> _ameaca(String id, String ref, String nome) =>
    {'id': id, 'tipo': 'ameaca', 'ref': ref, 'nome': nome, 'valor': 10, 'desempate': 0};

Map<String, dynamic> _agente(String id, String ref, String nome) =>
    {'id': id, 'tipo': 'agente', 'ref': ref, 'nome': nome, 'valor': 8, 'desempate': 0};

Map<String, dynamic> _ataque(int total, int at, {required String alvo}) => {
      'titulo': 'Rafa: ataque com Faca',
      'detalhe': '1d20 [$total] → $total + 0',
      'total': total,
      'critico': false,
      'falhaCritica': false,
      'danoTotal': 6,
      'danoDetalhe': '1d6 [6]',
      'alvo': alvo,
      'fichaId': 'a1',
      'golpe': {'acao': 'ataque', 'nome': 'Faca', 'tiposDano': ['corte']},
      'uid': 'jogador',
      'personagem': 'Rafa',
      'at': at,
    };

/// A mesa com o mestre, o combate, as ameaças, os agentes e os registros
/// dados, aberta na parte Dano (na tela do computador).
Future<DocumentReference<Map<String, dynamic>>> _abrirDano(
  WidgetTester tester, {
  required List<Map<String, dynamic>> ordem,
  Map<String, Map<String, dynamic>> ameacas = const {},
  Map<String, Map<String, dynamic>> fichas = const {},
  Map<String, Map<String, dynamic>> registros = const {},
}) async {
  final db = FakeFirebaseFirestore();
  Repo.dbTeste = db;
  Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'mestre', displayName: 'Mestre'));
  for (final e in ordem.where((e) => e['tipo'] == 'agente')) {
    final ref = asStr(e['ref']);
    await db.collection('characters').doc(ref).set({
      ...novaFicha('jogador', 'Jo'),
      'nome': e['nome'],
      'campaignId': 'c1',
      'editors': ['jogador', 'mestre'],
      ...?fichas[ref],
    });
  }
  final camp = db.collection('campaigns').doc('c1');
  await camp.set({
    'nome': 'Mesa',
    'masterUid': 'mestre',
    'joinCode': 'ABC123',
    'memberUids': ['mestre', 'jogador'],
    'members': {'mestre': 'Mestre', 'jogador': 'Jo'},
    'regras': <String, dynamic>{},
    'combate': {'ativo': true, 'rodada': 1, 'turno': 0, 'ordem': ordem},
  });
  for (final a in ameacas.entries) {
    await camp.collection('threats').doc(a.key).set(a.value);
  }
  for (final r in registros.entries) {
    await camp.collection('rolls').doc(r.key).set(r.value);
  }

  tester.view.physicalSize = const Size(2560, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: temaCris(), home: const TelaCampanha(campanhaId: 'c1')));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('Combate').first);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('DANO').first);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return camp;
}
