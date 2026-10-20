import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
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
            rotulo: 'Nome do agente',
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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in atributosChaves) _CaixaAtributo(ctx: ctx, chave: k),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Toque para rolar • segure para modificadores\nPontos distribuídos: $gastos (criação: $pontos, máx. 3; reduzir a 0 dá +1 ponto)',
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
          onPressed: () => Repo.setVarios(f.id, {
            'pvAtual': c.pvMax,
            'peAtual': c.peMax,
            'sanAtual': c.sanMax,
            'pdAtual': c.pdMax,
          }),
          icon: const Icon(Icons.restore, size: 18),
          label: const Text('Recuperar tudo'),
        ),
      ],
      child: Wrap(spacing: 8, runSpacing: 8, children: [
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

    final habilidades = _secaoHabilidades(context, c);
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
              child: Column(
                  children: [identidade, modos, habilidades, if (alteracoes != null) alteracoes, historia])),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [atributos, stats, condicoes, bonus])),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        atributos,
        stats,
        identidade,
        modos,
        habilidades,
        if (alteracoes != null) alteracoes,
        condicoes,
        bonus,
        historia
      ],
    );
  }

  Widget _secaoHabilidades(BuildContext context, Calc c) {
    final f = ctx.f;
    final linhas = <Widget>[];
    void hab(String titulo, String resumo, {String? origem}) {
      linhas.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(resumo, style: const TextStyle(fontSize: 13)),
          if (origem != null)
            Text(origem,
                style: const TextStyle(fontSize: 11, color: Cores.textoFraco)),
        ]),
      ));
    }

    final o = c.origemDados;
    if (o != null) {
      final p = asMap(o['poder']);
      hab('${asStr(p['nome'])} (origem ${asStr(o['nome'])})', asStr(p['resumo']),
          origem: Catalogo.fonteCurta(o));
    }
    final cd = c.classeDados;
    if (cd != null) {
      final limite = c.sobrevivente ? f.estagio : c.nexClasse;
      for (final h in asMapList(cd['habilidades'])) {
        if (asInt(h['nex']) > limite) continue;
        hab(asStr(h['nome']), asStr(h['resumo']), origem: Catalogo.fonteCurta(cd));
      }
    }
    final t = c.trilhaDados;
    if (t != null) {
      for (final h in asMapList(t['habilidades'])) {
        if (!c.trilhaLiberada(asInt(h['nex']))) continue;
        final rotulo = c.sobrevivente ? 'estágio ${asInt(h['nex'])}' : 'NEX ${asInt(h['nex'])}%';
        hab('${asStr(h['nome'])} (${asStr(t['nome'])}, $rotulo)', asStr(h['resumo']),
            origem: Catalogo.fonteCurta(t));
      }
    }
    final prog = c.progressaoAtual;
    return Secao(
      titulo: 'Habilidades',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (linhas.isEmpty)
          const Text('Escolha classe, origem e trilha para ver as habilidades.',
              style: TextStyle(color: Cores.textoFraco)),
        ...linhas,
        if (prog.isNotEmpty)
          Card(
            color: Cores.painel2,
            margin: const EdgeInsets.only(top: 8),
            child: ExpansionTile(
              dense: true,
              title: const Text('Progressão recebida',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              children: [
                for (final p in prog)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(p, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
      ]),
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
                    style: const TextStyle(
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

class _CaixaAtributo extends StatelessWidget {
  final CtxFicha ctx;
  final String chave;
  const _CaixaAtributo({required this.ctx, required this.chave});
  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final v = f.attr(chave);
    final efetivo = ctx.calc.attr(chave);
    return Container(
      width: 92,
      decoration: BoxDecoration(
        color: Cores.painel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Cores.borda),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          onTap: () => ctx.rolarAtributo(context, chave),
          onLongPress: () async {
            final m = await pedirModificadores(context);
            if (m != null && context.mounted) {
              ctx.rolarAtributo(context, chave,
                  dadosExtra: m.dados, bonusExtra: m.bonus);
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Column(children: [
              Text(efetivo == v ? '$v' : '$efetivo',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: efetivo == v ? Cores.texto : Cores.ok)),
              Text(atributosSigla[chave]!,
                  style: const TextStyle(
                      color: Cores.destaque,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
            ]),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed:
                v > 0 ? () => Repo.set(f.id, 'atributos.$chave', v - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: () => Repo.set(f.id, 'atributos.$chave', v + 1),
            icon: const Icon(Icons.add),
          ),
        ]),
      ]),
    );
  }
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
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: alerta ? Cores.destaque.withValues(alpha: 0.2) : Cores.painel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alerta ? Cores.destaque : Cores.borda),
      ),
      child: Column(children: [
        Text(valor,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(rotulo,
            style: const TextStyle(
                fontSize: 10, letterSpacing: 1, color: Cores.textoFraco)),
      ]),
    );
    return dica == null ? w : Tooltip(message: dica!, child: w);
  }
}
