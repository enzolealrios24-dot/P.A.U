import 'package:flutter/material.dart';

import '../../core/dice.dart';
import '../../core/efeitos_texto.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import '../../widgets/runa.dart';
import 'rolar.dart';
import 'tab_listas.dart';

/// Grupo da tag de cada carta: Origem, Classe, Trilha, Geral (inclui
/// homebrew), Paranormal ou Própria.
String grupoPoder(Map<String, dynamic> p) {
  final t = asStr(p['tipo']).toLowerCase();
  if (t.startsWith('paranormal')) return 'Paranormal';
  if (t.startsWith('geral') || t.startsWith('homebrew')) return 'Geral';
  if (t.startsWith('origem')) return 'Origem';
  if (t.startsWith('trilha')) return 'Trilha';
  if (t.startsWith('própria') || t.startsWith('propria')) return 'Própria';
  return 'Classe';
}

String romano(int n) {
  const valores = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const letras = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
  var resto = n, s = '';
  for (var i = 0; i < valores.length; i++) {
    while (resto >= valores[i]) {
      s += letras[i];
      resto -= valores[i];
    }
  }
  return s;
}

/// Uma carta da aba: poder escolhido, habilidade de origem, classe ou
/// trilha (vêm sozinhas do livro) ou habilidade própria.
class EntradaPoder {
  final String chave;
  /// O que a carta mostra: nome, tipo, descricao, elemento, afinidade.
  final Map<String, dynamic> carta;
  /// O que o livro diz que ela faz na ficha (efeitos, custo, ativavel, escolha).
  final Map<String, dynamic> meta;
  /// Posição em "poderes" (poder escolhido) ou null.
  final int? indicePoder;
  /// Vem do livro (origem, classe, trilha): dá para editar o texto e ocultar.
  final bool doLivro;
  final bool propria;
  final bool editada;
  const EntradaPoder({
    required this.chave,
    required this.carta,
    this.meta = const {},
    this.indicePoder,
    this.doLivro = false,
    this.propria = false,
    this.editada = false,
  });

  String get nome => asStr(carta['nome'], 'Poder');
  String get grupo => grupoPoder(carta);
  bool get afinidade => asBool(carta['afinidade']);
}

/// Habilidades de classe que só avisam da progressão (a trilha, os poderes
/// e os aumentos chegam por outros caminhos): não viram carta.
const _soProgressao = {
  'Habilidade de Trilha', 'Poder de Combatente', 'Poder de Especialista', 'Poder de Ocultista',
  'Aumento de Atributo', 'Grau de Treinamento', 'Versatilidade',
};

/// Todas as cartas da ficha: origem, classe, trilha, próprias e poderes.
List<EntradaPoder> entradasPoder(CtxFicha ctx) {
  final f = ctx.f;
  final c = ctx.calc;
  final editadas = asMap(f.d['habilidadesEditadas']);
  final r = <EntradaPoder>[];
  void doLivro(String chave, String tipo, Map<String, dynamic> meta, String nome, String fonte, {String? detalhe}) {
    final ed = asMap(editadas[chave]);
    r.add(EntradaPoder(
      chave: chave,
      doLivro: true,
      editada: ed.isNotEmpty,
      meta: meta,
      carta: {
        'nome': ed.isEmpty ? nome : asStr(ed['nome'], nome),
        'tipo': tipo,
        'descricao': ed.isEmpty ? asStr(meta['resumo']) : asStr(ed['resumo'], asStr(meta['resumo'])),
        'detalhe': [if (detalhe != null) detalhe, fonte].where((s) => s.isNotEmpty).join(' · '),
      },
    ));
  }

  final o = c.origemDados;
  if (o != null) {
    final poder = asMap(o['poder']);
    doLivro(Calc.chaveOrigem(o), 'Origem', {...poder, 'efeitos': [...asMapList(o['efeitos']), ...asMapList(poder['efeitos'])]},
        asStr(poder['nome'], asStr(o['nome'])), Catalogo.fonteCurta(o),
        detalhe: 'origem ${asStr(o['nome'])}');
  }
  final cd = c.classeDados;
  if (cd != null) {
    for (final h in asMapList(cd['habilidades'])) {
      if (!c.habilidadeClasseLiberada(h) || _soProgressao.contains(asStr(h['nome']))) continue;
      doLivro(Calc.chaveClasse(cd, h), 'Classe', h, asStr(h['nome']), Catalogo.fonteCurta(cd),
          detalhe: asStr(cd['nome']));
    }
  }
  final t = c.trilhaDados;
  if (t != null) {
    for (final h in asMapList(t['habilidades'])) {
      if (!c.trilhaLiberada(asInt(h['nex']))) continue;
      final quando = c.sobrevivente ? 'estágio ${asInt(h['nex'])}' : 'NEX ${asInt(h['nex'])}%';
      doLivro(Calc.chaveTrilha(t, h), 'Trilha', h, asStr(h['nome']), Catalogo.fonteCurta(t),
          detalhe: '${asStr(t['nome'])}, $quando');
    }
  }
  for (final h in asMapList(f.d['habilidadesProprias'])) {
    r.add(EntradaPoder(
      chave: asStr(h['id']),
      propria: true,
      carta: {
        'nome': asStr(h['nome'], 'Habilidade'),
        'tipo': 'Própria',
        'descricao': asStr(h['resumo']),
        'detalhe': asStr(h['fonte']),
      },
    ));
  }
  for (final (i, p) in f.poderes.indexed) {
    r.add(EntradaPoder(
      chave: Calc.chavePoder(p),
      indicePoder: i,
      carta: p,
      meta: Catalogo.instance.porRef(asStr(p['ref'])) ?? const {},
    ));
  }
  return r;
}

/// As escolhas que valem na carta (as dela ou as da irmã da trilha).
List<String> _escolhasDaCarta(EntradaPoder e, Calc c) =>
    c.escolhasValendo(e.meta, e.chave, e.indicePoder == null ? const {} : c.irmasDoPoder(e.carta));

/// O que a carta faz sozinha na ficha (com as escolhas e a afinidade).
List<String> efeitosFixosDe(EntradaPoder e, Calc c) {
  final escolhas = _escolhasDaCarta(e, c);
  return descreverEfeitos([
    for (final x in [...asMapList(e.meta['efeitos']), if (e.afinidade) ...asMapList(e.meta['efeitosAfinidade'])])
      ...Calc.comEscolhas(x, escolhas),
  ]);
}

/// O que ela faz enquanto está ativa.
List<String> efeitosAtivosDe(EntradaPoder e, Calc c) {
  final a = asMap(e.meta['ativavel']);
  final escolhas = _escolhasDaCarta(e, c);
  return descreverEfeitos([
    for (final x in [...asMapList(a['efeitos']), if (e.afinidade) ...asMapList(a['efeitosAfinidade'])])
      ...Calc.comEscolhas(x, escolhas),
  ]);
}

/// Gasta PE (ou PD) de um poder. Os temporários saem primeiro.
bool gastarPontos(BuildContext context, CtxFicha ctx, int n) {
  if (n <= 0) return true;
  final f = ctx.f;
  final pd = ctx.calc.determinacao;
  final atual = pd ? f.pdAtual : f.peAtual;
  if (atual + f.peTemp < n) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Faltam ${pd ? 'PD' : 'PE'}: precisa de $n e há ${atual + f.peTemp}.')));
    return false;
  }
  Repo.mudarPontos(f, pd ? 'pdAtual' : 'peAtual', atual - n);
  return true;
}

void _ativar(BuildContext context, CtxFicha ctx, EntradaPoder e) {
  final c = ctx.calc;
  if (c.ativos.contains(e.chave)) {
    Repo.set(ctx.f.id, 'ativos', [for (final a in c.ativos) if (a != e.chave) a]);
    return;
  }
  if (!gastarPontos(context, ctx, c.custoPoder(e.meta) ?? 0)) return;
  Repo.set(ctx.f.id, 'ativos', [...c.ativos, e.chave]);
}

void _usar(BuildContext context, CtxFicha ctx, EntradaPoder e) {
  final n = ctx.calc.custoPoder(e.meta) ?? 0;
  if (!gastarPontos(context, ctx, n)) return;
  // "aoUsar": PV temporários (dados ou atributo × multiplicador); não somam
  // com os que já tem, fica o maior
  final ao = asMap(e.meta['aoUsar']);
  var extra = '';
  if (ao.isNotEmpty) {
    final temp = ao['pvTemp'] != null
        ? Dados.expressao(asStr(ao['pvTemp'])).total
        : ctx.calc.attr(asStr(ao['pvTempAttr'])) * asInt(ao['mult'], 1);
    if (temp > ctx.f.pvTemp) Repo.mudarTemporario(ctx.f, 'pvTemp', temp);
    extra = ' $temp PV temporários.';
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${e.nome}: ${n == 0 ? 'usado' : '−$n ${ctx.calc.determinacao ? 'PD' : 'PE'}'}.$extra')));
}

/// Escolhas de um poder (perícias para treinar, atributo, elemento, ritual).
Future<void> _escolher(BuildContext context, CtxFicha ctx, EntradaPoder e) async {
  final f = ctx.f;
  final c = ctx.calc;
  final esc = asMap(e.meta['escolha']);
  final tipo = asStr(esc['tipo']);
  final quantas = asInt(esc['quantas'], 1);
  final opcoes = <(String, String)>[
    if (tipo == 'pericia' || tipo == 'treino')
      for (final p in periciasDef)
        // "opcoes": só essas; "attrs": perícias desses atributos; "exceto"
        if ((asStrList(esc['opcoes']).isEmpty || asStrList(esc['opcoes']).contains(p.nome)) &&
            (asStrList(esc['attrs']).isEmpty || asStrList(esc['attrs']).contains(p.attr)) &&
            !asStrList(esc['exceto']).contains(p.nome))
          (p.nome, p.nome)
    else if (tipo == 'atributo')
      for (final a in asStrList(esc['opcoes']).isEmpty ? atributosChaves : asStrList(esc['opcoes']))
        (a, atributosNomes[a] ?? a)
    else if (tipo == 'elemento')
      for (final el in asStrList(esc['opcoes']).isEmpty
          ? const ['Conhecimento', 'Energia', 'Morte', 'Sangue', 'Medo']
          : asStrList(esc['opcoes']))
        (el, el)
    else if (tipo == 'ritual')
      for (final r in f.rituais) (asStr(r['nome']), asStr(r['nome'])),
  ];
  if (opcoes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nada para escolher ainda (aprenda um ritual primeiro).')));
    return;
  }
  final antes = c.escolhasDe(e.chave);
  final novas = await escolherOpcoes(context,
      titulo: asStr(esc['rotulo'], 'Escolha'), opcoes: opcoes, quantas: quantas, atuais: antes);
  if (novas == null) return;
  final m = <String, dynamic>{
    'escolhasPoder': {...asMap(f.d['escolhasPoder']), e.chave: novas},
  };
  // Treinamento em Perícia: treina de verdade (sobe um grau) as escolhidas
  if (tipo == 'treino') {
    for (final p in antes.where((p) => !novas.contains(p))) {
      m['pericias.$p.grau'] = (f.grau(p) - 5).clamp(0, 15);
    }
    for (final p in novas.where((p) => !antes.contains(p))) {
      m['pericias.$p.grau'] = (f.grau(p) + 5).clamp(0, 15);
    }
  }
  Repo.setVarios(f.id, m);
}

/// Lista de opções com limite de escolhas.
Future<List<String>?> escolherOpcoes(BuildContext context,
    {required String titulo,
    required List<(String, String)> opcoes,
    required int quantas,
    required List<String> atuais}) {
  final sel = [...atuais.where((a) => opcoes.any((o) => o.$1 == a))];
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(quantas == 1 ? 'Escolha uma.' : 'Escolha até $quantas (${sel.length}/$quantas).',
                style: const TextStyle(color: Cores.textoFraco, fontSize: 13)),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final (v, rotulo) in opcoes)
                  CheckboxListTile(
                    dense: true,
                    value: sel.contains(v),
                    title: Text(rotulo),
                    onChanged: (marcar) => setState(() {
                      if (marcar == true) {
                        if (quantas == 1) sel.clear();
                        if (sel.length < quantas) sel.add(v);
                      } else {
                        sel.remove(v);
                      }
                    }),
                  ),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, sel), child: const Text('Salvar')),
        ],
      ),
    ),
  );
}

/// Aba PODERES & NOTAS: cada poder e habilidade é uma carta arcana (moldura
/// dupla na cor da afinidade, runa na arte, numeral romano e a tag do tipo).
/// Origem, classe e trilha entram sozinhas; o que elas fazem já conta na
/// ficha, e as que custam PE têm botão de usar ou de ativar.
class TabPoderes extends StatefulWidget {
  final CtxFicha ctx;
  const TabPoderes({super.key, required this.ctx});
  @override
  State<TabPoderes> createState() => _TabPoderesState();
}

class _TabPoderesState extends State<TabPoderes> {
  String? _grupo;
  bool _verOcultas = false;

  static const _grupos = ['Origem', 'Classe', 'Trilha', 'Geral', 'Paranormal', 'Própria'];

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final c = ctx.calc;
    final todas = entradasPoder(ctx);
    final visiveis = todas.where((e) => !c.ocultas.contains(e.chave)).toList();
    final ocultas = todas.where((e) => c.ocultas.contains(e.chave)).toList();
    final filtradas = [for (final e in visiveis) if (_grupo == null || e.grupo == _grupo) e];
    int conta(String g) => visiveis.where((e) => e.grupo == g).length;
    final ligadas = [for (final e in todas) if (c.ativos.contains(e.chave)) e];
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 28), children: [
      Text('Cartas arcanas', style: estiloTitulo(26, cor: Cores.texto)),
      const SizedBox(height: 4),
      Text('${visiveis.length} ${visiveis.length == 1 ? 'carta' : 'cartas'} · o que elas fazem já conta na ficha',
          style: estiloMaquina(12.5, cor: Cores.textoFraco)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        botoesAdicionarPoder(context, ctx),
        TextButton.icon(
          onPressed: () => _novaPropria(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Habilidade própria'),
        ),
      ]),
      if (ligadas.isNotEmpty) ...[
        const SizedBox(height: 12),
        _PainelAtivos(ctx: ctx, ligadas: ligadas),
      ],
      const SizedBox(height: 10),
      FaixaRolavel(altura: 42, quebrarAcima: 0, children: [
        for (final (g, rotulo) in [
          (null, 'Todas  ${visiveis.length}'),
          for (final g in _grupos)
            if (conta(g) > 0) (g, '$g  ${conta(g)}'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: ChoiceChip(
              label: Text(rotulo),
              selected: _grupo == g,
              onSelected: (_) => setState(() => _grupo = g),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      if (filtradas.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(todas.isEmpty ? 'Nenhum poder ainda.' : 'Nenhuma carta deste tipo.',
              textAlign: TextAlign.center, style: estiloMao(22, cor: Cores.textoFraco)),
        )
      else
        _grade(context, [for (final e in filtradas) (e, todas.indexOf(e) + 1)]),
      if (ocultas.isNotEmpty) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _verOcultas = !_verOcultas),
            style: TextButton.styleFrom(foregroundColor: Cores.textoFraco),
            icon: Icon(_verOcultas ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
            label: Text(_verOcultas
                ? 'Esconder as ocultas'
                : (ocultas.length == 1 ? '1 carta oculta (não conta na ficha)' : '${ocultas.length} cartas ocultas (não contam na ficha)')),
          ),
        ),
        if (_verOcultas) Opacity(opacity: 0.5, child: _grade(context, [for (final e in ocultas) (e, todas.indexOf(e) + 1)])),
      ],
      const SizedBox(height: 18),
      Secao(
        titulo: 'Anotações',
        acoes: [
          TextButton.icon(
            onPressed: () => abrirQuadroFicha(context, ctx),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Quadro'),
          ),
        ],
        child: CampoSync(
            valor: ctx.f.notas,
            maxLinhas: 14,
            dica: 'Pistas, NPCs, segredos...',
            estilo: estiloMao(21, cor: Cores.texto),
            aoSalvar: (v) => Repo.set(ctx.f.id, 'notas', v)),
      ),
    ]);
  }

  Widget _grade(BuildContext context, List<(EntradaPoder, int)> cartas) {
    final c = widget.ctx.calc;
    return LayoutBuilder(builder: (context, lim) {
      final colunas = (lim.maxWidth / 175).floor().clamp(2, 6);
      final largura = (lim.maxWidth - 10 * (colunas - 1)) / colunas;
      return Wrap(spacing: 10, runSpacing: 12, children: [
        for (final (e, n) in cartas)
          SizedBox(
            width: largura,
            child: CartaArcana(
              poder: e.carta,
              numero: n,
              elementoFicha: widget.ctx.f.elementoDaFicha,
              selos: _selos(e, c),
              ligado: c.ativos.contains(e.chave),
              aoTocar: () => _abrir(context, e),
              aoSegurar: () => _editar(context, e),
            ),
          ),
      ]);
    });
  }

  /// Selos da carta: AUTO (soma sozinha), ATIVÁVEL/ATIVO, custo e ESCOLHER.
  List<String> _selos(EntradaPoder e, Calc c) {
    final custo = c.custoPoder(e.meta);
    final ativavel = asMap(e.meta['ativavel']).isNotEmpty;
    final escolha = asMap(e.meta['escolha']).isNotEmpty;
    return [
      if (efeitosFixosDe(e, c).isNotEmpty) 'AUTO',
      if (ativavel) c.ativos.contains(e.chave) ? 'ATIVO' : 'ATIVÁVEL',
      if (custo != null && custo > 0) '$custo ${c.determinacao ? 'PD' : 'PE'}',
      if (escolha && c.escolhasDe(e.chave).isEmpty) 'ESCOLHER',
    ];
  }

  void _editar(BuildContext context, EntradaPoder e) {
    if (e.indicePoder != null) {
      editarPoder(context, widget.ctx, e.indicePoder!);
    } else if (e.propria) {
      _editarPropria(context, e);
    } else {
      _editarDoLivro(context, e);
    }
  }

  static const _camposPropria = [
    CampoDef('nome', 'Nome'),
    CampoDef('resumo', 'O que ela faz', tipo: TipoCampo.multi),
    CampoDef('fonte', 'Origem (opcional)', dica: 'ex.: poder do mestre, item amaldiçoado'),
  ];

  Future<void> _novaPropria(BuildContext context) async {
    final f = widget.ctx.f;
    final r = await editarFormulario(context, titulo: 'Nova habilidade', inicial: const {}, campos: _camposPropria);
    final d = r?.dados;
    if (d == null || asStr(d['nome']).trim().isEmpty) return;
    Repo.set(f.id, 'habilidadesProprias', [
      ...asMapList(f.d['habilidadesProprias']),
      {'id': novoId(), 'nome': asStr(d['nome']).trim(), 'resumo': asStr(d['resumo']).trim(), 'fonte': asStr(d['fonte']).trim()},
    ]);
  }

  Future<void> _editarPropria(BuildContext context, EntradaPoder e) async {
    final f = widget.ctx.f;
    final lista = asMapList(f.d['habilidadesProprias']);
    final i = lista.indexWhere((x) => asStr(x['id']) == e.chave);
    if (i < 0) return;
    final r = await editarFormulario(context,
        titulo: 'Editar habilidade', inicial: lista[i], campos: _camposPropria, podeApagar: true);
    if (r == null) return;
    if (r.apagar) {
      lista.removeAt(i);
    } else if (r.dados != null) {
      lista[i] = {
        ...lista[i],
        'nome': asStr(r.dados!['nome']).trim(),
        'resumo': asStr(r.dados!['resumo']).trim(),
        'fonte': asStr(r.dados!['fonte']).trim(),
      };
    } else {
      return;
    }
    Repo.set(f.id, 'habilidadesProprias', lista);
  }

  Future<void> _editarDoLivro(BuildContext context, EntradaPoder e) async {
    final f = widget.ctx.f;
    final r = await editarFormulario(context,
        titulo: 'Editar texto',
        inicial: {'nome': e.nome, 'resumo': asStr(e.carta['descricao'])},
        campos: const [
          CampoDef('nome', 'Nome'),
          CampoDef('resumo', 'O que ela faz', tipo: TipoCampo.multi),
        ]);
    final d = r?.dados;
    if (d == null) return;
    // grava o mapa inteiro: as chaves têm ":" e espaços
    Repo.set(f.id, 'habilidadesEditadas', {
      ...asMap(f.d['habilidadesEditadas']),
      e.chave: {'nome': asStr(d['nome']).trim(), 'resumo': asStr(d['resumo']).trim()},
    });
  }

  void _ocultar(EntradaPoder e, bool ocultar) {
    final c = widget.ctx.calc;
    final l = {...c.ocultas};
    ocultar ? l.add(e.chave) : l.remove(e.chave);
    Repo.set(widget.ctx.f.id, 'habilidadesOcultas', l.toList());
  }

  /// Carta aberta: texto inteiro, o que ela faz na ficha e as ações.
  void _abrir(BuildContext context, EntradaPoder e) {
    final ctx = widget.ctx;
    final c = ctx.calc;
    final f = ctx.f;
    final fixos = efeitosFixosDe(e, c);
    final quandoAtivo = efeitosAtivosDe(e, c);
    final ativavel = asMap(e.meta['ativavel']);
    final escolha = asMap(e.meta['escolha']);
    final custo = c.custoPoder(e.meta);
    final ligado = c.ativos.contains(e.chave);
    final escolhas = c.escolhasDe(e.chave);
    final oculta = c.ocultas.contains(e.chave);
    final temAfinidade = asStr(e.meta['afinidade']).isNotEmpty;
    final pontos = c.determinacao ? 'PD' : 'PE';
    String nomeEscolha(String v) => atributosNomes[v] ?? v;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx2) {
        void fechar(VoidCallback acao) {
          Navigator.pop(ctx2);
          acao();
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Runa(
                  elemento: _elementoDaCarta(e.carta, f.elementoDaFicha),
                  circulo: _circuloDaCarta(e.carta),
                  semente: e.nome,
                  tamanho: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        [e.grupo.toUpperCase(), if (asStr(e.carta['detalhe']).isNotEmpty) asStr(e.carta['detalhe'])]
                            .join(' · '),
                        style: estiloRotulo(12.5, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.2)),
                    Text(e.nome, style: estiloTitulo(21, cor: Cores.texto)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Text(asStr(e.carta['descricao'], 'Sem descrição.'), style: const TextStyle(fontSize: 14.5, height: 1.4)),
              if (fixos.isNotEmpty || quandoAtivo.isNotEmpty || escolha.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('NA FICHA', style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.6)),
                const SizedBox(height: 4),
                if (escolha.isNotEmpty)
                  _linha(Icons.tune, escolhas.isEmpty
                      ? '${asStr(escolha['rotulo'], 'Escolha')}: ainda não escolhido'
                      : '${asStr(escolha['rotulo'], 'Escolha')}: ${escolhas.map(nomeEscolha).join(', ')}'),
                for (final t in fixos) _linha(Icons.check_circle_outline, t),
                for (final t in quandoAtivo) _linha(ligado ? Icons.bolt : Icons.bolt_outlined, '$t (quando ativo)'),
                if (oculta) _linha(Icons.visibility_off_outlined, 'Oculta: não está contando na ficha.'),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (ativavel.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => fechar(() => _ativar(context, ctx, e)),
                    icon: Icon(ligado ? Icons.stop_circle_outlined : Icons.bolt, size: 18),
                    label: Text(ligado
                        ? 'Encerrar'
                        : (custo != null && custo > 0 ? 'Ativar (−$custo $pontos)' : 'Ativar')),
                  )
                else if (custo != null)
                  FilledButton.icon(
                    onPressed: () => fechar(() => _usar(context, ctx, e)),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(custo > 0 ? 'Usar (−$custo $pontos)' : 'Usar'),
                  ),
                if (escolha.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => fechar(() => _escolher(context, ctx, e)),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(escolhas.isEmpty ? 'Escolher' : 'Trocar escolha'),
                  ),
                if (e.indicePoder != null && temAfinidade)
                  OutlinedButton.icon(
                    onPressed: () => fechar(() => alternarAfinidadePoder(ctx, e.indicePoder!)),
                    icon: Icon(e.afinidade ? Icons.star : Icons.star_border, size: 18),
                    label: Text(e.afinidade ? 'Tirar afinidade' : 'Com afinidade'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => fechar(() => _editar(context, e)),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(e.doLivro ? 'Editar texto' : 'Editar'),
                ),
                if (e.doLivro && e.editada)
                  TextButton(
                    onPressed: () => fechar(() =>
                        Repo.set(f.id, 'habilidadesEditadas', {...asMap(f.d['habilidadesEditadas'])}..remove(e.chave))),
                    child: const Text('Voltar ao texto do livro'),
                  ),
                if (e.doLivro)
                  TextButton(
                    onPressed: () => fechar(() => _ocultar(e, !oculta)),
                    child: Text(oculta ? 'Mostrar de novo' : 'Ocultar'),
                  ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  static Widget _linha(IconData icone, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icone, size: 16, color: Cores.destaque)),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13.5))),
        ]),
      );
}

/// Poderes ativos agora, com encerrar um ou todos (fim da cena).
class _PainelAtivos extends StatelessWidget {
  final CtxFicha ctx;
  final List<EntradaPoder> ligadas;
  const _PainelAtivos({required this.ctx, required this.ligadas});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Cores.destaque.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Cores.destaque.withValues(alpha: 0.5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.bolt, size: 18, color: Cores.destaque),
            const SizedBox(width: 6),
            Expanded(
              child: Text('ATIVOS AGORA',
                  style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.8)),
            ),
            TextButton(
              onPressed: () => Repo.set(ctx.f.id, 'ativos', const <String>[]),
              child: const Text('Fim da cena'),
            ),
          ]),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in ligadas)
              InputChip(
                label: Text(e.nome),
                onDeleted: () => _ativar(context, ctx, e),
                deleteButtonTooltipMessage: 'Encerrar',
              ),
          ]),
        ]),
      );
}

String _elementoDaCarta(Map<String, dynamic> p, String elementoFicha) {
  final e = asStr(p['elemento']);
  if (e.isNotEmpty) return e;
  return elementoFicha.isEmpty ? 'medo' : elementoFicha;
}

int _circuloDaCarta(Map<String, dynamic> p) => switch (grupoPoder(p)) {
      'Paranormal' => asBool(p['afinidade']) ? 4 : 3,
      'Trilha' => 3,
      'Classe' => 2,
      _ => 1,
    };

/// Carta de um poder ou habilidade.
class CartaArcana extends StatelessWidget {
  final Map<String, dynamic> poder;
  final int numero;
  final String elementoFicha;
  final VoidCallback aoTocar, aoSegurar;
  /// AUTO, ATIVÁVEL/ATIVO, custo, ESCOLHER.
  final List<String> selos;
  /// Ativável ligado: a carta brilha.
  final bool ligado;
  const CartaArcana({
    super.key,
    required this.poder,
    required this.numero,
    required this.elementoFicha,
    required this.aoTocar,
    required this.aoSegurar,
    this.selos = const [],
    this.ligado = false,
  });

  @override
  Widget build(BuildContext context) {
    final grupo = grupoPoder(poder);
    final elemento = _elementoDaCarta(poder, elementoFicha);
    final corRuna = grupo == 'Paranormal' ? Runa.corDo(elemento) : Cores.destaque;
    final corTag = switch (grupo) {
      'Paranormal' => Runa.corDo(elemento),
      'Classe' => Cores.destaque,
      'Origem' => Cores.roxoClaro,
      'Trilha' => Cores.san,
      'Própria' => Cores.ok,
      _ => Cores.textoFraco,
    };
    final afinidade = asBool(poder['afinidade']);
    final tipo = asStr(poder['tipo']);
    return AspectRatio(
      aspectRatio: 0.62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: ligado ? [BoxShadow(color: Cores.destaque.withValues(alpha: 0.45), blurRadius: 14)] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: aoTocar,
            onLongPress: aoSegurar,
            child: CustomPaint(
              painter: _PintorMoldura(Cores.destaque),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(children: [
                  Text(romano(numero), style: estiloTitulo(14, cor: Cores.destaque, espaco: 2)),
                  const SizedBox(height: 6),
                  // arte da carta: a runa sobre um fundo escuro
                  Expanded(
                    flex: 5,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Cores.destaque.withValues(alpha: 0.35)),
                        gradient: RadialGradient(
                          colors: [corRuna.withValues(alpha: ligado ? 0.32 : 0.18), Colors.black.withValues(alpha: 0.55)],
                        ),
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        LayoutBuilder(
                          builder: (context, c) => Runa(
                            elemento: elemento,
                            circulo: _circuloDaCarta(poder),
                            semente: asStr(poder['nome']),
                            cor: corRuna,
                            tamanho: (c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth) * 0.82,
                          ),
                        ),
                        if (afinidade)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(Icons.star, size: 16, color: corRuna),
                          ),
                        if (selos.isNotEmpty)
                          Positioned(
                            left: 4,
                            right: 4,
                            bottom: 4,
                            child: Wrap(alignment: WrapAlignment.center, spacing: 3, runSpacing: 3, children: [
                              for (final s in selos) _Selinho(s, ativo: s == 'ATIVO'),
                            ]),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(asStr(poder['nome'], 'Poder'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: estiloTitulo(14.5, cor: Cores.texto, altura: 1.1)),
                  const SizedBox(height: 5),
                  Etiqueta(grupo == 'Classe' && tipo.isNotEmpty && tipo != 'Classe'
                      ? '${grupo.toUpperCase()} · ${tipo.toUpperCase()}'
                      : grupo.toUpperCase(), cor: corTag),
                  const SizedBox(height: 6),
                  Expanded(
                    flex: 3,
                    child: Text(asStr(poder['descricao']),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.fade,
                        style: const TextStyle(fontSize: 11.5, height: 1.3, color: Cores.textoFraco)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Selinho extends StatelessWidget {
  final String texto;
  final bool ativo;
  const _Selinho(this.texto, {this.ativo = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: ativo ? Cores.destaque : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Cores.destaque.withValues(alpha: 0.7)),
        ),
        child: Text(texto,
            style: estiloRotulo(10, cor: ativo ? Colors.black : Cores.destaque, peso: FontWeight.w700, espaco: 0.8)),
      );
}

/// Moldura dupla da carta, com cantos marcados.
class _PintorMoldura extends CustomPainter {
  final Color cor;
  _PintorMoldura(this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = Cores.painel);
    final fora = Paint()
      ..color = cor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final dentro = Paint()
      ..color = cor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(6)), fora);
    canvas.drawRect(r.deflate(5), dentro);
    final cheio = Paint()..color = cor;
    for (final c in [r.deflate(5).topLeft, r.deflate(5).topRight, r.deflate(5).bottomLeft, r.deflate(5).bottomRight]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 3.5)
          ..lineTo(c.dx + 3.5, c.dy)
          ..lineTo(c.dx, c.dy + 3.5)
          ..lineTo(c.dx - 3.5, c.dy)
          ..close(),
        cheio,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorMoldura old) => old.cor != cor;
}
