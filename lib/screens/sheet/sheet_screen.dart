import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import 'rolar.dart';
import 'tab_agente.dart';
import 'tab_listas.dart';
import 'tab_pericias.dart';

class TelaFicha extends StatelessWidget {
  final String fichaId;
  const TelaFicha({super.key, required this.fichaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Ficha?>(
      stream: Repo.ficha(fichaId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Sem acesso a esta ficha.\n${snap.error}')));
        }
        if (!snap.hasData) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final f = snap.data;
        if (f == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Ficha não encontrada.')));
        }
        final cid = f.campaignId;
        if (cid == null) return _Ficha(ctx: CtxFicha(f, null));
        return StreamBuilder<Campanha?>(
          stream: Repo.campanha(cid),
          builder: (context, cs) => _Ficha(ctx: CtxFicha(f, cs.data)),
        );
      },
    );
  }
}

class _Ficha extends StatelessWidget {
  final CtxFicha ctx;
  const _Ficha({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final calc = ctx.calc;
    final dono = f.ownerUid == Repo.uid;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.nome, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                  '${f.classe} • ${calc.resumoProgressao} • ${calc.patente.nome}${ctx.camp != null ? ' • ${ctx.camp!.nome}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'dup') {
                  final id = Repo.duplicarFicha(f);
                  if (context.mounted) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TelaFicha(fichaId: id)));
                  }
                } else if (v == 'sairMesa') {
                  Repo.desvincularFicha(f);
                } else if (v == 'apagar') {
                  if (await confirmar(
                      context, 'Apagar "${f.nome}" para sempre?')) {
                    Repo.apagarFicha(f.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'dup', child: Text('Duplicar ficha')),
                if (dono && f.campaignId != null)
                  const PopupMenuItem(
                      value: 'sairMesa', child: Text('Tirar da mesa')),
                if (dono)
                  const PopupMenuItem(
                      value: 'apagar', child: Text('Apagar ficha')),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'AGENTE'),
              Tab(text: 'PERÍCIAS'),
              Tab(text: 'COMBATE'),
              Tab(text: 'RITUAIS'),
              Tab(text: 'INVENTÁRIO'),
              Tab(text: 'PODERES & NOTAS'),
            ],
          ),
        ),
        body: Column(
          children: [
            BarrasTopo(ctx: ctx),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(children: [
                TabAgente(ctx: ctx),
                TabPericias(ctx: ctx),
                TabCombate(ctx: ctx),
                TabRituais(ctx: ctx),
                TabInventario(ctx: ctx),
                TabPoderes(ctx: ctx),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// PV / PE / SAN (ou PD) sempre visiveis no topo.
class BarrasTopo extends StatelessWidget {
  final CtxFicha ctx;
  const BarrasTopo({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final c = ctx.calc;
    final barras = <Widget>[
      BarraStatus(
          rotulo: 'PV',
          atual: f.pvAtual,
          max: c.pvMax,
          cor: Cores.pv,
          compacta: true,
          aoMudar: (v) => Repo.set(f.id, 'pvAtual', v)),
      if (c.determinacao)
        BarraStatus(
            rotulo: 'PD',
            atual: f.pdAtual,
            max: c.pdMax,
            cor: Cores.pd,
            compacta: true,
            aoMudar: (v) => Repo.set(f.id, 'pdAtual', v))
      else ...[
        BarraStatus(
            rotulo: 'PE',
            atual: f.peAtual,
            max: c.peMax,
            cor: Cores.pe,
            compacta: true,
            aoMudar: (v) => Repo.set(f.id, 'peAtual', v)),
        BarraStatus(
            rotulo: 'SAN',
            atual: f.sanAtual,
            max: c.sanMax,
            cor: Cores.san,
            compacta: true,
            aoMudar: (v) => Repo.set(f.id, 'sanAtual', v)),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          LayoutBuilder(builder: (context, cons) {
            if (cons.maxWidth < 560) {
              return Column(children: [
                for (final b in barras)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 4), child: b),
              ]);
            }
            return Row(children: [
              for (var i = 0; i < barras.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: barras[i]),
              ]
            ]);
          }),
          if (f.condicoes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (final cd in f.condicoes)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Cores.destaque.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(cd, style: const TextStyle(fontSize: 11)),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}
