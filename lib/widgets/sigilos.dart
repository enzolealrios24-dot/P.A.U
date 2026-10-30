import 'dart:math';
import 'dart:ui' as ui;

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
/// da cor secundária embaixo, sigilos de Conhecimento bem apagados e o grão
/// de papel por cima.
class FundoCris extends StatelessWidget {
  final Widget child;
  const FundoCris({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _PintorFundo(
                fundo: Cores.fundo,
                topo: Cores.degradeTopo,
                base: Cores.degradeBase,
                sigiloTopo: Cores.destaque,
                sigiloBase: Cores.roxoClaro,
                escala: MediaQuery.devicePixelRatioOf(context),
              ),
            ),
          ),
        ),
      ),
      child,
    ]);
  }
}

/// Pinta o fundo de uma vez numa imagem, guardada por tamanho e paleta, e
/// depois só a cola. Desenhado camada por camada, os degradês eram refeitos a
/// cada quadro das transições (com a tela de trás encolhendo e a nova
/// acendendo), e no computador a abertura de uma tela caía para uns 15
/// quadros por segundo.
class _PintorFundo extends CustomPainter {
  final Color fundo, topo, base, sigiloTopo, sigiloBase;
  final double escala;
  _PintorFundo({
    required this.fundo,
    required this.topo,
    required this.base,
    required this.sigiloTopo,
    required this.sigiloBase,
    required this.escala,
  });

  // Poucas imagens bastam: o tema do app, a paleta da ficha aberta e algum
  // tamanho de janela anterior.
  static final _prontas = <String, ui.Image>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = (size.width * escala).ceil(), h = (size.height * escala).ceil();
    // Pelos números das cores: na versão final o Flutter apaga o toString de
    // Color, e todas as paletas dariam a mesma chave (e o mesmo fundo).
    final cores = [fundo, topo, base, sigiloTopo, sigiloBase].map((c) => c.toARGB32()).join(' ');
    final chave = '$w $h $cores ${Texturas.grao != null}';
    final img = _prontas.remove(chave) ?? _desenhar(size, w, h);
    _prontas[chave] = img;
    while (_prontas.length > 4) {
      _prontas.remove(_prontas.keys.first)!.dispose();
    }
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low);
  }

  ui.Image _desenhar(Size size, int w, int h) {
    final gravador = ui.PictureRecorder();
    final c = Canvas(gravador)..scale(escala);
    final area = Offset.zero & size;
    c.drawRect(area, Paint()..color = fundo);
    c.drawRect(
      area,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.2, -1.25),
          radius: 1.25,
          colors: [topo.withValues(alpha: 0.20), topo.withValues(alpha: 0.05), Colors.transparent],
          stops: const [0, 0.45, 1],
        ).createShader(area),
    );
    c.drawRect(
      area,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.9, 1.3),
          radius: 1.35,
          colors: [base.withValues(alpha: 0.24), base.withValues(alpha: 0.06), Colors.transparent],
          stops: const [0, 0.5, 1],
        ).createShader(area),
    );
    final grande = min(size.width * 0.8, 560.0);
    c.save();
    c.translate(size.width + grande * 0.34 - grande, -grande * 0.34);
    _PintorSigilo(sigiloTopo.withValues(alpha: 0.06), 1.2, 0).paint(c, Size.square(grande));
    c.restore();
    final menor = grande * 0.9;
    c.save();
    c.translate(-grande * 0.32, size.height + grande * 0.38 - menor);
    _PintorSigilo(sigiloBase.withValues(alpha: 0.06), 1.2, 1).paint(c, Size.square(menor));
    c.restore();
    // grão de papel gasto por cima de tudo, bem de leve
    const PintorGrao().paint(c, size);
    final desenho = gravador.endRecording();
    final img = desenho.toImageSync(w, h);
    desenho.dispose();
    return img;
  }

  @override
  bool shouldRepaint(covariant _PintorFundo old) =>
      old.fundo != fundo ||
      old.topo != topo ||
      old.base != base ||
      old.sigiloTopo != sigiloTopo ||
      old.sigiloBase != sigiloBase ||
      old.escala != escala;
}

/// Transição das páginas: a tela nova sobe um pouco e acende; a de trás
/// recua de leve. Cada tela já vem com o fundo do app atrás.
class TransicaoComFundo extends PageTransitionsBuilder {
  const TransicaoComFundo();

  static final _sobe = Tween(begin: const Offset(0, 0.035), end: Offset.zero)
      .chain(CurveTween(curve: Curves.easeOutCubic));
  static final _acende = CurveTween(curve: Curves.easeOut);
  static final _recua = Tween(begin: 1.0, end: 0.965).chain(CurveTween(curve: Curves.easeOutCubic));

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // Os mesmos três invólucros do começo ao fim: se a árvore mudasse de
    // forma quando a animação acaba, a tela inteira seria montada de novo
    // (era o tranco no fim da abertura). O fundo fica numa camada própria e
    // não é redesenhado a cada quadro; a ficha desenha o fundo dela.
    final fundoProprio = rotasComFundoProprio.contains(route.settings.name);
    return ScaleTransition(
      scale: secondaryAnimation.drive(_recua),
      child: FadeTransition(
        opacity: animation.drive(_acende),
        child: SlideTransition(
          position: animation.drive(_sobe),
          child: RepaintBoundary(child: fundoProprio ? child : FundoCris(child: child)),
        ),
      ),
    );
  }
}

/// Rotas cuja tela já desenha o próprio fundo (a ficha, nas cores da
/// afinidade); a transição não põe outro atrás.
const rotasComFundoProprio = {'/ficha'};

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
