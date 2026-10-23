import 'dart:math';

import 'package:flutter/material.dart';

import '../core/dice.dart';
import '../core/theme.dart';
import 'common.dart';
import 'dado3d.dart';
import 'efeitos.dart';

/// Janela de rolagem: uma moldura ornamentada com o d20 que cai, gira e quica
/// até parar no resultado. Depois aparecem o bônus, o total e o dano.
Future<void> mostrarDados(BuildContext context, Rolagem r) => showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, a, _, child) {
        final t = Curves.easeOutCubic.transform(a.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        );
      },
      pageBuilder: (context, _, __) => Center(child: _JanelaDados(r: r)),
    );

class _JanelaDados extends StatefulWidget {
  final Rolagem r;
  const _JanelaDados({required this.r});
  @override
  State<_JanelaDados> createState() => _JanelaDadosState();
}

class _JanelaDadosState extends State<_JanelaDados> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2700))..forward();

  // Momento em que o dado para (1,9 s de 2,7 s; o resto revela o resultado).
  static const _pousa = 0.7;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Números que passam pela face enquanto o dado gira.
  int _sorteio(int k) {
    final r = widget.r;
    final teto = r.natural != null ? 20 : max(20, r.total + 6);
    return (k * 7919 + r.total * 31 + k * k * 13) % teto + 1;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final tela = MediaQuery.sizeOf(context);
    final largura = min(340.0, tela.width - 32);
    final altura = min(r.danoTotal != null ? 560.0 : 500.0, tela.height - 48);
    // "Rafael: Ocultismo" vira o rótulo RAFAEL e o título Ocultismo
    final partes = r.titulo.split(': ');
    final rotulo = partes.length > 1 ? partes.first : 'Rolagem';
    final titulo = partes.length > 1 ? partes.sublist(1).join(': ') : r.titulo;
    final corResultado = r.critico ? Cores.ok : (r.falhaCritica ? Cores.pv : Cores.destaque);

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: largura,
        height: altura,
        child: CustomPaint(
          painter: _PintorMoldura(Cores.destaque),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 18),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final p = (t / _pousa).clamp(0.0, 1.0);
                final parado = p >= 1;
                final depois = ((t - _pousa) / (1 - _pousa)).clamp(0.0, 1.0);
                final valorDado = parado ? (r.natural ?? r.total) : _sorteio((t * 34).floor());
                final destaque = parado && (r.critico || r.falhaCritica);
                return Column(children: [
                  Text(rotulo.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w700, espaco: 2.6)),
                  const SizedBox(height: 4),
                  Text(titulo,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: estiloTitulo(20, cor: Cores.texto)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: r.natural != null
                        ? _arena3D(r.natural!)
                        : _arena(p, valorDado, destaque ? corResultado : null),
                  ),
                  const SizedBox(height: 12),
                  Opacity(opacity: depois, child: _resultado(depois, corResultado)),
                  const SizedBox(height: 6),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('FECHAR')),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Teste de d20: o dado 3D cai e para na face tirada.
  Widget _arena3D(int natural) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Cores.destaque.withValues(alpha: 0.25)),
          gradient: RadialGradient(
            center: const Alignment(0, 0.35),
            radius: 0.9,
            colors: [Color.lerp(Cores.painel2, Cores.roxo, 0.18)!, Colors.black],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) => Center(
            child: Dado3D(resultado: natural, tamanho: min(c.maxWidth, c.maxHeight) * 0.86),
          ),
        ),
      );

  /// Fundo escuro onde o dado cai (rolagens que não são de d20).
  Widget _arena(double p, int valor, Color? brilho) {
    // queda com quiques e giro que perde força até parar
    final queda = Curves.bounceOut.transform(p);
    final giro = pow(1 - p, 2).toDouble();
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateX(giro * 9.5)
      ..rotateY(giro * 7.0)
      ..rotateZ(giro * 4.5);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Cores.destaque.withValues(alpha: 0.25)),
        gradient: RadialGradient(
          center: const Alignment(0, 0.35),
          radius: 0.9,
          colors: [
            Color.lerp(Cores.painel2, Cores.roxo, 0.18)!,
            Colors.black,
          ],
        ),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final lado = min(c.maxWidth, c.maxHeight) * 0.62;
        final repouso = c.maxHeight * 0.5 - lado / 2;
        final y = -lado + (repouso + lado) * queda;
        return Stack(clipBehavior: Clip.hardEdge, children: [
          // sombra no "chão", que cresce quando o dado se aproxima
          Positioned(
            left: c.maxWidth / 2 - lado * 0.42,
            top: repouso + lado * 0.86,
            child: Opacity(
              opacity: (0.15 + 0.45 * queda).clamp(0.0, 1.0),
              child: Container(
                width: lado * 0.84,
                height: lado * 0.14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(lado * 0.42, lado * 0.07)),
                  boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 14, spreadRadius: 2)],
                ),
              ),
            ),
          ),
          Positioned(
            left: c.maxWidth / 2 - lado / 2,
            top: y,
            width: lado,
            height: lado,
            child: Transform(
              alignment: Alignment.center,
              transform: m,
              child: CustomPaint(painter: _PintorD20('$valor', Cores.destaque, brilho)),
            ),
          ),
        ]);
      }),
    );
  }

  /// Natural + bônus = total, crítico e dano.
  Widget _resultado(double depois, Color cor) {
    final r = widget.r;
    // o total "conta" do natural até o valor final
    final contando = Curves.easeOut.transform((depois * 1.6).clamp(0.0, 1.0));
    final natural = r.natural;
    final totalMostrado = natural == null ? r.total : (natural + (r.total - natural) * contando).round();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (natural != null) ...[
          _parcela('NATURAL', '$natural'),
          _parcela('', r.bonus >= 0 ? '+${r.bonus}' : '${r.bonus}', fraco: true),
          _parcela('', '=', fraco: true),
        ],
        _parcela('TOTAL', '$totalMostrado', grande: true, cor: r.critico || r.falhaCritica ? cor : null),
      ]),
      if (r.dados.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 4, alignment: WrapAlignment.center, children: [
            Text('${r.dados.length}d20${r.pegouMenor ? ' (menor)' : ''}:',
                style: estiloRotulo(13, cor: Cores.textoFraco, espaco: 0.6)),
            for (final d in r.dados)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: d == natural ? Cores.destaque : Cores.borda),
                ),
                child: Text('$d',
                    style: estiloNumero(13, cor: d == natural ? Cores.destaque : Cores.textoFraco)),
              ),
          ]),
        )
      else if (natural == null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(r.detalhe,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
        ),
      if (r.critico || r.falhaCritica) ...[
        const SizedBox(height: 8),
        RotuloArquivo(r.critico ? 'Crítico!' : 'Falha: natural 1', cor: cor, tamanho: 13),
      ],
      if (r.danoTotal != null) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('DANO', style: estiloRotulo(13, cor: Cores.pv, peso: FontWeight.w700, espaco: 2.2)),
          const SizedBox(width: 10),
          Text('${r.danoTotal}', style: estiloNumero(30, cor: Cores.texto)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(r.danoDetalhe ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
          ),
        ]),
      ],
    ]);
  }

  Widget _parcela(String rotulo, String valor, {bool grande = false, bool fraco = false, Color? cor}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (rotulo.isNotEmpty)
            Text(rotulo, style: estiloRotulo(11, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.6)),
          Text(valor,
              style: estiloNumero(grande ? 40 : 24,
                  cor: cor ?? (fraco ? Cores.textoFraco : Cores.texto))),
        ]),
      );
}

/// Moldura ornamentada: dois filetes, cantos em degraus com um losango e
/// um medalhão no alto e embaixo.
class _PintorMoldura extends CustomPainter {
  final Color cor;
  _PintorMoldura(this.cor);

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Cores.painel2, Color.lerp(Cores.painel2, Colors.black, 0.6)!],
        ).createShader(r),
    );
    final grao = Texturas.grao;
    if (grao != null) {
      canvas.drawRect(
          r,
          Paint()
            ..shader = ImageShader(grao, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage)
            ..blendMode = BlendMode.plus);
    }
    final forte = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fino = Paint()
      ..color = cor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cheio = Paint()..color = cor;
    canvas.drawRect(r.deflate(3), forte);
    canvas.drawRect(r.deflate(10), fino);

    // cantos em degraus
    void canto(Offset o, double sx, double sy) {
      Offset p(double x, double y) => o + Offset(x * sx, y * sy);
      final degrau = Path()
        ..moveTo(p(10, 40).dx, p(10, 40).dy)
        ..lineTo(p(18, 40).dx, p(18, 40).dy)
        ..lineTo(p(18, 18).dx, p(18, 18).dy)
        ..lineTo(p(40, 18).dx, p(40, 18).dy)
        ..lineTo(p(40, 10).dx, p(40, 10).dy);
      canvas.drawPath(degrau, forte);
      canvas.drawLine(p(24, 24), p(54, 24), fino);
      canvas.drawLine(p(24, 24), p(24, 54), fino);
      _losango(canvas, p(10, 10), 5, cheio);
    }

    canto(Offset.zero, 1, 1);
    canto(Offset(s.width, 0), -1, 1);
    canto(Offset(0, s.height), 1, -1);
    canto(Offset(s.width, s.height), -1, -1);

    // medalhões no meio de cima e de baixo
    for (final y in [3.0, s.height - 3]) {
      final c = Offset(s.width / 2, y);
      canvas.drawLine(c - const Offset(46, 0), c + const Offset(46, 0), Paint()
        ..color = Cores.painel2
        ..strokeWidth = 4);
      canvas.drawLine(c - const Offset(40, 0), c - const Offset(12, 0), forte);
      canvas.drawLine(c + const Offset(12, 0), c + const Offset(40, 0), forte);
      _losango(canvas, c, 9, Paint()..color = Cores.painel2);
      _losango(canvas, c, 9, forte);
      _losango(canvas, c, 4, cheio);
    }
  }

  static void _losango(Canvas canvas, Offset c, double t, Paint p) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - t)
        ..lineTo(c.dx + t, c.dy)
        ..lineTo(c.dx, c.dy + t)
        ..lineTo(c.dx - t, c.dy)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorMoldura old) => old.cor != cor;
}

/// d20 visto de frente: hexágono com as faces em volta do triângulo do meio,
/// sombreado como se a luz viesse do alto à esquerda.
class _PintorD20 extends CustomPainter {
  final String numero;
  final Color aresta;
  /// Brilho em volta (crítico ou falha); null quando não tem.
  final Color? brilho;
  _PintorD20(this.numero, this.aresta, this.brilho);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final raio = size.shortestSide / 2 * 0.96;
    Offset h(int i) {
      final a = -pi / 2 + i * pi / 3;
      return c + Offset(cos(a), sin(a)) * raio;
    }

    final t0 = c + Offset(0, -0.50 * raio);
    final t1 = c + Offset(0.47 * raio, 0.30 * raio);
    final t2 = c + Offset(-0.47 * raio, 0.30 * raio);
    final contorno = Path()..addPolygon([for (var i = 0; i < 6; i++) h(i)], true);

    // brilho por trás
    canvas.drawPath(
      contorno,
      Paint()
        ..color = (brilho ?? aresta).withValues(alpha: brilho != null ? 0.75 : 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, raio * (brilho != null ? 0.35 : 0.22)),
    );

    final faces = <List<Offset>>[
      [h(0), h(1), t0],
      [h(1), t1, t0],
      [h(1), h(2), t1],
      [h(2), h(3), t1],
      [h(3), t2, t1],
      [h(3), h(4), t2],
      [h(4), h(5), t2],
      [h(5), t0, t2],
      [h(5), h(0), t0],
    ];
    const claro = Color(0xFFF4F1F8);
    const escuro = Color(0xFF6E6880);
    final linha = Paint()
      ..color = aresta.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, raio * 0.025)
      ..strokeJoin = StrokeJoin.round;
    for (final f in faces) {
      final centro = (f[0] + f[1] + f[2]) / 3 - c;
      // faces viradas para o alto e para a esquerda recebem mais luz
      final luz = (0.62 - centro.dy / raio * 0.42 - centro.dx / raio * 0.18).clamp(0.0, 1.0);
      final p = Path()..addPolygon(f, true);
      canvas.drawPath(p, Paint()..color = Color.lerp(escuro, claro, luz)!.withValues(alpha: 0.94));
      canvas.drawPath(p, linha);
    }
    final meio = Path()..addPolygon([t0, t1, t2], true);
    canvas.drawPath(
      meio,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.white, claro],
        ).createShader(meio.getBounds()),
    );
    canvas.drawPath(meio, linha);

    final texto = TextPainter(
      text: TextSpan(text: numero, style: estiloNumero(raio * 0.42, cor: const Color(0xFF1B1622))),
      textDirection: TextDirection.ltr,
    )..layout();
    final centroMeio = (t0 + t1 + t2) / 3;
    texto.paint(canvas, centroMeio - Offset(texto.width / 2, texto.height * 0.42));
  }

  @override
  bool shouldRepaint(covariant _PintorD20 old) =>
      old.numero != numero || old.aresta != aresta || old.brilho != brilho;
}
