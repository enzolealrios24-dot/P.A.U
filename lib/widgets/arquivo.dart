import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';
import 'efeitos.dart';

// Peças da área das mesas e das listas do início, no jeito do arquivo da
// Ordem: abas de fichário, carimbos, blocos de cantos cortados.

/// Fundo da área aberta pelo fichário: um tom acima do fundo do app. A aba
/// escolhida tem a mesma cor, para parecer presa à página.
Color get corDoCampo => Color.alphaBlend(
    Cores.destaque.withValues(alpha: 0.025), Colors.white.withValues(alpha: 0.03));

/// Carimbo de borracha: letras espaçadas dentro de um contorno duplo, um
/// pouco torto e gasto. Para estados que importam (mestre, ao vivo, nova).
class Carimbo extends StatelessWidget {
  final String texto;
  final Color? cor;
  final double tamanho;
  final double giro;
  const Carimbo(this.texto, {super.key, this.cor, this.tamanho = 12, this.giro = -0.035});

  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cores.destaque;
    return Transform.rotate(
      angle: giro,
      child: Gasto(
        escala: 0.5,
        child: Container(
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(border: Border.all(color: c, width: 1.6)),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: tamanho * 0.5, vertical: tamanho * 0.14),
            decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.7), width: 0.8)),
            child: Text(texto,
                maxLines: 1,
                style: estiloRotulo(tamanho, cor: c, peso: FontWeight.w700, espaco: tamanho * 0.16)),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho de uma aba: o título, para que ela serve e os botões dela.
class CabecalhoAba extends StatelessWidget {
  final String titulo;
  final String? texto;
  final List<Widget> acoes;
  /// Algo antes do título (a foto do jogador, por exemplo).
  final Widget? inicio;
  const CabecalhoAba({super.key, required this.titulo, this.texto, this.acoes = const [], this.inicio});

  @override
  Widget build(BuildContext context) {
    final textos = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Gasto(escala: 0.7, child: Text(titulo, style: estiloTitulo(24, cor: Cores.texto, peso: FontWeight.w700))),
      if (texto != null) ...[
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(texto!, style: const TextStyle(fontSize: 14, height: 1.4, color: Cores.textoFraco)),
        ),
      ],
    ]);
    final cabeca = inicio == null
        ? textos
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            inicio!,
            const SizedBox(width: 14),
            Expanded(child: textos),
          ]);
    final botoes = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: acoes);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: LayoutBuilder(
        builder: (context, c) => acoes.isEmpty
            ? cabeca
            : c.maxWidth >= 720
                ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: cabeca),
                    const SizedBox(width: 16),
                    botoes,
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    cabeca,
                    const SizedBox(height: 12),
                    botoes,
                  ]),
      ),
    );
  }
}

/// Bloco da área das mesas: painel de cantos cortados com o título dentro e
/// os botões dele ao lado.
class BlocoMesa extends StatelessWidget {
  final String titulo;
  final Widget child;
  final List<Widget> acoes;
  /// Contorno na cor do tema (o que pede atenção agora).
  final bool forte;
  const BlocoMesa({super.key, required this.titulo, required this.child, this.acoes = const [], this.forte = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          color: Cores.painel,
          shape: CorteCantos(
              corte: 14, cor: forte ? Cores.destaque.withValues(alpha: 0.8) : Cores.borda, largura: forte ? 1.4 : 1),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // botões baixos, para não empurrar o título para baixo
              TextButtonTheme(
                data: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Cores.destaque,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: estiloRotulo(15, peso: FontWeight.w700, espaco: 0.5),
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Text(titulo, style: estiloTitulo(17, cor: Cores.texto))),
                  ...acoes,
                ]),
              ),
              const SizedBox(height: 10),
              child,
            ]),
          ),
        ),
      );
}

/// Um número da ficha com o nome embaixo (Defesa 13, Carga 0/5...).
class Marcador extends StatelessWidget {
  final String rotulo;
  final String valor;
  const Marcador(this.rotulo, this.valor, {super.key});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(valor, maxLines: 1, style: estiloNumero(18, cor: Cores.texto)),
        const SizedBox(height: 3),
        Text(rotulo, maxLines: 1, style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 0.6)),
      ]);
}

/// Fileira de marcadores separados por traços finos.
class FileiraMarcadores extends StatelessWidget {
  final List<Marcador> itens;
  const FileiraMarcadores(this.itens, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: Cores.linha)),
        ),
        child: Row(children: [
          for (final (i, m) in itens.indexed) ...[
            if (i > 0) Container(width: 1, height: 28, color: Cores.linha),
            Expanded(child: m),
          ],
        ]),
      );
}

// ---------------- fichário ----------------

/// Uma aba do fichário: ícone, nome e quantas coisas esperam nela.
class AbaFichario {
  final IconData icone;
  final String rotulo;
  final int aviso;
  const AbaFichario(this.icone, this.rotulo, {this.aviso = 0});
}

/// Tela com abas de fichário. No computador, as abas ficam numa coluna à
/// esquerda e a escolhida se prende à página; no celular, numa barra
/// embaixo, com as que não cabem em "Mais".
class Fichario extends StatelessWidget {
  final List<AbaFichario> abas;
  final int atual;
  final ValueChanged<int> aoEscolher;
  final Widget corpo;
  final PreferredSizeWidget? appBar;
  final Widget? botao;
  /// No celular, quantas abas cabem na barra (as outras vão para "Mais").
  final int naBarra;
  const Fichario({
    super.key,
    required this.abas,
    required this.atual,
    required this.aoEscolher,
    required this.corpo,
    this.appBar,
    this.botao,
    this.naBarra = 5,
  });

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: appBar,
      floatingActionButton: botao,
      body: largo
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Indice(abas: abas, atual: atual, aoEscolher: aoEscolher),
              Expanded(child: ColoredBox(color: corDoCampo, child: corpo)),
            ])
          : corpo,
      bottomNavigationBar: largo ? null : _Barra(abas: abas, atual: atual, aoEscolher: aoEscolher, naBarra: naBarra),
    );
  }
}

Widget _comAviso(Widget icone, int aviso) =>
    aviso > 0 ? Badge(label: Text('$aviso'), child: icone) : icone;

/// A coluna de abas do computador.
class _Indice extends StatelessWidget {
  final List<AbaFichario> abas;
  final int atual;
  final ValueChanged<int> aoEscolher;
  const _Indice({required this.abas, required this.atual, required this.aoEscolher});

  @override
  Widget build(BuildContext context) {
    const largura = 150.0;
    // o traço que separa as abas da página; a escolhida passa por cima dele
    const divisa = BorderSide(color: Cores.linha);
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: SizedBox(
              width: largura,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(height: 14, decoration: const BoxDecoration(border: Border(right: divisa))),
                for (var i = 0; i < abas.length; i++) _aba(i),
                Expanded(child: Container(decoration: const BoxDecoration(border: Border(right: divisa)))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _aba(int i) {
    final a = abas[i];
    final sim = i == atual;
    final cor = sim ? Cores.destaque : Cores.textoFraco;
    return Semantics(
      selected: sim,
      button: true,
      child: Container(
        padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
        decoration: sim ? null : const BoxDecoration(border: Border(right: BorderSide(color: Cores.linha))),
        child: Material(
          color: sim ? corDoCampo : Colors.transparent,
          shape: sim ? const _FormaAba() : const _FormaAba(borda: false),
          child: InkWell(
            customBorder: const _FormaAba(),
            onTap: () => aoEscolher(i),
            child: Container(
              height: 50,
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Row(children: [
                _comAviso(Icon(a.icone, size: 21, color: cor), a.aviso),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(a.rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: estiloRotulo(16, cor: sim ? Cores.texto : Cores.textoFraco,
                          peso: sim ? FontWeight.w700 : FontWeight.w600, espaco: 0.6)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aba de fichário: canto de cima à esquerda cortado, aberta à direita
/// (onde encosta na página). O contorno marca a escolhida.
class _FormaAba extends ShapeBorder {
  final bool borda;
  const _FormaAba({this.borda = true});
  static const _corte = 10.0;

  Path _caminho(Rect r) => Path()
    ..moveTo(r.right, r.top)
    ..lineTo(r.left + _corte, r.top)
    ..lineTo(r.left, r.top + _corte)
    ..lineTo(r.left, r.bottom)
    ..lineTo(r.right, r.bottom);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _caminho(rect)..close();
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _caminho(rect)..close();
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (!borda) return;
    canvas.drawPath(
        _caminho(rect.deflate(0.5)),
        Paint()
          ..color = Cores.borda
          ..style = PaintingStyle.stroke);
    // a marca da aba escolhida, na borda de fora
    canvas.drawLine(Offset(rect.left + 1.5, rect.top + _corte + 4), Offset(rect.left + 1.5, rect.bottom - 6),
        Paint()
          ..color = Cores.destaque
          ..strokeWidth = 3);
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// A barra de abas do celular.
class _Barra extends StatelessWidget {
  final List<AbaFichario> abas;
  final int atual;
  final ValueChanged<int> aoEscolher;
  final int naBarra;
  const _Barra({required this.abas, required this.atual, required this.aoEscolher, required this.naBarra});

  Future<void> _mais(BuildContext context) async {
    final i = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = _quantas; i < abas.length; i++)
            ListTile(
              leading: _comAviso(Icon(abas[i].icone), abas[i].aviso),
              title: Text(abas[i].rotulo),
              selected: i == atual,
              onTap: () => Navigator.pop(ctx, i),
            ),
        ]),
      ),
    );
    if (i != null) aoEscolher(i);
  }

  /// Com mais abas do que cabem, a última vaga vira "Mais".
  int get _quantas => abas.length <= naBarra ? abas.length : naBarra - 1;

  @override
  Widget build(BuildContext context) {
    final sobra = abas.length > _quantas;
    final avisoMais = [for (var i = _quantas; i < abas.length; i++) abas[i].aviso].fold(0, (a, b) => a + b);
    final foraDaBarra = atual >= _quantas;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(Cores.painel2.withValues(alpha: 0.7), Cores.fundo),
        border: const Border(top: BorderSide(color: Cores.linha)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            for (var i = 0; i < _quantas; i++)
              _item(abas[i].icone, abas[i].rotulo, abas[i].aviso, i == atual, () => aoEscolher(i)),
            if (sobra)
              _item(foraDaBarra ? abas[atual].icone : Icons.more_horiz, foraDaBarra ? abas[atual].rotulo : 'Mais',
                  avisoMais, foraDaBarra, () => _mais(context)),
          ]),
        ),
      ),
    );
  }

  Widget _item(IconData icone, String rotulo, int aviso, bool sim, VoidCallback aoTocar) {
    final cor = sim ? Cores.destaque : Cores.textoFraco;
    return Expanded(
      child: Semantics(
        selected: sim,
        button: true,
        child: InkWell(
          onTap: aoTocar,
          child: Container(
            decoration: BoxDecoration(
              color: sim ? corDoCampo : null,
              border: Border(top: BorderSide(color: sim ? Cores.destaque : Colors.transparent, width: 3)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _comAviso(Icon(icone, size: 22, color: cor), aviso),
              const SizedBox(height: 4),
              Text(rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: estiloRotulo(12.5, cor: sim ? Cores.texto : Cores.textoFraco,
                      peso: sim ? FontWeight.w700 : FontWeight.w600, espaco: 0.4)),
            ]),
          ),
        ),
      ),
    );
  }
}
