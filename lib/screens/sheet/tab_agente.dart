import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
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
    final largo = MediaQuery.sizeOf(context).width >= 900;

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
              opcoes: classes,
              aoMudar: (v) => Repo.setVarios(f.id, {'classe': v, 'trilha': ''}),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Seletor(
              rotulo: 'NEX',
              valor: '${f.nex}%',
              opcoes: [for (final n in nexValores) '$n%'],
              aoMudar: (v) =>
                  Repo.set(f.id, 'nex', int.parse(v.replaceAll('%', ''))),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Seletor(
              rotulo: 'Origem',
              valor: f.origem,
              opcoes: origens.keys.toList(),
              aoMudar: (v) {
                final m = <String, dynamic>{'origem': v};
                for (final p in origens[v] ?? const <String>[]) {
                  if (f.grau(p) < 5) m['pericias.$p.grau'] = 5;
                }
                Repo.setVarios(f.id, m);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Seletor(
              rotulo: 'Trilha (NEX 10%)',
              valor: f.trilha,
              opcoes: trilhas[f.classe] ?? const [],
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
        Text('Perícias da classe: ${classesPericiasTexto[f.classe] ?? ''}',
            style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
      ]),
    );

    final gastos = c.pontosAtributoGastos;
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
          'Toque para rolar • segure para modificadores\nPontos distribuídos: $gastos (criação: 4, máx. 3; reduzir a 0 dá +1 ponto)',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              color: f.nex <= 5 && gastos > 4 ? Cores.destaque : Cores.textoFraco),
        ),
      ]),
    );

    final treinadas =
        periciasDef.where((p) => f.grau(p.nome) >= 5).length;
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
        _Stat('LIMITE PE', '${c.limitePE}/turno'),
        _Stat('DT RITUAIS', '${c.dtRitual}'),
        _Stat('CARGA', '${c.cargaAtual}/${c.cargaMax}',
            alerta: c.sobrecarregado),
        _Stat('TREINADAS', '$treinadas',
            dica: 'Classe + origem. Classe permite ${c.periciasTreinadasPermitidas} à escolha'),
      ]),
    );

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
                InputChip(
                  label: Text(cd),
                  onDeleted: () => Repo.set(f.id, 'condicoes',
                      f.condicoes.where((x) => x != cd).toList()),
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
            'Poderes, itens e regras que mudam os valores calculados',
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
          Expanded(child: Column(children: [identidade, historia])),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [atributos, stats, condicoes, bonus])),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [atributos, stats, identidade, condicoes, bonus, historia],
    );
  }
}

Future<void> editarCondicoes(BuildContext context, Ficha f) async {
  final sel = {...f.condicoes};
  final r = await showDialog<Set<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Condições'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in condicoesLista)
                FilterChip(
                  label: Text(c),
                  selected: sel.contains(c),
                  onSelected: (v) => set(() => v ? sel.add(c) : sel.remove(c)),
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
              Text('$v',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900, height: 1)),
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
