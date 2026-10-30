// Vitrine de telas: monta o app com dados de exemplo (Firestore e login de
// mentira) e salva prints em vitrine/prints/. Serve para conferir o visual
// sem celular nem Firebase:
//
//   flutter test --update-goldens vitrine/vitrine_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cris_ficha/core/dice.dart';
import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/core/theme.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/imagens.dart';
import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/data/seguranca.dart';
import 'package:cris_ficha/screens/campaign/campaign_screen.dart';
import 'package:cris_ficha/screens/home.dart';
import 'package:cris_ficha/screens/master/ameacas.dart';
import 'package:cris_ficha/screens/master/regras.dart';
import 'package:cris_ficha/screens/login.dart';
import 'package:cris_ficha/screens/pastas.dart';
import 'package:cris_ficha/screens/quadro/quadro_screen.dart';
import 'package:cris_ficha/screens/seguranca.dart';
import 'package:cris_ficha/data/quadro.dart';
import 'package:cris_ficha/screens/sheet/sheet_screen.dart';
import 'package:cris_ficha/screens/sheet/tab_combate.dart';
import 'package:cris_ficha/screens/sheet/tab_rituais.dart';
import 'package:cris_ficha/widgets/common.dart';
import 'package:cris_ficha/widgets/efeitos.dart';
import 'package:cris_ficha/widgets/imagem.dart';
import 'package:cris_ficha/widgets/runa.dart';
import 'package:cris_ficha/widgets/tema_picker.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

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
    final tema = Platform.environment['VITRINE_TEMA'] ?? 'medo';
    Cores.aplicar(temasCores.firstWhere((t) => t.id == tema));
    await _prepararDados();

    await _print(tester, 'runas', const Scaffold(body: SingleChildScrollView(padding: EdgeInsets.all(16), child: AmostraRunas())));
    await _print(tester, 'login', const TelaLogin());
    escolherTema(tester.element(find.byType(TelaLogin)));
    await _salvar(tester, 'tema_cores');
    Navigator.of(tester.element(find.text('Tema de cores'))).pop();
    await tester.pump(const Duration(milliseconds: 300));
    await _print(tester, 'inicio', const TelaInicio());
    await tester.tap(find.byTooltip('Mover para uma pasta').first);
    await _salvar(tester, 'pasta_mover');
    Navigator.of(tester.element(find.text('Nova pasta…'))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Nova pasta'));
    await _salvar(tester, 'pasta_nova');
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 400));
    await _print(tester, 'pasta', const TelaPasta(pastaId: 'pa1'));
    await _print(tester, 'mesas', const TelaInicio());
    await tester.tap(find.text('Mesas'));
    await _salvar(tester, 'mesas');
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
    await tester.tap(find.text('Mesas'));
    await _salvar(tester, 'mesas_pc');
    // a ficha em cada afinidade do dossiê
    for (final af in ['Conhecimento', 'Energia', 'Morte', 'Sangue']) {
      await Repo.db.collection('characters').doc('a1').update({'elementoVisual': af, 'seloCirculo': 3});
      await _print(tester, 'afinidade_${af.toLowerCase()}', const TelaFicha(fichaId: 'a1'));
      await _rolar(tester, 520);
      await _salvar(tester, 'afinidade_${af.toLowerCase()}_2');
      await _abrirAba(tester, 'PERÍCIAS');
      await _salvar(tester, 'pericias_${af.toLowerCase()}');
      if (af == 'Conhecimento') {
        // a Profissão com a profissão escrita ao lado dos dados
        await tester.ensureVisible(find.text('professora de história'));
        await tester.pump(const Duration(milliseconds: 300));
        await _salvar(tester, 'pericias_profissao');
      }
      await _abrirAba(tester, 'COMBATE');
      await _salvar(tester, 'combate_${af.toLowerCase()}');
      if (af == 'Conhecimento') {
        // a reação de defesa que o agente escolhe
        await tester.ensureVisible(find.text('SUA REAÇÃO'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(find.byType(TabCombate), const Offset(0, 160));
        await _salvar(tester, 'reacao_escolha');
      }
      await _rolar(tester, 650);
      await _salvar(tester, 'combate_rd_${af.toLowerCase()}');
      if (af == 'Conhecimento') {
        await _rolar(tester, 700);
        await _salvar(tester, 'combate_rituais');
      }
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
      if (af == 'Conhecimento') {
        // a fileira de chips rola para o lado: acha mesmo fora da tela
        Finder chip(String t) => find.ancestor(
            of: find.text(t, skipOffstage: false), matching: find.byType(ChoiceChip, skipOffstage: false));
        final lista = find.descendant(of: find.byType(TabRituais), matching: find.byType(Scrollable)).first;
        await tester.dragUntilVisible(chip('Sobrevivendo ao Horror'), lista, const Offset(0, 300));
        await tester.ensureVisible(chip('Sobrevivendo ao Horror'));
        await tester.pump();
        await tester.tap(chip('Sobrevivendo ao Horror'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(lista, const Offset(0, -250));
        await _salvar(tester, 'rituais_livros');
        await tester.dragUntilVisible(chip('Todos os livros'), lista, const Offset(0, 300));
        await tester.ensureVisible(chip('Todos os livros'));
        await tester.pump();
        await tester.tap(chip('Todos os livros'));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    // carta de habilidade de origem aberta (custo e o que faz na ficha)
    await _print(tester, 'poderes_ficha', const TelaFicha(fichaId: 'a1'));
    DefaultTabController.of(tester.element(find.byType(TabBarView))).index = 5;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _rolar(tester, 700);
    await _salvar(tester, 'poderes_cartas');
    await tester.ensureVisible(find.text('Saber é Poder', skipOffstage: false).first);
    await tester.pump();
    await tester.tap(find.text('Saber é Poder').first);
    await _salvar(tester, 'poder_aberto');
    Navigator.of(tester.element(find.textContaining('Usar ('))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    // seletor do livro com as trilhas da classe e as origens
    await _rolar(tester, -3000);
    await tester.ensureVisible(find.text('Do livro'));
    await tester.pump();
    await tester.tap(find.text('Do livro'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Trilhas'));
    await _salvar(tester, 'seletor_trilhas');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Origens'));
    await _salvar(tester, 'seletor_origens');
    await tester.tap(find.text('Fechar'));
    await tester.pump(const Duration(milliseconds: 400));
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
    // seletor dos rituais rápidos numa ficha sem rituais: os dos livros
    await _print(tester, 'combatente_sem_rituais', const TelaFicha(fichaId: 'a3'));
    DefaultTabController.of(tester.element(find.byType(TabBarView))).index = 2;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 6 && find.text('Escolher').evaluate().isEmpty; i++) {
      await _rolar(tester, 400);
    }
    await tester.ensureVisible(find.text('Escolher'));
    await tester.pump();
    await tester.tap(find.text('Escolher'));
    await _salvar(tester, 'seletor_rituais');
    await tester.enterText(find.widgetWithText(TextField, 'Buscar ritual…'), 'esfolar');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.tap(find.text('Salvar'));
    await tester.pump(const Duration(milliseconds: 400));
    await _salvar(tester, 'rituais_rapidos_livro');
    await _telasCombateMestre(tester);
    await _telasSeguranca(tester);
    debugDisableShadows = true;
  });
}

/// Segurança da conta: o medidor de senha ao criar a conta, a tela com os
/// aparelhos (um já desconectado) e as janelas de trocar a senha e de
/// desconectar os outros.
Future<void> _telasSeguranca(WidgetTester tester) async {
  // fecha a ficha aberta antes: ela devolve as cores do tema ao sair
  await tester.pumpWidget(const SizedBox());
  // a vitrine fica fora de test/, mas é um teste
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'pau.aparelho': 'ap1'});
  final agora = DateTime.now();
  int seg(Duration atras) => agora.subtract(atras).millisecondsSinceEpoch ~/ 1000;
  final eu = Repo.db.collection('users').doc(_uid);
  await eu.set({'revogado': seg(const Duration(days: 5))}, SetOptions(merge: true));
  final aparelhos = eu.collection('aparelhos');
  await aparelhos.doc('ap1').set({
    'nome': 'Computador DESKTOP-ENZO',
    'plataforma': 'windows',
    'desde': seg(const Duration(hours: 2)),
    'ultimo': Timestamp.fromDate(agora.subtract(const Duration(minutes: 1))),
  });
  await aparelhos.doc('ap2').set({
    'nome': 'Galaxy A54 de Enzo (Samsung SM-A546E)',
    'plataforma': 'android',
    'desde': seg(const Duration(hours: 27)),
    'ultimo': Timestamp.fromDate(agora.subtract(const Duration(hours: 3))),
  });
  await aparelhos.doc('ap3').set({
    'nome': 'Computador SALA-RPG',
    'plataforma': 'windows',
    'desde': seg(const Duration(days: 9)),
    'ultimo': Timestamp.fromDate(agora.subtract(const Duration(days: 8))),
  });

  await _print(tester, 'login_criar', const TelaLogin());
  await tester.tap(find.text('Criar conta'));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(find.widgetWithText(TextField, 'Seu nome / apelido'), 'Enzo');
  await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'enzo@exemplo.com');
  await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'Flamengo2024');
  await _salvar(tester, 'login_criar');
  await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'lanterna corvo');
  await _salvar(tester, 'login_criar_boa');

  Seguranca.avisoSenha.value = 'Essa senha já apareceu em vazamentos de outros sites (3 vezes). '
      'Quem tenta invadir contas testa essas primeiro: escolha outra.';
  await _print(tester, 'seguranca', const TelaSeguranca());
  await _rolar(tester, 600);
  await _salvar(tester, 'seguranca_2');
  Seguranca.avisoSenha.value = null;
  await _print(tester, 'seguranca_pc', const TelaSeguranca(), tamanho: _pc);
  await tester.tap(find.text('Trocar a senha'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(find.widgetWithText(TextField, 'Senha atual'), 'Flamengo2024');
  await tester.enterText(find.widgetWithText(TextField, 'Senha nova'), 'velho casarao');
  await _salvar(tester, 'seguranca_trocar');
  await tester.tap(find.text('Cancelar'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Desconectar os outros'));
  await _salvar(tester, 'seguranca_desconectar');
  await tester.tap(find.text('Cancelar'));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Combate do mestre: o espaço do alvo (agentes em arco e a ameaça da vez),
/// as ações da ameaça em botões, o resumo ao passar o mouse e o resultado.
Future<void> _telasCombateMestre(WidgetTester tester) async {
  final db = Repo.db;
  final camp = db.collection('campaigns').doc('c1');
  for (final ref in ['as2/felino_infernal', 'sah/medusa']) {
    await camp.collection('threats').doc(ref.split('/').last).set(ameacaDoLivro(Catalogo.instance.porRef('ameacas:$ref')!));
  }
  final chars = db.collection('characters');
  final agora = DateTime.now().millisecondsSinceEpoch;
  await chars.doc('a4').set({
    ...novaFicha('u2', 'Lia'),
    'recadosMestre': {
      'n1': {
        'texto': 'Minha agente quer voltar à mansão sozinha hoje à noite, sem os outros saberem. Dá para fazer isso fora da sessão?',
        'autor': 'Lia',
        'uid': 'u2',
        'at': agora - 1200000,
        'lida': false,
      },
    },
    'pedidosHomebrew': {
      'p1': {
        'tipo': 'item',
        'nome': 'Faca de prata do avô',
        'descricao': 'Arma simples, 1d4 de corte. Esquenta perto de criaturas de Morte.',
        'autor': 'Lia',
        'uid': 'u2',
        'at': agora - 3600000,
        'estado': 'pendente',
      },
    },
    'nome': 'Bianca Torres',
    'classe': 'Especialista',
    'nex': 35,
    'foto': 'foto2',
    'campaignId': 'c1',
    'editors': ['u2', _uid],
    'atributos': {'agi': 3, 'for': 1, 'int': 2, 'pre': 1, 'vig': 2},
    'pericias': {'Reflexos': {'grau': 10}, 'Fortitude': {'grau': 5}},
    'reacao': 'esquiva',
    'pvAtual': 22,
  });
  await chars.doc('a5').set({
    ...novaFicha('u3', 'Davi'),
    'nome': 'Joaquim Vidal',
    'classe': 'Combatente',
    'nex': 35,
    'campaignId': 'c1',
    'editors': ['u3', _uid],
    'condicoes': ['Abalado'],
    'pvAtual': 31,
    'recadosMestre': {
      'n2': {
        'texto': 'Não vou poder na próxima sessão. O Joaquim pode ficar de guarda no carro?',
        'autor': 'Davi',
        'uid': 'u3',
        'at': agora - 2 * 86400000,
        'lida': true,
      },
    },
    'pedidosHomebrew': {
      'p2': {
        'tipo': 'poder',
        'nome': 'Guarda-costas',
        'descricao': 'Uma vez por cena, recebe no lugar de um aliado adjacente o ataque que o acertaria.',
        'autor': 'Davi',
        'uid': 'u3',
        'at': agora - 3 * 86400000,
        'estado': 'aceito',
        'naBiblioteca': true,
        'resposta': 'Aceito, está na biblioteca. Só vale uma vez por cena.',
      },
    },
  });
  await camp.update({
    'combate': {
      'ativo': true,
      'rodada': 2,
      // o combate começou há 4 minutos
      'inicio': DateTime.now().millisecondsSinceEpoch - 245000,
      'turno': 1,
      'ordem': [
        {'id': 'o1', 'tipo': 'agente', 'ref': 'a1', 'nome': 'Rafael Moraes', 'valor': 24, 'desempate': 2},
        {'id': 'o2', 'tipo': 'ameaca', 'ref': 'felino_infernal', 'nome': 'Felino-Infernal', 'valor': 21, 'desempate': 0, 'oculto': false},
        {'id': 'o3', 'tipo': 'agente', 'ref': 'a4', 'nome': 'Bianca Torres', 'valor': 18, 'desempate': 3},
        {'id': 'o4', 'tipo': 'ameaca', 'ref': 'medusa', 'nome': 'Medusa', 'valor': 15, 'desempate': 0, 'oculto': false},
        {'id': 'o5', 'tipo': 'agente', 'ref': 'a5', 'nome': 'Joaquim Vidal', 'valor': 9, 'desempate': 1},
      ],
    },
  });

  // golpes dos agentes, para a parte Dano
  Map<String, dynamic> golpe(int at, String ficha, String nome, String alvo, Map<String, dynamic> g,
          {required int total, required String detalhe, required int dano, required String danoDetalhe}) =>
      {
        'titulo': '$nome: ${g['nome']}',
        'detalhe': detalhe,
        'total': total,
        'critico': false,
        'falhaCritica': false,
        'danoTotal': dano,
        'danoDetalhe': danoDetalhe,
        'alvo': alvo,
        'fichaId': ficha,
        'golpe': g,
        'uid': 'u2',
        'personagem': nome,
        'at': at,
      };
  final rolls = camp.collection('rolls');
  await rolls.doc('g1').set(golpe(1, 'a1', 'Rafael Moraes', 'o2', {'acao': 'ataque', 'nome': 'Fuzil de caça', 'tiposDano': ['balistico']},
      total: 31, detalhe: '2d20 [12, 19] → 19 + 12', dano: 18, danoDetalhe: '2d10 [9, 6] = 15 + 3'));
  await rolls.doc('g2').set(golpe(2, 'a4', 'Bianca Torres', 'o4',
      {'acao': 'ritual', 'nome': 'Descarnar', 'forma': 'Padrão', 'tiposDano': ['sangue'], 'dt': 18, 'resistencia': 'Fortitude parcial'},
      total: 3, detalhe: 'Padrão', dano: 27, danoDetalhe: '6d8 [5, 3, 8, 2, 6, 3] = 27'));
  // ritual em área, sem alvo marcado: o mestre escolhe quem está nela
  await rolls.doc('g4').set({
    ...golpe(4, 'a4', 'Bianca Torres', '', {
      'acao': 'ritual',
      'nome': 'Miasma Entrópico',
      'forma': 'Padrão',
      'tiposDano': ['quimico'],
      'dt': 18,
      'resistencia': 'Fortitude parcial',
      'area': 'Área: nuvem de 6m de raio',
      'efeito': '4d8 de dano químico e enjoado 1 rodada (passar: metade, sem enjoo).',
      'condicoes': ['Enjoado'],
    }, total: 3, detalhe: 'Padrão', dano: 22, danoDetalhe: '4d8 [7, 3, 8, 4] = 22'),
    'participantes': ['o1', 'o2', 'o3', 'o4', 'o5'],
  });
  await rolls.doc('g3').set(golpe(3, 'a5', 'Joaquim Vidal', 'o2', {'acao': 'ataque', 'nome': 'Machado', 'tiposDano': ['corte']},
      total: 19, detalhe: '1d20 [15] → 15 + 4', dano: 9, danoDetalhe: '1d8 [8] = 8 + 1'));

  // computador: Combate e Ação lado a lado
  await _print(tester, 'mestre_pc', const TelaCampanha(campanhaId: 'c1'), tamanho: _pc);
  await tester.tap(find.text('Combate').first);
  await _salvar(tester, 'mestre_combate_pc');
  await tester.tap(find.text('Bianca Torres').first);
  await tester.pump(const Duration(milliseconds: 300));
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(find.text('Chicotada Perfurante')));
  await tester.pump(const Duration(milliseconds: 600));
  await _salvar(tester, 'mestre_dica_pc');
  await mouse.moveTo(Offset.zero);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Chicotada Perfurante'));
  await _salvar(tester, 'mestre_habilidade_pc');
  await tester.tap(find.text('Mordidas'));
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  Navigator.of(tester.element(find.text('AÇÃO').first)).pop();
  await _salvar(tester, 'mestre_ataque_pc');
  await mouse.removePointer();
  await tester.tap(find.text('DANO').first);
  await _salvar(tester, 'mestre_dano_pc');
  await tester.tap(find.text('Rolar Fortitude de Medusa'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Aplicar dano').first);
  await _salvar(tester, 'mestre_dano_aplicado_pc');
  for (final nome in ['Felino-Infernal', 'Medusa']) {
    await tester.ensureVisible(find.widgetWithText(FilterChip, nome));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, nome));
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.tap(find.text('Rolar Fortitude (2 alvos)'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(find.text('Miasma Entrópico'));
  await _salvar(tester, 'mestre_dano_area_pc');
  // a condição do ritual: o mestre escolhe se aplica
  await tester.ensureVisible(find.widgetWithText(FilterChip, 'Enjoado'));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilterChip, 'Enjoado'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(find.text('Miasma Entrópico'));
  await _salvar(tester, 'mestre_dano_condicao_pc');
  await tester.tap(find.text('Ameaças').first);
  await _salvar(tester, 'mestre_ameacas_pc');

  // a consulta do livro: as regras de combate
  await tester.tap(find.text('Regras').first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.scrollUntilVisible(find.text('Regras de combate'), 300,
      scrollable: find.descendant(of: find.byType(AbaRegras), matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(find.text('Regras de combate'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Regras de combate'));
  await tester.pump(const Duration(milliseconds: 400));
  // o tópico desce um pouco, para sair de baixo do cabeçalho
  final listaRegras = find.descendant(of: find.byType(AbaRegras), matching: find.byType(Scrollable)).first;
  await tester.ensureVisible(find.text('Defesa, esquiva e bloqueio'));
  await tester.drag(listaRegras, const Offset(0, 120));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Defesa, esquiva e bloqueio'));
  await tester.pump(const Duration(milliseconds: 400));
  await _salvar(tester, 'consulta_combate_pc');

  // tela larga: as três partes lado a lado
  await _print(tester, 'mestre_largo_pc', const TelaCampanha(campanhaId: 'c1'), tamanho: const Size(1680, 900));
  await tester.tap(find.text('Combate').first);
  await _salvar(tester, 'mestre_largo_pc');

  // celular: Combate e Ação em abas
  await _print(tester, 'mestre_painel', const TelaCampanha(campanhaId: 'c1'));
  await tester.tap(find.byIcon(Icons.flash_on_outlined));
  await _salvar(tester, 'mestre_combate');
  await tester.tap(find.text('AÇÃO'));
  await _salvar(tester, 'mestre_acao');
  await tester.tap(find.text('DANO').first);
  await _salvar(tester, 'mestre_dano');

  // as sessões do mestre: o registro com os nomes e as notas dele
  await _print(tester, 'mestre_sessoes_pc', const TelaCampanha(campanhaId: 'c1'), tamanho: _pc);
  await tester.tap(find.text('Sessões').first);
  await _salvar(tester, 'mestre_sessoes_pc');

  // os jogadores: notas e pedidos para o mestre, e o gerador de nomes
  await _print(tester, 'mestre_jogadores_pc', const TelaCampanha(campanhaId: 'c1'), tamanho: _pc);
  await tester.tap(find.text('Jogadores').first);
  await _salvar(tester, 'mestre_jogadores_pc');
  await tester.tap(find.text('Pedidos de homebrew (1)'));
  await _salvar(tester, 'mestre_pedidos_pc');
  await tester.tap(find.text('Nomes').first);
  await _salvar(tester, 'mestre_nomes_pc');
  await tester.tap(find.byIcon(Icons.casino_outlined).first);
  await _salvar(tester, 'mestre_rolagens_pc');
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await _salvar(tester, 'mestre_mesa_pc');
  await _print(tester, 'mestre_mais', const TelaCampanha(campanhaId: 'c1'));
  await tester.tap(find.text('Mais'));
  await _salvar(tester, 'mestre_mais');
  // o lado do jogador (Lia): as abas Notas e Pedidos da mesa
  Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u2', displayName: 'Lia'));
  await _print(tester, 'jogador_mesa_pc', const TelaCampanha(campanhaId: 'c1'), tamanho: _pc);
  await _print(tester, 'jogador_mesa', const TelaCampanha(campanhaId: 'c1'));
  await tester.tap(find.text('Notas'));
  await _salvar(tester, 'jogador_notas');
  await tester.tap(find.text('Pedidos'));
  await _salvar(tester, 'jogador_pedidos');
  // o ajuste da foto de perfil: o círculo, como fica na ficha e nas notas
  final ajuste =
      escolherEnquadramento(tester.element(find.text('Pedidos').first), foto: 'jogador2', nome: 'Lia', redondo: true);
  await _salvar(tester, 'foto_jogador_ajuste');
  await tester.tap(find.text('Cancelar'));
  await ajuste;
  Repo.authTeste = MockFirebaseAuth(
      signedIn: true, mockUser: MockUser(uid: _uid, displayName: 'Enzo', email: 'enzo@exemplo.com'));

  // a ficha do agente: o espaço do alvo embaixo dos rituais rápidos
  await chars.doc('a1').update({'alvo': 'o2'});
  await _print(tester, 'ficha_alvo', const TelaFicha(fichaId: 'a1'));
  DefaultTabController.of(tester.element(find.byType(TabBarView))).index = 2;
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.scrollUntilVisible(find.text('AMEAÇAS'), 400,
      scrollable: find.descendant(of: find.byType(TabCombate), matching: find.byType(Scrollable)).first);
  await tester.drag(find.byType(TabCombate), const Offset(0, -260));
  await _salvar(tester, 'ficha_alvo');

  // as sessões: a aba do agente (nomes e notas dele) e a do mestre
  DefaultTabController.of(tester.element(find.byType(TabBarView))).index = 7;
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _salvar(tester, 'ficha_sessoes');
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
  // fotos de perfil dos jogadores
  Imagens.guardarNaMemoria('jogador1', _retrato(0xFF20303A, 0xFF4A5A3A, 4));
  Imagens.guardarNaMemoria('jogador2', _retrato(0xFF4A2A4A, 0xFF2A4A5A, 5));
  await db.collection('users').doc(_uid).set({'foto': 'jogador1'});
  await db.collection('users').doc('u2').set({'foto': 'jogador2'});

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
      'Profissão': {'grau': 5, 'qual': 'professora de história'},
    },
    'reacao': 'bloqueio',
    'pvAtual': 14,
    'pvTemp': 5,
    'pvTempMax': 5,
    'peAtual': 9,
    'sanAtual': 18,
    'condicoes': ['Abalado'],
    'rd': {'fogo': 5, 'mental': 3},
    'ativos': ['poder:p7'],
    'poderes': [
      {'id': 'p6', 'nome': 'Resistir a Elemento', 'tipo': 'Paranormal', 'ref': 'oprpg/p.resistir_elemento', 'elemento': 'Sangue', 'descricao': 'Resistência 10 contra Sangue.'},
      {'id': 'p1', 'nome': 'Escolhido pelo Outro Lado', 'tipo': 'Classe', 'descricao': 'Conjura rituais de 1º círculo e aprende novos conforme o NEX aumenta.'},
      {'id': 'p2', 'nome': 'Potencial Aprimorado', 'tipo': 'Paranormal', 'elemento': 'Morte', 'ref': 'oprpg/p.potencial_aprimorado', 'descricao': 'Seus PE máximos aumentam em +1 por NEX.'},
      {'id': 'p3', 'nome': 'Sensitivo', 'ref': 'oprpg/p.sensitivo', 'tipo': 'Paranormal', 'elemento': 'Conhecimento', 'afinidade': true, 'descricao': 'Você sente emoções e intenções e recebe +5 em Diplomacia, Intimidação e Intuição.'},
      {'id': 'p4', 'nome': 'Sangue de Ferro', 'tipo': 'Paranormal', 'elemento': 'Sangue', 'descricao': 'Você recebe +2 PV por NEX e +5 em Fortitude.'},
      {'id': 'p7', 'nome': 'Encarar a Morte', 'tipo': 'Paranormal', 'elemento': 'Morte', 'ref': 'oprpg/p.encarar_morte', 'descricao': 'Em cenas de ação, seu limite de PE por turno aumenta em 1.'},
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
      {'id': 'r2', 'nome': 'Eletrocussão', 'elemento': 'Energia', 'circulo': 1, 'execucao': 'Padrão', 'alcance': 'Curto', 'alvo': '1 ser', 'dano': '3d6', 'custoDiscente': 2, 'custoVerdadeiro': 5, 'descricao': 'Corrente voltaica eletrocuta o alvo.'},
      {'id': 'r3', 'nome': 'Passagem de Conhecimento', 'elemento': 'Sangue/Conhecimento', 'circulo': 2, 'execucao': 'Padrão', 'alcance': 'Toque', 'fonte': 'AS1', 'descricao': 'Compartilha memórias com quem você toca.'},
    ],
    'rituaisRapidos': ['r2', 'r3'],
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
    'pasta': 'pa1',
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
    'pasta': 'pa1',
    'pvAtual': 2,
    'peAtual': 1,
    'sanAtual': 5,
  }));
  await db.collection('users').doc(_uid).set({
    'foto': 'jogador1',
    'pastas': [
      {'id': 'pa1', 'nome': 'Operação Sangue Velho', 'data': DateTime(2026, 10, 12).millisecondsSinceEpoch},
      {'id': 'pa2', 'nome': 'Arquivo morto', 'data': DateTime(2026, 3, 2).millisecondsSinceEpoch},
    ],
  });
  final agora = DateTime.now().millisecondsSinceEpoch;
  const dia = 86400000;
  await db.collection('campaigns').doc('c1').set({
    'nome': 'Operação Sangue Velho',
    'masterUid': _uid,
    'joinCode': 'K7Q2ZP',
    'memberUids': [_uid, 'u2', 'u3'],
    'members': {_uid: 'Enzo', 'u2': 'Lia', 'u3': 'Davi'},
    'regras': {'determinacao': false, 'progressao': 'nex'},
    'combate': {'ativo': false, 'rodada': 1, 'turno': 0, 'ordem': []},
    // a sessão começou há 1h12
    'sessao': {'ativa': true, 'numero': 3, 'inicio': agora - 4320000},
    'sessoes': [
      {'numero': 1, 'inicio': agora - 8 * dia, 'fim': agora - 8 * dia + 13260000},
      {'numero': 2, 'inicio': agora - dia, 'fim': agora - dia + 14188000},
      {'numero': 3, 'inicio': agora - 4320000},
    ],
    'ledger': [],
    'missao': 'Descobrir quem marcou o porão da mansão Albuquerque.',
  });
  await db.collection('campaigns').doc('c2').set({
    'nome': 'O Segredo na Ilha',
    'masterUid': 'u3',
    'joinCode': 'W2HX9B',
    'memberUids': ['u3', _uid, 'u2'],
    'members': {'u3': 'Davi', _uid: 'Enzo', 'u2': 'Lia'},
    'regras': {'determinacao': false, 'progressao': 'nex'},
    'combate': {'ativo': false, 'rodada': 1, 'turno': 0, 'ordem': []},
    'sessao': {'ativa': false, 'numero': 2, 'inicio': agora - 3 * dia, 'fim': agora - 3 * dia + 11400000},
    'sessoes': [
      {'numero': 1, 'inicio': agora - 10 * dia, 'fim': agora - 10 * dia + 12600000},
      {'numero': 2, 'inicio': agora - 3 * dia, 'fim': agora - 3 * dia + 11400000},
    ],
    'ledger': [],
    'missao': 'Achar o pesquisador que sumiu na ilha antes da próxima lua cheia.',
  });
  // os nomes e as notas das sessões: os do mestre e os de um agente
  await db.collection('campaigns').doc('c1').collection('gm').doc('sessoes').set({
    '1': {'nome': 'A mansão Albuquerque', 'nota': 'Pista: o sigilo no porão é de Sangue.'},
    '2': {'nome': 'O porão da fazenda', 'nota': 'Joaquim caiu a 0 PV e foi salvo por Bianca. O cultista fugiu com o diário.'},
  });
  await db.collection('characters').doc('a1').update({
    'notasSessoes': {
      'c1': {
        '2': {'nome': 'Porão', 'nota': 'Fulano morreu. A chave ficou com a Bianca.'},
      },
    },
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
