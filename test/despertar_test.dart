import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/core/theme.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/screens/sheet/despertar.dart';
import 'package:cris_ficha/screens/sheet/sheet_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Ficha _ficha(Map<String, dynamic> campos) => Ficha('f1', {...novaFicha('eu', 'Enzo'), ...campos});

void main() {
  setUpAll(() => Catalogo.instance.carregar());

  setUp(() {
    Repo.dbTeste = FakeFirebaseFirestore();
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'eu'));
  });

  test('a cena só vem na passagem para NEX 50%, para o dono e sem afinidade', () {
    expect(chegouAoNex50(45, _ficha({'nex': 50})), isTrue);
    expect(chegouAoNex50(40, _ficha({'nex': 60})), isTrue);
    expect(chegouAoNex50(50, _ficha({'nex': 55})), isFalse);
    expect(chegouAoNex50(45, _ficha({'nex': 45})), isFalse);
    expect(chegouAoNex50(45, _ficha({'nex': 50, 'afinidade': 'Sangue'})), isFalse);
    expect(chegouAoNex50(45, _ficha({'nex': 50, 'ownerUid': 'outro'})), isFalse);
  });

  Future<void> mostrar(WidgetTester tester, Widget tela) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: temaCris(), home: tela));
  }

  Future<void> passar(WidgetTester tester, double segundos) async {
    for (var i = 0; i < segundos * 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  testWidgets('a cena termina nos símbolos, e tocar em um grava a afinidade', (tester) async {
    String? escolhido;
    var fechou = false;
    await mostrar(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('abrir'),
            onPressed: () async {
              await Navigator.of(context).push(rotaDespertar((e) => escolhido = e));
              fechou = true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    // durante o cometa ainda não há o que escolher
    await passar(tester, 2);
    expect(find.bySemanticsLabel('Escolher a afinidade Sangue'), findsNothing);
    await passar(tester, 3);
    expect(find.bySemanticsLabel('Escolher a afinidade Sangue'), findsOneWidget);
    expect(escolhido, isNull);

    await tester.tap(find.bySemanticsLabel('Escolher a afinidade Sangue'));
    await passar(tester, 0.5);
    // só grava com a tela toda coberta
    expect(escolhido, isNull);
    await passar(tester, 1.2);
    expect(escolhido, 'Sangue');
    expect(fechou, isTrue);
    expect(find.byType(TelaDespertar), findsNothing);
  });

  testWidgets('tocar durante o cometa pula para os símbolos', (tester) async {
    await mostrar(tester, TelaDespertar(aoEscolher: (_) {}));
    await passar(tester, 1.2);
    expect(find.text('Toque para pular'), findsOneWidget);
    await tester.tapAt(const Offset(200, 200));
    await passar(tester, 1);
    expect(find.bySemanticsLabel('Escolher a afinidade Morte'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Decidir depois" fecha sem gravar nada', (tester) async {
    String? escolhido;
    await mostrar(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('abrir'),
            onPressed: () => Navigator.of(context).push(rotaDespertar((e) => escolhido = e)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await passar(tester, 5);
    await tester.tap(find.text('Decidir depois'));
    await passar(tester, 0.3);
    expect(find.byType(TelaDespertar), findsNothing);
    expect(escolhido, isNull);
  });

  testWidgets('com "remover animações" no aparelho, vai direto aos símbolos', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: temaCris(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1600, 900), disableAnimations: true),
        child: TelaDespertar(aoEscolher: (_) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('Escolher a afinidade Energia'), findsOneWidget);
    expect(find.text('Toque para pular'), findsNothing);
  });

  testWidgets('subir o NEX da ficha aberta para 50 abre a cena', (tester) async {
    final id = Repo.criarFicha();
    await mostrar(tester, TelaFicha(fichaId: id));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TelaDespertar), findsNothing);

    await Repo.chars.doc(id).update({'nex': 50});
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(TelaDespertar), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
