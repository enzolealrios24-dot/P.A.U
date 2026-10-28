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
}
