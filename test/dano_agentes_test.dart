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

  testWidgets('o mestre vê se acertou e aplica o dano na ameaça', (tester) async {
    final db = FakeFirebaseFirestore();
    Repo.dbTeste = db;
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'mestre', displayName: 'Mestre'));
    await db.collection('characters').doc('a1').set({
      ...novaFicha('jogador', 'Jo'),
      'nome': 'Rafa',
      'campaignId': 'c1',
      'editors': ['jogador', 'mestre'],
    });
    final camp = db.collection('campaigns').doc('c1');
    await camp.set({
      'nome': 'Mesa',
      'masterUid': 'mestre',
      'joinCode': 'ABC123',
      'memberUids': ['mestre', 'jogador'],
      'members': {'mestre': 'Mestre', 'jogador': 'Jo'},
      'regras': <String, dynamic>{},
      'combate': {
        'ativo': true,
        'rodada': 1,
        'turno': 0,
        'ordem': [
          {'id': 'o1', 'tipo': 'ameaca', 'ref': 't1', 'nome': 'Bêbado Local', 'valor': 10, 'desempate': 0},
          {'id': 'o2', 'tipo': 'agente', 'ref': 'a1', 'nome': 'Rafa', 'valor': 8, 'desempate': 0},
        ],
      },
    });
    await camp.collection('threats').doc('t1').set({
      'nome': 'Bêbado Local',
      'pv': 10,
      'pvMax': 10,
      'defesa': 12,
      'resistencias': 'Resistências: Corte 2',
    });
    Map<String, dynamic> golpe(int total, int at) => {
          'titulo': 'Rafa: ataque com Faca contra Bêbado Local',
          'detalhe': '1d20 [$total] → $total + 0',
          'total': total,
          'critico': false,
          'falhaCritica': false,
          'danoTotal': 6,
          'danoDetalhe': '1d6 [6]',
          'alvo': 'o1',
          'fichaId': 'a1',
          'golpe': {'acao': 'ataque', 'nome': 'Faca', 'tiposDano': ['corte']},
          'uid': 'jogador',
          'personagem': 'Rafa',
          'at': at,
        };
    await camp.collection('rolls').doc('acerto').set(golpe(15, 2));
    await camp.collection('rolls').doc('erro').set(golpe(5, 1));
    // um combate antigo: o alvo não está mais na ordem
    await camp.collection('rolls').doc('antigo').set({...golpe(18, 0), 'alvo': 'velho'});

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
}
