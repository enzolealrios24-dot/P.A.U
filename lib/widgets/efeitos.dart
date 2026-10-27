import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';

// Efeitos do visual "arquivo da Ordem": textura de papel gasto no fundo,
// letras com desgaste, falha de tela (glitch) e a entrada animada das coisas.
// As texturas são geradas aqui mesmo, por ruído, sem nenhuma imagem pronta.

class Texturas {
  /// Grão e arranhões claros, para cobrir o fundo bem de leve.
  static ui.Image? grao;
  /// Máscara de desgaste: quase toda opaca, com falhas, para títulos.
  static ui.Image? desgaste;

  static Future<void> carregar() async {
    grao ??= await _gerar(320, _pixelGrao(320, Random(7)));
    desgaste ??= await _gerar(192, _pixelDesgaste(192, Random(11)));
  }

  static Future<ui.Image> _gerar(int lado, Uint8List px) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, lado, lado, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// Ruído de valor (manchas suaves), de 0 a 1, que se repete nas bordas.
  static List<double> _manchas(int lado, int celulas, Random r) {
    final g = List.generate(celulas * celulas, (_) => r.nextDouble());
    double v(int x, int y) => g[(y % celulas) * celulas + (x % celulas)];
    final saida = List<double>.filled(lado * lado, 0);
    final passo = lado / celulas;
    for (var y = 0; y < lado; y++) {
      for (var x = 0; x < lado; x++) {
        final fx = x / passo, fy = y / passo;
        final x0 = fx.floor(), y0 = fy.floor();
        var tx = fx - x0, ty = fy - y0;
        tx = tx * tx * (3 - 2 * tx);
        ty = ty * ty * (3 - 2 * ty);
        final a = v(x0, y0) + (v(x0 + 1, y0) - v(x0, y0)) * tx;
        final b = v(x0, y0 + 1) + (v(x0 + 1, y0 + 1) - v(x0, y0 + 1)) * tx;
        saida[y * lado + x] = a + (b - a) * ty;
      }
    }
    return saida;
  }

  static Uint8List _pixelGrao(int lado, Random r) {
    final px = Uint8List(lado * lado * 4);
    final m1 = _manchas(lado, 8, r);
    final m2 = _manchas(lado, 32, r);
    for (var i = 0; i < lado * lado; i++) {
      final mancha = (m1[i] * 0.6 + m2[i] * 0.4);
      var a = r.nextDouble() * 14; // grão fino
      if (mancha > 0.66) a += (mancha - 0.66) * 70; // manchas de tinta clara
      // pixels pré-multiplicados: o branco vale o mesmo que a opacidade
      final v = a.clamp(0, 40).toInt();
      px[i * 4] = v;
      px[i * 4 + 1] = v;
      px[i * 4 + 2] = v;
      px[i * 4 + 3] = v;
    }
    // arranhões finos
    for (var k = 0; k < 9; k++) {
      final x = r.nextDouble() * lado, y = r.nextDouble() * lado;
      final ang = r.nextDouble() * pi;
      final comp = 8 + r.nextDouble() * 34;
      for (var s = 0.0; s < comp; s += 0.7) {
        final xi = (x + cos(ang) * s).floor() % lado, yi = (y + sin(ang) * s).floor() % lado;
        final i = (yi * lado + xi) * 4;
        final v = max(px[i + 3], 16 + r.nextInt(12));
        px[i] = v;
        px[i + 1] = v;
        px[i + 2] = v;
        px[i + 3] = v;
      }
    }
    return px;
  }

  static Uint8List _pixelDesgaste(int lado, Random r) {
    final px = Uint8List(lado * lado * 4);
    final m1 = _manchas(lado, 12, r);
    final m2 = _manchas(lado, 48, r);
    for (var i = 0; i < lado * lado; i++) {
      final m = m1[i] * 0.55 + m2[i] * 0.45;
      var a = 255.0;
      if (m > 0.72) a = 255 - (m - 0.72) * 650; // falhas de tinta
      if (r.nextDouble() < 0.02) a *= 0.45; // pontinhos
      final v = a.clamp(105, 255).toInt();
      px[i * 4] = v;
      px[i * 4 + 1] = v;
      px[i * 4 + 2] = v;
      px[i * 4 + 3] = v;
    }
    return px;
  }
}

/// Grão de papel por cima do fundo.
class PintorGrao extends CustomPainter {
  const PintorGrao();
  @override
  void paint(Canvas canvas, Size size) {
    final img = Texturas.grao;
    if (img == null) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage)
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Texto (ou qualquer coisa) com desgaste de impressão, como os títulos dos
/// livros da Ordem.
class Gasto extends StatelessWidget {
  final Widget child;
  final double escala;
  const Gasto({super.key, required this.child, this.escala = 1});
  @override
  Widget build(BuildContext context) {
    final img = Texturas.desgaste;
    if (img == null) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => ImageShader(img, TileMode.repeated, TileMode.repeated,
          (Matrix4.identity()..setEntry(0, 0, escala)..setEntry(1, 1, escala)).storage),
      child: child,
    );
  }
}

/// Falha de tela: de tempos em tempos a imagem se divide num tom claro e
/// num escuro da cor do tema por um instante, como nas páginas de Energia.
class Glitch extends StatefulWidget {
  final Widget child;
  /// Intervalo médio entre as falhas.
  final Duration intervalo;
  const Glitch({super.key, required this.child, this.intervalo = const Duration(seconds: 6)});
  @override
  State<Glitch> createState() => _GlitchState();
}

class _GlitchState extends State<Glitch> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  final _r = Random();
  Timer? _proxima;

  @override
  void initState() {
    super.initState();
    _agendar(primeira: true);
  }

  void _agendar({bool primeira = false}) {
    final base = widget.intervalo.inMilliseconds;
    final espera = primeira ? 900 + _r.nextInt(900) : base ~/ 2 + _r.nextInt(base);
    _proxima = Timer(Duration(milliseconds: espera), () async {
      if (!mounted) return;
      await _c.forward(from: 0);
      if (mounted) _agendar();
    });
  }

  @override
  void dispose() {
    _proxima?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        if (t == 0 || t == 1) return child!;
        // tremidas curtas, mais fortes no meio da falha
        final forca = sin(t * pi);
        final dx = (sin(t * 47) * 3.5 + (t > 0.45 && t < 0.55 ? 4 : 0)) * forca;
        final dy = sin(t * 31) * 1.2 * forca;
        Widget tinta(Color cor) => ColorFiltered(
              colorFilter: ColorFilter.mode(cor.withValues(alpha: 0.75), BlendMode.srcIn),
              child: child,
            );
        return Stack(clipBehavior: Clip.none, children: [
          Transform.translate(offset: Offset(-dx, dy), child: tinta(Cores.roxoClaro)),
          Transform.translate(offset: Offset(dx, -dy), child: tinta(Cores.roxo)),
          Transform.translate(offset: Offset(dx * 0.3, 0), child: child),
        ]);
      },
    );
  }
}

/// Entrada animada: aparece subindo um pouco, com um atraso pela posição na
/// lista (para os itens surgirem um depois do outro).
class Surgir extends StatefulWidget {
  final Widget child;
  final int ordem;
  /// Começa um pouco menor em vez de mais baixo (bolhas, selos).
  final bool crescer;
  const Surgir({super.key, required this.child, this.ordem = 0, this.crescer = false});
  @override
  State<Surgir> createState() => _SurgirState();
}

class _SurgirState extends State<Surgir> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _atraso;

  @override
  void initState() {
    super.initState();
    final ms = min(widget.ordem, 10) * 55;
    if (ms == 0) {
      _c.forward();
    } else {
      _atraso = Timer(Duration(milliseconds: ms), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _atraso?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) {
          final v = _t.value;
          return Opacity(
            opacity: v,
            child: widget.crescer
                ? Transform.scale(scale: 0.85 + 0.15 * v, child: child)
                : Transform.translate(offset: Offset(0, 22 * (1 - v)), child: child),
          );
        },
      );
}

/// Selo hexagonal, como os números de página dos livros.
class Hexagono extends StatelessWidget {
  final String texto;
  final String? rotulo;
  final Color? cor;
  final double tamanho;
  const Hexagono(this.texto, {super.key, this.rotulo, this.cor, this.tamanho = 54});
  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cores.destaque;
    return SizedBox(
      width: tamanho,
      height: tamanho * 0.92,
      child: CustomPaint(
        painter: _PintorHexagono(c),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (rotulo != null)
              Text(rotulo!,
                  style: estiloRotulo(tamanho * 0.17, cor: Cores.sobreDestaque, peso: FontWeight.w700, espaco: 1)),
            Text(texto, style: estiloNumero(tamanho * 0.32, cor: Cores.sobreDestaque)),
          ]),
        ),
      ),
    );
  }
}

class _PintorHexagono extends CustomPainter {
  final Color cor;
  _PintorHexagono(this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(p.shift(const Offset(3, 3)), Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawPath(p, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant _PintorHexagono old) => old.cor != cor;
}

/// Fita adesiva translúcida, para prender o retrato no "mural".
class Fita extends StatelessWidget {
  final double largura;
  final double giro;
  const Fita({super.key, this.largura = 60, this.giro = -0.08});
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: giro,
        child: Container(
          width: largura,
          height: largura * 0.32,
          decoration: BoxDecoration(
            color: const Color(0xFFE9E2CF).withValues(alpha: 0.55),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      );
}
