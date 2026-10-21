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
    final f = ctx.f;
    final c = ctx.calc;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Toque no nome para rolar (segure para modificadores). Toque no grau para mudar o treino. '
            '* só pode ser usada treinada. ⚖ sofre penalidade de carga.',
            style: const TextStyle(fontSize: 12, color: Cores.textoFraco),
          ),
        ),
        for (final p in periciasDef)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () => ctx.rolarPericia(context, p.nome),
                    onLongPress: () async {
                      final m = await pedirModificadores(context);
                      if (m != null && context.mounted) {
                        ctx.rolarPericia(context, p.nome,
                            dadosExtra: m.dados, bonusExtra: m.bonus);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Icon(Icons.casino_outlined,
                            size: 18, color: Cores.destaque),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${p.nome}${p.soTreinada ? '*' : ''}${p.carga ? ' ⚖' : ''}',
                            style: TextStyle(
                                fontWeight: f.grau(p.nome) > 0
                                    ? FontWeight.w800
                                    : FontWeight.w400),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('(${atributosSigla[p.attr]})',
                            style: const TextStyle(
                                color: Cores.textoFraco, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
                _ChipGrau(
                  grau: f.grau(p.nome),
                  aoMudar: (g) => Repo.set(f.id, 'pericias.${p.nome}.grau', g),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 54,
                  child: CampoNumero(
                    valor: f.bonusPericia(p.nome),
                    rotulo: 'outros',
                    aoSalvar: (v) =>
                        Repo.set(f.id, 'pericias.${p.nome}.bonus', v),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Column(children: [
                    Text(
                      '${c.bonusPericia(p.nome) >= 0 ? '+' : ''}${c.bonusPericia(p.nome)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${c.dadosPericia(p.nome) <= 0 ? 2 - c.dadosPericia(p.nome) : c.dadosPericia(p.nome)}d20',
                      style: const TextStyle(
                          fontSize: 11, color: Cores.textoFraco),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
      ],
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
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cor),
          color: cor.withValues(alpha: 0.12),
        ),
        child: Text(
          const {0: 'DESTR.', 5: 'TREIN.', 10: 'VETER.', 15: 'EXPERT'}[grau] ?? '+$grau',
          textAlign: TextAlign.center,
          style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
