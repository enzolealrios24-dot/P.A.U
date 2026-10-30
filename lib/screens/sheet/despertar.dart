import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/runa.dart';
import 'afinidade.dart';

/// O agente acabou de chegar a NEX 50% e ainda não tem afinidade. Só para o
/// dono da ficha: é a escolha dele, mesmo que o mestre tenha subido o NEX.
bool chegouAoNex50(int nexAntes, Ficha f) =>
    nexAntes < 50 && f.nex >= 50 && f.afinidade.isEmpty && !f.eTransformacao && f.ownerUid == Repo.uid;

/// A cena da chegada a NEX 50%: a tela escurece, um cometa cruza o céu e, do
/// impacto, saem os quatro símbolos para a escolha da afinidade.
Future<void> abrirDespertar(BuildContext context, Ficha f) => Navigator.of(context, rootNavigator: true)
    .push(rotaDespertar((e) => Repo.set(f.id, 'afinidade', e)));

/// A cena faz a própria entrada e saída; a rota não anima nada.
Route<void> rotaDespertar(void Function(String elemento) aoEscolher) => PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => TelaDespertar(aoEscolher: aoEscolher),
    );

// Linha do tempo da cena, em segundos.
const _fimEscuro = 0.9;
const _inicioCeu = 0.75;
const _inicioCometa = 1.1;
const _impacto = 3.0;
const _abertura = _impacto + 0.05;
const _entreSimbolos = 0.11;
const _entradaSimbolo = 0.75;

// Tempos da escolha, contados a partir do toque.
const _picoEscolha = 0.95;
const _fimEscolha = 1.45;

/// Cores da cena: mais vivas que as da ficha, de propósito.
const _vivas = {
  'Conhecimento': Color(0xFFFFC21A),
  'Energia': Color(0xFFB45CFF),
  'Morte': Color(0xFFF4F6FF),
  'Sangue': Color(0xFFFF1A3C),
};

class TelaDespertar extends StatefulWidget {
  final void Function(String elemento) aoEscolher;
  const TelaDespertar({super.key, required this.aoEscolher});

  @override
  State<TelaDespertar> createState() => _TelaDespertarState();
}

class _TelaDespertarState extends State<TelaDespertar> with SingleTickerProviderStateMixin {
  final _tempo = ValueNotifier<double>(0);
  final _cena = _Cena();
  late final Ticker _relogio = createTicker(_aoPassar);
  // Quanto a cena foi adiantada por "pular".
  double _desvio = 0;
  bool _revelado = false;
  bool _botoes = false;
  bool _gravou = false;
  bool _calmo = false;
  bool _coberta = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Com "remover animações" no aparelho: só os símbolos, parados.
    if (MediaQuery.disableAnimationsOf(context)) {
      _calmo = true;
      _revelado = _botoes = true;
      _tempo.value = _abertura + 3;
      if (_relogio.isActive) _relogio.stop();
    } else if (!_relogio.isActive && !_calmo) {
      _relogio.start();
    }
  }

  /// Com a tela já toda coberta, a ficha de trás para de ser desenhada: ela e
  /// os sigilos vivos dela custavam mais que a própria cena a cada quadro.
  void _cobrir(bool sim) {
    if (_coberta == sim) return;
    _coberta = sim;
    final rota = ModalRoute.of(context);
    if (rota != null && rota.overlayEntries.isNotEmpty) rota.overlayEntries.last.opaque = sim;
  }

  void _aoPassar(Duration d) {
    final t = d.inMicroseconds / 1e6 + _desvio;
    _tempo.value = t;
    final e = _cena.tEscolha;
    if (e == null && t >= _fimEscuro + 0.05) _cobrir(true);
    if (e != null) {
      final q = t - e;
      if (q >= _picoEscolha && !_gravou) {
        // com a tela toda coberta: a ficha troca de cores sem ninguém ver
        _gravou = true;
        widget.aoEscolher(_cena.escolhido!);
        _cobrir(false);
      }
      if (q >= _fimEscolha) {
        _relogio.stop();
        Navigator.of(context).pop();
      }
      return;
    }
    if (!_revelado && t >= _abertura + 0.6) setState(() => _revelado = true);
    if (!_botoes && t >= _abertura + 1.2) setState(() => _botoes = true);
  }

  void _pular() {
    if (_tempo.value >= _impacto - 0.06) return;
    _desvio += _impacto - 0.06 - _tempo.value;
  }

  void _escolher(String e) {
    if (_cena.escolhido != null) return;
    if (_calmo) {
      widget.aoEscolher(e);
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _cena.escolhido = e;
      _cena.tEscolha = _tempo.value;
    });
  }

  @override
  void dispose() {
    _relogio.dispose();
    _tempo.dispose();
    _cena.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final escolhendo = _cena.escolhido != null;
    return LayoutBuilder(builder: (context, c) {
      final tam = c.biggest;
      final palco = _Palco.de(tam);
      final escala = MediaQuery.devicePixelRatioOf(context);
      final largura = tam.width;
      final tituloTam = min(largura * 0.09, 46.0);
      return Material(
        type: MaterialType.transparency,
        child: Stack(fit: StackFit.expand, children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pular,
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: tam,
                  painter: _PintorCena(tempo: _tempo, cena: _cena, palco: palco, escala: escala, calmo: _calmo),
                ),
              ),
            ),
          ),
          if (!_revelado)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Text('Toque para pular',
                    style: estiloRotulo(13, cor: Colors.white.withValues(alpha: 0.42), espaco: 0.8)),
              ),
            ),
          Positioned(
            top: tam.height * 0.045,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: _Surge(
                visivel: _revelado && !escolhendo,
                child: Column(children: [
                  Text('NEX 50%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontWeight: FontWeight.w800,
                        fontSize: tituloTam,
                        letterSpacing: 3,
                        color: Colors.white,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 14)],
                      )),
                  const SizedBox(height: 2),
                  Text('Um elemento responde a você. Qual deles?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: Fontes.texto,
                        fontSize: min(largura * 0.04, 17.0),
                        color: Colors.white.withValues(alpha: 0.8),
                        shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                      )),
                ]),
              ),
            ),
          ),
          for (final (i, e) in palco.ordem.indexed) ..._simbolo(palco, i, e, escolhendo),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _Surge(
                visivel: _botoes && !escolhendo,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    onPressed: _botoes && !escolhendo ? () => Navigator.of(context).pop() : null,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Decidir depois'),
                  ),
                  Text('Você pode mudar depois, na Identidade do agente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.55))),
                ]),
              ),
            ),
          ),
        ]),
      );
    });
  }

  /// A área de toque e o nome de um símbolo. O desenho dele está na cena.
  List<Widget> _simbolo(_Palco palco, int i, String e, bool escolhendo) {
    final c = palco.centros[i];
    final r = palco.raio;
    final caixa = r * 2.5;
    return [
      Positioned(
        left: c.dx - caixa / 2,
        top: c.dy - caixa / 2,
        width: caixa,
        height: caixa,
        child: _revelado && !escolhendo
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => _cena.foco = i,
                onExit: (_) {
                  if (_cena.foco == i) _cena.foco = null;
                },
                child: Semantics(
                  button: true,
                  label: 'Escolher a afinidade $e',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _cena.foco = i,
                    onTapCancel: () => _cena.foco = null,
                    onTap: () => _escolher(e),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      Positioned(
        left: c.dx - palco.celula / 2,
        width: palco.celula,
        top: c.dy + r * 1.28,
        child: IgnorePointer(
          child: _Surge(
            visivel: _revelado && !escolhendo,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(e,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: temasAfinidade[e]!.fonteTitulo,
                    fontWeight: FontWeight.w800,
                    fontSize: max(16, min(r * 0.36, 28)),
                    color: _vivas[e],
                    shadows: [
                      Shadow(color: _vivas[e]!.withValues(alpha: 0.75), blurRadius: 16),
                      const Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  )),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Texto que acende subindo um pouco.
class _Surge extends StatelessWidget {
  final bool visivel;
  final Widget child;
  const _Surge({required this.visivel, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: visivel ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: visivel ? Offset.zero : const Offset(0, 0.25),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          child: child,
        ),
      );
}

/// Onde cada símbolo fica. Na coluna do Sangue o sangue desce do alto da tela,
/// então no celular ele vai na fila de cima, para não correr por outro símbolo.
class _Palco {
  final List<String> ordem;
  final List<Offset> centros;
  final double raio;
  /// Largura de cada símbolo: o nome dele não passa daqui.
  final double celula;
  const _Palco(this.ordem, this.centros, this.raio, this.celula);

  factory _Palco.de(Size s) {
    if (s.width >= 640 && s.width >= s.height) {
      final celula = min(s.width / 4, 360.0);
      final inicio = s.width / 2 - celula * 1.5;
      return _Palco(
        afinidadesDossie,
        [for (var i = 0; i < 4; i++) Offset(inicio + celula * i, s.height * 0.5)],
        min(celula * 0.31, s.height * 0.2),
        celula,
      );
    }
    return _Palco(
      const ['Conhecimento', 'Sangue', 'Morte', 'Energia'],
      [
        Offset(s.width * 0.26, s.height * 0.36),
        Offset(s.width * 0.74, s.height * 0.36),
        Offset(s.width * 0.26, s.height * 0.66),
        Offset(s.width * 0.74, s.height * 0.66),
      ],
      min(s.width * 0.195, s.height * 0.115),
      s.width * 0.47,
    );
  }
}

/// O que a cena precisa saber da tela, mais as imagens feitas uma vez só:
/// desenhar brilho e desfoque a cada quadro é o que derruba a fluidez.
class _Cena {
  String? escolhido;
  double? tEscolha;
  int? foco;
  final focoSuave = List<double>.filled(4, 0);

  ui.Image? brilho;
  ui.Image? glifos;
  ui.Image? rabo;
  ui.Image? ceu;
  ui.Image? palco;
  ui.Image? marcas;
  Size? tamanhoCeu;
  double? raioRunas;
  final runas = <String, ui.Image>{};
  final auras = <String, ui.Image>{};

  void dispose() {
    brilho?.dispose();
    glifos?.dispose();
    rabo?.dispose();
    ceu?.dispose();
    palco?.dispose();
    marcas?.dispose();
    for (final i in runas.values) {
      i.dispose();
    }
    for (final i in auras.values) {
      i.dispose();
    }
  }
}

ui.Image _imagem(int w, int h, void Function(Canvas) desenhar) {
  final gravador = ui.PictureRecorder();
  desenhar(Canvas(gravador));
  final figura = gravador.endRecording();
  final img = figura.toImageSync(w, h);
  figura.dispose();
  return img;
}

/// Sigilos inventados, de traço de pincel: cada um são algumas pinceladas que
/// afinam nas pontas, ganchos, um triângulo ou pingos, sempre os mesmos.
class _Glifos {
  static const quantos = 24;
  static const colunas = 6;
  static const lado = 96;

  static Rect recorte(int i) {
    final k = i % quantos;
    return Rect.fromLTWH(
        (k % colunas) * lado.toDouble(), (k ~/ colunas) * lado.toDouble(), lado.toDouble(), lado.toDouble());
  }

  static void _pincelada(Path destino, Offset a, Offset b, Offset d, double largura) {
    const n = 14;
    final esquerda = <Offset>[], direita = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final s = i / n;
      final q = a * ((1 - s) * (1 - s)) + b * (2 * s * (1 - s)) + d * (s * s);
      final t = (b - a) * (2 * (1 - s)) + (d - b) * (2 * s);
      final normal = Offset(-t.dy, t.dx) / max(t.distance, 0.001);
      // mais grossa perto do começo, como quem encosta o pincel e vai tirando
      final w = largura * pow(sin(pi * pow(s, 0.7)), 0.8);
      esquerda.add(q + normal * w);
      direita.add(q - normal * w);
    }
    destino.addPolygon([...esquerda, ...direita.reversed], true);
  }

  static Path glifo(Random r) {
    final p = Path();
    Offset ponto(double raio) => Offset((r.nextDouble() * 2 - 1) * raio, (r.nextDouble() * 2 - 1) * raio);
    // a pincelada principal, de cima para baixo
    final topo = Offset((r.nextDouble() - 0.5) * 0.9, -0.85);
    final base = Offset((r.nextDouble() - 0.5) * 0.9, 0.85);
    _pincelada(p, topo, ponto(0.9), base, 0.13);
    for (var i = 0, n = 1 + r.nextInt(3); i < n; i++) {
      switch (r.nextInt(4)) {
        case 0: // gancho
          final a = ponto(0.7);
          _pincelada(p, a, a + Offset((r.nextBool() ? 1 : -1) * 0.75, -0.3), a + Offset(0.15, 0.55), 0.09);
        case 1: // travessa
          final y = (r.nextDouble() - 0.5) * 1.1;
          _pincelada(p, Offset(-0.8, y), Offset(0, y + (r.nextDouble() - 0.5) * 0.7), Offset(0.8, y - 0.15), 0.08);
        case 2: // triângulo vazado
          final c = ponto(0.45);
          for (var v = 0; v < 3; v++) {
            final a = c + Offset(cos(v * 2.094 - pi / 2), sin(v * 2.094 - pi / 2)) * 0.42;
            final b = c + Offset(cos((v + 1) * 2.094 - pi / 2), sin((v + 1) * 2.094 - pi / 2)) * 0.42;
            _pincelada(p, a, (a + b) / 2, b, 0.05);
          }
        default: // pingo
          p.addOval(Rect.fromCircle(center: ponto(0.75), radius: 0.07 + r.nextDouble() * 0.05));
      }
    }
    return p;
  }
}

class _Lote {
  final transformacoes = <RSTransform>[];
  final recortes = <Rect>[];
  final cores = <Color>[];
  void add(Rect recorte, Offset pos, double escala, double giro, Color cor) {
    transformacoes.add(RSTransform.fromComponents(
      rotation: giro,
      scale: escala,
      anchorX: recorte.width / 2,
      anchorY: recorte.height / 2,
      translateX: pos.dx,
      translateY: pos.dy,
    ));
    recortes.add(recorte);
    cores.add(cor);
  }

  void desenhar(Canvas canvas, ui.Image img, Paint pintura) {
    if (transformacoes.isEmpty) return;
    canvas.drawAtlas(img, transformacoes, recortes, cores, BlendMode.modulate, null, pintura);
    transformacoes.clear();
    recortes.clear();
    cores.clear();
  }
}

double _ate1(double v) => v.clamp(0.0, 1.0);

/// Curva de entrada com uma passada bem exagerada do ponto final.
double _exagerada(double q) {
  const s = 2.8;
  final x = q - 1;
  return 1 + (s + 1) * x * x * x + s * x * x;
}

class _PintorCena extends CustomPainter {
  final ValueNotifier<double> tempo;
  final _Cena cena;
  final _Palco palco;
  final double escala;
  final bool calmo;
  _PintorCena({
    required this.tempo,
    required this.cena,
    required this.palco,
    required this.escala,
    required this.calmo,
  }) : super(repaint: tempo);

  static final _soma = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;
  static final _liso = Paint()..filterQuality = FilterQuality.low;

  // Sorteios fixos: partículas, gotas e estrelas são as mesmas a cada quadro.
  static final _centelhas = () {
    final r = Random(50);
    return List.generate(
        70,
        (_) => (
              nasce: r.nextDouble(),
              ang: r.nextDouble() * 2 * pi,
              vel: 0.05 + r.nextDouble() * 0.22,
              vida: 0.35 + r.nextDouble() * 0.7,
              tam: 0.25 + r.nextDouble() * 0.8,
              cor: r.nextInt(4),
            ));
  }();
  static final _estilhacos = () {
    final r = Random(51);
    return List.generate(
        150,
        (_) => (
              ang: r.nextDouble() * 2 * pi,
              vel: 0.3 + r.nextDouble() * 1.1,
              vida: 0.5 + r.nextDouble() * 1.1,
              tam: 0.25 + r.nextDouble() * 1.1,
              cor: r.nextInt(5),
            ));
  }();
  static final _riscos = () {
    final r = Random(52);
    return List.generate(
        36, (_) => (ang: r.nextDouble() * 2 * pi, tam: 0.5 + r.nextDouble(), atraso: r.nextDouble() * 0.12));
  }();
  static final _fiosAlto = () {
    final r = Random(53);
    return List.generate(
        13,
        (_) => (
              x: r.nextDouble() * 3 - 1.5,
              largura: 0.018 + r.nextDouble() * r.nextDouble() * 0.075,
              fim: 0.22 + r.nextDouble() * 0.9,
              atraso: r.nextDouble() * 0.5,
              ritmo: 0.55 + r.nextDouble() * 0.7,
              periodo: 2.4 + r.nextDouble() * 3,
              fase: r.nextDouble(),
            ));
  }();
  static final _fiosRuna = () {
    final r = Random(54);
    return List.generate(
        9,
        (_) => (
              x: r.nextDouble() * 1.7 - 0.85,
              largura: 0.025 + r.nextDouble() * 0.045,
              fim: 0.4 + r.nextDouble() * 0.9,
              periodo: 2.6 + r.nextDouble() * 2.8,
              fase: r.nextDouble(),
            ));
  }();
  static final _respingos = () {
    final r = Random(55);
    return List.generate(
        30,
        (_) => (
              ang: r.nextDouble() * 2 * pi,
              dist: 1.05 + r.nextDouble() * 0.8,
              tam: 0.01 + r.nextDouble() * r.nextDouble() * 0.04,
              alonga: 1 + r.nextDouble() * 1.2,
            ));
  }();

  void _preparar(Size s) {
    final c = cena;
    if (c.brilho == null) {
      const lado = 128;
      c.brilho = _imagem(lado, lado, (k) {
        final centro = const Offset(lado / 2, lado / 2);
        k.drawCircle(
          centro,
          lado / 2,
          Paint()
            ..shader = ui.Gradient.radial(centro, lado / 2, const [
              Color(0xFFFFFFFF),
              Color(0x66FFFFFF),
              Color(0x14FFFFFF),
              Color(0x00FFFFFF),
            ], const [
              0,
              0.18,
              0.55,
              1,
            ]),
        );
      });
    }
    if (c.glifos == null) {
      final r = Random(1913);
      const lado = _Glifos.lado;
      const linhas = _Glifos.quantos ~/ _Glifos.colunas;
      c.glifos = _imagem(lado * _Glifos.colunas, lado * linhas, (k) {
        for (var i = 0; i < _Glifos.quantos; i++) {
          final caixa = _Glifos.recorte(i);
          final p = _Glifos.glifo(r);
          k.save();
          k.translate(caixa.center.dx, caixa.center.dy);
          k.scale(lado * 0.34);
          k.drawPath(
              p,
              Paint()
                ..color = const Color(0x88FFFFFF)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.09));
          k.drawPath(p, Paint()..color = Colors.white);
          k.restore();
        }
      });
    }
    if (c.raioRunas != palco.raio) {
      for (final i in c.runas.values) {
        i.dispose();
      }
      for (final i in c.auras.values) {
        i.dispose();
      }
      c.runas.clear();
      c.auras.clear();
      c.raioRunas = palco.raio;
      final d = palco.raio * 2;
      final lado = (d * 1.4 * escala).ceil();
      for (final e in palco.ordem) {
        void runa(Canvas k) {
          k.scale(escala);
          k.translate(d * 0.2, d * 0.2);
          PintorRuna(
            elemento: Runa.normalizar(e),
            circulo: 3,
            semente: e,
            cor: _vivas[e]!,
            espessura: max(1.2, d / 62),
          ).paint(k, Size.square(d));
        }

        c.runas[e] = _imagem(lado, lado, runa);
        c.auras[e] = _imagem(lado, lado, (k) {
          k.saveLayer(
              null, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: d * 0.05 * escala, sigmaY: d * 0.05 * escala));
          runa(k);
          k.restore();
        });
      }
    }
    if (c.rabo == null) {
      c.rabo = _imagem(1024, 256, _pintarRabo);
    }
    if (c.tamanhoCeu != s) {
      c.ceu?.dispose();
      c.palco?.dispose();
      c.marcas?.dispose();
      c.tamanhoCeu = s;
      final f = escala * 0.6;
      c.ceu = _imagem((s.width * f).ceil(), (s.height * f).ceil(), (k) {
        k.scale(f);
        _pintarCeu(k, s);
      });
      c.palco = _imagem((s.width * f).ceil(), (s.height * f).ceil(), (k) {
        k.scale(f);
        _pintarPalco(k, s);
      });
      final lado = (s.shortestSide * 1.3 * f).ceil();
      c.marcas = _imagem(lado, lado, (k) {
        final r = lado / 2;
        final o = Offset(r, r);
        final linha = Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..strokeWidth = 1.2 * f;
        for (var i = 0; i < 48; i++) {
          final a = 2 * pi * i / 48;
          final d = Offset(cos(a), sin(a));
          k.drawLine(o + d * r * 0.93, o + d * r * (i % 4 == 0 ? 0.8 : 0.88), linha);
        }
      });
    }
  }

  /// A cauda do cometa, deitada: a ponta fina à esquerda, abrindo para a
  /// direita em faixas de luz desfocadas.
  void _pintarRabo(Canvas k) {
    const w = 1024.0, h = 256.0;
    const meio = h / 2;
    void faixa(double largura, double desvio, Color cor, double alfa, double desfoque) {
      final caminho = Path()..moveTo(0, meio);
      caminho.quadraticBezierTo(w * 0.35, meio + desvio - largura * 0.55, w, meio + desvio - largura);
      caminho.lineTo(w, meio + desvio + largura);
      caminho.quadraticBezierTo(w * 0.35, meio + desvio + largura * 0.55, 0, meio);
      k.drawPath(
        caminho,
        Paint()
          ..blendMode = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, desfoque)
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(w, 0), [
            Colors.white.withValues(alpha: alfa),
            cor.withValues(alpha: alfa),
            cor.withValues(alpha: alfa * 0.38),
            cor.withValues(alpha: 0),
          ], const [
            0,
            0.07,
            0.42,
            0.97,
          ]),
      );
    }

    faixa(112, 0, const Color(0xFF1244F0), 0.8, 14);
    faixa(70, -14, const Color(0xFF1F7BFF), 0.8, 8);
    faixa(46, 18, const Color(0xFF39B2FF), 0.75, 6);
    faixa(20, -30, const Color(0xFF9ADFFF), 0.8, 2.5);
    faixa(16, 6, const Color(0xFFE2F6FF), 0.9, 2);
    faixa(9, 30, const Color(0xFFBDEBFF), 0.8, 1.5);
  }

  /// O fundo dos símbolos: preto, com a luz vindo de cima e um grande círculo
  /// apagado.
  void _pintarPalco(Canvas k, Size s) {
    final area = Offset.zero & s;
    k.drawRect(area, Paint()..color = const Color(0xFF020104));
    k.drawRect(
      area,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height * 0.62), const [
          Color(0x7A2A1B4D),
          Color(0x00000000),
        ]),
    );
    final c = s.center(Offset.zero);
    final raio = s.shortestSide * 0.62;
    final anel = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.2;
    k.drawCircle(c, raio, anel);
    k.drawCircle(c, raio * 0.8, anel);
  }

  void _pintarCeu(Canvas k, Size s) {
    final area = Offset.zero & s;
    k.drawRect(
      area,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), const [
          Color(0xFF060833),
          Color(0xFF10309B),
          Color(0xFF2C78EC),
          Color(0xFF9DCDFF),
        ], const [
          0,
          0.42,
          0.8,
          1,
        ]),
    );
    final r = Random(9);
    final estrela = Paint();
    for (var i = 0; i < 280; i++) {
      final y = pow(r.nextDouble(), 1.5) * s.height * 0.75;
      estrela.color = Colors.white.withValues(alpha: (0.25 + r.nextDouble() * 0.75) * (1 - y / s.height));
      k.drawCircle(
          Offset(r.nextDouble() * s.width, y.toDouble()), 0.4 + r.nextDouble() * r.nextDouble() * 1.7, estrela);
    }
    // Cada nuvem são muitos tufos, dos de trás (baixos, azulados) para os da
    // frente, cada um claro em cima e azul embaixo, com a luz vinda de cima.
    void nuvem(double cx, double base, double largura) {
      final partes = <(Offset, double)>[];
      for (var i = 0; i < 46; i++) {
        final x = r.nextDouble() * 2 - 1;
        final alto = (1 - x * x) * (0.25 + r.nextDouble() * 0.75);
        final raio = largura * (0.028 + 0.075 * (1 - x.abs()) * (0.35 + r.nextDouble() * 0.65));
        partes.add((Offset(cx + x * largura / 2, base - alto * largura * 0.2), raio));
      }
      partes.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
      for (final (o, raio) in partes) {
        k.drawCircle(
          o,
          raio,
          Paint()
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, raio * 0.09)
            ..shader = ui.Gradient.radial(o - Offset(raio * 0.25, raio * 0.65), raio * 1.75, const [
              Color(0xFFFFFFFF),
              Color(0xFFEFF5FF),
              Color(0xFFB4CDF5),
              Color(0xFF6E98E2),
            ], const [
              0,
              0.42,
              0.72,
              1,
            ]),
        );
      }
    }

    final l = s.shortestSide;
    nuvem(s.width * 0.1, s.height * 1.0, l * 0.9);
    nuvem(s.width * 0.92, s.height * 0.95, l * 1.0);
    nuvem(s.width * 0.62, s.height * 1.04, l * 0.75);
  }

  static Color _corDe(int i) =>
      const [Color(0xFFFFC21A), Color(0xFFB45CFF), Color(0xFFF4F6FF), Color(0xFFFF1A3C), Color(0xFF8AD0FF)][i];

  void _brilho(Canvas canvas, Offset p, double raio, Color cor) {
    final img = cena.brilho!;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCircle(center: p, radius: raio),
      _soma..color = cor,
    );
    _soma.color = Colors.white;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _preparar(size);
    final t = tempo.value;
    final centro = size.center(Offset.zero);
    final lado = size.shortestSide;

    // Depois do pico da escolha só resta a cor, que vai apagando sobre a ficha
    // já com as cores novas.
    if (cena.tEscolha != null && t - cena.tEscolha! >= _picoEscolha) {
      final q = (t - cena.tEscolha! - _picoEscolha - 0.1) / (_fimEscolha - _picoEscolha - 0.1);
      canvas.drawRect(Offset.zero & size, Paint()..color = _vivas[cena.escolhido!]!.withValues(alpha: 1 - _ate1(q)));
      return;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // a câmera treme com a chegada do cometa e, mais forte, com o impacto
    if (!calmo) {
      final forca = t < _impacto
          ? pow(_ate1((t - _inicioCometa) / (_impacto - _inicioCometa)), 5) * lado * 0.012
          : exp(-(t - _impacto) * 7) * lado * 0.05;
      if (forca > 0.2) {
        canvas.translate(sin(t * 91) * forca, cos(t * 77) * forca);
      }
    }

    // o que já ficou todo coberto nem é desenhado
    final palcoCheio = t >= _abertura + 0.5;
    final ceuCheio = t >= _inicioCeu + 0.65;
    if (!ceuCheio) _escurecer(canvas, size, t);
    if (t > _inicioCeu && !palcoCheio) _ceu(canvas, size, t);
    if (t > _inicioCometa && t < _impacto + 0.1) _cometa(canvas, size, t, centro);
    if (t >= _abertura - 0.05) {
      _fundoDosSimbolos(canvas, size, t);
      _simbolos(canvas, size, t, centro);
    }
    if (t >= _impacto && t < _impacto + 2.2) _explosao(canvas, size, t, centro);
    canvas.restore();
    if (cena.tEscolha != null) _inundar(canvas, size, t, centro);
  }

  // ---------------- a tela escurece ----------------

  void _escurecer(Canvas canvas, Size size, double t) {
    final e = Curves.easeInOutCubic.transform(_ate1(t / _fimEscuro));
    final area = Offset.zero & size;
    // a escuridão fecha das bordas para o meio, enquanto a tela apaga
    canvas.drawRect(area, Paint()..color = Colors.black.withValues(alpha: 0.97 * Curves.easeIn.transform(e)));
    if (e < 1) {
      final raio = size.longestSide * (1.05 - 0.8 * e);
      canvas.drawRect(
        area,
        Paint()
          ..shader = ui.Gradient.radial(size.center(Offset.zero), max(raio, 1), [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: min(1, e * 1.6)),
          ], const [
            0.35,
            1,
          ]),
      );
    }
  }

  // ---------------- o céu e o cometa ----------------

  void _ceu(Canvas canvas, Size size, double t) {
    final img = cena.ceu!;
    final a = _ate1((t - _inicioCeu) / 0.65);
    // a câmera vai se aproximando do ponto do impacto
    final zoom = 1 + 0.16 * Curves.easeIn.transform(_ate1((t - _inicioCeu) / (_impacto - _inicioCeu)));
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: size.center(Offset.zero), width: size.width * zoom, height: size.height * zoom),
      _liso..color = Colors.white.withValues(alpha: a),
    );
    _liso.color = Colors.white;
  }

  void _cometa(Canvas canvas, Size size, double t, Offset fim) {
    final lado = size.shortestSide;
    final p = _ate1((t - _inicioCometa) / (_impacto - _inicioCometa));
    final inicio = Offset(-size.width * 0.06, -size.height * 0.1);
    const curva = 1.75;
    final andar = pow(p, curva).toDouble();
    final cabeca = Offset.lerp(inicio, fim, andar)!;
    final dir = fim - inicio;
    final d = dir / dir.distance;
    final n = Offset(-d.dy, d.dx);
    final perto = 0.3 + 1.2 * pow(p, 1.5).toDouble();
    final comprimento = size.longestSide * 1.5;
    final fimRabo = cabeca - d * comprimento;

    // a cauda: a faixa de luz já pronta, que só gira e estica...
    final rabo = cena.rabo!;
    canvas.save();
    canvas.translate(cabeca.dx, cabeca.dy);
    canvas.rotate(atan2(-d.dy, -d.dx));
    canvas.drawImageRect(
      rabo,
      Rect.fromLTWH(0, 0, rabo.width.toDouble(), rabo.height.toDouble()),
      Rect.fromLTWH(0, -lado * 0.34 * perto, comprimento, lado * 0.68 * perto),
      _soma,
    );
    canvas.restore();

    // ...e, por cima, as fitas dos quatro elementos, trançadas
    void fita(Color cor, double largura, double fase, double onda, double alfa) {
      const pontos = 18;
      final a = <Offset>[], b = <Offset>[];
      for (var i = 0; i <= pontos; i++) {
        final s = i / pontos;
        final o = cabeca - d * (comprimento * s * s);
        final meio = sin(s * 9 + fase + t * 7) * onda * lado * perto * s;
        final w = largura * lado * perto * (0.02 + pow(s, 0.55));
        a.add(o + n * (meio + w));
        b.add(o + n * (meio - w));
      }
      canvas.drawPath(
        Path()..addPolygon([...a, ...b.reversed], true),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(cabeca, fimRabo, [
            Colors.white.withValues(alpha: alfa),
            cor.withValues(alpha: alfa * 0.9),
            cor.withValues(alpha: alfa * 0.32),
            cor.withValues(alpha: 0),
          ], const [
            0,
            0.05,
            0.32,
            0.8,
          ]),
      );
    }

    for (var i = 0; i < 4; i++) {
      fita(_corDe(i), 0.011, i * pi / 2, 0.05, 0.95);
    }

    // centelhas que ficam para trás
    final centelhas = _Lote();
    final brilho = cena.brilho!;
    final recorte = Rect.fromLTWH(0, 0, brilho.width.toDouble(), brilho.height.toDouble());
    for (final c in _centelhas) {
      final idade = p - c.nasce * 0.95;
      if (idade < 0 || idade > c.vida) continue;
      final v = idade / c.vida;
      final q = Offset.lerp(inicio, fim, pow(c.nasce * 0.95, curva).toDouble())!;
      final pos = q + Offset(cos(c.ang), sin(c.ang)) * c.vel * lado * Curves.easeOut.transform(_ate1(v * 1.2));
      final tam = c.tam * lado * 0.13 * (1 - v) / brilho.width;
      centelhas.add(recorte, pos, tam * 2, 0, _corDe(c.cor).withValues(alpha: (1 - v)));
    }
    centelhas.desenhar(canvas, brilho, _soma);

    // a cabeça: um clarão com dois fios de luz em cruz
    final raio = lado * 0.17 * perto;
    _brilho(canvas, cabeca, raio * 2.2, const Color(0xFF7FC4FF));
    _brilho(canvas, cabeca, raio, Colors.white);
    canvas.save();
    canvas.translate(cabeca.dx, cabeca.dy);
    final giro = t * 1.2;
    for (final (i, a) in const [0.0, pi / 2, pi / 4, -pi / 4].indexed) {
      canvas.save();
      canvas.rotate(a + giro * 0.3);
      final comp = raio * (i < 2 ? 3.4 : 1.7) * (0.85 + 0.15 * sin(t * 37 + i));
      canvas.drawImageRect(
        brilho,
        recorte,
        Rect.fromCenter(center: Offset.zero, width: comp * 2, height: raio * 0.12),
        _soma,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  // ---------------- o impacto ----------------

  void _explosao(Canvas canvas, Size size, double t, Offset c) {
    final tau = t - _impacto;
    final lado = size.shortestSide;
    final longe = size.longestSide;

    // riscos de velocidade para fora
    if (tau < 0.5) {
      final risco = Paint()..blendMode = BlendMode.plus;
      for (final r in _riscos) {
        final q = _ate1((tau - r.atraso) / 0.36);
        if (q <= 0 || q >= 1) continue;
        final d = Offset(cos(r.ang), sin(r.ang));
        final n = Offset(-d.dy, d.dx);
        final ini = longe * (0.08 + 0.75 * Curves.easeOut.transform(q));
        final fim = ini + longe * 0.32 * r.tam * (1 - q);
        final w = lado * 0.01 * r.tam * (1 - q);
        risco.color = Colors.white.withValues(alpha: 1 - q);
        canvas.drawPath(
          Path()
            ..moveTo((c + d * fim).dx, (c + d * fim).dy)
            ..lineTo((c + d * ini + n * w).dx, (c + d * ini + n * w).dy)
            ..lineTo((c + d * ini - n * w).dx, (c + d * ini - n * w).dy)
            ..close(),
          risco,
        );
      }
    }

    // ondas de choque, uma de cada elemento
    for (var i = 0; i < 4; i++) {
      final q = _ate1((tau - i * 0.06) / 0.85);
      if (q <= 0 || q >= 1) continue;
      final e = Curves.easeOutCubic.transform(q);
      canvas.drawCircle(
        c,
        longe * 0.85 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lado * 0.05 * (1 - e)
          ..blendMode = BlendMode.plus
          ..color = _corDe(i).withValues(alpha: 1 - q),
      );
    }

    // estilhaços de luz
    final brilho = cena.brilho!;
    final recorte = Rect.fromLTWH(0, 0, brilho.width.toDouble(), brilho.height.toDouble());
    final lote = _Lote();
    for (final e in _estilhacos) {
      if (tau > e.vida) continue;
      final v = tau / e.vida;
      final dist = longe * 0.52 * e.vel * (1 - exp(-tau * 3.6));
      final pos = c + Offset(cos(e.ang), sin(e.ang)) * dist + Offset(0, lado * 0.09 * tau * tau);
      lote.add(
          recorte, pos, e.tam * lado * 0.09 * (1 - v) / brilho.width * 2, 0, _corDe(e.cor).withValues(alpha: 1 - v));
    }
    lote.desenhar(canvas, brilho, _soma);

    // o clarão: um só, que sobe num instante e vai apagando
    if (tau < 0.6) {
      final a = tau < 0.045 ? tau / 0.045 : pow(1 - (tau - 0.045) / 0.555, 2.2).toDouble();
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: a));
    }
  }

  // ---------------- os símbolos ----------------

  void _fundoDosSimbolos(Canvas canvas, Size size, double t) {
    final q = _ate1((t - _abertura) / 0.5);
    final c = size.center(Offset.zero);
    final palcoImg = cena.palco!;
    canvas.drawImageRect(
      palcoImg,
      Rect.fromLTWH(0, 0, palcoImg.width.toDouble(), palcoImg.height.toDouble()),
      Offset.zero & size,
      _liso..color = Colors.white.withValues(alpha: q),
    );
    _liso.color = Colors.white;
    // as marcas do círculo giram devagar atrás de tudo
    final marcas = cena.marcas!;
    final raio = size.shortestSide * 0.65;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 0.08);
    canvas.drawImageRect(
      marcas,
      Rect.fromLTWH(0, 0, marcas.width.toDouble(), marcas.height.toDouble()),
      Rect.fromCircle(center: Offset.zero, radius: raio),
      _liso..color = Colors.white.withValues(alpha: q),
    );
    _liso.color = Colors.white;
    canvas.restore();
  }

  void _simbolos(Canvas canvas, Size size, double t, Offset centro) {
    final foco = cena.foco;
    for (var i = 0; i < 4; i++) {
      final alvo = foco == i ? 1.0 : 0.0;
      cena.focoSuave[i] += (alvo - cena.focoSuave[i]) * 0.2;
    }
    final e = cena.tEscolha;
    final depois = e == null ? 0.0 : t - e;
    for (final (i, nome) in palco.ordem.indexed) {
      final q = _ate1((t - _abertura - i * _entreSimbolos) / _entradaSimbolo);
      if (q <= 0) continue;
      var pos = Offset.lerp(centro, palco.centros[i], Curves.easeOutCubic.transform(q))!;
      var tam = _exagerada(q) * (1 + cena.focoSuave[i] * 0.09);
      var alfa = _ate1(q * 5);
      if (e != null) {
        if (cena.escolhido == nome) {
          final v = Curves.easeOutBack.transform(_ate1(depois / 0.55));
          pos = Offset.lerp(pos, centro, v)!;
          tam *= 1 + 0.8 * v;
        } else {
          final v = _ate1(depois / 0.26);
          tam *= 1 - 0.45 * v;
          alfa *= 1 - v;
        }
      }
      if (alfa <= 0) continue;
      final viva = t - _abertura - i * _entreSimbolos;
      switch (nome) {
        case 'Sangue':
          _sangue(canvas, size, pos, tam, viva, alfa, q);
        case 'Morte':
          _morte(canvas, pos, tam, viva, alfa, q);
        case 'Energia':
          _energia(canvas, pos, tam, viva, alfa);
        default:
          _conhecimento(canvas, pos, tam, viva, alfa, q);
      }
      // o baque da chegada
      if (q > 0.45 && q < 1) {
        final b = (q - 0.45) / 0.55;
        canvas.drawCircle(
          palco.centros[i],
          palco.raio * (0.9 + 1.2 * b),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = palco.raio * 0.1 * (1 - b)
            ..blendMode = BlendMode.plus
            ..color = _vivas[nome]!.withValues(alpha: 1 - b),
        );
      }
    }
  }

  /// A runa no lugar dela: [giro] em volta do centro, [aura] é a força do
  /// brilho.
  void _runa(Canvas canvas, String e, Offset p, double tam, double giro, double aura, double alfa, {Paint? pintura}) {
    final img = cena.runas[e]!;
    final d = palco.raio * 2 * 1.4 * tam;
    final origem = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final destino = Rect.fromCenter(center: Offset.zero, width: d, height: d);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    if (giro != 0) canvas.rotate(giro);
    if (aura > 0) {
      canvas.drawImageRect(
          cena.auras[e]!, origem, destino, _soma..color = Colors.white.withValues(alpha: _ate1(aura * alfa)));
      if (aura > 1) {
        canvas.drawImageRect(
            cena.auras[e]!, origem, destino, _soma..color = Colors.white.withValues(alpha: _ate1((aura - 1) * alfa)));
      }
      _soma.color = Colors.white;
    }
    final p2 = pintura ?? _liso;
    p2.color = Colors.white.withValues(alpha: alfa);
    canvas.drawImageRect(img, origem, destino, p2);
    p2.color = Colors.white;
    canvas.restore();
  }

  /// Sigilos em volta, em dois anéis que giram ao contrário um do outro, e um
  /// fluxo deles entrando em espiral, como as letras da mesa de encantamento.
  void _conhecimento(Canvas canvas, Offset p, double tam, double t, double alfa, double q) {
    final cor = _vivas['Conhecimento']!;
    final r = palco.raio * tam;
    final pulso = 0.5 + 0.5 * sin(t * 2.4);
    _brilho(canvas, p, r * 2.3, cor.withValues(alpha: (0.34 + 0.2 * pulso) * alfa));
    _runa(canvas, 'Conhecimento', p, tam, 0, 1 + pulso * 0.9, alfa);

    final img = cena.glifos!;
    final lote = _Lote();
    final abre = Curves.easeOutBack.transform(_ate1(q * 1.4));
    final claro = Color.lerp(cor, Colors.white, 0.45)!;
    void anel(int quantos, double raio, double vel, double tamanho, int base) {
      for (var i = 0; i < quantos; i++) {
        final a = t * vel + 2 * pi * i / quantos;
        final d = Offset(cos(a), sin(a));
        final pos = p + d * r * raio * abre + Offset(0, sin(t * 2.1 + i) * r * 0.03);
        // cada um acende e apaga no seu tempo
        final luz = 0.55 + 0.45 * sin(t * 1.7 + i * 1.3);
        lote.add(_Glifos.recorte(base + i), pos, r * tamanho / _Glifos.lado, a + pi / 2,
            Color.lerp(cor, claro, luz)!.withValues(alpha: alfa * (0.5 + 0.5 * luz)));
      }
    }

    anel(12, 1.24, 0.6, 0.46, 0);
    anel(16, 1.56, -0.38, 0.38, 7);
    for (var i = 0; i < 20; i++) {
      final periodo = 1.9 + (i % 5) * 0.34;
      final x = t / periodo + i * 0.381;
      final ciclo = x.floor();
      final s = x - ciclo;
      final rnd = Random(i * 7919 + ciclo * 104729);
      final a0 = rnd.nextDouble() * 2 * pi;
      final dist = r * (2.05 - 1.75 * Curves.easeIn.transform(s));
      final a = a0 + s * 2.5;
      final pos = p + Offset(cos(a), sin(a)) * dist;
      lote.add(_Glifos.recorte(rnd.nextInt(_Glifos.quantos)), pos, r * (0.5 - 0.28 * s) / _Glifos.lado,
          (rnd.nextDouble() - 0.5) * 0.9 + s, claro.withValues(alpha: alfa * sin(pi * s)));
    }
    lote.desenhar(canvas, img, _soma);
  }

  /// Gira no sentido anti-horário, com rastros, e puxa a cinza em volta.
  void _morte(Canvas canvas, Offset p, double tam, double t, double alfa, double q) {
    final cor = _vivas['Morte']!;
    final r = palco.raio * tam;
    // entra girando rápido e assenta numa rotação constante
    final giro = -(t * 1.15 + 9 * (1 - Curves.easeOutCubic.transform(q)));
    _brilho(canvas, p, r * 2.1, const Color(0xFF9FB0FF).withValues(alpha: 0.3 * alfa));
    for (var k = 5; k >= 1; k--) {
      _runa(canvas, 'Morte', p, tam, giro + k * 0.15, 0, alfa * 0.3 / k, pintura: _soma);
    }
    _runa(canvas, 'Morte', p, tam, giro, 1.25, alfa);

    // arcos de fora, também no sentido anti-horário
    final arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (var i = 0; i < 3; i++) {
      final raio = r * (1.14 + i * 0.13);
      arco
        ..strokeWidth = r * (0.03 - i * 0.007)
        ..color = cor.withValues(alpha: alfa * (0.6 - i * 0.15));
      for (var k = 0; k < 3; k++) {
        canvas.drawArc(Rect.fromCircle(center: p, radius: raio), giro * (1.5 + i * 0.7) + k * 2 * pi / 3 + i,
            1.1 - i * 0.2, false, arco);
      }
    }

    // cinza caindo em espiral para o centro
    final brilho = cena.brilho!;
    final recorte = Rect.fromLTWH(0, 0, brilho.width.toDouble(), brilho.height.toDouble());
    final lote = _Lote();
    for (var i = 0; i < 46; i++) {
      final periodo = 1.5 + (i % 7) * 0.26;
      final x = t / periodo + i * 0.27;
      final s = x - x.floor();
      final a = i * 2.399 - s * 5.2 - t * 0.4;
      final dist = r * (1.85 - 1.55 * s);
      lote.add(recorte, p + Offset(cos(a), sin(a)) * dist, r * (0.13 - 0.07 * s) / brilho.width * 2, 0,
          cor.withValues(alpha: alfa * sin(pi * s) * 0.85));
    }
    lote.desenhar(canvas, brilho, _soma);
  }

  /// Pisca e falha: de tempos em tempos entra uma rajada em que a luz some,
  /// as cores se separam, a imagem racha em faixas e saem raios.
  void _energia(Canvas canvas, Offset p, double tam, double t, double alfa) {
    final cor = _vivas['Energia']!;
    final r = palco.raio * tam;
    final quadro = (t * 16).floor();
    final rnd = Random(quadro * 7 + 3);
    final rajada = sin(t * 3.1) + sin(t * 1.27 + 1) > 0.35;
    final sorte = rnd.nextDouble();
    final luz = rajada
        ? (sorte < 0.34 ? 0.12 + rnd.nextDouble() * 0.2 : (sorte < 0.6 ? 0.55 : 1.0))
        : (sorte < 0.08 ? 0.55 : 1.0);
    final falha = rajada && rnd.nextDouble() < 0.5;
    final tremor = rajada ? Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() - 0.5) * r * 0.07 : Offset.zero;
    final centro = p + tremor;

    _brilho(canvas, centro, r * 2.4, cor.withValues(alpha: (rajada ? 0.62 : 0.34) * luz * alfa));
    if (falha) {
      final desvio = r * (0.05 + rnd.nextDouble() * 0.09);
      _runa(canvas, 'Energia', centro + Offset(desvio, 0), tam, 0, 0, alfa * 0.8,
          pintura: Paint()
            ..blendMode = BlendMode.plus
            ..filterQuality = FilterQuality.low
            ..colorFilter = const ColorFilter.mode(Color(0xFF29E7FF), BlendMode.srcIn));
      _runa(canvas, 'Energia', centro - Offset(desvio, 0), tam, 0, 0, alfa * 0.8,
          pintura: Paint()
            ..blendMode = BlendMode.plus
            ..filterQuality = FilterQuality.low
            ..colorFilter = const ColorFilter.mode(Color(0xFFFF2BD6), BlendMode.srcIn));
      const faixas = 5;
      final topo = centro.dy - r * 1.4;
      for (var i = 0; i < faixas; i++) {
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(centro.dx - r * 1.6, topo + r * 2.8 * i / faixas, r * 3.2, r * 2.8 / faixas));
        _runa(
            canvas, 'Energia', centro + Offset((rnd.nextDouble() - 0.5) * r * 0.26, 0), tam, 0, 0.9 * luz, alfa * luz);
        canvas.restore();
      }
    } else {
      _runa(canvas, 'Energia', centro, tam, 0, 1.3 * luz + 0.3, alfa * luz);
    }

    // raios saindo do círculo
    final quantos = rajada ? 3 : (rnd.nextDouble() < 0.2 ? 1 : 0);
    for (var i = 0; i < quantos; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final a2 = a + (rnd.nextDouble() - 0.5) * 1.1;
      final de = centro + Offset(cos(a), sin(a)) * r * 0.86;
      final para = centro + Offset(cos(a2), sin(a2)) * r * (1.25 + rnd.nextDouble() * 0.45);
      final caminho = Path()..moveTo(de.dx, de.dy);
      final d = para - de;
      final n = Offset(-d.dy, d.dx) / max(d.distance, 1);
      for (var k = 1; k < 6; k++) {
        final o = de + d * (k / 6) + n * (rnd.nextDouble() - 0.5) * r * 0.22;
        caminho.lineTo(o.dx, o.dy);
      }
      caminho.lineTo(para.dx, para.dy);
      canvas.drawPath(
          caminho,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.055
            ..strokeJoin = StrokeJoin.round
            ..blendMode = BlendMode.plus
            ..color = cor.withValues(alpha: 0.5 * alfa));
      canvas.drawPath(
          caminho,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.016
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white.withValues(alpha: 0.95 * alfa));
      _brilho(canvas, para, r * 0.24, cor.withValues(alpha: alfa));
    }
  }

  /// O sangue desce do alto da tela, grosso e devagar, passa pelo símbolo e
  /// continua pingando dele. O símbolo bate como um coração.
  void _sangue(Canvas canvas, Size size, Offset p, double tam, double t, double alfa, double q) {
    final cor = _vivas['Sangue']!;
    final r = palco.raio * tam;
    final x = t % 1.25;
    double pico(double m) => exp(-pow((x - m) / 0.07, 2)).toDouble();
    final batida = pico(0.1) + 0.6 * pico(0.32);

    final escuro = const Color(0xFF8C0013);
    final vivo = const Color(0xFFE8001F);
    final tinta = Paint()..color = vivo.withValues(alpha: alfa);
    final base = palco.centros[palco.ordem.indexOf('Sangue')];
    final raioBase = palco.raio;

    // o alto da tela
    final cresce = Curves.easeOutCubic.transform(_ate1(t / 1.4));
    final cortina = Path()..moveTo(base.dx - raioBase * 1.9, -4);
    for (var i = 0; i <= 26; i++) {
      final s = i / 26;
      final xx = base.dx + raioBase * (s * 3.8 - 1.9);
      final bico = sin(pi * s);
      final h = raioBase * (0.05 + 0.4 * bico * (0.55 + 0.45 * sin(i * 2.7))) * cresce;
      cortina.lineTo(xx, h);
    }
    cortina
      ..lineTo(base.dx + raioBase * 1.9, -4)
      ..close();
    canvas.drawPath(cortina, Paint()..color = escuro.withValues(alpha: alfa));

    // os fios que descem
    final alvo = base.dy + raioBase * 0.95;
    for (final f in _fiosAlto) {
      final idade = t - f.atraso;
      if (idade <= 0) continue;
      final fim = alvo * f.fim * (1 - exp(-idade * f.ritmo));
      final fx = base.dx + f.x * raioBase;
      final w = f.largura * raioBase;
      _fio(canvas, fx, -2, fim, w, tinta, alfa);
      // uma gota que corre pelo fio e cai da ponta
      final s = (t / f.periodo + f.fase) % 1;
      final gy = -2 + (size.height + 40) * s * s;
      if (gy < fim) {
        canvas.drawCircle(Offset(fx, gy), w * 1.05, tinta);
      } else if (fim > raioBase * 0.3) {
        canvas.drawOval(Rect.fromCenter(center: Offset(fx, gy), width: w * 1.5, height: w * 2.8), tinta);
      }
    }

    // o símbolo por cima do que escorre
    _brilho(canvas, p, r * (2.1 + 0.3 * batida), cor.withValues(alpha: (0.3 + 0.32 * batida) * alfa));
    _runa(canvas, 'Sangue', p, tam * (1 + 0.075 * batida), 0, 0.9 + batida * 1.2, alfa);

    // o que pinga do próprio símbolo
    for (final f in _fiosRuna) {
      final s = (t / f.periodo + f.fase) % 1;
      final xr = f.x * r;
      final y0 = p.dy + sqrt(max(0, r * r * 0.9 - xr * xr)) - r * 0.08;
      final w = f.largura * r;
      if (s < 0.68) {
        final l = r * f.fim * Curves.easeInOutCubic.transform(s / 0.68);
        _fio(canvas, p.dx + xr, y0, y0 + l, w, tinta, alfa);
      } else {
        // a gota solta e o fio que recolhe
        final v = (s - 0.68) / 0.32;
        final l = r * f.fim * (1 - v * 0.75);
        _fio(canvas, p.dx + xr, y0, y0 + l, w * (1 - v * 0.5), tinta, alfa);
        final gy = y0 + r * f.fim + (size.height * 0.85) * v * v;
        canvas.drawOval(Rect.fromCenter(center: Offset(p.dx + xr, gy), width: w * 1.6, height: w * (2 + v * 3)), tinta);
      }
    }

    // respingos da chegada, que ficam
    final respinga = Curves.easeOutBack.transform(_ate1((q - 0.35) * 2.2));
    if (respinga > 0) {
      for (final g in _respingos) {
        final d = Offset(cos(g.ang), sin(g.ang));
        final o = base + d * raioBase * g.dist * respinga;
        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(g.ang);
        canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: raioBase * g.tam * 2 * g.alonga, height: raioBase * g.tam * 2),
            tinta);
        canvas.restore();
      }
    }
  }

  /// Um fio de sangue: largo em cima, fino no meio e com a gota na ponta.
  void _fio(Canvas canvas, double x, double y0, double y1, double w, Paint tinta, double alfa) {
    if (y1 <= y0) return;
    final meio = (y0 + y1) / 2;
    canvas.drawPath(
      Path()
        ..moveTo(x - w * 1.25, y0)
        ..quadraticBezierTo(x - w * 0.45, meio, x - w * 0.45, y1)
        ..lineTo(x + w * 0.45, y1)
        ..quadraticBezierTo(x + w * 0.45, meio, x + w * 1.25, y0)
        ..close(),
      tinta,
    );
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y1 + w * 0.3), width: w * 2, height: w * 2.7), tinta);
    canvas.drawCircle(Offset(x - w * 0.3, y1), w * 0.26, Paint()..color = Colors.white.withValues(alpha: 0.5 * alfa));
  }

  // ---------------- a escolha ----------------

  /// A cor do elemento escolhido toma a tela a partir do centro.
  void _inundar(Canvas canvas, Size size, double t, Offset c) {
    final q = _ate1((t - cena.tEscolha! - 0.42) / (_picoEscolha - 0.42));
    if (q <= 0) return;
    final cor = _vivas[cena.escolhido!]!;
    final e = Curves.easeInCubic.transform(q);
    final raio = size.longestSide * 1.1 * e;
    if (raio < 1) return;
    canvas.drawCircle(
      c,
      raio,
      Paint()
        ..shader = ui.Gradient.radial(c, raio, [
          Color.lerp(cor, Colors.white, 0.75)!,
          cor,
          cor,
        ], const [
          0,
          0.55,
          1,
        ]),
    );
    if (q >= 1) canvas.drawRect(Offset.zero & size, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant _PintorCena old) =>
      old.palco.raio != palco.raio ||
      old.palco.ordem != palco.ordem ||
      old.palco.centros[0] != palco.centros[0] ||
      old.escala != escala ||
      old.calmo != calmo;
}
