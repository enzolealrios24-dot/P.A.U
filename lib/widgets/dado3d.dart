import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Vetor 3D simples (x para a direita, y para cima, z para quem olha).
class _V {
  final double x, y, z;
  const _V(this.x, this.y, this.z);
  _V operator +(_V o) => _V(x + o.x, y + o.y, z + o.z);
  _V operator -(_V o) => _V(x - o.x, y - o.y, z - o.z);
  _V operator *(double k) => _V(x * k, y * k, z * k);
  double dot(_V o) => x * o.x + y * o.y + z * o.z;
  _V cross(_V o) => _V(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get comprimento => sqrt(dot(this));
  _V get unitario => this * (1 / comprimento);
}

/// Matriz de rotação 3x3 (linhas).
class _M {
  final List<double> m; // 9 números, linha a linha
  const _M(this.m);

  _V vezes(_V v) => _V(
        m[0] * v.x + m[1] * v.y + m[2] * v.z,
        m[3] * v.x + m[4] * v.y + m[5] * v.z,
        m[6] * v.x + m[7] * v.y + m[8] * v.z,
      );

  _M vezesM(_M o) {
    final r = List<double>.filled(9, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        var s = 0.0;
        for (var k = 0; k < 3; k++) {
          s += m[i * 3 + k] * o.m[k * 3 + j];
        }
        r[i * 3 + j] = s;
      }
    }
    return _M(r);
  }

  /// Rotação de [ang] radianos em volta do eixo [e] (unitário).
  static _M eixo(_V e, double ang) {
    final c = cos(ang), s = sin(ang), t = 1 - c;
    return _M([
      t * e.x * e.x + c, t * e.x * e.y - s * e.z, t * e.x * e.z + s * e.y,
      t * e.x * e.y + s * e.z, t * e.y * e.y + c, t * e.y * e.z - s * e.x,
      t * e.x * e.z - s * e.y, t * e.y * e.z + s * e.x, t * e.z * e.z + c,
    ]);
  }
}

class _Face {
  final int a, b, c; // vértices, no sentido anti-horário visto de fora
  final int numero;
  const _Face(this.a, this.b, this.c, this.numero);
}

/// Geometria do d20: 12 vértices, 20 faces e os números como num dado de
/// verdade (faces opostas somam 21).
class _Icosaedro {
  late final List<_V> vertices;
  late final List<_Face> faces;

  _Icosaedro() {
    final p = (1 + sqrt(5)) / 2;
    final brutos = <_V>[
      _V(-1, p, 0), _V(1, p, 0), _V(-1, -p, 0), _V(1, -p, 0),
      _V(0, -1, p), _V(0, 1, p), _V(0, -1, -p), _V(0, 1, -p),
      _V(p, 0, -1), _V(p, 0, 1), _V(-p, 0, -1), _V(-p, 0, 1),
    ];
    vertices = [for (final v in brutos) v.unitario];
    const tri = [
      [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
      [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
      [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
      [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
    ];
    // garante o sentido anti-horário visto de fora
    final orientados = <List<int>>[];
    for (final t in tri) {
      final a = vertices[t[0]], b = vertices[t[1]], c = vertices[t[2]];
      final n = (b - a).cross(c - a);
      orientados.add(n.dot(a + b + c) >= 0 ? t : [t[0], t[2], t[1]]);
    }
    // numeração: cada face e a oposta somam 21
    final numeros = List<int>.filled(20, 0);
    var proximo = 1;
    for (var i = 0; i < 20; i++) {
      if (numeros[i] != 0) continue;
      final ci = _centro(orientados[i]);
      var oposta = 0;
      var melhor = 2.0;
      for (var j = 0; j < 20; j++) {
        final d = _centro(orientados[j]).dot(ci);
        if (d < melhor) {
          melhor = d;
          oposta = j;
        }
      }
      numeros[i] = proximo;
      numeros[oposta] = 21 - proximo;
      proximo++;
    }
    faces = [
      for (var i = 0; i < 20; i++) _Face(orientados[i][0], orientados[i][1], orientados[i][2], numeros[i]),
    ];
  }

  _V _centro(List<int> t) => (vertices[t[0]] + vertices[t[1]] + vertices[t[2]]).unitario;

  _Face faceDo(int numero) => faces.firstWhere((f) => f.numero == numero);

  /// Rotação que deixa a face do [numero] de frente para a câmera, com o
  /// número de pé.
  _M deFrente(int numero) {
    final f = faceDo(numero);
    final a = vertices[f.a], b = vertices[f.b], c = vertices[f.c];
    final centro = (a + b + c) * (1 / 3);
    final e3 = centro.unitario;
    final e2 = (a - centro).unitario; // o vértice "a" fica em cima
    final e1 = e2.cross(e3);
    return _M([e1.x, e1.y, e1.z, e2.x, e2.y, e2.z, e3.x, e3.y, e3.z]);
  }
}

final _d20 = _Icosaedro();

/// Paleta do dado conforme a afinidade (pela cor de destaque).
class _CoresDado {
  final Color clara, escura, aresta, numero;
  const _CoresDado(this.clara, this.escura, this.aresta, this.numero);

  factory _CoresDado.de(Color destaque) {
    final hsl = HSLColor.fromColor(destaque);
    if (hsl.saturation < 0.15) {
      // Morte: cinza e branco
      return const _CoresDado(Color(0xFFF2F2F2), Color(0xFF3A3A3A), Color(0xFF0A0A0A), Color(0xFF0A0A0A));
    }
    return _CoresDado(
      hsl.withLightness((hsl.lightness * 1.05).clamp(0.0, 0.72)).toColor(),
      hsl.withLightness(0.14).withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness(0.86).withSaturation(0.55).toColor(),
      Colors.white,
    );
  }
}

/// d20 desenhado em 3D. [rotacao] gira o dado; [destaqueFace] acende a
/// face de frente (crítico ou falha).
class _PintorDado3D extends CustomPainter {
  final _M rotacao;
  final Color cor;
  final Color? destaqueFace;
  final int? faceDeFrente;
  _PintorDado3D(this.rotacao, this.cor, {this.destaqueFace, this.faceDeFrente});

  static const _luz = _V(-0.45, 0.6, 0.66);

  @override
  void paint(Canvas canvas, Size size) {
    final cores = _CoresDado.de(cor);
    final centro = size.center(Offset.zero);
    final escala = size.shortestSide * 0.46;
    const distancia = 4.2; // câmera
    final pts = [for (final v in _d20.vertices) rotacao.vezes(v)];
    Offset tela(_V v) {
      final k = distancia / (distancia - v.z);
      return centro + Offset(v.x * escala * k, -v.y * escala * k);
    }

    // brilho atrás do dado
    canvas.drawCircle(
      centro,
      escala * 0.95,
      Paint()
        ..color = (destaqueFace ?? cor).withValues(alpha: destaqueFace != null ? 0.55 : 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, escala * 0.35),
    );

    final visiveis = <(_Face, _V, double)>[];
    for (final f in _d20.faces) {
      final a = pts[f.a], b = pts[f.b], c = pts[f.c];
      final n = (b - a).cross(c - a).unitario;
      if (n.z <= 0.02) continue;
      visiveis.add((f, n, (a.z + b.z + c.z) / 3));
    }
    visiveis.sort((p, q) => p.$3.compareTo(q.$3));

    final aresta = Paint()
      ..color = cores.aresta.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, escala * 0.018)
      ..strokeJoin = StrokeJoin.round;
    for (final (f, n, _) in visiveis) {
      final pa = tela(pts[f.a]), pb = tela(pts[f.b]), pc = tela(pts[f.c]);
      final caminho = Path()..addPolygon([pa, pb, pc], true);
      final luz = (0.28 + 0.72 * max(0.0, n.dot(_luz.unitario))).clamp(0.0, 1.0);
      final brilho = pow(max(0.0, n.dot(_luz.unitario)), 12).toDouble() * 0.35;
      var corFace = Color.lerp(cores.escura, cores.clara, luz)!;
      corFace = Color.lerp(corFace, Colors.white, brilho)!;
      final deFrente = f.numero == faceDeFrente && destaqueFace != null;
      canvas.drawPath(caminho, Paint()..color = corFace);
      if (deFrente) {
        // a face tirada acende (clareia) e ganha o contorno do resultado
        canvas.drawPath(caminho, Paint()..color = Colors.white.withValues(alpha: 0.16));
      }
      canvas.drawPath(caminho, deFrente ? (Paint()
        ..color = destaqueFace!
        ..style = PaintingStyle.stroke
        ..strokeWidth = aresta.strokeWidth * 2.2
        ..strokeJoin = StrokeJoin.round) : aresta);

      // número na face, deitado sobre ela (só nas que estão bem de frente)
      if (n.z < 0.32) continue;
      _numero(canvas, f.numero, pa, pb, pc, n.z, luz, cores, deFrente);
    }
  }

  void _numero(Canvas canvas, int numero, Offset pa, Offset pb, Offset pc, double frente, double luz,
      _CoresDado cores, bool destaque) {
    // triângulo de referência (vértice "a" em cima) e o projetado na tela
    const ra = Offset(0, -1), rb = Offset(-0.866, 0.5), rc = Offset(0.866, 0.5);
    final u = rb - ra, v = rc - ra;
    final pu = pb - pa, pv = pc - pa;
    final det = u.dx * v.dy - u.dy * v.dx;
    final m00 = (pu.dx * v.dy - pv.dx * u.dy) / det;
    final m01 = (pv.dx * u.dx - pu.dx * v.dx) / det;
    final m10 = (pu.dy * v.dy - pv.dy * u.dy) / det;
    final m11 = (pv.dy * u.dx - pu.dy * v.dx) / det;
    final tx = pa.dx - (m00 * ra.dx + m01 * ra.dy);
    final ty = pa.dy - (m10 * ra.dx + m11 * ra.dy);
    final corNumero = luz > 0.62 && cores.numero == Colors.white
        ? Colors.white
        : (cores.numero == Colors.white ? Colors.white.withValues(alpha: 0.9) : cores.numero);
    final texto = TextPainter(
      text: TextSpan(
        text: numero == 6 || numero == 9 ? '$numero.' : '$numero',
        style: estiloNumero(numero >= 10 ? 52 : 60,
            cor: corNumero.withValues(alpha: ((frente - 0.32) / 0.4).clamp(0.0, 1.0))),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.transform(Matrix4(m00, m10, 0, 0, m01, m11, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1).storage);
    canvas.scale(0.01);
    if (destaque) {
      final sombra = TextPainter(
        text: TextSpan(
            text: '$numero',
            style: estiloNumero(numero >= 10 ? 52 : 60, cor: Colors.black.withValues(alpha: 0.5))),
        textDirection: TextDirection.ltr,
      )..layout();
      sombra.paint(canvas, Offset(-sombra.width / 2 + 3, -sombra.height * 0.42 + 3));
    }
    texto.paint(canvas, Offset(-texto.width / 2, -texto.height * 0.42));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PintorDado3D old) => true;
}

/// Dado 3D animado. Ao receber um [resultado] novo, cai, gira com
/// desaceleração (ease-out cúbico) por ~1,9 s, quica e para com essa face de
/// frente. Sem resultado, fica girando devagar.
class Dado3D extends StatefulWidget {
  final int? resultado;
  /// Muda a cada rolagem (para rolar de novo o mesmo número).
  final int rodada;
  final double tamanho;
  /// Cor da afinidade (sem cor, a de destaque do tema).
  final Color? cor;
  final VoidCallback? aoParar;
  const Dado3D({super.key, this.resultado, this.rodada = 0, this.tamanho = 180, this.cor, this.aoParar});

  /// Duração da rolagem.
  static const duracao = Duration(milliseconds: 1900);

  @override
  State<Dado3D> createState() => _Dado3DState();
}

class _Dado3DState extends State<Dado3D> with TickerProviderStateMixin {
  late final AnimationController _rolar = AnimationController(vsync: this, duration: Dado3D.duracao)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.aoParar?.call();
    });
  late final AnimationController _ocioso =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  final _r = Random();
  _V _eixo = const _V(0.3, 1, 0.2);
  double _voltas = 5;

  @override
  void initState() {
    super.initState();
    if (widget.resultado != null) _comecar();
  }

  @override
  void didUpdateWidget(covariant Dado3D old) {
    super.didUpdateWidget(old);
    if (widget.resultado != null && (widget.rodada != old.rodada || widget.resultado != old.resultado)) {
      _comecar();
    }
  }

  void _comecar() {
    _eixo = _V(_r.nextDouble() * 2 - 1, _r.nextDouble() * 2 - 1, _r.nextDouble() - 0.5).unitario;
    _voltas = 4 + _r.nextDouble() * 2.5;
    _rolar.forward(from: 0);
  }

  _M _rotacaoOciosa() {
    final t = _ocioso.value * 2 * pi;
    return _M.eixo(const _V(0.25, 1, 0.12).unitario, t).vezesM(_M.eixo(const _V(1, 0, 0), 0.5));
  }

  @override
  void dispose() {
    _rolar.dispose();
    _ocioso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = widget.cor ?? Cores.destaque;
    return SizedBox.square(
      dimension: widget.tamanho,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rolar, _ocioso]),
        builder: (context, _) {
          final res = widget.resultado;
          if (res == null || (!_rolar.isAnimating && _rolar.value == 0)) {
            return CustomPaint(painter: _PintorDado3D(_rotacaoOciosa(), cor));
          }
          final t = _rolar.value;
          final giro = Curves.easeOutCubic.transform(t);
          // gira em volta do eixo sorteado e termina exatamente com a face
          // do resultado de frente
          final fim = _d20.deFrente(res);
          final resto = _M.eixo(_eixo, (1 - giro) * _voltas * 2 * pi);
          final rot = fim.vezesM(resto);
          // queda com quiques e um leve deslize lateral
          final queda = Curves.bounceOut.transform((t / 0.8).clamp(0.0, 1.0));
          final dy = (1 - queda) * -widget.tamanho * 0.55;
          final dx = (1 - giro) * widget.tamanho * 0.25;
          final achatar = t > 0.25 && t < 0.8 ? 1 - 0.06 * sin((t - 0.25) / 0.55 * pi * 3).abs() : 1.0;
          final parado = t >= 1;
          final destaque = parado && (res == 20 || res == 1) ? (res == 20 ? Cores.ok : Cores.pv) : null;
          return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            // sombra no chão
            Positioned(
              bottom: widget.tamanho * 0.02,
              child: Opacity(
                opacity: (0.25 + 0.5 * queda).clamp(0.0, 1.0),
                child: Container(
                  width: widget.tamanho * (0.45 + 0.25 * queda),
                  height: widget.tamanho * 0.08,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(widget.tamanho, widget.tamanho * 0.1)),
                    boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 16, spreadRadius: 1)],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scaleY: achatar,
                scaleX: 2 - achatar,
                child: CustomPaint(
                  size: Size.square(widget.tamanho),
                  painter: _PintorDado3D(rot, cor, destaqueFace: destaque, faceDeFrente: parado ? res : null),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
