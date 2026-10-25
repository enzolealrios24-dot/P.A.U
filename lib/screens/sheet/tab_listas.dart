import 'package:flutter/material.dart';

import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/quadro.dart';
import '../../data/repo.dart';
import '../../widgets/catalogo_picker.dart';
import '../../widgets/form_dialog.dart';
import '../quadro/quadro_screen.dart';
import 'rolar.dart';

// ---------------- definicoes de formularios (reaproveitadas pelo mestre) ----

const camposItem = [
  CampoDef('nome', 'Nome'),
  CampoDef('tipo', 'Tipo',
      tipo: TipoCampo.opcoes,
      opcoes: ['geral', 'arma', 'protecao'],
      meiaLargura: true),
  CampoDef('categoria', 'Categoria (0 a 4)',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('espacos', 'Espaços', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('qtd', 'Quantidade', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('dano', 'Dano (arma)', dica: 'ex.: 1d8 ou 2d6+2', meiaLargura: true),
  CampoDef('critico', 'Crítico (arma)', dica: 'ex.: 19/x3', meiaLargura: true),
  CampoDef('pericia', 'Perícia de ataque',
      tipo: TipoCampo.opcoes, opcoes: ['Luta', 'Pontaria'], meiaLargura: true),
  CampoDef('alcance', 'Alcance', meiaLargura: true),
  CampoDef('bonusAtaque', 'Bônus de ataque',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('bonusDano', 'Bônus de dano',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('defesa', 'Defesa (proteção)',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('equipado', 'Equipado', tipo: TipoCampo.booleano, meiaLargura: true),
  CampoDef('descricao', 'Descrição / anotações', tipo: TipoCampo.multi),
];

const itemPadrao = {
  'nome': '',
  'tipo': 'geral',
  'categoria': 0,
  'espacos': 1,
  'qtd': 1,
  'pericia': 'Luta',
  'critico': '20/x2',
  // itens novos começam guardados; a chave da etiqueta equipa
  'equipado': false,
};

const camposRitual = [
  CampoDef('nome', 'Nome'),
  CampoDef('elemento', 'Elemento',
      tipo: TipoCampo.opcoes, opcoes: elementos, meiaLargura: true),
  CampoDef('circulo', 'Círculo (1 a 4)',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('custo', 'Custo PE (0 = padrão)',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('execucao', 'Execução', meiaLargura: true),
  CampoDef('alcance', 'Alcance', meiaLargura: true),
  CampoDef('alvo', 'Alvo/Área', meiaLargura: true),
  CampoDef('duracao', 'Duração', meiaLargura: true),
  CampoDef('resistencia', 'Resistência', meiaLargura: true),
  CampoDef('dano', 'Dano/cura padrão', dica: 'ex.: 3d6', meiaLargura: true),
  CampoDef('custoDiscente', 'Discente: +PE',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('danoDiscente', 'Discente: dano', meiaLargura: true),
  CampoDef('custoVerdadeiro', 'Verdadeiro: +PE',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('danoVerdadeiro', 'Verdadeiro: dano', meiaLargura: true),
  CampoDef('descricao', 'Efeito (suas anotações)', tipo: TipoCampo.multi),
];

const ritualPadrao = {'nome': '', 'elemento': 'Sangue', 'circulo': 1};

const camposPoder = [
  CampoDef('nome', 'Nome'),
  CampoDef('tipo', 'Tipo',
      tipo: TipoCampo.opcoes,
      opcoes: ['Classe', 'Trilha', 'Origem', 'Paranormal', 'Geral', 'Homebrew']),
  CampoDef('descricao', 'Descrição / efeito', tipo: TipoCampo.multi),
];

const poderPadrao = {'nome': '', 'tipo': 'Classe'};

// ---------------- helpers de lista ----------------

void _salvarLista(CtxFicha ctx, String campo, List<Map<String, dynamic>> l) =>
    Repo.set(ctx.f.id, campo, l);

Future<void> _editarNaLista(
  BuildContext context,
  CtxFicha ctx, {
  required String campo,
  required String titulo,
  required List<CampoDef> campos,
  required Map<String, dynamic> padrao,
  int? indice,
}) async {
  final lista = asMapList(ctx.f.d[campo]);
  final inicial = indice == null
      ? Map<String, dynamic>.from(padrao)
      : lista[indice];
  final r = await editarFormulario(context,
      titulo: titulo,
      inicial: inicial,
      campos: campos,
      podeApagar: indice != null);
  if (r == null) return;
  if (r.apagar && indice != null) {
    lista.removeAt(indice);
  } else if (r.dados != null) {
    if (indice == null) {
      lista.add({...r.dados!, 'id': novoId()});
    } else {
      lista[indice] = r.dados!;
    }
  } else {
    return;
  }
  _salvarLista(ctx, campo, lista);
}

/// Escolhe algo da biblioteca homebrew da mesa.
Future<Map<String, dynamic>?> escolherDaBiblioteca(
    BuildContext context, String cid, String tipo) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Biblioteca da mesa'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: StreamBuilder<List<(String, Map<String, dynamic>)>>(
          stream: Repo.stream(Repo.homebrew(cid)),
          builder: (ctx, s) {
            if (s.hasError) return Text('${s.error}');
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final l = s.data!.where((e) => asStr(e.$2['tipoBiblio']) == tipo);
            if (l.isEmpty) {
              return const Center(
                  child: Text('O mestre ainda não cadastrou nada aqui.'));
            }
            return ListView(children: [
              for (final e in l)
                ListTile(
                  title: Text(asStr(e.$2['nome'])),
                  subtitle: Text(asStr(e.$2['descricao']),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, e.$2),
                ),
            ]);
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))
      ],
    ),
  );
}

Widget _botoesAdicionar(BuildContext context, CtxFicha ctx,
    {required String campo,
    required String titulo,
    required List<CampoDef> campos,
    required Map<String, dynamic> padrao,
    required String tipoBiblio,
    bool doLivro = true}) {
  final camp = ctx.camp;
  return Wrap(spacing: 8, runSpacing: 8, children: [
    FilledButton.icon(
      onPressed: () => _editarNaLista(context, ctx,
          campo: campo, titulo: titulo, campos: campos, padrao: padrao),
      icon: const Icon(Icons.add),
      label: const Text('Adicionar'),
    ),
    if (doLivro)
    FilledButton.tonalIcon(
      onPressed: () => adicionarDoLivro(context, ctx, tipoBiblio),
      icon: const Icon(Icons.auto_stories_outlined),
      label: const Text('Do livro'),
    ),
    if (camp != null)
      OutlinedButton.icon(
        onPressed: () async {
          final m = await escolherDaBiblioteca(context, camp.id, tipoBiblio);
          if (m == null) return;
          final copia = Map<String, dynamic>.from(m)..remove('tipoBiblio');
          final lista = asMapList(ctx.f.d[campo])
            ..add({...copia, 'id': novoId()});
          _salvarLista(ctx, campo, lista);
        },
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Da biblioteca da mesa'),
      ),
  ]);
}

// ---------------- adicionar do livro ----------------

String _tipoPoderFicha(String tipo) {
  switch (tipo) {
    case 'paranormal':
      return 'Paranormal';
    case 'geral':
      return 'Geral';
    case 'trilha':
      return 'Trilha';
    case 'origem':
      return 'Origem';
    default:
      return 'Classe';
  }
}

Future<void> adicionarDoLivro(
    BuildContext context, CtxFicha ctx, String tipoBiblio) async {
  final cat = Catalogo.instance;
  final f = ctx.f;
  Map<String, dynamic>? e;
  String campo;
  Map<String, dynamic> novo;
  if (tipoBiblio == 'ritual') {
    campo = 'rituais';
    e = await escolherDoLivro(
      context,
      titulo: 'Rituais dos livros',
      itens: cat.rituais,
      filtros: [
        const FiltroCatalogo('Todos', _sempre),
        for (var c = 1; c <= 4; c++)
          FiltroCatalogo('$cº círculo', (r) => asInt(r['circulo']) == c),
        for (final el in elementos)
          FiltroCatalogo(
              el,
              (r) =>
                  asStr(r['elemento']) == el ||
                  asStrList(r['elementos']).contains(el)),
      ],
      meta: metaRitual,
      detalhes: detalhesRitual,
    );
    if (e == null) return;
    novo = ritualDoLivro(e);
  } else if (tipoBiblio == 'poder') {
    campo = 'poderes';
    final minhaClasse = Catalogo.normalizar(f.classe);
    // trilhas da classe da ficha (sem classe, todas)
    bool daMinhaClasse(Map<String, dynamic> p) =>
        minhaClasse.isEmpty ||
        Catalogo.normalizar(asStr(p['classe'])) == minhaClasse ||
        asStrList(p['classes']).map(Catalogo.normalizar).contains(minhaClasse);
    e = await escolherDoLivro(
      context,
      titulo: 'Poderes dos livros',
      itens: [...cat.poderes, ...cat.poderesTrilha, ...cat.poderesOrigem]
        ..sort((a, b) => Catalogo.normalizar(asStr(a['nome']))
            .compareTo(Catalogo.normalizar(asStr(b['nome'])))),
      filtros: [
        FiltroCatalogo('Minha classe',
            (p) => Catalogo.normalizar(asStr(p['tipo'])) == minhaClasse),
        FiltroCatalogo('Trilhas', (p) => _trilha(p) && daMinhaClasse(p)),
        const FiltroCatalogo('Origens', _origem),
        const FiltroCatalogo('Paranormais', _paranormal),
        const FiltroCatalogo('Gerais', _geral),
        const FiltroCatalogo('Todos', _sempre),
      ],
      meta: metaPoder,
      detalhes: detalhesPoder,
    );
    if (e == null) return;
    // a da própria trilha ou origem já é carta e já conta na ficha
    final ref = asStr(e['ref']);
    final daFicha = (_trilha(e) &&
            ctx.calc.trilhaDados != null &&
            ref.startsWith('${asStr(ctx.calc.trilhaDados!['ref'])}#') &&
            ctx.calc.trilhaLiberada(asInt(e['nex']))) ||
        (_origem(e) &&
            ctx.calc.origemDados != null &&
            ref == '${asStr(ctx.calc.origemDados!['ref'])}#poder');
    if (daFicha) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${asStr(e['nome'])} já vem da sua ${_trilha(e) ? 'trilha' : 'origem'} e já está nas cartas.')));
      }
      return;
    }
    final pre = asStr(e['prereq']);
    novo = {
      'nome': asStr(e['nome']),
      'tipo': _tipoPoderFicha(asStr(e['tipo'])),
      'descricao':
          '${detalhesPoder(e)}${pre.isEmpty ? '' : '\nPré-requisito: $pre'}',
      if (_trilha(e)) 'detalhe': '${asStr(e['trilha'])}, ${asStr(e['quando'])}',
      if (_origem(e)) 'detalhe': 'origem ${asStr(e['origem'])}',
      if (e['elemento'] != null) 'elemento': e['elemento'],
      'fonte': e['fonte'],
      'pag': e['pag'],
      'ref': e['ref'],
    };
  } else {
    campo = 'inventario';
    e = await escolherDoLivro(
      context,
      titulo: 'Itens dos livros',
      itens: cat.itens
          .where((i) =>
              asStr(i['tipo']) != 'modificacao' &&
              asStr(i['tipo']) != 'maldicao')
          .toList(),
      filtros: const [
        FiltroCatalogo('Armas', _arma),
        FiltroCatalogo('Proteções', _protecao),
        FiltroCatalogo('Munições', _municao),
        FiltroCatalogo('Equipamentos', _equipamento),
        FiltroCatalogo('Paranormais', _itemParanormal),
        FiltroCatalogo('Amaldiçoados', _amaldicoado),
        FiltroCatalogo('Todos', _sempre),
      ],
      meta: metaItem,
    );
    if (e == null) return;
    final tipo = asStr(e['tipo']);
    final ataque = asStr(e['ataque']);
    novo = {
      'nome': asStr(e['nome']),
      'tipo':
          tipo == 'arma' ? 'arma' : (tipo == 'protecao' ? 'protecao' : 'geral'),
      'categoria': asInt(e['categoria']),
      'espacos': e['espacos'] is num ? e['espacos'] : 1,
      'qtd': 1,
      'equipado': false,
      for (final k in const [
        'dano', 'critico', 'alcance', 'ataque', 'agil', 'somaFor', 'tipoDano',
        'defesa', 'rd', 'elemento', 'fonte', 'pag', 'ref', 'bonusAtaque'
      ])
        if (e[k] != null) k: e[k],
      if (tipo == 'arma') 'pericia': ataque == 'corpo' ? 'Luta' : 'Pontaria',
      'categoriaLivro': tipo,
      'descricao': asStr(e['resumo']),
    };
  }
  final lista = asMapList(f.d[campo])..add({...novo, 'id': novoId()});
  _salvarLista(ctx, campo, lista);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${asStr(e['nome'])} adicionado.')));
  }
}

bool _sempre(Map<String, dynamic> _) => true;
bool _paranormal(Map<String, dynamic> p) => asStr(p['tipo']) == 'paranormal';
bool _geral(Map<String, dynamic> p) => asStr(p['tipo']) == 'geral';
bool _trilha(Map<String, dynamic> p) => asStr(p['tipo']) == 'trilha';
bool _origem(Map<String, dynamic> p) => asStr(p['tipo']) == 'origem';
bool _arma(Map<String, dynamic> i) => asStr(i['tipo']) == 'arma';
bool _protecao(Map<String, dynamic> i) => asStr(i['tipo']) == 'protecao';
bool _municao(Map<String, dynamic> i) => asStr(i['tipo']) == 'municao';
bool _equipamento(Map<String, dynamic> i) =>
    const ['acessorio', 'explosivo', 'operacional', 'geral']
        .contains(asStr(i['tipo']));
bool _itemParanormal(Map<String, dynamic> i) => asStr(i['tipo']) == 'paranormal';
bool _amaldicoado(Map<String, dynamic> i) => asStr(i['tipo']) == 'amaldicoado';

// ---------------- modificacoes e maldicoes ----------------

/// Quais "aplica" de modificacoes/maldicoes servem para o item.
Set<String> _aplicaveis(Map<String, dynamic> item) {
  final tipo = asStr(item['tipo']);
  final livro = asStr(item['categoriaLivro']);
  if (tipo == 'arma') {
    final ataque = asStr(item['ataque'],
        asStr(item['pericia']) == 'Pontaria' ? 'fogo' : 'corpo');
    return {
      'arma',
      if (ataque == 'corpo') ...{'corpo', 'corpo_disparo'},
      if (ataque == 'disparo') 'corpo_disparo',
      if (ataque == 'fogo') ...{'fogo', 'municao'},
    };
  }
  if (tipo == 'protecao') return {'protecao'};
  if (livro == 'municao') return {'municao'};
  if (livro == 'explosivo') return {'granada'};
  final doLivro = Catalogo.instance.porRef(asStr(item['ref']));
  if (asBool(doLivro?['drone'])) return {'drone'};
  if (asBool(doLivro?['remedio']) ||
      Catalogo.normalizar(asStr(item['nome'])).contains('cicatrizante')) {
    return {'medicamento', 'acessorio'};
  }
  return {'acessorio'};
}

String _formatarCritico(int margem, int mult) {
  if (margem >= 20) return 'x$mult';
  if (mult == 2) return '$margem';
  return '$margem/x$mult';
}

String _maisUmDado(String dano) {
  final m = RegExp(r'(\d*)[dD](\d+)').firstMatch(dano);
  if (m == null) return dano;
  final n = (int.tryParse(m.group(1) ?? '') ?? 1) + 1;
  return dano.replaceRange(m.start, m.end, '${n}d${m.group(2)}');
}

Future<void> editarModificacoes(
    BuildContext context, CtxFicha ctx, int indice) async {
  final cat = Catalogo.instance;
  final lista = asMapList(ctx.f.d['inventario']);
  if (indice < 0 || indice >= lista.length) return;
  final item = lista[indice];
  final apl = _aplicaveis(item);
  final mods = cat.itens
      .where((m) =>
          asStr(m['tipo']) == 'modificacao' && apl.contains(asStr(m['aplica'])))
      .toList();
  final mals = cat.itens
      .where((m) =>
          asStr(m['tipo']) == 'maldicao' && apl.contains(asStr(m['aplica'])))
      .toList();
  final selMods = {...asStrList(item['mods'])};
  final selMals = {...asStrList(item['maldicoes'])};
  final ok = await showDialog<bool>(
    context: context,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, set) {
        Widget chips(List<Map<String, dynamic>> l, Set<String> sel) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in l)
                  Tooltip(
                    message:
                        '${asStr(m['resumo'])}${asStr(m['elemento']).isNotEmpty ? ' (${asStr(m['elemento'])})' : ''}',
                    child: FilterChip(
                      label: Text(asStr(m['nome'])),
                      selected: sel.contains(asStr(m['ref'])),
                      onSelected: (v) => set(() => v
                          ? sel.add(asStr(m['ref']))
                          : sel.remove(asStr(m['ref']))),
                    ),
                  ),
              ],
            );
        return AlertDialog(
          title: Text('Modificar: ${asStr(item['nome'])}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      apl.contains('drone')
                          ? 'Escolha o tipo do drone. Cada tipo além do primeiro aumenta a categoria em I (até IV). Segure um item para ver o efeito.'
                          : 'Cada modificação aumenta a categoria em I. A primeira maldição aumenta em II e as seguintes em I. Segure um item para ver o efeito.',
                      style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
                  const SizedBox(height: 10),
                  const Text('MODIFICAÇÕES',
                      style: TextStyle(fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  if (mods.isEmpty)
                    const Text('Nenhuma para este tipo de item.')
                  else
                    chips(mods, selMods),
                  const SizedBox(height: 14),
                  const Text('MALDIÇÕES',
                      style: TextStyle(fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  if (mals.isEmpty)
                    const Text('Nenhuma para este tipo de item.')
                  else
                    chips(mals, selMals),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('Aplicar')),
          ],
        );
      },
    ),
  );
  if (ok != true) return;
  final base = item['base'] is Map
      ? asMap(item['base'])
      : <String, dynamic>{
          for (final k in const [
            'categoria', 'espacos', 'bonusAtaque', 'bonusDano', 'critico',
            'dano', 'defesa'
          ])
            k: item[k],
        };
  var categoria = asInt(base['categoria']);
  num espacos = base['espacos'] is num ? base['espacos'] as num : asInt(base['espacos'], 1);
  var bonusAtaque = asInt(base['bonusAtaque']);
  var bonusDano = asInt(base['bonusDano']);
  var defesa = asInt(base['defesa']);
  var dano = asStr(base['dano']);
  final crit = Dados.critico(asStr(base['critico'], 'x2'));
  var margem = crit.margem;
  var mult = crit.mult;
  void aplicar(Map<String, dynamic>? m, {required bool nivelItem}) {
    if (m == null) return;
    for (final e in asMapList(m['efeitos'])) {
      final v = asInt(e['valor']);
      switch (asStr(e['alvo'])) {
        case 'bonusAtaque':
          bonusAtaque += v;
        case 'bonusDano':
          bonusDano += v;
        case 'espacos':
          espacos += v;
        case 'margem':
          margem -= v;
        case 'multiplicador':
          mult += v;
        case 'dadoDano':
          if (dano.isNotEmpty) dano = _maisUmDado(dano);
        case 'danoExtra':
          if (dano.isNotEmpty) dano = '$dano+${asStr(e['dano'])}';
        case 'defesa':
          if (nivelItem) defesa += v;
      }
    }
  }

  for (final r in selMods) {
    aplicar(cat.porRef(r), nivelItem: true);
  }
  for (final r in selMals) {
    aplicar(cat.porRef(r), nivelItem: false);
  }
  if (_aplicaveis(item).contains('drone')) {
    // Drones: o primeiro tipo vem com o item; cada tipo extra soma I, até IV.
    categoria += selMods.isEmpty ? 0 : selMods.length - 1;
    if (categoria > 4) categoria = 4;
  } else {
    categoria += selMods.length + (selMals.isEmpty ? 0 : selMals.length + 1);
  }
  lista[indice] = {
    ...item,
    'base': base,
    'mods': selMods.toList(),
    'maldicoes': selMals.toList(),
    'categoria': categoria,
    'espacos': espacos < 0 ? 0 : espacos,
    if (base['bonusAtaque'] != null || bonusAtaque != 0)
      'bonusAtaque': bonusAtaque,
    if (base['bonusDano'] != null || bonusDano != 0) 'bonusDano': bonusDano,
    if (base['defesa'] != null || defesa != 0) 'defesa': defesa,
    if (dano.isNotEmpty) 'dano': dano,
    if (base['critico'] != null)
      'critico': _formatarCritico(margem.clamp(2, 20), mult),
  };
  _salvarLista(ctx, 'inventario', lista);
}

String nomesModificacoes(Map<String, dynamic> item) {
  final cat = Catalogo.instance;
  final n = [
    for (final r in [
      ...asStrList(item['mods']),
      ...asStrList(item['maldicoes'])
    ])
      asStr(cat.porRef(r)?['nome'], r.split('/').last)
  ];
  return n.join(', ');
}

// ---------------- COMBATE ----------------

/// Abre o formulário da arma [indice] do inventário (aba COMBATE).
void editarArma(BuildContext context, CtxFicha ctx, int indice) => _editarNaLista(context, ctx,
    campo: 'inventario', titulo: 'Editar arma', campos: camposItem, padrao: itemPadrao, indice: indice);

// ---------------- RITUAIS (a aba fica em tab_rituais.dart) ----------------

/// Ritual do livro no formato da ficha. [elemento] escolhe o elemento dos
/// rituais de elemento variável (ex.: Amaldiçoar Arma).
Map<String, dynamic> ritualDoLivro(Map<String, dynamic> e, {String? elemento}) => {
      for (final k in const [
        'nome', 'elemento', 'circulo', 'execucao', 'alcance', 'alvo', 'duracao',
        'resistencia', 'dano', 'custoDiscente', 'danoDiscente',
        'custoVerdadeiro', 'danoVerdadeiro', 'fonte', 'pag', 'ref'
      ])
        if (e[k] != null) k: e[k],
      if (elemento != null) 'elemento': elemento,
      'descricao': textoRitual(e),
    };

/// Aprende um ritual do livro (acrescenta na ficha).
void aprenderRitual(BuildContext context, CtxFicha ctx, Map<String, dynamic> e, {String? elemento}) {
  final lista = asMapList(ctx.f.d['rituais'])..add({...ritualDoLivro(e, elemento: elemento), 'id': novoId()});
  _salvarLista(ctx, 'rituais', lista);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('${asStr(e['nome'])} aprendido.')));
}

Widget botoesAdicionarRitual(BuildContext context, CtxFicha ctx) => _botoesAdicionar(context, ctx,
    campo: 'rituais', titulo: 'Novo ritual', campos: camposRitual, padrao: ritualPadrao, tipoBiblio: 'ritual', doLivro: false);

void editarRitual(BuildContext context, CtxFicha ctx, int indice) => _editarNaLista(context, ctx,
    campo: 'rituais', titulo: 'Editar ritual', campos: camposRitual, padrao: ritualPadrao, indice: indice);

/// Chave de um ritual conhecido (o id; nas fichas antigas, o nome).
String chaveRitual(Map<String, dynamic> r) => asStr(r['id'], asStr(r['nome']));

/// Rituais no uso rápido da aba Combate, na ordem escolhida.
List<String> rituaisRapidos(Ficha f) => asStrList(f.d['rituaisRapidos']);

/// Põe ou tira um ritual conhecido do uso rápido.
void alternarRitualRapido(BuildContext context, CtxFicha ctx, Map<String, dynamic> r) {
  final l = rituaisRapidos(ctx.f);
  final k = chaveRitual(r);
  final tirar = l.contains(k);
  Repo.set(ctx.f.id, 'rituaisRapidos', tirar ? [for (final x in l) if (x != k) x] : [...l, k]);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tirar
          ? '${asStr(r['nome'])} saiu do uso rápido.'
          : '${asStr(r['nome'])} está no uso rápido da aba Combate.')));
}

// ---------------- INVENTARIO ----------------

// A aba fica em tab_inventario.dart; aqui ficam os atalhos que ela usa.

Widget botoesAdicionarItem(BuildContext context, CtxFicha ctx) => _botoesAdicionar(context, ctx,
    campo: 'inventario', titulo: 'Novo item', campos: camposItem, padrao: itemPadrao, tipoBiblio: 'item');

void editarItem(BuildContext context, CtxFicha ctx, int indice) => _editarNaLista(context, ctx,
    campo: 'inventario', titulo: 'Editar item', campos: camposItem, padrao: itemPadrao, indice: indice);

String espacosTexto(dynamic v) => _espacosTexto(v);

// ---------------- PODERES & NOTAS ----------------

// A aba fica em tab_poderes.dart; aqui ficam os atalhos que ela usa.

Widget botoesAdicionarPoder(BuildContext context, CtxFicha ctx) => _botoesAdicionar(context, ctx,
    campo: 'poderes', titulo: 'Novo poder/habilidade', campos: camposPoder, padrao: poderPadrao, tipoBiblio: 'poder');

void editarPoder(BuildContext context, CtxFicha ctx, int indice) => _editarNaLista(context, ctx,
    campo: 'poderes', titulo: 'Editar poder', campos: camposPoder, padrao: poderPadrao, indice: indice);

/// Liga ou desliga o benefício de afinidade de um poder paranormal.
void alternarAfinidadePoder(CtxFicha ctx, int indice) {
  final lista = asMapList(ctx.f.d['poderes']);
  lista[indice] = {...lista[indice], 'afinidade': !asBool(lista[indice]['afinidade'])};
  _salvarLista(ctx, 'poderes', lista);
}

/// Equipa ou guarda um item do inventário. Só os equipados contam na
/// ficha (Defesa, RD, bloqueio, esquiva e os outros bônus).
void alternarEquipado(CtxFicha ctx, int indice) {
  final lista = asMapList(ctx.f.d['inventario']);
  lista[indice] = {...lista[indice], 'equipado': !asBool(lista[indice]['equipado'], true)};
  _salvarLista(ctx, 'inventario', lista);
}

/// Espaços com fração (0,5) sem perder o meio espaço.
String _espacosTexto(dynamic v) {
  if (v is! num) return '${asInt(v, 1)}';
  return v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');
}

/// Abre o quadro (estilo Milanote) da ficha em tela cheia.
void abrirQuadroFicha(BuildContext context, CtxFicha ctx) => Navigator.push(
    context,
    MaterialPageRoute(
        // com o tema da afinidade da ficha (as cores já estão aplicadas)
        builder: (_) => Theme(data: temaCris(), child: TelaQuadro(fonte: FonteQuadro.ficha(ctx.f.id)))));

// A aba QUADRO (mural) fica em tab_quadro.dart.
