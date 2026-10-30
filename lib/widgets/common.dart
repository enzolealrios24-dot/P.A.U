import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dice.dart';
import '../core/theme.dart';
import 'efeitos.dart';
import 'rolagem_dados.dart';

/// Campo de texto que salva sozinho (com atraso) e nao "pula" enquanto voce
/// digita, mesmo recebendo atualizacoes em tempo real.
class CampoSync extends StatefulWidget {
  final String valor;
  final ValueChanged<String> aoSalvar;
  final String? rotulo;
  final int maxLinhas;
  final bool numerico;
  final TextAlign alinhamento;
  final TextStyle? estilo;
  final String? dica;
  const CampoSync({
    super.key,
    required this.valor,
    required this.aoSalvar,
    this.rotulo,
    this.maxLinhas = 1,
    this.numerico = false,
    this.alinhamento = TextAlign.start,
    this.estilo,
    this.dica,
  });

  @override
  State<CampoSync> createState() => _CampoSyncState();
}

class _CampoSyncState extends State<CampoSync> {
  late final TextEditingController _c = TextEditingController(text: widget.valor);
  final _foco = FocusNode();
  Timer? _t;
  String? _pendente;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _salvarAgora();
    });
  }

  @override
  void didUpdateWidget(covariant CampoSync old) {
    super.didUpdateWidget(old);
    if (!_foco.hasFocus && _pendente == null && _c.text != widget.valor) {
      _c.text = widget.valor;
    }
  }

  void _salvarAgora() {
    _t?.cancel();
    final p = _pendente;
    if (p != null) {
      _pendente = null;
      if (p != widget.valor) widget.aoSalvar(p);
    }
  }

  @override
  void dispose() {
    _salvarAgora();
    _t?.cancel();
    _foco.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _foco,
      maxLines: widget.maxLinhas,
      minLines: 1,
      textAlign: widget.alinhamento,
      style: widget.estilo,
      keyboardType: widget.numerico
          ? const TextInputType.numberWithOptions(signed: true)
          : (widget.maxLinhas > 1 ? TextInputType.multiline : TextInputType.text),
      inputFormatters: widget.numerico
          ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))]
          : null,
      decoration: InputDecoration(labelText: widget.rotulo, hintText: widget.dica),
      onChanged: (v) {
        _pendente = v;
        _t?.cancel();
        _t = Timer(const Duration(milliseconds: 700), _salvarAgora);
      },
      onSubmitted: (_) => _salvarAgora(),
    );
  }
}

class CampoNumero extends StatelessWidget {
  final int valor;
  final ValueChanged<int> aoSalvar;
  final String? rotulo;
  const CampoNumero(
      {super.key, required this.valor, required this.aoSalvar, this.rotulo});
  @override
  Widget build(BuildContext context) => CampoSync(
        valor: '$valor',
        numerico: true,
        rotulo: rotulo,
        alinhamento: TextAlign.center,
        aoSalvar: (s) => aoSalvar(int.tryParse(s) ?? 0),
      );
}

/// Barra de PV/PE/SAN: « -5, ‹ -1, toque no número para digitar, › +1, » +5.
class BarraStatus extends StatelessWidget {
  final String rotulo;
  final int atual;
  final int max;
  final Color cor;
  final ValueChanged<int> aoMudar; // novo valor
  final bool compacta;
  const BarraStatus({
    super.key,
    required this.rotulo,
    required this.atual,
    required this.max,
    required this.cor,
    required this.aoMudar,
    this.compacta = false,
  });

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (atual / max).clamp(0.0, 1.0);
    final alto = compacta ? 34.0 : 40.0;
    Widget seta(IconData icone, int d) => SizedBox(
          width: compacta ? 30 : 34,
          height: alto,
          child: InkWell(
            onTap: () => aoMudar(atual + d),
            child: Tooltip(
              message: d > 0 ? '+$d' : '$d',
              child: Icon(icone, size: compacta ? 17 : 20, color: Cores.texto.withValues(alpha: 0.8)),
            ),
          ),
        );
    // o nome fica numa casa à esquerda, como na ficha impressa; o
    // preenchimento é translúcido, para o número ficar legível em qualquer
    // cor de tema
    return Container(
      height: alto,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.alphaBlend(cor.withValues(alpha: 0.07), Cores.painel2),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          width: rotulo.length > 3 ? 62 : 42,
          alignment: Alignment.center,
          color: cor.withValues(alpha: 0.16),
          child: Text(rotulo,
              textAlign: TextAlign.center,
              style: estiloRotulo(compacta ? 11.5 : 13, cor: Cores.texto, peso: FontWeight.w700, espaco: 1)),
        ),
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: frac),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: child,
              ),
              child: ColoredBox(color: cor.withValues(alpha: 0.32)),
            ),
            Row(children: [
              seta(Icons.keyboard_double_arrow_left, -5),
              seta(Icons.chevron_left, -1),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final v = await pedirNumero(context, rotulo, atual);
                    if (v != null) aoMudar(v);
                  },
                  child: Center(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$atual', style: estiloNumero(compacta ? 18 : 21, cor: Cores.texto)),
                        TextSpan(
                            text: ' / $max',
                            style: estiloNumero(compacta ? 13 : 15,
                                cor: Cores.texto.withValues(alpha: 0.7), peso: FontWeight.w600)),
                      ]),
                      style: const TextStyle(shadows: [Shadow(color: Colors.black87, blurRadius: 4)]),
                    ),
                  ),
                ),
              ),
              seta(Icons.chevron_right, 1),
              seta(Icons.keyboard_double_arrow_right, 5),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Medidor pequeno (só leitura): rótulo, valor e uma barra fina.
class MedidorMini extends StatelessWidget {
  final String rotulo;
  final int atual, max;
  final Color cor;
  /// Pontos temporários, mostrados como "+N".
  final int temp;
  const MedidorMini(
      {super.key,
      required this.rotulo,
      required this.atual,
      required this.max,
      required this.cor,
      this.temp = 0});

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (atual / max).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(rotulo, style: estiloRotulo(11.5, cor: cor, peso: FontWeight.w700, espaco: 1.2)),
        const Spacer(),
        Text.rich(TextSpan(children: [
          TextSpan(text: '$atual', style: estiloNumero(15, cor: Cores.texto)),
          TextSpan(text: '/$max', style: estiloNumero(11.5, cor: Cores.textoFraco, peso: FontWeight.w600)),
          if (temp > 0)
            TextSpan(text: ' +$temp', style: estiloNumero(11.5, cor: cor, peso: FontWeight.w700)),
        ])),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 4,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: cor.withValues(alpha: 0.16)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: ColoredBox(color: cor),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Selo pequeno (NEX, patente, "em uso"...).
class Selo extends StatelessWidget {
  final String texto;
  final Color? cor;
  final IconData? icone;
  /// Preenchido com a cor (em vez de só contornado).
  final bool cheio;
  const Selo(this.texto, {super.key, this.cor, this.icone, this.cheio = false});

  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cores.destaque;
    final frente = cheio ? Cores.sobreDestaque : c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: cheio ? 0.95 : 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.withValues(alpha: cheio ? 1 : 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[
          Icon(icone, size: 13, color: frente),
          const SizedBox(width: 4),
        ],
        Text(texto, style: estiloRotulo(12.5, cor: frente, peso: FontWeight.w700, espaco: 1)),
      ]),
    );
  }
}

Future<int?> pedirNumero(BuildContext context, String titulo, int atual) {
  final c = TextEditingController(text: '$atual');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: const InputDecoration(
            helperText: 'Use +N ou -N para somar/subtrair'),
        onSubmitted: (_) => Navigator.pop(ctx, _interpretar(c.text, atual)),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, _interpretar(c.text, atual)),
            child: const Text('OK')),
      ],
    ),
  );
}

int? _interpretar(String s, int atual) {
  final t = s.trim();
  if (t.startsWith('+')) {
    final v = int.tryParse(t.substring(1));
    return v == null ? null : atual + v;
  }
  if (t.startsWith('-') && t.length > 1) {
    final v = int.tryParse(t.substring(1));
    return v == null ? null : atual - v;
  }
  return int.tryParse(t);
}

Future<String?> pedirTexto(BuildContext context, String titulo,
    {String inicial = '', String? dica}) {
  final c = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: dica),
        onSubmitted: (_) => Navigator.pop(ctx, c.text.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirmar(BuildContext context, String texto) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(texto),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar')),
      ],
    ),
  );
  return r ?? false;
}

/// Mostra uma rolagem com o d20 animado (janela em rolagem_dados.dart).
void mostrarRolagem(BuildContext context, Rolagem r) => mostrarDados(context, r);

class Secao extends StatelessWidget {
  final String titulo;
  final Widget child;
  final List<Widget> acoes;
  const Secao(
      {super.key, required this.titulo, required this.child, this.acoes = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Stack(clipBehavior: Clip.none, children: [
          // Material (e não só uma caixa) para as listas de dentro terem o
          // efeito de toque
          Material(
            color: Cores.painel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: Cores.borda),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: child,
            ),
          ),
          Positioned(left: 12, top: -11, child: RotuloArquivo(titulo)),
          // os botões da seção ficam presos na borda, do lado oposto da etiqueta
          if (acoes.isNotEmpty)
            Positioned(
              right: 10,
              top: -15,
              child: Material(
                color: Cores.painel2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: Cores.borda),
                ),
                child: TextButtonTheme(
                  data: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: Cores.destaque,
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: estiloRotulo(14.5, peso: FontWeight.w700, espaco: 0.6),
                    ),
                  ),
                  child: IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        minimumSize: const Size(30, 30),
                        padding: const EdgeInsets.all(4),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: acoes),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// Etiqueta de arquivo: caixa sólida com letras espaçadas e um bloco
/// deslocado atrás, como "SUMÁRIO" e "O ANFITRIÃO" nos livros.
class RotuloArquivo extends StatelessWidget {
  final String texto;
  final Color? cor;
  final double tamanho;
  const RotuloArquivo(this.texto, {super.key, this.cor, this.tamanho = 13});
  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cores.destaque;
    final frente = c == Cores.destaque ? Cores.sobreDestaque : (c.computeLuminance() > 0.45 ? Colors.black : Colors.white);
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
        left: 3,
        top: 3,
        right: -3,
        bottom: -3,
        child: ColoredBox(color: Cores.roxo.withValues(alpha: 0.9)),
      ),
      Container(
        color: c,
        padding: EdgeInsets.fromLTRB(tamanho * 0.7, tamanho * 0.3, tamanho * 0.75, tamanho * 0.3),
        child: Text(texto.toUpperCase(),
            style: estiloRotulo(tamanho, cor: frente, peso: FontWeight.w700, espaco: tamanho * 0.17)),
      ),
    ]);
  }
}

/// Etiqueta pequena de tipo (ORIGEM, CLASSE...), sólida e de canto reto.
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color? cor;
  const Etiqueta(this.texto, {super.key, this.cor});
  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cores.destaque;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      color: c.withValues(alpha: 0.9),
      child: Text(texto,
          style: estiloRotulo(10.5,
              cor: c.computeLuminance() > 0.4 ? Colors.black : Colors.white,
              peso: FontWeight.w700,
              espaco: 1.3)),
    );
  }
}

/// Losango pequeno que marca títulos.
class Losango extends StatelessWidget {
  final double tamanho;
  final Color? cor;
  const Losango({super.key, this.tamanho = 7, this.cor});
  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cores.destaque;
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: c,
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)],
        ),
      ),
    );
  }
}

/// Seletor simples (dropdown) que aceita valor fora da lista.
class Seletor extends StatelessWidget {
  final String rotulo;
  final String valor;
  final List<String> opcoes;
  final ValueChanged<String> aoMudar;
  const Seletor(
      {super.key,
      required this.rotulo,
      required this.valor,
      required this.opcoes,
      required this.aoMudar});
  @override
  Widget build(BuildContext context) {
    final ops = [...opcoes];
    if (valor.isNotEmpty && !ops.contains(valor)) ops.insert(0, valor);
    return InputDecorator(
      decoration: InputDecoration(labelText: rotulo),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor.isEmpty ? null : valor,
          isDense: true,
          isExpanded: true,
          hint: const Text('—'),
          items: [
            for (final o in ops) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) {
            if (v != null) aoMudar(v);
          },
        ),
      ),
    );
  }
}

String formatarHora(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

/// Título grande no alto das listas (Agentes, Mesas...): letras gastas, e
/// embaixo uma linha de máquina de escrever.
class TituloPagina extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;
  const TituloPagina({super.key, required this.titulo, this.subtitulo, this.acoes = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Gasto(child: Text(titulo.toUpperCase(), style: estiloTitulo(30, cor: Cores.texto, peso: FontWeight.w800, espaco: 1.5))),
              if (subtitulo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Container(width: 26, height: 3, color: Cores.destaque),
                    const SizedBox(width: 10),
                    Flexible(child: Text(subtitulo!, style: estiloMaquina(13.5, cor: Cores.textoFraco))),
                  ]),
                ),
            ]),
          ),
          ...acoes,
        ]),
      );
}

/// Fileira que rola para o lado também com o mouse: arrastando, com a
/// rodinha ou pela barra. Com [quebrarAcima], quando a largura passa desse
/// valor, as opções quebram em linhas e aparecem todas de uma vez.
class FaixaRolavel extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  /// Altura da fileira quando ela rola (sem altura, usa a do pai).
  final double? altura;
  final double? quebrarAcima;
  const FaixaRolavel(
      {super.key, required this.children, this.padding, this.altura, this.quebrarAcima});
  @override
  State<FaixaRolavel> createState() => _FaixaRolavelState();
}

class _FaixaRolavelState extends State<FaixaRolavel> {
  final _c = ScrollController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// A rodinha (que rola na vertical) passa a andar para o lado.
  void _rodinha(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_c.hasClients || e.scrollDelta.dx != 0) return;
    final p = _c.position;
    final novo = (p.pixels + e.scrollDelta.dy).clamp(p.minScrollExtent, p.maxScrollExtent);
    if (novo == p.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (_) => _c.jumpTo(novo));
  }

  @override
  Widget build(BuildContext context) {
    final computador = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    Widget rolavel = Listener(
      onPointerSignal: _rodinha,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: Scrollbar(
          controller: _c,
          thumbVisibility: computador,
          thickness: 3,
          child: ListView(
            controller: _c,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            children: widget.children,
          ),
        ),
      ),
    );
    if (widget.altura != null) rolavel = SizedBox(height: widget.altura, child: rolavel);
    final limite = widget.quebrarAcima;
    if (limite == null) return rolavel;
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= limite
          ? Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: Align(alignment: Alignment.centerLeft, child: Wrap(children: widget.children)),
            )
          : rolavel,
    );
  }
}

/// Recorte com os cantos de cima à direita e de baixo à esquerda cortados.
class CorteCantos extends ShapeBorder {
  final double corte;
  final Color? cor;
  final double largura;
  const CorteCantos({this.corte = 16, this.cor, this.largura = 1});

  Path _caminho(Rect r) => Path()
    ..moveTo(r.left, r.top)
    ..lineTo(r.right - corte, r.top)
    ..lineTo(r.right, r.top + corte)
    ..lineTo(r.right, r.bottom)
    ..lineTo(r.left + corte, r.bottom)
    ..lineTo(r.left, r.bottom - corte)
    ..close();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _caminho(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _caminho(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final c = cor;
    if (c == null) return;
    canvas.drawPath(
        _caminho(rect.deflate(largura / 2)),
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = largura);
  }

  @override
  ShapeBorder scale(double t) => CorteCantos(corte: corte * t, cor: cor, largura: largura * t);
}

/// "12:04", ou "1:02:03" passando de uma hora.
String duracaoTexto(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String dois(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${dois(m)}:${dois(s)}' : '${dois(m)}:${dois(s)}';
}

/// O tempo desde [inicio] (milissegundos desde 1970), contando ao vivo.
class Cronometro extends StatefulWidget {
  final int inicio;
  final TextStyle? estilo;
  const Cronometro({super.key, required this.inicio, this.estilo});

  @override
  State<Cronometro> createState() => _CronometroState();
}

class _CronometroState extends State<Cronometro> {
  late final Timer _tique;

  @override
  void initState() {
    super.initState();
    _tique = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tique.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        duracaoTexto(DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(widget.inicio))),
        style: widget.estilo,
      );
}

/// "12/10/2026 às 19:30".
String dataHora(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year} às ${dois(d.hour)}:${dois(d.minute)}';
}
