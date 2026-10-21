import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/cris_import.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/imagem.dart';
import 'forma.dart';
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
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(children: [
            AvatarFicha(
              foto: f.foto,
              nome: f.nome,
              tamanho: 40,
              transformacao: f.eTransformacao,
              aoTocar: () => opcoesFoto(context, f),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                      '${f.eTransformacao ? 'Transformação • ' : ''}${f.classe} • ${calc.resumoProgressao} • ${calc.patente.nome}${ctx.camp != null ? ' • ${ctx.camp!.nome}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
                ],
              ),
            ),
          ]),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'foto') {
                  await opcoesFoto(context, f);
                } else if (v == 'transformar') {
                  await novaTransformacao(context, f);
                } else if (v == 'dup') {
                  final id = Repo.duplicarFicha(f);
                  if (context.mounted) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TelaFicha(fichaId: id)));
                  }
                } else if (v == 'cris') {
                  if (!await confirmar(context,
                      'Trazer de novo os dados do site do CRIS? Atributos, perícias, listas e anotações desta ficha serão trocados pelos de lá.')) {
                    return;
                  }
                  try {
                    final a = await CrisImport.ler(asStr(f.d['crisId']));
                    Repo.atualizarFichaImportada(
                        f, CrisImport.paraFicha(a, f.ownerUid, f.jogador));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Ficha atualizada com o site do CRIS.')));
                    }
                  } on CrisErro catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.mensagem)));
                    }
                  }
                } else if (v == 'sairMesa') {
                  Repo.desvincularFicha(f);
                } else if (v == 'apagar') {
                  final n = f.transformacoes.length;
                  if (await confirmar(
                      context,
                      n == 0
                          ? 'Apagar "${f.nome}" para sempre?'
                          : 'Apagar "${f.nome}" e ${n == 1 ? 'sua transformação' : 'suas $n transformações'} para sempre?')) {
                    final de = f.transformacaoDe;
                    final agente = de == null ? null : await Repo.ficha(de).first;
                    Repo.apagarFichaCompleta(f, agente: agente);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'foto',
                    child: Text(f.foto.isEmpty ? 'Colocar foto' : 'Foto')),
                if (dono && !f.eTransformacao)
                  const PopupMenuItem(
                      value: 'transformar', child: Text('Nova transformação')),
                if (!f.eTransformacao)
                  const PopupMenuItem(value: 'dup', child: Text('Duplicar ficha')),
                if (dono && asStr(f.d['crisId']).isNotEmpty)
                  const PopupMenuItem(
                      value: 'cris', child: Text('Atualizar do site do CRIS')),
                if (dono && f.campaignId != null && !f.eTransformacao)
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
              Tab(text: 'QUADRO'),
            ],
          ),
        ),
        body: Column(
          children: [
            FaixaForma(ficha: f),
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
                TabQuadro(ctx: ctx),
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
    final pd = c.determinacao;
    final barras = <Widget>[
      BarraStatus(
          rotulo: 'PV',
          atual: f.pvAtual,
          max: c.pvMax,
          cor: Cores.pv,
          compacta: true,
          aoMudar: (v) => Repo.mudarPontos(f, 'pvAtual', v)),
      BarraStatus(
          rotulo: 'PV TEMP',
          atual: f.pvTemp,
          max: f.pvTempMax < f.pvTemp ? f.pvTemp : f.pvTempMax,
          cor: Cores.pvTemp,
          compacta: true,
          aoMudar: (v) => Repo.mudarTemporario(f, 'pvTemp', v)),
      BarraStatus(
          rotulo: pd ? 'PD' : 'PE',
          atual: pd ? f.pdAtual : f.peAtual,
          max: pd ? c.pdMax : c.peMax,
          cor: pd ? Cores.pd : Cores.pe,
          compacta: true,
          aoMudar: (v) => Repo.mudarPontos(f, pd ? 'pdAtual' : 'peAtual', v)),
      BarraStatus(
          rotulo: pd ? 'PD TEMP' : 'PE TEMP',
          atual: f.peTemp,
          max: f.peTempMax < f.peTemp ? f.peTemp : f.peTempMax,
          cor: pd ? Cores.pdTemp : Cores.peTemp,
          compacta: true,
          aoMudar: (v) => Repo.mudarTemporario(f, 'peTemp', v)),
      if (!pd)
        BarraStatus(
            rotulo: 'SAN',
            atual: f.sanAtual,
            max: c.sanMax,
            cor: Cores.san,
            compacta: true,
            aoMudar: (v) => Repo.mudarRecursos(f, {'sanAtual': v})),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          LayoutBuilder(builder: (context, cons) {
            // Quantas barras cabem lado a lado (cada uma precisa de ~190px).
            final colunas = (cons.maxWidth / 190).floor().clamp(1, barras.length);
            final largura = (cons.maxWidth - 12 * (colunas - 1)) / colunas;
            return Wrap(spacing: 12, runSpacing: 4, children: [
              for (final b in barras) SizedBox(width: largura, child: b),
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
