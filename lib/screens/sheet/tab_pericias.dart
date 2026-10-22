import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import 'rolar.dart';

class TabPericias extends StatelessWidget {
  final CtxFicha ctx;
  const TabPericias({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Toque no nome para rolar (segure para modificadores) e no treino para mudar. '),
              TextSpan(text: '* só treinada. ', style: TextStyle(fontWeight: FontWeight.w700)),
              WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(Icons.backpack_outlined, size: 14, color: Cores.textoFraco)),
              TextSpan(text: ' sofre penalidade de carga.'),
            ]),
            style: TextStyle(fontSize: 12.5, color: Cores.textoFraco),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (k, p) in periciasDef.indexed) ...[
              if (k > 0) const Divider(indent: 14, endIndent: 14),
              _LinhaPericia(ctx: ctx, p: p),
            ],
          ]),
        ),
      ],
    );
  }
}

class _LinhaPericia extends StatelessWidget {
  final CtxFicha ctx;
  final PericiaDef p;
  const _LinhaPericia({required this.ctx, required this.p});

  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final c = ctx.calc;
    final treinada = f.grau(p.nome) > 0;
    final bonus = c.bonusPericia(p.nome);
    final dados = c.dadosPericia(p.nome);
    final outros = f.bonusPericia(p.nome);
    return InkWell(
      onTap: () => ctx.rolarPericia(context, p.nome),
      onLongPress: () async {
        final m = await pedirModificadores(context);
        if (m != null && context.mounted) {
          ctx.rolarPericia(context, p.nome, dadosExtra: m.dados, bonusExtra: m.bonus);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        child: Row(children: [
          Icon(Icons.casino_outlined,
              size: 18, color: treinada ? Cores.destaque : Cores.textoFraco.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text('${p.nome}${p.soTreinada ? '*' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: treinada ? FontWeight.w700 : FontWeight.w500,
                          color: treinada ? Cores.texto : Cores.texto.withValues(alpha: 0.85))),
                ),
                if (p.carga) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.backpack_outlined, size: 14, color: Cores.textoFraco),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${atributosSigla[p.attr]} · ${dados <= 0 ? 2 - dados : dados}d20${dados <= 0 ? ' (pior)' : ''}',
                  style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w500, espaco: 0.8)),
            ]),
          ),
          _ChipGrau(
            grau: f.grau(p.nome),
            aoMudar: (g) => Repo.set(f.id, 'pericias.${p.nome}.grau', g),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Outros bônus',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                final v = await pedirNumero(context, 'Outros bônus: ${p.nome}', outros);
                if (v != null) Repo.set(f.id, 'pericias.${p.nome}.bonus', v);
              },
              child: Container(
                width: 38,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Cores.borda),
                ),
                child: Text(outros == 0 ? '±' : (outros > 0 ? '+$outros' : '$outros'),
                    style: estiloNumero(14, cor: outros == 0 ? Cores.textoFraco : Cores.texto)),
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text('${bonus >= 0 ? '+' : ''}$bonus',
                textAlign: TextAlign.right,
                style: estiloNumero(22, cor: treinada || bonus != 0 ? Cores.texto : Cores.textoFraco)),
          ),
        ]),
      ),
    );
  }
}

class _ChipGrau extends StatelessWidget {
  final int grau;
  final ValueChanged<int> aoMudar;
  const _ChipGrau({required this.grau, required this.aoMudar});
  @override
  Widget build(BuildContext context) {
    final cores = {
      0: Cores.textoFraco,
      5: Cores.ok,
      10: Cores.san,
      15: Cores.pe,
    };
    final cor = cores[grau] ?? Cores.textoFraco;
    return PopupMenuButton<int>(
      tooltip: 'Grau de treinamento',
      onSelected: aoMudar,
      itemBuilder: (_) => [
        for (final e in grausTreino.entries)
          PopupMenuItem(value: e.key, child: Text('${e.value} (+${e.key})')),
      ],
      child: Container(
        width: 62,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: cor.withValues(alpha: grau == 0 ? 0.35 : 0.7)),
          color: cor.withValues(alpha: grau == 0 ? 0.04 : 0.12),
        ),
        child: Text(
          const {0: 'DESTR.', 5: 'TREIN.', 10: 'VETER.', 15: 'EXPERT'}[grau] ?? '+$grau',
          style: estiloRotulo(12.5, cor: cor, peso: FontWeight.w700, espaco: 1),
        ),
      ),
    );
  }
}
