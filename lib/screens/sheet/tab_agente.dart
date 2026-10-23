import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/efeitos.dart';
import '../../widgets/imagem.dart';
import '../../widgets/sigilos.dart';
import '../../widgets/runa.dart';
import 'afinidade.dart';
import 'forma.dart';
import 'habilidades.dart';
import 'rolar.dart';

class TabAgente extends StatelessWidget {
  final CtxFicha ctx;
  const TabAgente({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final c = ctx.calc;
    final cat = Catalogo.instance;
    final largo = MediaQuery.sizeOf(context).width >= 900;
    final classe = c.classeDados;

    Widget progressao;
    if (c.sobrevivente) {
      progressao = Seletor(
        rotulo: 'Estágio',
        valor: '${f.estagio}',
        opcoes: [for (var i = 1; i <= c.maxEstagio; i++) '$i'],
        aoMudar: (v) => Repo.set(f.id, 'estagio', int.parse(v)),
      );
    } else if (c.modoPatente) {
      progressao = InputDecorator(
        decoration: const InputDecoration(labelText: 'Patente (pelos PP)'),
        child: Text('${c.patente.nome} • limite PD ${c.patente.limitePD}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    } else if (c.modoNivel) {
      progressao = Seletor(
        rotulo: 'Nível',
        valor: '${f.nivel}',
        opcoes: [for (var i = 1; i <= 20; i++) '$i'],
        aoMudar: (v) => Repo.set(f.id, 'nivel', int.parse(v)),
      );
    } else {
      progressao = Seletor(
        rotulo: 'NEX',
        valor: '${f.nex}%',
        opcoes: [for (final n in nexValores) '$n%'],
        aoMudar: (v) => Repo.set(f.id, 'nex', int.parse(v.replaceAll('%', ''))),
      );
    }

    final mostraNexExposicao = c.modoNivel || c.modoPatente || c.sobrevivente;
    final mostraAfinidade = c.nexExposicao >= 50 || f.afinidade.isNotEmpty;

    final identidade = Secao(
      titulo: 'Identidade',
      child: Column(children: [
        CampoSync(
            valor: f.nome,
            rotulo: f.eTransformacao ? 'Nome da transformação' : 'Nome do agente',
            aoSalvar: (v) => Repo.set(f.id, 'nome', v)),
        const SizedBox(height: 10),
        CampoSync(
            valor: f.jogador,
            rotulo: 'Jogador',
            aoSalvar: (v) => Repo.set(f.id, 'jogador', v)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Seletor(
              rotulo: 'Classe',
              valor: f.classe,
              opcoes: nomesClasses(),
              aoMudar: (v) => Repo.setVarios(f.id, {'classe': v, 'trilha': ''}),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: progressao),
        ]),
        if (mostraNexExposicao || mostraAfinidade) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (mostraNexExposicao)
              Expanded(
                child: CampoNumero(
                    valor: f.nex,
                    rotulo: 'NEX (exposição %)',
                    aoSalvar: (v) => Repo.set(f.id, 'nex', v.clamp(0, 99))),
              ),
            if (mostraNexExposicao && mostraAfinidade) const SizedBox(width: 10),
            if (mostraAfinidade)
              Expanded(
                child: Seletor(
                  rotulo: 'Afinidade (NEX 50%)',
                  valor: f.afinidade,
                  opcoes: elementosAfinidade,
                  aoMudar: (v) => Repo.set(f.id, 'afinidade', v),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Seletor(
              rotulo: 'Origem',
              valor: f.origem,
              opcoes: [for (final o in cat.origens) asStr(o['nome'])],
              aoMudar: (v) {
                final m = <String, dynamic>{'origem': v};
                final o = cat.origemPorNome(v);
                for (final p in asStrList(o?['pericias'])) {
                  if (f.grau(p) < 5) m['pericias.$p.grau'] = 5;
                }
                Repo.setVarios(f.id, m);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Seletor(
              rotulo: c.sobrevivente ? 'Trilha (estágio 2)' : 'Trilha (NEX 10%)',
              valor: f.trilha,
              opcoes: [
                for (final t in cat.trilhasDaClasse(f.classe)) asStr(t['nome'])
              ],
              aoMudar: (v) => Repo.set(f.id, 'trilha', v),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: CampoNumero(
                valor: f.pp,
                rotulo: 'Pontos de prestígio',
                aoSalvar: (v) => Repo.set(f.id, 'pp', v)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Patente'),
              child: Text(
                  '${c.patente.nome} • crédito ${c.patente.credito}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              'Perícias da classe: ${asStr(classe?['periciasTexto'])}\nProficiências: ${asStr(classe?['proficiencias'])}',
              style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
        ),
      ]),
    );

    final modos = Secao(
      titulo: 'Modo de jogo',
      child: ctx.camp != null
          ? Row(children: [
              const Icon(Icons.lock_outline, size: 18, color: Cores.textoFraco),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${modosProgressao[c.modoProgressao]} • ${c.determinacao ? 'Sem sanidade (PD)' : 'Com sanidade'}\nDefinido pelo mestre da mesa.',
                    style: const TextStyle(fontSize: 13)),
              ),
            ])
          : Column(children: [
              Seletor(
                rotulo: 'Sanidade',
                valor: modosSanidade[c.determinacao ? 'pd' : 'san']!,
                opcoes: modosSanidade.values.toList(),
                aoMudar: (v) => Repo.set(f.id, 'modoSanidade',
                    v == modosSanidade['pd'] ? 'pd' : 'san'),
              ),
              const SizedBox(height: 10),
              Seletor(
                rotulo: 'Progressão',
                valor: modosProgressao[c.modoProgressao]!,
                opcoes: modosProgressao.values.toList(),
                aoMudar: (v) {
                  final modo = modosProgressao.entries
                      .firstWhere((e) => e.value == v)
                      .key;
                  final m = <String, dynamic>{'modoProgressao': modo};
                  if (modo == 'nivel' && f.modoProgressao == 'nex') {
                    m['nivel'] = (c.nivel).clamp(1, 20);
                  }
                  Repo.setVarios(f.id, m);
                },
              ),
              if (c.modoPatente)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                      'Evolução por patentes usa sempre Pontos de Determinação. A patente vem dos pontos de prestígio.',
                      style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
                ),
              if (c.modoNivel)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                      'O nível controla a classe; o NEX só sobe por exposição ao paranormal e traz alterações.',
                      style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
                ),
            ]),
    );

    final gastos = c.pontosAtributoGastos;
    final pontos = c.pontosAtributoIniciais;
    final atributos = Secao(
      titulo: 'Atributos',
      child: Column(children: [
        _CirculoAtributos(ctx: ctx),
        const SizedBox(height: 8),
        Text(
          'Toque para rolar • segure para modificadores • dois toques mudam o valor\nPontos distribuídos: $gastos (criação: $pontos, máx. 3; reduzir a 0 dá +1 ponto)',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              color: c.nivel <= 1 && gastos > pontos
                  ? Cores.destaque
                  : Cores.textoFraco),
        ),
      ]),
    );

    final treinadas = periciasDef.where((p) => f.grau(p.nome) >= 5).length;
    final stats = Secao(
      titulo: 'Estatísticas',
      acoes: [
        TextButton.icon(
          onPressed: () => Repo.mudarRecursos(f, {
            'pvAtual': c.pvMax,
            'peAtual': c.peMax,
            'sanAtual': c.sanMax,
            'pdAtual': c.pdMax,
          }),
          icon: const Icon(Icons.restore, size: 18),
          label: const Text('Recuperar tudo'),
        ),
      ],
      child: _Grade(children: [
        _Stat('DEFESA', '${c.defesa}'),
        _Stat('DESLOC.', '${c.deslocamento} m'),
        _Stat(c.determinacao ? 'LIMITE PD' : 'LIMITE PE', '${c.limitePE}/turno'),
        _Stat('DT RITUAIS', '${c.dtRitual}'),
        _Stat('CARGA', '${c.cargaAtual}/${c.cargaMax}', alerta: c.sobrecarregado),
        _Stat('TREINADAS', '$treinadas',
            dica:
                'Classe + origem. Classe permite ${c.periciasTreinadasPermitidas} à escolha'),
        if (!c.sobrevivente) _Stat('NÍVEL', '${c.nivel}', dica: 'Nível de classe usado nos cálculos'),
      ]),
    );

    final dossie = _Dossie(ctx: ctx);
    final afinidade = SecaoAfinidade(ctx: ctx);
    final transformacoes = SecaoTransformacoes(ctx: ctx);
    final habilidades = SecaoHabilidades(ctx: ctx);
    final alteracoes = c.modoNivel ? _secaoAlteracoes(c) : null;

    final condicoes = Secao(
      titulo: 'Condições',
      acoes: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: () => editarCondicoes(context, f),
        )
      ],
      child: f.condicoes.isEmpty
          ? const Text('Nenhuma condição.',
              style: TextStyle(color: Cores.textoFraco))
          : Wrap(spacing: 6, runSpacing: 6, children: [
              for (final cd in f.condicoes)
                Tooltip(
                  message: asStr(cat.condicao(cd)?['resumo']),
                  child: InputChip(
                    label: Text(cd),
                    onDeleted: () => Repo.set(f.id, 'condicoes',
                        f.condicoes.where((x) => x != cd).toList()),
                  ),
                ),
            ]),
    );

    final bonus = Card(
      child: ExpansionTile(
        title: const Text('BÔNUS MANUAIS',
            style: TextStyle(
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                color: Cores.textoFraco,
                fontSize: 12)),
        subtitle: const Text(
            'Ajustes que o app não calcula sozinho',
            style: TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in const {
              'pv': 'PV máx.',
              'pe': 'PE máx.',
              'san': 'SAN máx.',
              'pd': 'PD máx.',
              'defesa': 'Defesa',
              'deslocamento': 'Desloc. (m)',
              'limitePE': 'Limite PE',
              'carga': 'Carga',
              'dtRitual': 'DT rituais',
            }.entries)
              SizedBox(
                width: 110,
                child: CampoNumero(
                    valor: f.b(e.key),
                    rotulo: e.value,
                    aoSalvar: (v) => Repo.set(f.id, 'bonus.${e.key}', v)),
              ),
          ]),
        ],
      ),
    );

    final historia = Secao(
      titulo: 'Aparência e história',
      child: Column(children: [
        CampoSync(
            valor: asStr(f.d['aparencia']),
            rotulo: 'Aparência',
            maxLinhas: 4,
            aoSalvar: (v) => Repo.set(f.id, 'aparencia', v)),
        const SizedBox(height: 10),
        CampoSync(
            valor: asStr(f.d['historia']),
            rotulo: 'História',
            maxLinhas: 8,
            aoSalvar: (v) => Repo.set(f.id, 'historia', v)),
      ]),
    );

    if (largo) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(children: [
            for (final (i, w) in [dossie, afinidade, identidade, transformacoes, modos, habilidades, if (alteracoes != null) alteracoes, historia].indexed)
              Surgir(ordem: i, child: w),
          ])),
          const SizedBox(width: 12),
          Expanded(
              child: Column(children: [
            for (final (i, w) in [atributos, stats, condicoes, bonus].indexed) Surgir(ordem: i + 1, child: w),
          ])),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final (i, w) in [
          dossie,
          afinidade,
          atributos,
          stats,
          identidade,
          transformacoes,
          modos,
          habilidades,
          if (alteracoes != null) alteracoes,
          condicoes,
          bonus,
          historia,
        ].indexed)
          Surgir(ordem: i, child: w),
      ],
    );
  }

  Widget _secaoAlteracoes(Calc c) {
    final f = ctx.f;
    final escolhas = asMap(f.d['escolhas']);
    final alts = c.alteracoesNex;
    return Secao(
      titulo: 'Alterações de NEX',
      child: alts.isEmpty
          ? const Text('Nenhuma alteração ainda (a primeira vem com NEX 25%).',
              style: TextStyle(color: Cores.textoFraco))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final a in alts) ...[
                Text(
                    'NEX ${asInt(a['nex'])}%${a['elemento'] != null ? ' • ${asStr(a['elemento'])}' : ''}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: Cores.destaque)),
                Text(asStr(a['resumo']), style: const TextStyle(fontSize: 13)),
                for (final e in asMapList(a['efeitos']))
                  if (asStr(e['alvo']) == 'escolhaPenalidade')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Seletor(
                        rotulo: 'Perícia com −5',
                        valor: asStr(escolhas[asStr(e['chave'])]),
                        opcoes: asStrList(e['opcoes']),
                        aoMudar: (v) =>
                            Repo.set(f.id, 'escolhas.${asStr(e['chave'])}', v),
                      ),
                    )
                  else if (asStr(e['alvo']) == 'escolhaAtributoPE')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Seletor(
                        rotulo: 'Atributo somado aos PE',
                        valor: atributosNomes[asStr(escolhas[asStr(e['chave'])])] ?? '',
                        opcoes: [
                          for (final k in atributosChaves)
                            if (k != 'pre') atributosNomes[k]!
                        ],
                        aoMudar: (v) => Repo.set(
                            f.id,
                            'escolhas.${asStr(e['chave'])}',
                            atributosNomes.entries
                                .firstWhere((x) => x.value == v)
                                .key),
                      ),
                    ),
                const SizedBox(height: 10),
              ],
            ]),
    );
  }
}

Future<void> editarCondicoes(BuildContext context, Ficha f) async {
  final sel = {...f.condicoes};
  final cat = Catalogo.instance;
  final r = await showDialog<Set<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Condições'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in nomesCondicoes())
                Tooltip(
                  message: asStr(cat.condicao(c)?['resumo']),
                  child: FilterChip(
                    label: Text(c),
                    selected: sel.contains(c),
                    onSelected: (v) => set(() => v ? sel.add(c) : sel.remove(c)),
                  ),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, sel),
              child: const Text('Salvar')),
        ],
      ),
    ),
  );
  if (r != null) Repo.set(f.id, 'condicoes', r.toList());
}

/// Atributos num círculo ritual, como no CRIS original: AGI no topo e os
/// outros em volta, no sentido horário.
class _CirculoAtributos extends StatelessWidget {
  final CtxFicha ctx;
  const _CirculoAtributos({required this.ctx});

  static const _ordem = ['agi', 'int', 'vig', 'pre', 'for'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final lado = c.maxWidth < 340 ? c.maxWidth : 340.0;
      final meio = lado / 2;
      final anel = lado * 0.33;
      final raio = lado * 0.135;
      final centro = lado * 0.17;
      return Center(
        child: SizedBox(
          width: lado,
          height: lado,
          child: Stack(children: [
            Positioned.fill(
                child: CustomPaint(painter: _PintorCirculo(anel / lado))),
            Positioned(
              left: meio - centro,
              top: meio - centro,
              width: centro * 2,
              height: centro * 2,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Color.lerp(Cores.painel2, Cores.roxo, 0.25)!,
                    Cores.painel2,
                  ]),
                  border: Border.all(color: Cores.roxoClaro.withValues(alpha: 0.45), width: 1.2),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  SigiloConhecimento(
                      tamanho: centro * 1.7,
                      cor: Cores.roxoClaro.withValues(alpha: 0.22),
                      espessura: 1),
                  Text('Atributos', style: estiloTitulo(lado * 0.04, cor: Cores.texto, espaco: 0.6)),
                ]),
              ),
            ),
            for (var i = 0; i < _ordem.length; i++)
              Positioned(
                left: meio + anel * cos(-pi / 2 + 2 * pi * i / 5) - raio,
                top: meio + anel * sin(-pi / 2 + 2 * pi * i / 5) - raio,
                width: raio * 2,
                height: raio * 2,
                child: Surgir(crescer: true, ordem: i + 2, child: _BolhaAtributo(ctx: ctx, chave: _ordem[i], lado: lado)),
              ),
          ]),
        ),
      );
    });
  }
}

class _BolhaAtributo extends StatelessWidget {
  final CtxFicha ctx;
  final String chave;
  final double lado;
  const _BolhaAtributo(
      {required this.ctx, required this.chave, required this.lado});

  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final v = f.attr(chave);
    final efetivo = ctx.calc.attr(chave);
    return Material(
      shape: CircleBorder(
          side: BorderSide(color: Cores.destaque.withValues(alpha: 0.75), width: 1.6)),
      color: Color.lerp(Cores.painel2, Cores.fundo, 0.3),
      shadowColor: Cores.destaque,
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => ctx.rolarAtributo(context, chave),
        onLongPress: () async {
          final m = await pedirModificadores(context);
          if (m != null && context.mounted) {
            ctx.rolarAtributo(context, chave,
                dadosExtra: m.dados, bonusExtra: m.bonus);
          }
        },
        onDoubleTap: () async {
          final n = await pedirNumero(context, atributosNomes[chave]!, v);
          if (n != null) Repo.set(f.id, 'atributos.$chave', n < 0 ? 0 : n);
        },
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(efetivo == v ? '$v' : '$efetivo',
              style: estiloTitulo(lado * 0.088,
                  cor: efetivo == v ? Cores.texto : Cores.ok, peso: FontWeight.w800, altura: 1)),
          const SizedBox(height: 2),
          Text(atributosSigla[chave]!,
              style: estiloRotulo(lado * 0.04, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.6)),
        ]),
      ),
    );
  }
}

/// Anéis com marcas e o pentágono que liga os atributos.
class _PintorCirculo extends CustomPainter {
  final double anel; // raio do anel dos atributos, em fração do lado
  _PintorCirculo(this.anel);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final l = size.shortestSide;
    final traco = Paint()
      ..color = Cores.destaque.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final fraco = Paint()
      ..color = Cores.roxoClaro.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(c, l * 0.49, traco);
    canvas.drawCircle(c, l * 0.455, fraco);
    canvas.drawCircle(c, l * anel, traco);
    for (var i = 0; i < 60; i++) {
      final a = 2 * pi * i / 60;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(
          c + d * l * 0.458, c + d * l * (i % 5 == 0 ? 0.487 : 0.472), fraco);
    }
    final penta = Path();
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + 2 * pi * i / 5;
      final p = c + Offset(cos(a), sin(a)) * l * anel;
      if (i == 0) {
        penta.moveTo(p.dx, p.dy);
      } else {
        penta.lineTo(p.dx, p.dy);
      }
    }
    penta.close();
    canvas.drawPath(penta, fraco);
  }

  @override
  bool shouldRepaint(covariant _PintorCirculo old) => old.anel != anel;
}

class _Stat extends StatelessWidget {
  final String rotulo;
  final String valor;
  final bool alerta;
  final String? dica;
  const _Stat(this.rotulo, this.valor, {this.alerta = false, this.dica});
  @override
  Widget build(BuildContext context) {
    final w = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: alerta ? Cores.destaque.withValues(alpha: 0.16) : Cores.painel2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: alerta ? Cores.destaque.withValues(alpha: 0.7) : Cores.borda),
      ),
      child: Column(children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(valor, style: estiloNumero(24, cor: Cores.texto))),
        const SizedBox(height: 5),
        Text(rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: estiloRotulo(11.5, cor: Cores.textoFraco, espaco: 1.3)),
      ]),
    );
    return dica == null ? w : Tooltip(message: dica!, child: w);
  }
}

/// Grade que reparte a largura entre os blocos (3 por linha no celular).
class _Grade extends StatelessWidget {
  final List<Widget> children;
  const _Grade({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final colunas = (c.maxWidth / 112).floor().clamp(3, 6);
        final largura = (c.maxWidth - 8 * (colunas - 1)) / colunas;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in children) SizedBox(width: largura, child: w),
        ]);
      });
}

/// Número de arquivo fixo para cada ficha (só decoração, como nos dossiês).
String numeroArquivo(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return (h % 10000).toString().padLeft(4, '0');
}

/// Topo da aba AGENTE, como uma ficha de arquivo da Ordem: retrato preso com
/// fita, número de arquivo, nome gasto e o NEX num selo hexagonal.
class _Dossie extends StatelessWidget {
  final CtxFicha ctx;
  const _Dossie({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final c = ctx.calc;
    final detalhes = [f.classe, f.trilha].where((s) => s.isNotEmpty).join(' · ');
    final elemento = f.elementoDaFicha;
    // o que vai no selo hexagonal, conforme o modo de progressão
    final (rotuloSelo, valorSelo) = c.sobrevivente
        ? ('ESTÁGIO', '${f.estagio}')
        : c.modoPatente
            ? ('PP', '${f.pp}')
            : c.modoNivel
                ? ('NÍVEL', '${c.nivel}')
                : ('NEX', '${f.nex}%');
    final camera = Material(
      color: Cores.destaque,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => opcoesFoto(context, f),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(f.foto.isEmpty ? Icons.add_a_photo_outlined : Icons.photo_camera_outlined,
              size: 18, color: Cores.sobreDestaque),
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 7, 12),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: Cores.painel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cores.borda),
        boxShadow: [
          BoxShadow(
              color: (f.eTransformacao ? Cores.roxoClaro : Cores.roxo).withValues(alpha: 0.6),
              offset: const Offset(7, 7)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(children: [
          if (f.foto.isNotEmpty) ...[
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26, tileMode: TileMode.decal),
                child: Opacity(opacity: 0.5, child: FotoEnquadrada(id: f.foto, ajuste: f.fotoAjuste)),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Cores.painel.withValues(alpha: 0.35), Cores.painel.withValues(alpha: 0.94)],
                  ),
                ),
              ),
            ),
          ],
          // runa grande e apagada da afinidade, como marca-d'água
          Positioned(
            right: -130,
            bottom: -125,
            child: Runa(
              elemento: elemento.isEmpty ? 'medo' : elemento,
              circulo: f.seloCirculo,
              semente: f.nome,
              cor: Cores.destaque.withValues(alpha: 0.06),
              tamanho: 260,
              espessura: 1.3,
            ),
          ),
          // selo do agente no canto
          Positioned(
            top: 14,
            right: 14,
            child: Column(children: [
              Runa(
                elemento: elemento.isEmpty ? 'medo' : elemento,
                circulo: f.seloCirculo,
                semente: f.nome,
                cor: elemento.isEmpty ? Cores.textoFraco : Cores.destaque,
                tamanho: 52,
              ),
              const SizedBox(height: 3),
              Text(elemento.isEmpty ? 'SEM AFINIDADE' : elemento.toUpperCase(),
                  style: estiloRotulo(10, cor: elemento.isEmpty ? Cores.textoFraco : Cores.destaque,
                      peso: FontWeight.w700, espaco: 1.4)),
            ]),
          ),
          if (f.eTransformacao)
            Positioned(
              right: 14,
              bottom: 14,
              child: Transform.rotate(
                angle: -0.14,
                child: Gasto(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(border: Border.all(color: Cores.roxoClaro, width: 2)),
                    child: Text('TRANSFORMAÇÃO', style: estiloMaquina(14, cor: Cores.roxoClaro, espaco: 1.5)),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 16, 20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Transform.rotate(
                angle: -0.035,
                child: Stack(clipBehavior: Clip.none, children: [
                  RetratoFicha(
                    foto: f.foto,
                    nome: f.nome,
                    ajuste: f.fotoAjuste,
                    largura: 112,
                    transformacao: f.eTransformacao,
                    aoTocar: () => opcoesFoto(context, f),
                    canto: camera,
                    heroi: 'retrato-${f.id}',
                  ),
                  const Positioned(top: -11, left: 26, child: Fita(largura: 58)),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 52),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ARQUIVO Nº ${numeroArquivo(f.id)}',
                      style: estiloMaquina(12.5, cor: Cores.textoFraco, espaco: 1)),
                  const SizedBox(height: 6),
                  Gasto(child: Text(f.nome, style: estiloTitulo(24, cor: Cores.texto, peso: FontWeight.w800, altura: 1.1))),
                  if (detalhes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(detalhes,
                        style: estiloRotulo(16, cor: Cores.textoFraco, peso: FontWeight.w500, espaco: 0.4)),
                  ],
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Hexagono(valorSelo, rotulo: rotuloSelo, tamanho: 54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        if (c.modoNivel) Selo('NEX ${f.nex}%'),
                        Selo(c.patente.nome, cor: Cores.roxoClaro),
                        if (f.origem.isNotEmpty) Selo(f.origem, cor: Cores.textoFraco),
                      ]),
                    ),
                  ]),
                  if (f.jogador.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('JOGADOR: ${f.jogador}',
                        overflow: TextOverflow.ellipsis,
                        style: estiloMaquina(12.5, cor: Cores.textoFraco, espaco: 0.8)),
                  ],
                ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
