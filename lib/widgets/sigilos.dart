import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'efeitos.dart';

/// Sigilo no estilo dos círculos rituais de Conhecimento: anéis com runas,
/// um triângulo e um olho no centro. Desenho original do app.
class SigiloConhecimento extends StatelessWidget {
  final double tamanho;
  /// Sem cor, usa o destaque do tema atual.
  final Color? cor;
  final double espessura;
  /// Muda a disposição das runas para os sigilos não ficarem iguais.
  final int variante;
  const SigiloConhecimento({
    super.key,
    this.tamanho = 120,
    this.cor,
    this.espessura = 1.4,
    this.variante = 0,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(tamanho),
        painter: _PintorSigilo(cor ?? Cores.destaque, espessura, variante),
      );
}

class _PintorSigilo extends CustomPainter {
  final Color cor;
  final double espessura;
  final int variante;
  _PintorSigilo(this.cor, this.espessura, this.variante);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final traco = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..strokeCap = StrokeCap.round;
    final cheio = Paint()..color = cor;

    // Anéis externos.
    canvas.drawCircle(c, r * 0.97, traco);
    canvas.drawCircle(c, r * 0.80, traco);
    canvas.drawCircle(c, r * 0.30, traco);

    // Marcas entre os anéis e runas em pontos fixos.
    final marcas = 36 + variante * 6;
    for (var i = 0; i < marcas; i++) {
      final a = 2 * pi * i / marcas;
      final dir = Offset(cos(a), sin(a));
      final longo = i % 3 == 0;
      canvas.drawLine(c + dir * r * 0.82, c + dir * r * (longo ? 0.93 : 0.88), traco);
    }
    final runas = 5 + variante % 3;
    for (var i = 0; i < runas; i++) {
      final a = -pi / 2 + 2 * pi * i / runas + pi / runas;
      final p = c + Offset(cos(a), sin(a)) * r * 0.885;
      _runa(canvas, p, r * 0.06, a + variante, traco, cheio);
    }

    // Triângulo apontado para cima, com os vértices no anel interno.
    final tri = Path();
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 + 2 * pi * i / 3;
      final p = c + Offset(cos(a), sin(a)) * r * 0.80;
      if (i == 0) {
        tri.moveTo(p.dx, p.dy);
      } else {
        tri.lineTo(p.dx, p.dy);
      }
      canvas.drawCircle(p, r * 0.035, cheio);
    }
    tri.close();
    canvas.drawPath(tri, traco);

    // Olho: duas curvas e a íris, com raios saindo para cima.
    final w = r * 0.50, h = r * 0.24;
    final olho = Path()
      ..moveTo(c.dx - w, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - h * 1.9, c.dx + w, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + h * 1.9, c.dx - w, c.dy)
      ..close();
    canvas.drawPath(olho, traco);
    canvas.drawCircle(c, r * 0.13, traco);
    canvas.drawCircle(c, r * 0.05, cheio);
    for (final a in [-pi / 2, -pi / 2 - 0.45, -pi / 2 + 0.45]) {
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(c + dir * r * 0.36, c + dir * r * 0.52, traco);
    }
  }

  /// Glifo pequeno: haste com traço cruzado e um ponto.
  void _runa(Canvas canvas, Offset p, double t, double giro, Paint traco, Paint cheio) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(giro);
    canvas.drawLine(Offset(0, -t), Offset(0, t), traco);
    canvas.drawLine(Offset(-t * 0.7, -t * 0.2), Offset(t * 0.7, t * 0.4), traco);
    canvas.drawCircle(Offset(t * 0.6, -t * 0.8), t * 0.22, cheio);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PintorSigilo old) =>
      old.cor != cor || old.espessura != espessura || old.variante != variante;
}

/// Fundo das telas: quase preto, com um brilho da cor do tema no alto, outro
/// da cor secundária embaixo e sigilos de Conhecimento bem apagados.
class FundoCris extends StatelessWidget {
  final Widget child;
  const FundoCris({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Cores.fundo,
      child: Stack(children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(builder: (context, c) {
              final grande = c.maxWidth * 0.8 > 560 ? 560.0 : c.maxWidth * 0.8;
              return Stack(clipBehavior: Clip.hardEdge, children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.2, -1.25),
                        radius: 1.25,
                        colors: [
                          Cores.degradeTopo.withValues(alpha: 0.20),
                          Cores.degradeTopo.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.9, 1.3),
                        radius: 1.35,
                        colors: [
                          Cores.degradeBase.withValues(alpha: 0.24),
                          Cores.degradeBase.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -grande * 0.34,
                  right: -grande * 0.34,
                  child: SigiloConhecimento(
                      tamanho: grande,
                      cor: Cores.destaque.withValues(alpha: 0.06),
                      espessura: 1.2),
                ),
                Positioned(
                  bottom: -grande * 0.38,
                  left: -grande * 0.32,
                  child: SigiloConhecimento(
                      tamanho: grande * 0.9,
                      cor: Cores.roxoClaro.withValues(alpha: 0.06),
                      espessura: 1.2,
                      variante: 1),
                ),
              ]);
            }),
          ),
        ),
        // grão de papel gasto por cima de tudo, bem de leve
        const Positioned.fill(
          child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: PintorGrao()))),
        ),
        child,
      ]),
    );
  }
}

/// Transição das páginas: a tela nova sobe um pouco e acende; a de trás
/// recua de leve. Cada tela já vem com o fundo do app atrás.
class TransicaoComFundo extends PageTransitionsBuilder {
  const TransicaoComFundo();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: FundoCris(child: child),
      builder: (context, child) {
        final entra = Curves.easeOutCubic.transform(animation.value);
        final recua = Curves.easeOutCubic.transform(secondaryAnimation.value);
        Widget w = child!;
        if (recua > 0) w = Transform.scale(scale: 1 - 0.035 * recua, child: w);
        if (entra < 1) {
          w = Opacity(
            opacity: entra,
            child: Transform.translate(offset: Offset(0, 36 * (1 - entra)), child: w),
          );
        }
        return w;
      },
    );
  }
}

/// Linha fina embaixo do topo das telas: acende no meio e some nas pontas.
class LinhaCris extends StatelessWidget implements PreferredSizeWidget {
  const LinhaCris({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(1);
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            Cores.destaque.withValues(alpha: 0.55),
            Cores.roxoClaro.withValues(alpha: 0.35),
            Colors.transparent,
          ]),
        ),
      );
}
