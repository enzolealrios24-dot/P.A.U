import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme.dart';
import 'runa.dart';

/// Sigilo pentagonal desenhado por código (nenhuma arte dos livros), com o
/// efeito vivo do elemento:
/// - Conhecimento: sigilos translúcidos entram e saem dele, como as letras de
///   uma mesa de encantamento;
/// - Sangue: gotas lentas escorrem das linhas, e ele pulsa como um coração;
/// - Morte: o círculo de dentro vira um relógio de um ponteiro, a estrela
///   deixa rastros no tempo e uma onda sai do centro;
/// - Energia: estática, tremores, saltos e falhas, com faíscas entre as
///   pontas.
/// Sem elemento (ou Medo), fica cinza e só o anel de fora gira. Com
/// "remover animações" ligado no aparelho, fica parado.
class SigiloElemental extends StatefulWidget {
  final String elemento;
  final double tamanho;
  /// Pontas do polígono (4 na vantagem elemental, 5 nos atributos), com um
  /// medalhão em cada.
  final int pontas;
  /// Distância das pontas ao centro, em fração do raio: o que fica por cima
  /// delas (runas, atributos) cai bem no meio de cada ponta.
  final double raioPontas;
  /// Força das linhas do sigilo (os efeitos têm a sua própria).
  final double opacidade;
  /// Buracos no sigilo, a partir do centro, para o que fica por cima dele.
  final List<(Offset, double)> furos;
  const SigiloElemental({
    super.key,
    required this.elemento,
    this.tamanho = 224,
    this.pontas = 5,
    this.raioPontas = 0.84,
    this.opacidade = 0.34,
    this.furos = const [],
  });

  static const vivos = {'conhecimento', 'sangue', 'morte', 'energia'};

  @override
  State<SigiloElemental> createState() => _SigiloElementalState();
}

class _SigiloElementalState extends State<SigiloElemental> with SingleTickerProviderStateMixin {
  final _tempo = ValueNotifier<double>(0);
  late final Ticker _relogio = createTicker((d) => _tempo.value = d.inMicroseconds / 1e6);

  String get _elemento => widget.elemento.trim().isEmpty ? '' : Runa.normalizar(widget.elemento);

  void _ajustar() {
    final mexe = !MediaQuery.disableAnimationsOf(context);
    if (mexe && !_relogio.isActive) _relogio.start();
    if (!mexe && _relogio.isActive) _relogio.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustar();
  }

  @override
  void didUpdateWidget(SigiloElemental old) {
    super.didUpdateWidget(old);
    _ajustar();
  }

  @override
  void dispose() {
    _relogio.dispose();
    _tempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = _elemento;
    final vivo = SigiloElemental.vivos.contains(e);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.tamanho),
          painter: PintorSigilo(
            elemento: vivo ? e : '',
            cor: vivo ? Runa.corDo(e) : Cores.textoFraco,
            opacidade: vivo ? widget.opacidade : widget.opacidade * 0.8,
            pontas: widget.pontas,
            raioPontas: widget.raioPontas,
            furos: widget.furos,
            tempo: _tempo,
          ),
        ),
      ),
    );
  }
}

class PintorSigilo extends CustomPainter {
  final String elemento;
  final Color cor;
  final double opacidade;
  final int pontas;
  final double raioPontas;
  final List<(Offset, double)> furos;
  final ValueNotifier<double> tempo;
  PintorSigilo({
    required this.elemento,
    required this.cor,
    required this.opacidade,
    required this.pontas,
    required this.raioPontas,
    required this.furos,
    required this.tempo,
  }) : super(repaint: tempo);

  static final _apaga = Paint()..blendMode = BlendMode.clear;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tempo.value;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // tudo numa camada, para os buracos e os miolos dos medalhões
    // apagarem só o sigilo
    // (com folga para os sigilos que saem e as gotas que descem)
    canvas.saveLayer(Rect.fromLTRB(c.dx - r * 1.2, c.dy - r * 1.2, c.dx + r * 1.2, c.dy + r * 1.45), Paint());
    switch (elemento) {
      case 'conhecimento':
        _conhecimento(canvas, c, r, t);
      case 'sangue':
        _sangue(canvas, c, r, t);
      case 'morte':
        _morte(canvas, c, r, t);
      case 'energia':
        _energia(canvas, c, r, t);
      default:
        // sem afinidade: só a faixa de sigilos de fora gira, devagar
        _base(canvas, c, r, opacidade, giroBanda: t * 0.04);
    }
    for (final (o, raio) in furos) {
      canvas.drawCircle(c + o, raio, _apaga);
    }
    canvas.restore();
  }

  // ---------------- desenho do sigilo ----------------

  static Offset _dir(double a) => Offset(cos(a), sin(a));

  static Paint _linha(Color cor, double largura) => Paint()
    ..color = cor
    ..style = PaintingStyle.stroke
    ..strokeWidth = largura
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Path _poligono(List<Offset> p) => Path()..addPolygon(p, true);

  /// Pontas do polígono (a de cima primeiro, no sentido horário).
  List<Offset> _vertices(Offset c, double r) =>
      [for (var i = 0; i < pontas; i++) c + _dir(-pi / 2 + 2 * pi * i / pontas) * r * raioPontas];

  /// Pontas da estrela de sete pontas do círculo de dentro.
  static List<Offset> _nos(Offset c, double r, double giro) =>
      [for (var i = 0; i < 7; i++) c + _dir(giro - pi / 2 + 2 * pi * i / 7) * r * 0.52];

  /// Sigilos inventados: cada um é uma haste com ganchos, travessas, anéis e
  /// pontas em V, sempre os mesmos.
  static final List<Path> _glifos = () {
    final rnd = Random(1913);
    return List.generate(32, (_) {
      final p = Path();
      final x0 = rnd.nextDouble() * 0.6 - 0.3;
      p.moveTo(x0, -1);
      if (rnd.nextBool()) {
        p.lineTo(-x0 * 0.5, 1);
      } else {
        p.quadraticBezierTo(rnd.nextDouble() * 2 - 1, 0, -x0, 1);
      }
      final extras = 1 + rnd.nextInt(3);
      for (var i = 0; i < extras; i++) {
        switch (rnd.nextInt(5)) {
          case 0:
            final y = rnd.nextDouble() * 1.4 - 0.7;
            p.moveTo(-0.7, y);
            p.lineTo(0.7, y + (rnd.nextDouble() - 0.5) * 0.6);
          case 1:
            final y = rnd.nextDouble() * 1.2 - 0.6;
            final s = rnd.nextBool() ? 1.0 : -1.0;
            p.moveTo(0, y);
            p.quadraticBezierTo(s * 0.9, y - 0.5, s * 0.6, y + 0.4);
          case 2:
            p.moveTo(-0.8, -0.6 + rnd.nextDouble() * 0.4);
            p.lineTo(0.8, 0.6 - rnd.nextDouble() * 0.4);
          case 3:
            p.addOval(Rect.fromCircle(
                center: Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() * 1.2 - 0.6),
                radius: 0.22 + rnd.nextDouble() * 0.12));
          default:
            final y = rnd.nextDouble() - 0.5;
            p.moveTo(-0.6, y - 0.4);
            p.lineTo(0, y + 0.3);
            p.lineTo(0.6, y - 0.4);
        }
      }
      return p;
    });
  }();

  static void _glifo(Canvas canvas, int i, Offset p, double tam, double giro, Paint linha) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(giro);
    canvas.scale(tam);
    final largura = linha.strokeWidth;
    linha.strokeWidth = largura / tam;
    canvas.drawPath(_glifos[i % _glifos.length], linha);
    linha.strokeWidth = largura;
    canvas.restore();
  }

  void _estrela(Canvas canvas, Offset c, double r, double giro, Paint linha) {
    final h = _nos(c, r, giro);
    canvas.drawPath(_poligono([for (var i = 0; i < 7; i++) h[(i * 3) % 7]]), linha);
  }

  void _base(Canvas canvas, Offset c, double r, double alfa,
      {double giroBanda = 0, double giroEstrela = 0, Color? tinta}) {
    final k = tinta ?? cor;
    final forte = _linha(k.withValues(alpha: alfa.clamp(0, 1)), r * 0.013);
    final fino = _linha(k.withValues(alpha: (alfa * 0.7).clamp(0, 1)), r * 0.008);

    // anéis de fora e a faixa de sigilos entre eles
    canvas.drawCircle(c, r * 0.98, forte);
    canvas.drawCircle(c, r * 0.89, fino);
    const nFaixa = 30;
    for (var i = 0; i < nFaixa; i++) {
      final a = giroBanda + 2 * pi * i / nFaixa;
      _glifo(canvas, i * 7, c + _dir(a) * r * 0.935, r * 0.03, a + pi / 2, fino);
    }

    // polígono, a estrela das pontas e raios até o círculo de dentro: com
    // cinco pontas, um pentagrama; com quatro, uma rosa dos ventos
    final v = _vertices(c, r);
    canvas.drawPath(_poligono(v), forte);
    canvas.drawPath(
        _poligono(pontas >= 5
            ? [for (var i = 0; i < pontas; i++) v[(i * 2) % pontas]]
            : [
                for (var i = 0; i < pontas; i++) ...[
                  v[i],
                  c + _dir(-pi / 2 + 2 * pi * (i + 0.5) / pontas) * r * 0.3,
                ],
              ]),
        fino);
    for (var i = 0; i < pontas; i++) {
      final d = _dir(-pi / 2 + 2 * pi * i / pontas);
      canvas.drawLine(c + d * r * 0.30, c + d * r * 0.52, fino);
    }

    // círculo de dentro com a estrela de sete pontas
    canvas.drawCircle(c, r * 0.52, forte);
    _estrela(canvas, c, r, giroEstrela, fino);
    for (final p in _nos(c, r, giroEstrela)) {
      canvas.drawCircle(p, r * 0.035, _apaga);
      canvas.drawCircle(p, r * 0.035, fino);
    }
    canvas.drawCircle(c, r * 0.30, fino);
    canvas.drawCircle(c, r * 0.12, fino);

    // medalhões nas pontas, cada um com um sigilo
    for (var i = 0; i < pontas; i++) {
      canvas.drawCircle(v[i], r * 0.12, _apaga);
      canvas.drawCircle(v[i], r * 0.12, forte);
      canvas.drawCircle(v[i], r * 0.095, fino);
      _glifo(canvas, i * 5 + 3, v[i], r * 0.055, 0, forte);
    }
  }

  // ---------------- efeitos de cada elemento ----------------

  /// Sigilos que entram no círculo e saem dele, translúcidos, girando de
  /// leve no caminho.
  void _conhecimento(Canvas canvas, Offset c, double r, double t) {
    _base(canvas, c, r, opacidade, giroBanda: t * 0.05, giroEstrela: -t * 0.03);
    final claro = Color.lerp(cor, Colors.white, 0.35)!;
    for (var i = 0; i < 16; i++) {
      final periodo = 2.8 + (i % 5) * 0.5;
      final x = t / periodo + i * 0.618;
      final ciclo = x.floor();
      final p = x - ciclo;
      final rnd = Random(i * 7919 + ciclo * 104729);
      final entra = rnd.nextBool();
      final a0 = rnd.nextDouble() * 2 * pi;
      final longe = r * (1.0 + rnd.nextDouble() * 0.12);
      final perto = r * (0.24 + rnd.nextDouble() * 0.2);
      final e = Curves.easeInOut.transform(p);
      final dist = entra ? longe + (perto - longe) * e : perto + (longe - perto) * e;
      final ang = a0 + (entra ? 0.7 : -0.7) * e;
      final alfa = sin(pi * p) * 0.6;
      final tam = r * (0.04 + 0.035 * (dist - perto) / (longe - perto));
      final pos = c + _dir(ang) * dist + Offset(0, sin(t * 2 + i) * r * 0.012);
      final glifo = rnd.nextInt(32);
      final giro = (rnd.nextDouble() - 0.5) * 0.5;
      _glifo(canvas, glifo, pos, tam, giro, _linha(claro.withValues(alpha: alfa * 0.18), r * 0.035));
      _glifo(canvas, glifo, pos, tam, giro, _linha(claro.withValues(alpha: alfa), r * 0.011));
    }
  }

  /// Gotas que se juntam nas linhas e escorrem devagar; o sigilo pulsa
  /// numa batida dupla, como um coração.
  void _sangue(Canvas canvas, Offset c, double r, double t) {
    final x = t % 1.4;
    double pico(double m) => exp(-pow((x - m) / 0.06, 2));
    final batida = pico(0.12) + 0.55 * pico(0.34);
    _base(canvas, c, r, opacidade * (0.85 + 0.35 * batida));
    final v = _vertices(c, r);
    final fontes = <Offset>[
      for (final p in v) p + Offset(0, r * 0.12),
      for (final a in const [0.35, 0.8, 1.25, 1.95, 2.45]) c + _dir(a) * r * 0.98,
      for (final a in const [0.6, 1.57, 2.5]) c + _dir(a) * r * 0.52,
    ];
    final tinta = Color.lerp(cor, Colors.black, 0.15)!;
    for (var i = 0; i < 7; i++) {
      final periodo = 5.5 + (i % 4) * 0.9;
      final xx = t / periodo + i * 0.37;
      final ciclo = xx.floor();
      final rnd = Random(i * 31 + ciclo * 977);
      _gota(canvas, fontes[rnd.nextInt(fontes.length)], xx - ciclo, r * (0.16 + rnd.nextDouble() * 0.22),
          r * (0.018 + rnd.nextDouble() * 0.008), tinta);
    }
  }

  /// Uma gota: junta na linha, escorre deixando um rastro fino e some.
  void _gota(Canvas canvas, Offset s, double p, double comprimento, double gota, Color cor) {
    final alfa = p < 0.85 ? 0.9 : 0.9 * (1 - (p - 0.85) / 0.15);
    final tinta = Paint()..color = cor.withValues(alpha: alfa);
    if (p < 0.3) {
      final rb = gota * Curves.easeOut.transform(p / 0.3);
      canvas.drawCircle(s + Offset(0, rb * 0.8), rb, tinta);
      return;
    }
    final q = (p - 0.3) / 0.7;
    final h = s + Offset(0, comprimento * (0.55 * q + 0.45 * q * q) + gota * 0.8);
    final w0 = gota * 0.55, w1 = gota * 0.6;
    final rastro = Path()
      ..moveTo(s.dx - w0, s.dy)
      ..quadraticBezierTo(s.dx - w1 * 0.4, (s.dy + h.dy) / 2, h.dx - w1, h.dy)
      ..lineTo(h.dx + w1, h.dy)
      ..quadraticBezierTo(s.dx + w1 * 0.4, (s.dy + h.dy) / 2, s.dx + w0, s.dy)
      ..close();
    canvas.drawPath(rastro, tinta);
    canvas.drawCircle(h, gota, tinta);
    canvas.drawCircle(h + Offset(-gota * 0.35, -gota * 0.3), gota * 0.25,
        Paint()..color = Colors.white.withValues(alpha: alfa * 0.35));
  }

  /// Relógio de um ponteiro no círculo de dentro, que anda aos saltos; a
  /// estrela gira para trás deixando rastros e uma onda sai do centro.
  void _morte(Canvas canvas, Offset c, double r, double t) {
    final giro = -t * 0.1;
    for (var k = 2; k >= 1; k--) {
      _estrela(canvas, c, r, giro + k * 0.06, _linha(cor.withValues(alpha: opacidade * 0.3 / k), r * 0.008));
    }
    _base(canvas, c, r, opacidade, giroBanda: t * 0.025, giroEstrela: giro);
    final onda = (t / 4) % 1;
    canvas.drawCircle(
        c, r * (0.3 + 0.68 * onda), _linha(cor.withValues(alpha: 0.3 * pow(1 - onda, 2)), r * 0.01));
    // mostrador
    final marca = _linha(cor.withValues(alpha: min(1, opacidade * 1.8)), r * 0.012);
    for (var i = 0; i < 12; i++) {
      final d = _dir(-pi / 2 + 2 * pi * i / 12);
      canvas.drawLine(c + d * r * (i % 3 == 0 ? 0.41 : 0.45), c + d * r * 0.5, marca);
    }
    // ponteiro: um passo a cada meio segundo, uma volta a cada 24 segundos
    final passos = t * 2;
    final n = passos.floor();
    final a = -pi / 2 + 2 * pi * (n + Curves.easeOutBack.transform(min(1, (passos - n) / 0.3))) / 48;
    final d = _dir(a);
    final ponteiro = _linha(cor.withValues(alpha: 0.85), r * 0.02);
    canvas.drawLine(c - d * r * 0.1, c + d * r * 0.48, ponteiro);
    canvas.drawCircle(c + d * r * 0.48, r * 0.022, Paint()..color = cor.withValues(alpha: 0.85));
    canvas.drawCircle(c, r * 0.035, Paint()..color = cor.withValues(alpha: 0.85));
  }

  /// Tremores, saltos de giro, falhas em faixas, estática e faíscas.
  void _energia(Canvas canvas, Offset c, double r, double t) {
    final quadro = (t * 12).floor();
    final rnd = Random(quadro * 7 + 3);
    final tremor =
        rnd.nextDouble() < 0.4 ? Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() - 0.5) * r * 0.03 : Offset.zero;
    final salto = (Random((t * 1.6).floor()).nextDouble() - 0.5) * 0.5;
    final giro = 0.12 * sin(t * 1.9) + 0.07 * sin(t * 5.3 + 1) + salto;
    final alfa = opacidade * (0.8 + rnd.nextDouble() * 0.3);
    if (rnd.nextDouble() < 0.12) {
      // falha: um fantasma mais claro de lado e o sigilo em faixas tortas
      _base(canvas, c + Offset(r * 0.035, 0), r, alfa * 0.45,
          giroBanda: -giro * 0.6, giroEstrela: giro, tinta: Color.lerp(cor, Colors.white, 0.5));
      const faixas = 4;
      for (var i = 0; i < faixas; i++) {
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(c.dx - r * 1.2, c.dy - r + 2 * r * i / faixas, r * 2.4, 2 * r / faixas));
        _base(canvas, c + Offset((rnd.nextDouble() - 0.5) * r * 0.08, 0), r, alfa,
            giroBanda: -giro * 0.6, giroEstrela: giro);
        canvas.restore();
      }
    } else {
      _base(canvas, c + tremor, r, alfa, giroBanda: -giro * 0.6, giroEstrela: giro);
    }
    // estática: riscos curtos que mudam 24 vezes por segundo
    final ruido = Random((t * 24).floor());
    final risco = Paint()
      ..strokeWidth = r * 0.008
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 36; i++) {
      final p = c + _dir(ruido.nextDouble() * 2 * pi) * sqrt(ruido.nextDouble()) * r;
      risco.color = Color.lerp(cor, Colors.white, ruido.nextDouble() * 0.6)!
          .withValues(alpha: 0.15 + ruido.nextDouble() * 0.45);
      canvas.drawLine(p, p + Offset(r * (0.005 + ruido.nextDouble() * 0.03), 0), risco);
    }
    // faísca entre duas pontas do sigilo
    if (rnd.nextDouble() < 0.3) {
      final pontos = [..._vertices(c, r), ..._nos(c, r, giro)];
      final a = pontos[rnd.nextInt(pontos.length)], b = pontos[rnd.nextInt(pontos.length)];
      if (a != b) _faisca(canvas, a, b, rnd, r);
    }
  }

  void _faisca(Canvas canvas, Offset a, Offset b, Random rnd, double r) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final p = Path()..moveTo(a.dx, a.dy);
    const partes = 7;
    for (var i = 1; i < partes; i++) {
      final q = a + d * (i / partes) + n * (rnd.nextDouble() - 0.5) * r * 0.12;
      p.lineTo(q.dx, q.dy);
    }
    p.lineTo(b.dx, b.dy);
    canvas.drawPath(
        p, _linha(cor.withValues(alpha: 0.3), r * 0.035)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(p, _linha(Color.lerp(cor, Colors.white, 0.6)!.withValues(alpha: 0.9), r * 0.01));
  }

  @override
  bool shouldRepaint(covariant PintorSigilo old) =>
      old.elemento != elemento ||
      old.cor != cor ||
      old.opacidade != opacidade ||
      old.pontas != pontas ||
      old.raioPontas != raioPontas ||
      old.tempo != tempo ||
      old.furos.toString() != furos.toString();
}
