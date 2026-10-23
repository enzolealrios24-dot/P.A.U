import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
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

/// Números das faces já desenhados (em branco) como imagem. Girar a imagem
/// é barato; refazer o texto a cada quadro deixava a rolagem engasgada.
class _Numeros {
  static final _feitos = <String, (ui.Image, Size)>{};

  /// [resolucao]: quantos pixels da imagem por unidade do texto.
  static (ui.Image, Size) de(String texto, double tamanho, double resolucao) {
    final estilo = estiloNumero(tamanho, cor: Colors.white);
    return _feitos['${estilo.fontFamily}|$texto|$tamanho|$resolucao'] ??= _desenhar(texto, estilo, resolucao);
  }

  static (ui.Image, Size) _desenhar(String texto, TextStyle estilo, double resolucao) {
    final tp = TextPainter(text: TextSpan(text: texto, style: estilo), textDirection: TextDirection.ltr)..layout();
    final tam = tp.size;
    final gravador = ui.PictureRecorder();
    tp.paint(Canvas(gravador)..scale(resolucao), Offset.zero);
    tp.dispose();
    final figura = gravador.endRecording();
    final imagem = figura.toImageSync((tam.width * resolucao).ceil(), (tam.height * resolucao).ceil());
    figura.dispose();
    return (imagem, tam);
  }
}

/// Sombra do dado no chão: um oval escuro que some nas bordas.
class _PintorSombra extends CustomPainter {
  final double forca;
  _PintorSombra(this.forca);

  @override
  void paint(Canvas canvas, Size size) {
    final raio = size.width / 2;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1, size.height / size.width);
    canvas.drawCircle(
      Offset.zero,
      raio,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, raio,
            [Colors.black.withValues(alpha: forca), Colors.black.withValues(alpha: 0)], [0.3, 1]),
    );
  }

  @override
  bool shouldRepaint(covariant _PintorSombra old) => old.forca != forca;
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

    // brilho atrás do dado (gradiente; um desfoque a cada quadro pesava)
    final corBrilho = (destaqueFace ?? cor).withValues(alpha: destaqueFace != null ? 0.55 : 0.22);
    final raioBrilho = escala * 1.6;
    canvas.drawCircle(
      centro,
      raioBrilho,
      Paint()
        ..shader = ui.Gradient.radial(
          centro,
          raioBrilho,
          [corBrilho, corBrilho, corBrilho.withValues(alpha: corBrilho.a * 0.45), corBrilho.withValues(alpha: 0)],
          [0, 0.4, 0.6, 1],
        ),
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
      _numero(canvas, f.numero, pa, pb, pc, n.z, luz, cores, deFrente, escala);
    }
  }

  void _numero(Canvas canvas, int numero, Offset pa, Offset pb, Offset pc, double frente, double luz,
      _CoresDado cores, bool destaque, double escala) {
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
    // imagem pronta do número, com resolução pelo tamanho do dado na tela
    final resolucao = ((escala / 42) * 2).roundToDouble().clamp(2.0, 6.0) / 2;
    final (imagem, tam) =
        _Numeros.de(numero == 6 || numero == 9 ? '$numero.' : '$numero', numero >= 10 ? 52 : 60, resolucao);
    final origem = Offset.zero & Size(imagem.width.toDouble(), imagem.height.toDouble());
    final destino = Rect.fromLTWH(-tam.width / 2, -tam.height * 0.42, tam.width, tam.height);
    Paint tinta(Color c) => Paint()
      ..colorFilter = ColorFilter.mode(c, BlendMode.srcIn)
      ..filterQuality = FilterQuality.medium;
    canvas.save();
    canvas.transform(Matrix4(m00, m10, 0, 0, m01, m11, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1).storage);
    canvas.scale(0.01);
    if (destaque) {
      canvas.drawImageRect(imagem, origem, destino.shift(const Offset(3, 3)), tinta(Colors.black.withValues(alpha: 0.5)));
    }
    canvas.drawImageRect(
        imagem, origem, destino, tinta(corNumero.withValues(alpha: ((frente - 0.32) / 0.4).clamp(0.0, 1.0))));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PintorDado3D old) =>
      !listEquals(old.rotacao.m, rotacao.m) ||
      old.cor != cor ||
      old.destaqueFace != destaqueFace ||
      old.faceDeFrente != faceDeFrente;
}

/// Dado 3D animado. Ao receber um [resultado] novo, cai, gira perdendo força
/// por ~1,2 s, quica e para com essa face de frente. Sem resultado, fica
/// girando devagar.
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
  static const duracao = Duration(milliseconds: 1200);

  @override
  State<Dado3D> createState() => _Dado3DState();
}

class _Dado3DState extends State<Dado3D> with TickerProviderStateMixin {
  late final AnimationController _rolar = AnimationController(vsync: this, duration: Dado3D.duracao)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.aoParar?.call();
    });
  late final AnimationController _ocioso =
      AnimationController(vsync: this, duration: const Duration(seconds: 14));
  final _r = Random();
  _V _eixo = const _V(0.3, 1, 0.2);
  double _voltas = 2;

  @override
  void initState() {
    super.initState();
    if (widget.resultado != null) _comecar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustarOcioso();
  }

  @override
  void didUpdateWidget(covariant Dado3D old) {
    super.didUpdateWidget(old);
    if (widget.resultado != null && (widget.rodada != old.rodada || widget.resultado != old.resultado)) {
      _comecar();
    }
    _ajustarOcioso();
  }

  /// O giro lento só roda sem resultado e com a tela na frente: com a janela
  /// de rolagem aberta por cima, o dado da aba para de gastar quadros.
  void _ajustarOcioso() {
    final girar = widget.resultado == null && (ModalRoute.of(context)?.isCurrent ?? true);
    if (girar && !_ocioso.isAnimating) {
      _ocioso.repeat();
    } else if (!girar && _ocioso.isAnimating) {
      _ocioso.stop();
    }
  }

  void _comecar() {
    _eixo = _V(_r.nextDouble() * 2 - 1, _r.nextDouble() * 2 - 1, _r.nextDouble() - 0.5).unitario;
    // poucas voltas: rápido demais o dado parece pular de uma face para outra
    _voltas = 1.8 + _r.nextDouble() * 0.7;
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
      // só o dado é redesenhado a cada quadro, não a tela em volta
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_rolar, _ocioso]),
          builder: (context, _) {
            final res = widget.resultado;
            if (res == null || (!_rolar.isAnimating && _rolar.value == 0)) {
              return CustomPaint(painter: _PintorDado3D(_rotacaoOciosa(), cor));
            }
            final t = _rolar.value;
            // ease-out quadrático: perde força até parar, sem ficar quase
            // parado no fim
            final giro = Curves.easeOutQuad.transform(t);
            // gira em volta do eixo sorteado e termina exatamente com a face
            // do resultado de frente
            final fim = _d20.deFrente(res);
            final resto = _M.eixo(_eixo, (1 - giro) * _voltas * 2 * pi);
            final rot = fim.vezesM(resto);
            // queda com quiques e um leve deslize lateral
            final queda = Curves.bounceOut.transform((t / 0.75).clamp(0.0, 1.0));
            final dy = (1 - queda) * -widget.tamanho * 0.55;
            final dx = (1 - giro) * widget.tamanho * 0.25;
            final achatar = t > 0.25 && t < 0.75 ? 1 - 0.06 * sin((t - 0.25) / 0.5 * pi * 3).abs() : 1.0;
            final parado = t >= 1;
            final destaque = parado && (res == 20 || res == 1) ? (res == 20 ? Cores.ok : Cores.pv) : null;
            return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              // sombra no chão
              Positioned(
                bottom: -widget.tamanho * 0.02,
                child: CustomPaint(
                  size: Size(widget.tamanho * (0.55 + 0.28 * queda), widget.tamanho * 0.16),
                  painter: _PintorSombra((0.25 + 0.5 * queda).clamp(0.0, 1.0)),
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
      ),
    );
  }
}
