import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/core/theme.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/screens/campaign/campaign_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => Catalogo.instance.carregar());

  testWidgets('a vez passa para os agentes mesmo sem rolar a iniciativa deles', (tester) async {
    final db = FakeFirebaseFirestore();
    Repo.dbTeste = db;
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'mestre', displayName: 'Mestre'));
    await db.collection('characters').doc('a1').set({
      ...novaFicha('jogador', 'Jo'),
      'nome': 'Novo agente',
      'campaignId': 'c1',
      'editors': ['jogador', 'mestre'],
    });
    // como no vídeo: só a ameaça na iniciativa
    final camp = db.collection('campaigns').doc('c1');
    await camp.set({
      'nome': 'Mesa',
      'masterUid': 'mestre',
      'joinCode': 'ABC123',
      'memberUids': ['mestre'],
      'members': {'mestre': 'Mestre'},
      'regras': <String, dynamic>{},
      'combate': {
        'ativo': true,
        'rodada': 1,
        'turno': 0,
        'ordem': [
          {'id': 'o1', 'tipo': 'ameaca', 'ref': 't1', 'nome': 'Bêbado Local', 'valor': 10, 'desempate': 0},
        ],
      },
    });
    await camp.collection('threats').doc('t1').set(
        {'nome': 'Bêbado Local', 'pv': 10, 'pvMax': 10, 'defesa': 12, 'ataqueNome': 'Soco', 'ataqueDano': '1d4'});

    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: temaCris(), home: const TelaCampanha(campanhaId: 'c1')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Combate').first);
    await tester.pump(const Duration(milliseconds: 500));

    Future<Map<String, dynamic>> combate() async => asMap((await camp.get()).data()!['combate']);
    final vezes = <String>[];
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Próximo turno'));
      await tester.pump(const Duration(milliseconds: 300));
      final cb = await combate();
      final ordem = asMapList(cb['ordem']);
      vezes.add(asStr(ordem[asInt(cb['turno'])]['tipo']));
    }
    final ordem = asMapList((await combate())['ordem']);
    expect(ordem.where((e) => e['tipo'] == 'agente').length, 1);
    expect(vezes, contains('agente'));
    expect(vezes, contains('ameaca'));
  });

  test('a reação vale uma vez por rodada de cada combate', () {
    final camp = Campanha('c1', {
      'combate': {
        'ativo': true,
        'rodada': 2,
        'ordem': [
          {'id': 'o7', 'tipo': 'agente', 'ref': 'a1', 'nome': 'Jo'},
        ],
      },
    });
    final f = Ficha('a1', {'reacao': 'esquiva', 'reacaoUsada': 'o7:1'});
    expect(marcaReacao(camp, f), 'o7:2');
    expect(reacaoUsada(camp, f), isFalse);
    expect(reacaoUsada(camp, Ficha('a1', {'reacao': 'esquiva', 'reacaoUsada': 'o7:2'})), isTrue);
    expect(marcaReacao(Campanha('c1', {}), f), '');
  });

  testWidgets('a esquiva escolhida na ficha vale no primeiro ataque da rodada', (tester) async {
    final db = FakeFirebaseFirestore();
    Repo.dbTeste = db;
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'mestre', displayName: 'Mestre'));
    await db.collection('characters').doc('a1').set({
      ...novaFicha('jogador', 'Jo'),
      'nome': 'Bia',
      'campaignId': 'c1',
      'editors': ['jogador', 'mestre'],
      'pericias': {
        'Reflexos': {'grau': 5},
      },
      'reacao': 'esquiva',
    });
    final camp = db.collection('campaigns').doc('c1');
    await camp.set({
      'nome': 'Mesa',
      'masterUid': 'mestre',
      'joinCode': 'ABC123',
      'memberUids': ['mestre'],
      'members': {'mestre': 'Mestre'},
      'regras': <String, dynamic>{},
      'combate': {
        'ativo': true,
        'rodada': 1,
        'turno': 0,
        'ordem': [
          {'id': 'o1', 'tipo': 'ameaca', 'ref': 't1', 'nome': 'Bêbado Local', 'valor': 10, 'desempate': 0},
          {'id': 'o2', 'tipo': 'agente', 'ref': 'a1', 'nome': 'Bia', 'valor': 8, 'desempate': 0},
        ],
      },
    });
    await camp.collection('threats').doc('t1').set({
      'nome': 'Bêbado Local',
      'pv': 10,
      'pvMax': 10,
      'defesa': 12,
      'ataqueNome': 'Soco',
      'ataqueAlcance': 'Corpo a corpo',
      'ataqueDano': '1d4',
    });

    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: temaCris(), home: const TelaCampanha(campanhaId: 'c1')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Combate').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // o mestre vê a reação no cartão do agente e mira nele
    expect(find.textContaining('esquiva 1'), findsOneWidget);
    await tester.tap(find.text('Bia').first);
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> atacar() async {
      // o botão da ação (o cartão do resultado, acima, também diz Soco)
      await tester.tap(find.text('Soco').last);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // fecha a animação dos dados
      final nav = Navigator.of(tester.element(find.text('AÇÃO').first));
      if (nav.canPop()) nav.pop();
      await tester.pump(const Duration(milliseconds: 400));
    }

    FilterChip esquiva() => tester.widget<FilterChip>(find.ancestor(
        of: find.textContaining('Esquivou'), matching: find.byType(FilterChip)));

    await atacar();
    expect(esquiva().selected, isTrue);
    expect((await db.collection('characters').doc('a1').get()).data()!['reacaoUsada'], 'o2:1');
    expect(find.textContaining('esquiva usada'), findsOneWidget);

    // o segundo ataque da rodada já não tem a esquiva
    await atacar();
    expect(esquiva().selected, isFalse);
    expect(find.text('Já usou a reação nesta rodada.'), findsOneWidget);
  });
}
