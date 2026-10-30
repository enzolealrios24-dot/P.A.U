import 'package:cris_ficha/core/theme.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/screens/campaign/campaign_screen.dart';
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
    expect(find.text('SESSÃO 1'), findsOneWidget);
    await tester.tap(find.text('Iniciar sessão'));
    await tester.pump(const Duration(milliseconds: 300));
    final s = await sessao(db);
    expect(s['ativa'], isTrue);
    expect(s['numero'], 1);
    expect(find.text('SESSÃO 1 · EM ANDAMENTO'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);

    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar'));
    await tester.pump(const Duration(milliseconds: 300));
    final fim = await sessao(db);
    expect(fim['ativa'], isFalse);
    expect(fim['fim'], isNotNull);
    expect(find.text('SESSÃO 2'), findsOneWidget);
    expect(find.textContaining('A sessão 1 durou'), findsOneWidget);
  });

  testWidgets('o jogador vê a sessão, mas não tem o botão', (tester) async {
    final db = await abrirMesa(tester, 'jogador');
    expect(find.text('Iniciar sessão'), findsNothing);
    expect(find.textContaining('A sessão ainda não começou'), findsOneWidget);

    await db.collection('campaigns').doc('c1').update({
      'sessao': {'ativa': true, 'numero': 4, 'inicio': DateTime.now().millisecondsSinceEpoch - 65000},
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('SESSÃO 4 EM ANDAMENTO'), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Iniciar sessão'), findsNothing);
  });
}
