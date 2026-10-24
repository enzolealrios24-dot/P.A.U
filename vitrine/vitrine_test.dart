// Vitrine de telas: monta o app com dados de exemplo (Firestore e login de
// mentira) e salva prints em vitrine/prints/. Serve para conferir o visual
// sem celular nem Firebase:
//
//   flutter test --update-goldens vitrine/vitrine_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cris_ficha/core/dice.dart';
import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/core/theme.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/imagens.dart';
import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/screens/campaign/campaign_screen.dart';
import 'package:cris_ficha/screens/home.dart';
import 'package:cris_ficha/screens/login.dart';
import 'package:cris_ficha/screens/quadro/quadro_screen.dart';
import 'package:cris_ficha/data/quadro.dart';
import 'package:cris_ficha/screens/sheet/sheet_screen.dart';
import 'package:cris_ficha/widgets/common.dart';
import 'package:cris_ficha/widgets/efeitos.dart';
import 'package:cris_ficha/widgets/imagem.dart';
import 'package:cris_ficha/widgets/runa.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _uid = 'u1';

/// Tamanhos de tela: celular comum e janela de computador.
const _celular = Size(412, 892);
const _pc = Size(1280, 800);

void main() {
  setUpAll(() async {
    await _carregarFontes();
    await Catalogo.instance.carregar();
  });

  testWidgets('vitrine', (tester) async {
    await tester.runAsync(Texturas.carregar);
    // sombras de verdade (no teste elas viram blocos pretos)
    debugDisableShadows = false;
    final tema = Platform.environment['VITRINE_TEMA'] ?? 'amarelo';
    Cores.aplicar(temasCores.firstWhere((t) => t.id == tema));
    await _prepararDados();

    await _print(tester, 'runas', const Scaffold(body: SingleChildScrollView(padding: EdgeInsets.all(16), child: AmostraRunas())));
    await _print(tester, 'login', const TelaLogin());
    await _print(tester, 'inicio', const TelaInicio());
    await _print(tester, 'ficha_agente', const TelaFicha(fichaId: 'a1'));
    // ajuste de PV: toque no número do painel
    await tester.tap(find.textContaining('/31', findRichText: true).first);
    await _salvar(tester, 'ajuste_pv');
    await _print(tester, 'ficha_agente', const TelaFicha(fichaId: 'a1'));
    escolherEnquadramento(tester.element(find.byType(TabBarView)),
        foto: 'foto1', nome: 'Rafael Moraes');
    await _salvar(tester, 'enquadrar_foto');
    await _print(tester, 'ficha_agente', const TelaFicha(fichaId: 'a1'));
    mostrarRolagem(
        tester.element(find.byType(TabBarView)),
        Rolagem(
            titulo: 'Rafael Moraes: Ocultismo',
            detalhe: '2d20 (19, 7) + 10',
            total: 29,
            dados: [19, 7],
            natural: 19,
            bonus: 10,
            critico: true,
            danoTotal: 14,
            danoDetalhe: '2d6 (5, 6) + 3'));
    await tester.pump(const Duration(milliseconds: 380));
    await _imagensProntas(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('prints/rolagem_girando.png'));
    await _salvar(tester, 'rolagem');
    await _print(tester, 'ficha_agente', const TelaFicha(fichaId: 'a1'));
    await _rolar(tester, 600);
    await _salvar(tester, 'ficha_agente_2');
    await _rolar(tester, 900);
    await _salvar(tester, 'ficha_agente_3');
    for (final aba in ['PERÍCIAS', 'COMBATE', 'RITUAIS', 'INVENTÁRIO', 'PODERES & NOTAS']) {
      await _abrirAba(tester, aba);
      await _salvar(tester, 'ficha_${aba.toLowerCase().split(' ').first}');
    }
    await _print(tester, 'ficha_transformacao', const TelaFicha(fichaId: 't1'));
    await _print(tester, 'ficha_sem_foto', const TelaFicha(fichaId: 'a2'));
    await _print(tester, 'mestre', const TelaCampanha(campanhaId: 'c1'));
    await _print(tester, 'quadro', TelaQuadro(fonte: FonteQuadro.ficha('a1')));
    await _print(tester, 'ficha_pc', const TelaFicha(fichaId: 'a1'), tamanho: _pc);
    await _print(tester, 'inicio_pc', const TelaInicio(), tamanho: _pc);
    // a ficha em cada afinidade do dossiê
    for (final af in ['Conhecimento', 'Energia', 'Morte', 'Sangue']) {
      await Repo.db.collection('characters').doc('a1').update({'elementoVisual': af, 'seloCirculo': 3});
      await _print(tester, 'afinidade_${af.toLowerCase()}', const TelaFicha(fichaId: 'a1'));
      await _rolar(tester, 520);
      await _salvar(tester, 'afinidade_${af.toLowerCase()}_2');
      await _abrirAba(tester, 'PERÍCIAS');
      await _salvar(tester, 'pericias_${af.toLowerCase()}');
      await _abrirAba(tester, 'COMBATE');
      await _salvar(tester, 'combate_${af.toLowerCase()}');
      await _rolar(tester, 650);
      await _salvar(tester, 'combate_rd_${af.toLowerCase()}');
      if (af == 'Sangue') await _telasRd(tester);
      await _abrirAba(tester, 'INVENTÁRIO');
      await _salvar(tester, 'inventario_${af.toLowerCase()}');
      await _rolar(tester, 760);
      await _salvar(tester, 'inventario_${af.toLowerCase()}_2');
      await _abrirAba(tester, 'PODERES & NOTAS');
      await _salvar(tester, 'poderes_${af.toLowerCase()}');
      await _rolar(tester, 800);
      await _salvar(tester, 'poderes_${af.toLowerCase()}_2');
      await _abrirAba(tester, 'QUADRO');
      await _salvar(tester, 'mural_${af.toLowerCase()}');
      await _abrirAba(tester, 'RITUAIS');
      await _salvar(tester, 'rituais_${af.toLowerCase()}');
      await _rolar(tester, 900);
      await _salvar(tester, 'rituais_${af.toLowerCase()}_2');
    }
    mostrarRolagem(
        tester.element(find.byType(TabBarView)),
        Rolagem(
            titulo: 'Rafael Moraes: Dado do destino',
            detalhe: '1d20 [20] → 20 + 5',
            total: 25,
            dados: [20],
            natural: 20,
            bonus: 5,
            critico: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('prints/destino_girando.png'));
    await tester.pump(const Duration(milliseconds: 2400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('prints/destino.png'));
    debugDisableShadows = true;
  });
}

// ---------------- prints ----------------

Future<void> _print(WidgetTester tester, String nome, Widget tela,
    {Size tamanho = _celular}) async {
  tester.view.physicalSize = tamanho * 2;
  tester.view.devicePixelRatio = 2;
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    debugShowCheckedModeBanner: false,
    theme: temaCris(),
    home: tela,
  ));
  await _salvar(tester, nome);
}

Future<void> _salvar(WidgetTester tester, String nome) async {
  // espera as animações de entrada terminarem
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  await _imagensProntas(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('prints/$nome.png'));
}

/// Resistência a dano: ajuste de um tipo, a janela de sofrer dano e o
/// resultado (com o painel de RD já na tela).
Future<void> _telasRd(WidgetTester tester) async {
  await tester.ensureVisible(find.text('BLOQUEIO'));
  await tester.pump();
  await tester.tap(find.text('BLOQUEIO'));
  await _salvar(tester, 'bloqueio_detalhe');
  Navigator.of(tester.element(find.text('DE ONDE VEM'))).pop();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(find.text('Fogo'));
  await tester.pump();
  await tester.tap(find.text('Fogo'));
  await _salvar(tester, 'rd_editar');
  Navigator.of(tester.element(find.text('ANOTADA'))).pop();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(find.text('SOFRER DANO'));
  await tester.pump();
  await tester.tap(find.text('SOFRER DANO'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(find.byType(TextField).last, '12');
  await tester.tap(find.textContaining('Bloqueei'));
  await _salvar(tester, 'rd_sofrer');
  await tester.tap(find.text('APLICAR DANO'));
  await _salvar(tester, 'rd_aplicado');
}

Future<void> _rolar(WidgetTester tester, double quanto) async {
  final rolavel = find.byType(Scrollable).evaluate().where((e) {
    final s = e.widget as Scrollable;
    return s.axisDirection == AxisDirection.down;
  });
  if (rolavel.isEmpty) return;
  await tester.drag(find.byWidget(rolavel.first.widget), Offset(0, -quanto));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _abrirAba(WidgetTester tester, String aba) async {
  final f = find.text(aba);
  if (f.evaluate().isEmpty) return;
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pump(const Duration(milliseconds: 600));
}

/// Decodifica as imagens da tela (no teste isso não acontece sozinho).
Future<void> _imagensProntas(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      final w = e.widget as Image;
      await precacheImage(w.image, e);
    }
  });
  await tester.pump();
}

// ---------------- fontes ----------------

Future<void> _carregarFontes() async {
  Future<void> carregar(String familia, List<String> arquivos) async {
    final l = FontLoader(familia);
    for (final a in arquivos) {
      final f = File(a);
      if (!f.existsSync()) continue;
      l.addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await l.load();
  }

  var raiz = Platform.environment['FLUTTER_ROOT'];
  if (raiz == null) {
    // flutter_tester fica em <raiz>/bin/cache/artifacts/engine/<plataforma>/
    var d = File(Platform.resolvedExecutable).parent;
    while (d.parent.path != d.path && !File('${d.path}/bin/flutter').existsSync()) {
      d = d.parent;
    }
    raiz = d.path;
  }
  final mat = '$raiz/bin/cache/artifacts/material_fonts';
  await carregar('Roboto', [
    for (final p in ['Regular', 'Medium', 'Bold', 'Black', 'Light', 'Italic'])
      '$mat/Roboto-$p.ttf'
  ]);
  await carregar('MaterialIcons', ['$mat/MaterialIcons-Regular.otf']);
  await carregar('Cinzel', ['assets/fonts/Cinzel-Variavel.ttf']);
  await carregar('Barlow', [
    for (final p in ['Regular', 'Italic', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Barlow-$p.ttf'
  ]);
  await carregar('SpecialElite', ['assets/fonts/SpecialElite-Regular.ttf']);
  await carregar('ChakraPetch', ['assets/fonts/ChakraPetch-Bold.ttf']);
  await carregar('IMFellEnglishSC', ['assets/fonts/IMFellEnglishSC-Regular.ttf']);
  await carregar('MetalMania', ['assets/fonts/MetalMania-Regular.ttf']);
  await carregar('Caveat', ['assets/fonts/Caveat-Variavel.ttf']);
  await carregar('BarlowCondensed', [
    for (final p in ['Medium', 'SemiBold', 'Bold'])
      'assets/fonts/BarlowCondensed-$p.ttf'
  ]);
}

// ---------------- dados de exemplo ----------------

Future<void> _prepararDados() async {
  final db = FakeFirebaseFirestore();
  Repo.dbTeste = db;
  Repo.authTeste = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: _uid, displayName: 'Enzo', email: 'enzo@exemplo.com'));

  Imagens.guardarNaMemoria('foto1', _retrato(0xFF7A4A2A, 0xFF2A3A6A, 1));
  Imagens.guardarNaMemoria('foto2', _retrato(0xFF3A2A1A, 0xFF6A2030, 2));
  Imagens.guardarNaMemoria('foto3', _retrato(0xFF5A1010, 0xFF200810, 3));

  final chars = db.collection('characters');
  Map<String, dynamic> ficha(Map<String, dynamic> extra) =>
      {...novaFicha(_uid, 'Enzo'), ...extra};

  await chars.doc('a1').set(ficha({
    'nome': 'Rafael Moraes',
    'classe': 'Ocultista',
    'origem': 'Acadêmico',
    'trilha': 'Conduíte',
    'nex': 35,
    'foto': 'foto1',
    'campaignId': 'c1',
    'editors': [_uid],
    'atributos': {'agi': 2, 'for': 1, 'int': 3, 'pre': 3, 'vig': 1},
    'pericias': {
      'Ocultismo': {'grau': 10},
      'Investigação': {'grau': 5},
      'Vontade': {'grau': 5},
      'Ciências': {'grau': 5},
      'Fortitude': {'grau': 5},
      'Reflexos': {'grau': 5},
    },
    'pvAtual': 14,
    'pvTemp': 5,
    'pvTempMax': 5,
    'peAtual': 9,
    'sanAtual': 18,
    'condicoes': ['Abalado'],
    'rd': {'fogo': 5, 'mental': 3},
    'poderes': [
      {'id': 'p6', 'nome': 'Resistir a Elemento', 'tipo': 'Paranormal', 'ref': 'oprpg/p.resistir_elemento', 'elemento': 'Sangue', 'descricao': 'Resistência 10 contra Sangue.'},
      {'id': 'p1', 'nome': 'Escolhido pelo Outro Lado', 'tipo': 'Classe', 'descricao': 'Conjura rituais de 1º círculo e aprende novos conforme o NEX aumenta.'},
      {'id': 'p2', 'nome': 'Potencial Aprimorado', 'tipo': 'Trilha', 'descricao': 'Seus PE máximos aumentam em +1 por NEX.'},
      {'id': 'p3', 'nome': 'Sensitivo', 'tipo': 'Paranormal', 'elemento': 'Conhecimento', 'afinidade': true, 'descricao': 'Você sente emoções e intenções e recebe +5 em Diplomacia, Intimidação e Intuição.'},
      {'id': 'p4', 'nome': 'Sangue de Ferro', 'tipo': 'Paranormal', 'elemento': 'Sangue', 'descricao': 'Você recebe +2 PV por NEX e +5 em Fortitude.'},
      {'id': 'p5', 'nome': 'Treinamento em Perícia', 'tipo': 'Geral', 'descricao': 'Escolha duas perícias: você se torna treinado nelas.'},
    ],
    'inventario': [
      {'id': 'i1', 'nome': 'Pistola', 'tipo': 'arma', 'categoriaLivro': 'arma', 'categoria': 1, 'espacos': 1, 'qtd': 1, 'dano': '1d12', 'critico': '18/x2', 'pericia': 'Pontaria', 'equipado': true},
      {'id': 'i2', 'nome': 'Colete leve', 'tipo': 'protecao', 'categoriaLivro': 'protecao', 'categoria': 1, 'espacos': 2, 'defesa': 5, 'maldicoes': ['oprpg/mal.cinetica']},
      {'id': 'i3', 'nome': 'Componentes ritualísticos de Conhecimento', 'tipo': 'geral', 'categoriaLivro': 'paranormal', 'categoria': 0, 'espacos': 1, 'qtd': 2, 'equipado': false},
      {'id': 'i4', 'nome': 'Amuleto de Sangue', 'tipo': 'geral', 'categoriaLivro': 'amaldicoado', 'elemento': 'Sangue', 'categoria': 2, 'espacos': 1, 'descricao': 'Pulsa quando há sangue por perto.', 'equipado': false},
      {'id': 'i5', 'nome': 'Lanterna tática', 'tipo': 'geral', 'categoriaLivro': 'operacional', 'categoria': 0, 'espacos': 1, 'equipado': false},
      {'id': 'i6', 'nome': 'Braçadeira reforçada', 'tipo': 'geral', 'ref': 'sah/bracadeira_reforcada', 'categoriaLivro': 'operacional', 'categoria': 1, 'espacos': 1, 'equipado': true},
      {'id': 'i7', 'nome': 'Bastão policial', 'tipo': 'arma', 'ref': 'sah/bastao_policial', 'categoriaLivro': 'arma', 'categoria': 1, 'espacos': 1, 'dano': '1d6', 'pericia': 'Luta', 'equipado': false},
    ],
    'rituais': [
      {'id': 'r1', 'nome': 'Terceiro Olho', 'elemento': 'Conhecimento', 'circulo': 1, 'execucao': 'Padrão', 'alcance': 'Pessoal', 'duracao': 'Cena', 'descricao': 'Você vê manifestações paranormais.', 'custoDiscente': 2},
      {'id': 'r2', 'nome': 'Eletrocussão', 'elemento': 'Energia', 'circulo': 1, 'execucao': 'Padrão', 'alcance': 'Curto', 'alvo': '1 ser', 'descricao': 'Corrente voltaica eletrocuta o alvo.'},
    ],
    'transformacoes': {
      't1': {'pv': false, 'pe': true, 'san': true}
    },
    'formaAtiva': 't1',
    'aparencia': 'Casaco longo, olheiras fundas.',
    'quadro': {
      'quadros': {
        'raiz': {
          'nome': 'Quadro do agente',
          'itens': {
            'n1': {'tipo': 'titulo', 'x': 60.0, 'y': 40.0, 'w': 320.0, 'h': 70.0, 'texto': 'Caso: Sangue Velho'},
            'n2': {'tipo': 'nota', 'x': 60.0, 'y': 130.0, 'w': 220.0, 'h': 150.0, 'z': 1, 'texto': '# Pistas\n- marcas no porão\n- **sigilo** na parede\n[ ] falar com a zeladora'},
            'n3': {'tipo': 'tarefas', 'x': 300.0, 'y': 130.0, 'w': 220.0, 'h': 160.0, 'z': 2, 'titulo': 'Agora', 'tarefas': [
              {'t': 'Comprar sal', 'ok': true},
              {'t': 'Ritual de proteção', 'ok': false},
            ]},
            'n4': {'tipo': 'imagem', 'x': 60.0, 'y': 300.0, 'w': 200.0, 'h': 240.0, 'z': 3, 'imagem': 'foto3', 'texto': 'Suspeito'},
          },
          'ligacoes': {
            'l1': {'de': 'n2', 'para': 'n3', 'seta': true, 'texto': 'depois'},
          },
        },
      },
    },
  }));
  await chars.doc('t1').set(ficha({
    'nome': 'Rafael, Forma de Sangue',
    'classe': 'Combatente',
    'nex': 35,
    'foto': 'foto3',
    'campaignId': 'c1',
    'transformacaoDe': 'a1',
    'compartilha': {'pv': false, 'pe': true, 'san': true},
    'atributos': {'agi': 3, 'for': 4, 'int': 1, 'pre': 2, 'vig': 4},
    'pvAtual': 38,
    'peAtual': 9,
    'sanAtual': 18,
  }));
  await chars.doc('a2').set(ficha({
    'nome': 'Helena Duarte',
    'classe': 'Especialista',
    'origem': 'Investigadora',
    'nex': 20,
    'pvAtual': 16,
    'peAtual': 6,
    'sanAtual': 14,
  }));
  await chars.doc('a3').set(ficha({
    'nome': 'Kaio Viana',
    'classe': 'Combatente',
    'origem': 'Militar',
    'nex': 50,
    'foto': 'foto2',
    'pvAtual': 2,
    'peAtual': 1,
    'sanAtual': 5,
  }));
  await db.collection('campaigns').doc('c1').set({
    'nome': 'Operação Sangue Velho',
    'masterUid': _uid,
    'joinCode': 'K7Q2ZP',
    'memberUids': [_uid],
    'members': {_uid: 'Enzo'},
    'regras': {'determinacao': false, 'progressao': 'nex'},
    'combate': {'ativo': false, 'rodada': 1, 'turno': 0, 'ordem': []},
    'ledger': [],
    'missao': 'Descobrir quem marcou o porão da mansão Albuquerque.',
  });
}

/// Retrato inventado (fundo, ombros e rosto iluminados) para testar fotos.
Uint8List _retrato(int corRoupa, int corFundo, int semente) {
  const w = 600, h = 800;
  final im = img.Image(width: w, height: h);
  final r = Random(semente);
  final fundo = img.ColorRgb8((corFundo >> 16) & 0xFF, (corFundo >> 8) & 0xFF, corFundo & 0xFF);
  img.fill(im, color: fundo);
  // luz lateral
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      final luz = 0.55 + 0.6 * (1 - x / w) * (1 - y / h);
      im.setPixelRgb(x, y, (p.r * luz).clamp(0, 255).toInt(),
          (p.g * luz).clamp(0, 255).toInt(), (p.b * luz).clamp(0, 255).toInt());
    }
  }
  final roupa = img.ColorRgb8((corRoupa >> 16) & 0xFF, (corRoupa >> 8) & 0xFF, corRoupa & 0xFF);
  img.fillCircle(im, x: w ~/ 2, y: h + 120, radius: 330, color: roupa);
  img.fillRect(im, x1: w ~/ 2 - 55, y1: 420, x2: w ~/ 2 + 55, y2: 560,
      color: img.ColorRgb8(196, 150, 120));
  img.fillCircle(im, x: w ~/ 2, y: 330, radius: 135, color: img.ColorRgb8(214, 170, 138));
  img.fillCircle(im, x: w ~/ 2, y: 250, radius: 120, color: img.ColorRgb8(40 + r.nextInt(30), 28, 20));
  img.fillCircle(im, x: w ~/ 2 - 48, y: 340, radius: 12, color: img.ColorRgb8(30, 24, 20));
  img.fillCircle(im, x: w ~/ 2 + 48, y: 340, radius: 12, color: img.ColorRgb8(30, 24, 20));
  return img.encodePng(im);
}
