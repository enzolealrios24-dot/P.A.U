import 'package:cris_ficha/core/theme.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/screens/campaign/campaign_screen.dart';
import 'package:cris_ficha/screens/sheet/sheet_screen.dart';
import 'package:cris_ficha/widgets/common.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => Catalogo.instance.carregar());

  test('o tempo aparece em minutos e, passando de uma hora, em horas', () {
    expect(duracaoTexto(const Duration(seconds: 65)), '01:05');
    expect(duracaoTexto(const Duration(hours: 2, minutes: 3, seconds: 4)), '2:03:04');
    expect(duracaoTexto(const Duration(seconds: -3)), '00:00');
  });

  Future<FakeFirebaseFirestore> abrirMesa(WidgetTester tester, String quem) async {
    final db = FakeFirebaseFirestore();
    Repo.dbTeste = db;
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: quem, displayName: quem));
    await db.collection('campaigns').doc('c1').set({
      'nome': 'Mesa',
      'masterUid': 'mestre',
      'joinCode': 'ABC123',
      'memberUids': ['mestre', 'jogador'],
      'members': {'mestre': 'Mestre', 'jogador': 'Jo'},
      'regras': <String, dynamic>{},
    });
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: temaCris(), home: const TelaCampanha(campanhaId: 'c1')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return db;
  }

  Future<Map<String, dynamic>> sessao(FakeFirebaseFirestore db) async =>
      asMap((await db.collection('campaigns').doc('c1').get()).data()!['sessao']);

  testWidgets('só o mestre inicia e encerra a sessão, e ela conta o tempo', (tester) async {
    final db = await abrirMesa(tester, 'mestre');
    expect(find.text('Sessão 1'), findsOneWidget);
    await tester.tap(find.text('Iniciar sessão'));
    await tester.pump(const Duration(milliseconds: 300));
    final s = await sessao(db);
    expect(s['ativa'], isTrue);
    expect(s['numero'], 1);
    expect(find.text('Sessão 1'), findsOneWidget);
    expect(find.text('AO VIVO'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);

    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar'));
    await tester.pump(const Duration(milliseconds: 300));
    final fim = await sessao(db);
    expect(fim['ativa'], isFalse);
    expect(fim['fim'], isNotNull);
    expect(find.text('Sessão 2'), findsOneWidget);
    expect(find.textContaining('A sessão 1 durou'), findsOneWidget);

    // o registro guarda o tempo de cada sessão
    final registro = asMapList((await db.collection('campaigns').doc('c1').get()).data()!['sessoes']);
    expect(registro, hasLength(1));
    expect(registro.single['numero'], 1);
    expect(registro.single['fim'], fim['fim']);
  });

  testWidgets('na aba Sessões o mestre dá nome e notas que só ele vê', (tester) async {
    final db = await abrirMesa(tester, 'mestre');
    final inicio = DateTime(2026, 10, 30, 19, 30).millisecondsSinceEpoch;
    await db.collection('campaigns').doc('c1').update({
      'sessao': {'ativa': false, 'numero': 4, 'inicio': inicio, 'fim': inicio + 14188000},
      'sessoes': [
        {'numero': 3, 'inicio': inicio - 86400000, 'fim': inicio - 86400000 + 3600000},
        {'numero': 4, 'inicio': inicio, 'fim': inicio + 14188000},
      ],
    });
    await tester.tap(find.text('Sessões').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('3:56:28'), findsOneWidget);
    expect(find.text('1:00:00'), findsOneWidget);
    expect(find.textContaining('30/10/2026 às 19:30'), findsOneWidget);

    final campos = find.byType(TextField);
    // a mais nova primeiro: o nome e as notas da sessão 4
    await tester.enterText(campos.at(0), 'O porão');
    await tester.enterText(campos.at(1), 'Fulano morreu');
    await tester.pump(const Duration(seconds: 1));
    final notas = (await db.collection('campaigns').doc('c1').collection('gm').doc('sessoes').get()).data()!;
    expect(asMap(notas['4']), {'nome': 'O porão', 'nota': 'Fulano morreu'});
    // o nome dado vira o título do registro
    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'O porão'), findsOneWidget);
  });

  testWidgets('cada agente anota as sessões na própria ficha', (tester) async {
    final db = FakeFirebaseFirestore();
    Repo.dbTeste = db;
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'jogador', displayName: 'Jo'));
    await db.collection('campaigns').doc('c1').set({
      'nome': 'Mesa',
      'masterUid': 'mestre',
      'memberUids': ['mestre', 'jogador'],
      'members': {'mestre': 'Mestre', 'jogador': 'Jo'},
      'regras': <String, dynamic>{},
      'sessao': {'ativa': true, 'numero': 2, 'inicio': DateTime.now().millisecondsSinceEpoch - 65000},
      'sessoes': [
        {'numero': 1, 'inicio': 1000, 'fim': 3601000},
        {'numero': 2, 'inicio': DateTime.now().millisecondsSinceEpoch - 65000},
      ],
    });
    await db.collection('characters').doc('a1').set({
      ...novaFicha('jogador', 'Jo'),
      'nome': 'Bia',
      'campaignId': 'c1',
      'editors': ['jogador', 'mestre'],
    });
    tester.view.physicalSize = const Size(2000, 1784);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: temaCris(), home: const TelaFicha(fichaId: 'a1')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    DefaultTabController.of(tester.element(find.byType(TabBarView))).index = 7;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('SESSÕES'), findsWidgets);
    expect(find.textContaining('em andamento'), findsOneWidget);
    // a sessão em andamento começou há pouco mais de um minuto
    expect(find.textContaining(RegExp(r'^01:0\d$')), findsOneWidget);
    expect(find.text('1:00:00'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Achamos o diário');
    await tester.pump(const Duration(seconds: 1));
    final f = Ficha('a1', (await db.collection('characters').doc('a1').get()).data()!);
    expect(asMap(f.notasSessoes('c1')['2'])['nota'], 'Achamos o diário');
  });

  testWidgets('o jogador vê a sessão, mas não tem o botão', (tester) async {
    final db = await abrirMesa(tester, 'jogador');
    expect(find.text('Iniciar sessão'), findsNothing);
    expect(find.textContaining('A sessão ainda não começou'), findsOneWidget);

    await db.collection('campaigns').doc('c1').update({
      'sessao': {'ativa': true, 'numero': 4, 'inicio': DateTime.now().millisecondsSinceEpoch - 65000},
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sessão 4 em andamento'), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Iniciar sessão'), findsNothing);
  });
}
