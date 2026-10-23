import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/cris_import.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/imagem.dart';
import 'forma.dart';
import 'paleta_ficha.dart';
import 'rolar.dart';
import 'tab_agente.dart';
import 'tab_combate.dart';
import 'tab_inventario.dart';
import 'tab_listas.dart';
import 'tab_pericias.dart';
import 'tab_poderes.dart';
import 'tab_rituais.dart';

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

  // As cores, a fonte e o dado seguem a afinidade escolhida no dossiê.
  @override
  Widget build(BuildContext context) =>
      PaletaFicha(elemento: ctx.f.elementoDaFicha, child: Builder(builder: _montar));

  Widget _montar(BuildContext context) {
    final f = ctx.f;
    final calc = ctx.calc;
    final dono = f.ownerUid == Repo.uid;
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          title: Row(children: [
            AvatarFicha(
              foto: f.foto,
              nome: f.nome,
              ajuste: f.fotoAjuste,
              tamanho: 38,
              transformacao: f.eTransformacao,
              aoTocar: () => opcoesFoto(context, f),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: estiloTitulo(18, cor: Cores.texto)),
                  const SizedBox(height: 2),
                  Text(
                      '${f.eTransformacao ? 'Transformação · ' : ''}${f.classe} · ${calc.resumoProgressao}${ctx.camp != null ? ' · ${ctx.camp!.nome}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: estiloRotulo(13.5, cor: Cores.textoFraco, peso: FontWeight.w500, espaco: 0.4)),
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

/// Um recurso da ficha (PV, PE/PD ou SAN) com o que é preciso para mostrar e
/// mudar o valor, inclusive os pontos temporários.
class _Recurso {
  final String rotulo;
  final String nomeLongo;
  final int atual, max;
  final Color cor;
  final int temp, tempMax;
  final Color? corTemp;
  final ValueChanged<int> aoMudar;
  final ValueChanged<int>? aoMudarTemp;
  const _Recurso({
    required this.rotulo,
    required this.nomeLongo,
    required this.atual,
    required this.max,
    required this.cor,
    required this.aoMudar,
    this.temp = 0,
    this.tempMax = 0,
    this.corTemp,
    this.aoMudarTemp,
  });
}

List<_Recurso> _recursos(Ficha f, Calc c) {
  final pd = c.determinacao;
  return [
    _Recurso(
      rotulo: 'PV',
      nomeLongo: 'Pontos de vida',
      atual: f.pvAtual,
      max: c.pvMax,
      cor: Cores.pv,
      temp: f.pvTemp,
      tempMax: f.pvTempMax < f.pvTemp ? f.pvTemp : f.pvTempMax,
      corTemp: Cores.pvTemp,
      aoMudar: (v) => Repo.mudarPontos(f, 'pvAtual', v),
      aoMudarTemp: (v) => Repo.mudarTemporario(f, 'pvTemp', v),
    ),
    _Recurso(
      rotulo: pd ? 'PD' : 'PE',
      nomeLongo: pd ? 'Pontos de determinação' : 'Pontos de esforço',
      atual: pd ? f.pdAtual : f.peAtual,
      max: pd ? c.pdMax : c.peMax,
      cor: pd ? Cores.pd : Cores.pe,
      temp: f.peTemp,
      tempMax: f.peTempMax < f.peTemp ? f.peTemp : f.peTempMax,
      corTemp: pd ? Cores.pdTemp : Cores.peTemp,
      aoMudar: (v) => Repo.mudarPontos(f, pd ? 'pdAtual' : 'peAtual', v),
      aoMudarTemp: (v) => Repo.mudarTemporario(f, 'peTemp', v),
    ),
    if (!pd)
      _Recurso(
        rotulo: 'SAN',
        nomeLongo: 'Sanidade',
        atual: f.sanAtual,
        max: c.sanMax,
        cor: Cores.san,
        aoMudar: (v) => Repo.mudarRecursos(f, {'sanAtual': v}),
      ),
  ];
}

/// PV, PE (ou PD) e SAN sempre visíveis no topo, em painéis compactos: os
/// botões tiram e somam 1, e tocar no número abre o ajuste completo, com os
/// pontos temporários.
class BarrasTopo extends StatelessWidget {
  final CtxFicha ctx;
  const BarrasTopo({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final lista = _recursos(f, ctx.calc);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Row(children: [
            for (var i = 0; i < lista.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _PainelRecurso(
                  r: lista[i],
                  aoAbrir: () => _ajustarRecurso(context, f.id, ctx.camp?.regras, i),
                ),
              ),
            ],
          ]),
          if (f.condicoes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final cd in f.condicoes)
                    Selo(cd, icone: Icons.warning_amber_rounded),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PainelRecurso extends StatefulWidget {
  final _Recurso r;
  final VoidCallback aoAbrir;
  const _PainelRecurso({required this.r, required this.aoAbrir});
  @override
  State<_PainelRecurso> createState() => _PainelRecursoState();
}

class _PainelRecursoState extends State<_PainelRecurso> with SingleTickerProviderStateMixin {
  // Pisca vermelho ao perder pontos e verde ao ganhar.
  late final AnimationController _pulso =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700), value: 1);
  Color _corPulso = Cores.pv;
  bool _subiu = false;

  @override
  void didUpdateWidget(covariant _PainelRecurso old) {
    super.didUpdateWidget(old);
    if (widget.r.atual != old.r.atual) {
      _subiu = widget.r.atual > old.r.atual;
      _corPulso = _subiu ? Cores.ok : Cores.pv;
      _pulso.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final frac = r.max <= 0 ? 0.0 : (r.atual / r.max).clamp(0.0, 1.0);
    final fracTemp = r.tempMax <= 0 ? 0.0 : (r.temp / r.tempMax).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, cons) {
      final largo = cons.maxWidth >= 220;
      Widget botao(IconData icone, int d) => InkResponse(
            onTap: () => r.aoMudar(r.atual + d),
            radius: 20,
            child: SizedBox(
              width: 30,
              height: 34,
              child: Icon(icone, size: 18, color: r.cor.withValues(alpha: 0.9)),
            ),
          );
      final numero = AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: Offset(0, _subiu ? 0.45 : -0.45), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: Text.rich(
          key: ValueKey(r.atual),
          TextSpan(children: [
            TextSpan(text: '${r.atual}', style: estiloNumero(24, cor: Cores.texto)),
            TextSpan(text: '/${r.max}', style: estiloNumero(14, cor: Cores.textoFraco, peso: FontWeight.w600)),
          ]),
        ),
      );
      return AnimatedBuilder(
        animation: _pulso,
        builder: (context, child) {
          final k = 1 - Curves.easeOut.transform(_pulso.value);
          return Material(
            color: Color.lerp(r.cor.withValues(alpha: 0.07), _corPulso.withValues(alpha: 0.30), k),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(
                  color: Color.lerp(r.cor.withValues(alpha: 0.30), _corPulso, k)!, width: 1 + k),
            ),
            child: child,
          );
        },
        child: InkWell(
          onTap: widget.aoAbrir,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const SizedBox(width: 6),
                Text(r.rotulo, style: estiloRotulo(12.5, cor: r.cor, peso: FontWeight.w700, espaco: 1.8)),
                const Spacer(),
                if (r.temp > 0)
                  Text('+${r.temp}', style: estiloNumero(13, cor: r.corTemp ?? r.cor, peso: FontWeight.w700)),
                const SizedBox(width: 6),
              ]),
              Row(children: [
                if (largo) botao(Icons.keyboard_double_arrow_left, -5),
                botao(Icons.remove, -1),
                Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: numero)),
                botao(Icons.add, 1),
                if (largo) botao(Icons.keyboard_double_arrow_right, 5),
              ]),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _TrilhoAnimado(frac: frac, cor: r.cor, altura: 5),
              ),
              // a linha dos temporários ocupa lugar sempre, para os painéis
              // ficarem da mesma altura
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
                child: r.temp > 0
                    ? _TrilhoAnimado(frac: fracTemp, cor: r.corTemp ?? r.cor, altura: 3)
                    : const SizedBox(height: 3),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

/// Trilho que corre até o valor novo.
class _TrilhoAnimado extends StatelessWidget {
  final double frac;
  final Color cor;
  final double altura;
  const _TrilhoAnimado({required this.frac, required this.cor, required this.altura});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: frac),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => _Trilho(frac: v, cor: cor, altura: altura),
      );
}

class _Trilho extends StatelessWidget {
  final double frac;
  final Color cor;
  final double altura;
  const _Trilho({required this.frac, required this.cor, required this.altura});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(altura),
        child: SizedBox(
          height: altura,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: cor.withValues(alpha: 0.16)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cor.withValues(alpha: 0.7), cor]),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Ajuste completo de um recurso: ±1, ±5, digitar o valor, temporários e
/// recuperar tudo. Acompanha a ficha ao vivo enquanto está aberto.
Future<void> _ajustarRecurso(
        BuildContext context, String fichaId, Map<String, dynamic>? regras, int indice) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StreamBuilder<Ficha?>(
        stream: Repo.ficha(fichaId),
        builder: (ctx, s) {
          final f = s.data;
          if (f == null) return const SizedBox(height: 200);
          final lista = _recursos(f, Calc(f, regras));
          final r = lista[indice.clamp(0, lista.length - 1)];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Text(r.nomeLongo, style: estiloTitulo(19, cor: r.cor))),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${r.atual}', style: estiloNumero(34, cor: Cores.texto)),
                    TextSpan(text: ' / ${r.max}', style: estiloNumero(18, cor: Cores.textoFraco, peso: FontWeight.w600)),
                  ])),
                ]),
                const SizedBox(height: 10),
                _TrilhoAnimado(frac: r.max <= 0 ? 0 : (r.atual / r.max).clamp(0.0, 1.0), cor: r.cor, altura: 8),
                const SizedBox(height: 16),
                Row(children: [
                  for (final d in const [-5, -1]) ...[
                    Expanded(
                        child: _BotaoValor(
                            texto: '\u2212${-d}', cor: r.cor, aoTocar: () => r.aoMudar(r.atual + d))),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Tooltip(
                      message: 'Digitar o valor',
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero, minimumSize: const Size(0, 46)),
                        onPressed: () async {
                          final v = await pedirNumero(ctx, r.nomeLongo, r.atual);
                          if (v != null) r.aoMudar(v);
                        },
                        child: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ),
                  ),
                  for (final d in const [1, 5]) ...[
                    const SizedBox(width: 8),
                    Expanded(child: _BotaoValor(texto: '+$d', cor: r.cor, aoTocar: () => r.aoMudar(r.atual + d))),
                  ],
                ]),
                if (r.aoMudarTemp != null) ...[
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('TEMPORÁRIOS', style: estiloRotulo(13, cor: r.corTemp, peso: FontWeight.w700, espaco: 1.6)),
                        const Text('Gastos antes dos normais quando você perde pontos.',
                            style: TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
                      ]),
                    ),
                    _BotaoValor(texto: '\u22121', cor: r.corTemp ?? r.cor, aoTocar: () => r.aoMudarTemp!(r.temp - 1)),
                    SizedBox(
                      width: 52,
                      child: InkWell(
                        onTap: () async {
                          final v = await pedirNumero(ctx, '${r.rotulo} temporários', r.temp);
                          if (v != null) r.aoMudarTemp!(v);
                        },
                        child: Center(child: Text('${r.temp}', style: estiloNumero(24, cor: Cores.texto))),
                      ),
                    ),
                    _BotaoValor(texto: '+1', cor: r.corTemp ?? r.cor, aoTocar: () => r.aoMudarTemp!(r.temp + 1)),
                  ]),
                ],
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => r.aoMudar(r.max),
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text('Recuperar ${r.rotulo} ao máximo'),
                ),
              ]),
            ),
          );
        },
      ),
    );

class _BotaoValor extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback aoTocar;
  const _BotaoValor({required this.texto, required this.cor, required this.aoTocar});
  @override
  Widget build(BuildContext context) => Material(
        color: cor.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: cor.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          onTap: aoTocar,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: SizedBox(
            height: 46,
            width: 52,
            child: Center(child: Text(texto, style: estiloNumero(19, cor: cor))),
          ),
        ),
      );
}
