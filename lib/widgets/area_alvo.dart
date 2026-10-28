import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';
import 'imagem.dart';

/// Quem aparece no espaço do alvo: um agente ou uma ameaça do combate.
class Participante {
  final String id;
  final String nome;
  final String foto;
  final Map<String, dynamic> ajuste;
  /// PV (só de quem se pode ver: o mestre vê todos, o jogador só o dele).
  final int? pv;
  final int? pvMax;
  /// Linha de baixo: Defesa, condições, quem ele mira.
  final String linha;
  final bool naVez;
  const Participante({
    required this.id,
    required this.nome,
    this.foto = '',
    this.ajuste = const {},
    this.pv,
    this.pvMax,
    this.linha = '',
    this.naVez = false,
  });
}

/// O espaço do alvo: os agentes em arco em cima e as ameaças em arco
/// embaixo, como em volta de uma mesa, todos em cartões do mesmo tamanho.
/// O [alvo] leva o selo ALVO; o [atuante] (a ameaça que o mestre escolheu
/// para agir), o selo AGE.
class AreaAlvo extends StatelessWidget {
  final List<Participante> agentes;
  final List<Participante> ameacas;
  final String? alvo;
  final String? atuante;
  final Color cor;
  final ValueChanged<Participante>? aoTocarAgente;
  final ValueChanged<Participante>? aoTocarAmeaca;
  const AreaAlvo({
    super.key,
    required this.agentes,
    required this.ameacas,
    this.alvo,
    this.atuante,
    required this.cor,
    this.aoTocarAgente,
    this.aoTocarAmeaca,
  });

  @override
  Widget build(BuildContext context) {
    Widget rotulo(String t) => Text(t,
        textAlign: TextAlign.center,
        style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 2));
    return Material(
      color: Colors.black.withValues(alpha: 0.18),
      shape: CorteCantos(corte: 18, cor: cor.withValues(alpha: 0.35)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: LayoutBuilder(builder: (context, c) {
          // a mesma largura nas duas fileiras: a da que tem mais cartões
          final n = max(1, max(agentes.length, ameacas.length));
          final largura = min(176.0, (c.maxWidth - _Arco.espaco * (n - 1)) / n);
          final emFileiras = largura < 118;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            rotulo('AGENTES'),
            const SizedBox(height: 8),
            _Arco(
              itens: agentes,
              vazio: 'Nenhum agente no combate.',
              alvo: alvo,
              atuante: atuante,
              cor: cor,
              aoTocar: aoTocarAgente,
              largura: emFileiras ? 150 : largura,
              emFileiras: emFileiras,
            ),
            const SizedBox(height: 14),
            rotulo('AMEAÇAS'),
            const SizedBox(height: 8),
            _Arco(
              itens: ameacas,
              vazio: 'Nenhuma ameaça no combate.',
              alvo: alvo,
              atuante: atuante,
              cor: cor,
              aoTocar: aoTocarAmeaca,
              largura: emFileiras ? 150 : largura,
              emFileiras: emFileiras,
              embaixo: true,
            ),
          ]);
        }),
      ),
    );
  }
}

/// Cartões em arco: em cima, as pontas descem e se inclinam para fora; embaixo
/// ([embaixo]), sobem, fechando a mesa. Sem espaço, viram fileiras.
class _Arco extends StatelessWidget {
  static const espaco = 12.0;
  static const alto = 118.0;
  final List<Participante> itens;
  final String vazio;
  final String? alvo;
  final String? atuante;
  final Color cor;
  final ValueChanged<Participante>? aoTocar;
  final double largura;
  final bool emFileiras;
  final bool embaixo;
  const _Arco({
    required this.itens,
    required this.vazio,
    required this.alvo,
    required this.atuante,
    required this.cor,
    required this.aoTocar,
    required this.largura,
    required this.emFileiras,
    this.embaixo = false,
  });

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) {
      return Text(vazio,
          textAlign: TextAlign.center, style: const TextStyle(color: Cores.textoFraco, fontSize: 13));
    }
    Widget cartao(Participante p) => _Cartao(
          p: p,
          selo: p.id == alvo ? 'ALVO' : (p.id == atuante ? 'AGE' : null),
          cor: cor,
          aoTocar: aoTocar == null ? null : () => aoTocar!(p),
        );
    return LayoutBuilder(builder: (context, c) {
      final n = itens.length;
      if (emFileiras) {
        return Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (final p in itens) SizedBox(width: largura, height: alto, child: cartao(p)),
        ]);
      }
      final queda = n <= 1 ? 0.0 : (n == 2 ? 12.0 : 30.0);
      final inicio = (c.maxWidth - (largura * n + espaco * (n - 1))) / 2;
      return SizedBox(
        height: alto + queda + 12,
        child: Stack(clipBehavior: Clip.none, children: [
          for (final (i, p) in itens.indexed)
            if (n == 1 ? 0.0 : (i - (n - 1) / 2) / ((n - 1) / 2) case final u)
              Positioned(
                left: inicio + i * (largura + espaco),
                top: 6 + (embaixo ? queda * (1 - u * u) : queda * u * u),
                width: largura,
                height: alto,
                child: Transform.rotate(angle: (embaixo ? -u : u) * 0.11, child: cartao(p)),
              ),
        ]),
      );
    });
  }
}

class _Cartao extends StatelessWidget {
  final Participante p;
  final String? selo;
  final Color cor;
  final VoidCallback? aoTocar;
  const _Cartao({required this.p, required this.selo, required this.cor, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final marcado = selo != null;
    final max = p.pvMax ?? 0;
    final pv = p.pv;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: marcado ? Color.alphaBlend(cor.withValues(alpha: 0.16), Cores.painel2) : Cores.painel2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: marcado ? cor : (p.naVez ? Cores.destaque.withValues(alpha: 0.7) : Cores.borda),
              width: marcado ? 2 : 1,
            ),
            boxShadow: marcado ? [BoxShadow(color: cor.withValues(alpha: 0.35), blurRadius: 18)] : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: aoTocar,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    RetratoFicha(foto: p.foto, nome: p.nome, ajuste: p.ajuste, largura: 34, proporcao: 1, raio: 4),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.15)),
                    ),
                  ]),
                  const Spacer(),
                  if (pv != null && max > 0) ...[
                    Row(children: [
                      Text('PV ', style: estiloRotulo(11.5, cor: Cores.pv, peso: FontWeight.w700)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (pv / max).clamp(0.0, 1.0),
                            minHeight: 5,
                            color: Cores.pv,
                            backgroundColor: Cores.pv.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('$pv/$max', style: estiloNumero(13, cor: Cores.texto)),
                    ]),
                    const SizedBox(height: 4),
                  ],
                  if (p.linha.isNotEmpty)
                    Text(p.linha,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Cores.textoFraco, height: 1.25)),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (p.naVez)
        Positioned(
          top: -9,
          left: 8,
          child: _Selo('NA VEZ', cor: Cores.destaque, cheio: false),
        ),
      if (selo != null)
        Positioned(
          top: -9,
          right: 8,
          child: _Selo(selo!, cor: cor, cheio: true),
        ),
    ]);
  }
}

class _Selo extends StatelessWidget {
  final String texto;
  final Color cor;
  final bool cheio;
  const _Selo(this.texto, {required this.cor, required this.cheio});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cheio ? cor : Cores.painel2,
          border: Border.all(color: cor),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(texto,
            style: estiloRotulo(10.5, cor: cheio ? Cores.fundo : cor, peso: FontWeight.w800, espaco: 1.2)),
      );
}
