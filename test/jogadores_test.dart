import 'dart:math';

import 'package:cris_ficha/core/nomes.dart';
import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/core/theme.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/screens/campaign/campaign_screen.dart';
import 'package:cris_ficha/widgets/foto_jogador.dart';
import 'package:cris_ficha/widgets/imagem.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => Catalogo.instance.carregar());

  test('o gerador de nomes respeita o gênero, o nome do meio e os sobrenomes', () {
    final r = Random(7);
    for (var i = 0; i < 50; i++) {
      final f = gerarNome(r, genero: 'f').split(' ');
      expect(nomesFemininos, contains(f.first));
      expect(f, hasLength(2));
      expect(sobrenomes, contains(f.last));
      final m = gerarNome(r, genero: 'm', nomeDoMeio: true, doisSobrenomes: true).split(' ');
      expect(m, hasLength(4));
      expect(nomesMasculinos, containsAll([m[0], m[1]]));
      expect(m[0], isNot(m[1]));
      expect(m[2], isNot(m[3]));
    }
  });

  late FakeFirebaseFirestore db;

  Future<void> mesa({required String quem}) async {
    db = FakeFirebaseFirestore();
    Repo.dbTeste = db;
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: quem, displayName: quem == 'mestre' ? 'Mestre' : 'Lia'));
    await db.collection('campaigns').doc('c1').set({
      'nome': 'Mesa',
      'masterUid': 'mestre',
      'joinCode': 'ABC123',
      'memberUids': ['mestre', 'jogador'],
      'members': {'mestre': 'Mestre', 'jogador': 'Lia'},
      'regras': <String, dynamic>{},
    });
    await db.collection('characters').doc('a1').set({
      ...novaFicha('jogador', 'Lia'),
      'nome': 'Bianca Torres',
      'campaignId': 'c1',
      'editors': ['jogador', 'mestre'],
    });
  }

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // uma tela nova a cada vez (o jogador e depois o mestre)
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), theme: temaCris(), home: const TelaCampanha(campanhaId: 'c1')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<Ficha> ficha() async => Ficha('a1', (await db.collection('characters').doc('a1').get()).data()!);

  testWidgets('a nota do jogador chega ao mestre com o nome dele, e ele marca como lida', (tester) async {
    await mesa(quem: 'jogador');
    await abrir(tester);
    await tester.tap(find.text('NOTAS'));
    await esperar(tester);
    expect(find.textContaining('Ele vê seu nome (Lia) e o agente (Bianca Torres)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Quero investigar o diário.');
    await tester.tap(find.text('Enviar ao mestre'));
    await esperar(tester);
    final notas = (await ficha()).notasAoMestre;
    expect(notas, hasLength(1));
    final nota = asMap(notas.values.single);
    expect(nota['texto'], 'Quero investigar o diário.');
    expect(nota['autor'], 'Lia');
    expect(nota['lida'], isFalse);
    expect(find.text('Ainda não lida'), findsOneWidget);

    // o mestre vê na aba Jogadores, com o número de pendências
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'mestre', displayName: 'Mestre'));
    await abrir(tester);
    expect(find.text('1'), findsWidgets);
    await tester.tap(find.text('Jogadores'));
    await esperar(tester);
    expect(find.text('NOTAS DOS JOGADORES (1)'), findsOneWidget);
    expect(find.textContaining('Lia', findRichText: true), findsWidgets);
    expect(find.text('Quero investigar o diário.'), findsOneWidget);
    await tester.tap(find.text('Marcar como lida'));
    await esperar(tester);
    expect(asMap((await ficha()).notasAoMestre.values.single)['lida'], isTrue);
    expect(find.text('NOTAS DOS JOGADORES'), findsOneWidget);
  });

  testWidgets('o pedido de homebrew aceito entra na biblioteca da mesa', (tester) async {
    await mesa(quem: 'jogador');
    await abrir(tester);
    await tester.tap(find.text('PEDIDOS'));
    await esperar(tester);
    await tester.tap(find.text('Ritual'));
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Sussurro do Porão');
    await tester.enterText(find.widgetWithText(TextField, 'O que faz'), 'Ouve o que foi dito no lugar.');
    await tester.tap(find.text('Enviar pedido'));
    await esperar(tester);
    expect(find.text('Esperando o mestre'), findsOneWidget);

    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'mestre', displayName: 'Mestre'));
    await abrir(tester);
    await tester.tap(find.text('Jogadores'));
    await esperar(tester);
    await tester.tap(find.text('PEDIDOS DE HOMEBREW (1)'));
    await esperar(tester);
    expect(find.text('RITUAL · Sussurro do Porão'), findsOneWidget);
    await tester.tap(find.text('Aceitar e pôr na biblioteca'));
    await esperar(tester);
    final pedido = asMap((await ficha()).pedidosHomebrew.values.single);
    expect(pedido['estado'], 'aceito');
    final biblioteca = await db.collection('campaigns').doc('c1').collection('homebrew').get();
    expect(biblioteca.docs.single.data()['nome'], 'Sussurro do Porão');
    expect(biblioteca.docs.single.data()['tipoBiblio'], 'ritual');
    expect(find.text('Aceito · na biblioteca'), findsOneWidget);
  });

  testWidgets('a foto de perfil do jogador aparece onde ele aparece', (tester) async {
    await mesa(quem: 'jogador');
    await tester.pumpWidget(MaterialApp(
        theme: temaCris(), home: const Scaffold(body: FotoJogador(uid: 'jogador', nome: 'Lia Moreira', tamanho: 40))));
    await esperar(tester);
    expect(find.text('LM'), findsOneWidget);
    Repo.mudarMinhaFoto('img1');
    await esperar(tester);
    expect(find.byType(ImagemSalva), findsOneWidget);
    expect(find.text('LM'), findsNothing);
  });

  testWidgets('o mestre gera nomes e guarda os que quiser', (tester) async {
    await mesa(quem: 'mestre');
    await abrir(tester);
    await tester.tap(find.text('Nomes'));
    await esperar(tester);
    expect(find.text('GERADOR DE NOMES'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_border).first);
    await esperar(tester);
    final guardados = asStrList((await db.collection('campaigns').doc('c1').collection('gm').doc('nomes').get()).data()!['lista']);
    expect(guardados, hasLength(1));
    expect(find.text('GUARDADOS'), findsOneWidget);
  });
}
