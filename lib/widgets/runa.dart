import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Runa de ritual gerada por código (nenhuma arte dos livros):
/// - [elemento]: conhecimento, energia, morte, sangue ou medo — muda o
///   desenho do meio e as letras em volta;
/// - [circulo] (1 a 4): cada círculo a mais põe um anel e um triângulo;
/// - [semente] (nome do ritual, da perícia...): a mesma semente sempre gera
///   a mesma runa, e sementes diferentes variam os detalhes;
/// - [cor]: sem cor, usa a cor do elemento.
class Runa extends StatelessWidget {
  final String elemento;
  final int circulo;
  final String semente;
  final Color? cor;
  final double tamanho;
  final double? espessura;
  const Runa({
    super.key,
    required this.elemento,
    this.circulo = 1,
    this.semente = '',
    this.cor,
    this.tamanho = 48,
    this.espessura,
  });

  /// Cor de cada elemento (Medo é neutro, quase branco).
  static Color corDo(String elemento) => switch (normalizar(elemento)) {
        'sangue' => const Color(0xFFFF3B4F),
        'energia' => const Color(0xFF9B5CFF),
        'morte' => const Color(0xFFF2F2F2),
        'medo' => const Color(0xFFE6E8EF),
        _ => const Color(0xFFD6A72B),
      };

  static String normalizar(String e) {
    final s = e.toLowerCase().trim();
    for (final n in const ['conhecimento', 'energia', 'morte', 'sangue', 'medo']) {
      if (s.startsWith(n.substring(0, 3))) return n;
    }
    return 'conhecimento';
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: tamanho,
        child: CustomPaint(
          painter: PintorRuna(
            elemento: normalizar(elemento),
            circulo: circulo.clamp(1, 4),
            semente: semente,
            cor: cor ?? corDo(elemento),
            espessura: espessura ?? max(1.0, tamanho / 70),
          ),
        ),
      );
}

class PintorRuna extends CustomPainter {
  final String elemento;
  final int circulo;
  final String semente;
  final Color cor;
  final double espessura;
  PintorRuna({
    required this.elemento,
    required this.circulo,
    required this.semente,
    required this.cor,
    required this.espessura,
  });

  static int _hash(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rnd = Random(_hash('$elemento|$semente'));
    final forte = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura * 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fino = Paint()
      ..color = cor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..strokeCap = StrokeCap.round;
    final cheio = Paint()..color = cor;

    // anéis: um por círculo, com marcas e letras entre o primeiro e o segundo
    final passo = r * 0.085;
    for (var i = 0; i < circulo; i++) {
      canvas.drawCircle(c, r * 0.96 - i * passo, i == 0 ? forte : fino);
    }
    if (circulo >= 2) {
      final fora = r * 0.96, dentro = r * 0.96 - passo;
      final marcas = 24 + rnd.nextInt(4) * 6;
      final giro = rnd.nextDouble() * pi;
      final letras = <int>{};
      final nLetras = 3 + rnd.nextInt(4);
      while (letras.length < nLetras) {
        letras.add(rnd.nextInt(marcas));
      }
      for (var k = 0; k < marcas; k++) {
        final a = giro + 2 * pi * k / marcas;
        final d = Offset(cos(a), sin(a));
        if (letras.contains(k)) {
          _letra(canvas, c + d * ((fora + dentro) / 2), passo * 0.42, a, rnd, fino, cheio);
        } else {
          canvas.drawLine(c + d * (dentro + passo * 0.15),
              c + d * (dentro + passo * (k % 3 == 0 ? 0.75 : 0.45)), fino);
        }
      }
    }

    // triângulos: um a menos que o número de círculos
    final ri = r * 0.96 - circulo * passo - r * 0.03;
    final triangulos = circulo - 1;
    final base = switch (elemento) {
      'sangue' => pi / 2,
      'morte' => 0.0,
      'energia' => rnd.nextDouble() * 2 * pi,
      _ => -pi / 2,
    };
    for (var t = 0; t < triangulos; t++) {
      // dois triângulos formam uma estrela de seis pontas; três, de nove
      final ang = base + t * (triangulos == 2 ? pi / 3 : 2 * pi / 3 / triangulos);
      final p = Path();
      for (var v = 0; v < 3; v++) {
        final a = ang + v * 2 * pi / 3;
        final q = c + Offset(cos(a), sin(a)) * ri;
        v == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
        canvas.drawCircle(q, espessura * 1.6, cheio);
      }
      p.close();
      canvas.drawPath(p, t == 0 ? forte : fino);
    }

    // desenho do elemento no meio
    final rm = ri * (triangulos > 0 ? 0.5 : 0.78);
    switch (elemento) {
      case 'energia':
        _energia(canvas, c, rm, rnd, forte, fino, cheio);
      case 'morte':
        _morte(canvas, c, rm, rnd, forte, fino, cheio);
      case 'sangue':
        _sangue(canvas, c, rm, rnd, forte, fino, cheio);
      case 'medo':
        _medo(canvas, c, rm, rnd, forte, fino, cheio);
      default:
        _conhecimento(canvas, c, rm, rnd, forte, fino, cheio);
    }
  }

  /// Letra pequena entre os anéis, no estilo do elemento.
  void _letra(Canvas canvas, Offset p, double t, double giro, Random rnd, Paint linha, Paint cheio) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(giro + pi / 2);
    switch (elemento) {
      case 'energia':
        final z = Path()
          ..moveTo(-t, -t * 0.6)
          ..lineTo(t * 0.2, -t * 0.2)
          ..lineTo(-t * 0.3, t * 0.3)
          ..lineTo(t, t * 0.7);
        canvas.drawPath(z, linha);
      case 'morte':
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: t * 0.7), rnd.nextDouble() * pi,
            pi * 1.5, false, linha);
        canvas.drawCircle(Offset.zero, t * 0.15, cheio);
      case 'sangue':
        final g = Path()
          ..moveTo(-t * 0.7, -t * 0.6)
          ..lineTo(t * 0.7, -t * 0.6)
          ..lineTo(0, t * 0.4)
          ..close();
        canvas.drawPath(g, linha);
        canvas.drawLine(Offset(0, t * 0.4), Offset(0, t), linha);
      case 'medo':
        canvas.drawCircle(Offset.zero, t * 0.6, linha);
        canvas.drawLine(Offset(-t * 0.8, t * 0.8), Offset(t * 0.8, -t * 0.8), linha);
      default:
        canvas.drawLine(Offset(0, -t), Offset(0, t), linha);
        canvas.drawLine(Offset(-t * 0.7, -t * 0.2 + rnd.nextDouble() * t * 0.4), Offset(t * 0.7, t * 0.3), linha);
        canvas.drawCircle(Offset(t * 0.6, -t * 0.8), t * 0.2, cheio);
    }
    canvas.restore();
  }

  void _conhecimento(Canvas canvas, Offset c, double r, Random rnd, Paint forte, Paint fino, Paint cheio) {
    // olho com a íris e raios para cima
    final w = r, h = r * 0.5;
    final olho = Path()
      ..moveTo(c.dx - w, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - h * 1.6, c.dx + w, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + h * 1.6, c.dx - w, c.dy)
      ..close();
    canvas.drawPath(olho, forte);
    canvas.drawCircle(c, r * 0.32, fino);
    canvas.drawCircle(c, r * 0.12, cheio);
    final raios = 3 + rnd.nextInt(3);
    for (var i = 0; i < raios; i++) {
      final a = -pi / 2 + (i - (raios - 1) / 2) * 0.38;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(c + d * r * 0.62, c + d * r * 0.95, fino);
    }
  }

  void _energia(Canvas canvas, Offset c, double r, Random rnd, Paint forte, Paint fino, Paint cheio) {
    // raio em zigue-zague e faíscas espalhadas
    final p = Path()..moveTo(c.dx - r * 0.25, c.dy - r);
    var x = c.dx - r * 0.25;
    for (var i = 1; i <= 4; i++) {
      x += (i.isOdd ? 1 : -1) * r * (0.45 + rnd.nextDouble() * 0.2);
      p.lineTo(x, c.dy - r + i * r * 0.5);
    }
    canvas.drawPath(p, forte);
    final faiscas = 5 + rnd.nextInt(4);
    for (var i = 0; i < faiscas; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final d = Offset(cos(a), sin(a));
      final ini = r * (0.55 + rnd.nextDouble() * 0.3);
      canvas.drawLine(c + d * ini, c + d * (ini + r * 0.22), fino);
      if (rnd.nextBool()) canvas.drawCircle(c + d * (ini + r * 0.35), fino.strokeWidth, cheio);
    }
  }

  void _morte(Canvas canvas, Offset c, double r, Random rnd, Paint forte, Paint fino, Paint cheio) {
    // espiral do tempo que se fecha no centro
    final p = Path();
    final voltas = 2.2 + rnd.nextDouble() * 0.8;
    final inicio = rnd.nextDouble() * 2 * pi;
    const pontos = 90;
    for (var i = 0; i <= pontos; i++) {
      final t = i / pontos;
      final a = inicio + t * voltas * 2 * pi;
      final q = c + Offset(cos(a), sin(a)) * r * (1 - t) * 0.95;
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(p, forte);
    canvas.drawCircle(c, fino.strokeWidth * 1.8, cheio);
    // ponteiros cortando a espiral
    canvas.drawLine(c + Offset(-r, 0), c + Offset(-r * 0.6, 0), fino);
    canvas.drawLine(c + Offset(r * 0.6, 0), c + Offset(r, 0), fino);
  }

  void _sangue(Canvas canvas, Offset c, double r, Random rnd, Paint forte, Paint fino, Paint cheio) {
    // gota com espinhos e escorridos
    final gota = Path()
      ..moveTo(c.dx, c.dy - r)
      ..cubicTo(c.dx + r * 0.75, c.dy - r * 0.1, c.dx + r * 0.6, c.dy + r * 0.7, c.dx, c.dy + r * 0.7)
      ..cubicTo(c.dx - r * 0.6, c.dy + r * 0.7, c.dx - r * 0.75, c.dy - r * 0.1, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(gota, forte);
    canvas.drawCircle(c + Offset(0, r * 0.25), r * 0.18, cheio);
    final espinhos = 2 + rnd.nextInt(3);
    for (var i = 0; i < espinhos; i++) {
      final lado = i.isEven ? 1 : -1;
      final y = c.dy - r * 0.4 + i * r * 0.3;
      final esp = Path()
        ..moveTo(c.dx + lado * r * 0.5, y)
        ..quadraticBezierTo(c.dx + lado * r * 0.95, y - r * 0.15, c.dx + lado * r * 1.05, y - r * 0.45);
      canvas.drawPath(esp, fino);
    }
    final escorridos = 1 + rnd.nextInt(3);
    for (var i = 0; i < escorridos; i++) {
      final x = c.dx + (i - (escorridos - 1) / 2) * r * 0.3;
      canvas.drawLine(Offset(x, c.dy + r * 0.72), Offset(x, c.dy + r * (0.85 + rnd.nextDouble() * 0.2)), fino);
    }
  }

  void _medo(Canvas canvas, Offset c, double r, Random rnd, Paint forte, Paint fino, Paint cheio) {
    // vazio no centro, com um anel trêmulo e linhas finas para fora
    final p = Path();
    const pontos = 60;
    for (var i = 0; i <= pontos; i++) {
      final a = 2 * pi * i / pontos;
      final q = c + Offset(cos(a), sin(a)) * r * (0.7 + sin(a * 5 + rnd.nextDouble()) * 0.06);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(p, forte);
    canvas.drawCircle(c, r * 0.3, fino);
    for (var i = 0; i < 8; i++) {
      final a = 2 * pi * i / 8 + rnd.nextDouble() * 0.2;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(c + d * r * 0.78, c + d * r, fino);
    }
  }

  @override
  bool shouldRepaint(covariant PintorRuna old) =>
      old.elemento != elemento ||
      old.circulo != circulo ||
      old.semente != semente ||
      old.cor != cor ||
      old.espessura != espessura;
}

/// Grade com as runas dos cinco elementos nos quatro círculos (para conferir).
class AmostraRunas extends StatelessWidget {
  const AmostraRunas({super.key});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 12, children: [
        for (final e in const ['conhecimento', 'energia', 'morte', 'sangue', 'medo'])
          for (var c = 1; c <= 4; c++)
            Column(mainAxisSize: MainAxisSize.min, children: [
              Runa(elemento: e, circulo: c, semente: '$e$c', tamanho: 64),
              Text('$e $c', style: const TextStyle(fontSize: 10, color: Cores.textoFraco)),
            ]),
      ]);
}
