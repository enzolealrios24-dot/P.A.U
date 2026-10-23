import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/quadro.dart';
import '../../widgets/common.dart';
import '../../widgets/efeitos.dart';
import '../../widgets/imagem.dart';
import '../../widgets/runa.dart';
import '../quadro/quadro_screen.dart';
import 'rolar.dart';
import 'tab_listas.dart';

/// Tons de nota a partir da cor da afinidade (o tema muda, as notas também).
List<Color> coresNota(Color destaque) {
  final h = HSLColor.fromColor(destaque);
  if (h.saturation < 0.15) {
    // Morte: papéis cinza e quase brancos
    return const [Color(0xFF2B2B2B), Color(0xFF3A3A3A), Color(0xFF232323), Color(0xFF444444)];
  }
  return [
    h.withLightness(0.20).withSaturation((h.saturation * 0.55).clamp(0.0, 1.0)).toColor(),
    h.withHue((h.hue + 22) % 360).withLightness(0.18).withSaturation((h.saturation * 0.45).clamp(0.0, 1.0)).toColor(),
    h.withHue((h.hue + 338) % 360).withLightness(0.23).withSaturation((h.saturation * 0.5).clamp(0.0, 1.0)).toColor(),
    h.withLightness(0.15).withSaturation((h.saturation * 0.35).clamp(0.0, 1.0)).toColor(),
  ];
}

int _hash(String s) {
  var h = 5;
  for (final c in s.codeUnits) {
    h = (h * 33 + c) & 0x7fffffff;
  }
  return h;
}

/// Aba QUADRO como mural: as notas do quadro presas com alfinete ou fita,
/// coloridas pela afinidade, cada uma com a sua runa. As tarefas são
/// marcadas aqui mesmo; o quadro completo abre no botão.
class TabQuadro extends StatelessWidget {
  final CtxFicha ctx;
  const TabQuadro({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final fonte = FonteQuadro.ficha(ctx.f.id);
    final quadros = asMap(asMap(ctx.f.d['quadro'])['quadros']);
    final raiz = quadros[FonteQuadro.raiz] is Map ? Quadro(FonteQuadro.raiz, asMap(quadros[FonteQuadro.raiz])) : null;
    final todos = raiz?.itens.values.toList() ?? const <ItemQuadro>[];
    const noMural = {TiposQuadro.titulo, TiposQuadro.nota, TiposQuadro.tarefas, TiposQuadro.imagem, TiposQuadro.link};
    final itens = todos.where((i) => noMural.contains(i.tipo)).toList()
      ..sort((a, b) {
        // ordem de leitura do quadro: de cima para baixo, da esquerda para a direita
        final y = (a.y / 120).floor().compareTo((b.y / 120).floor());
        return y != 0 ? y : a.x.compareTo(b.x);
      });
    final outros = todos.length - itens.length;
    final elemento = ctx.f.elementoDaFicha;
    final cores = coresNota(Cores.destaque);
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 28), children: [
      Text('Mural', style: estiloTitulo(26, cor: Cores.texto)),
      const SizedBox(height: 4),
      Text('${itens.length} ${itens.length == 1 ? 'nota presa' : 'notas presas'}${outros > 0 ? ' · mais $outros no quadro completo' : ''}',
          style: estiloMaquina(12.5, cor: Cores.textoFraco)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          onPressed: () => _novaNota(context, fonte, raiz),
          icon: const Icon(Icons.push_pin_outlined),
          label: const Text('Nova nota'),
        ),
        OutlinedButton.icon(
          onPressed: () => abrirQuadroFicha(context, ctx),
          icon: const Icon(Icons.dashboard_outlined),
          label: const Text('Quadro completo'),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Cores.borda),
        ),
        child: itens.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text('Mural vazio. Prenda a primeira nota.',
                    textAlign: TextAlign.center, style: estiloMao(22, cor: Cores.textoFraco)),
              )
            : LayoutBuilder(builder: (context, c) {
                final colunas = (c.maxWidth / 170).floor().clamp(2, 5);
                final largura = (c.maxWidth - 12 * (colunas - 1)) / colunas;
                return Wrap(spacing: 12, runSpacing: 16, children: [
                  for (final (k, i) in itens.indexed)
                    SizedBox(
                      width: i.tipo == TiposQuadro.titulo ? c.maxWidth : largura,
                      child: _NotaMural(
                        item: i,
                        indice: k,
                        cor: i.cor != null && i.tipo != TiposQuadro.titulo ? Color(i.cor!) : cores[k % cores.length],
                        elemento: elemento.isEmpty ? 'medo' : elemento,
                        aoMarcar: (t) => _marcar(fonte, i, t),
                        aoAbrir: () => abrirQuadroFicha(context, ctx),
                      ),
                    ),
                ]);
              }),
      ),
    ]);
  }

  void _marcar(FonteQuadro fonte, ItemQuadro i, int k) {
    final l = i.tarefas;
    if (k < 0 || k >= l.length) return;
    l[k] = {...l[k], 'ok': l[k]['ok'] != true};
    fonte.mudarItem(FonteQuadro.raiz, i.id, {'tarefas': l});
  }

  Future<void> _novaNota(BuildContext context, FonteQuadro fonte, Quadro? raiz) async {
    final t = await pedirTexto(context, 'Nova nota', dica: 'Pista, nome, suspeita...');
    if (t == null || t.trim().isEmpty) return;
    final itens = raiz?.itens.values.toList() ?? const <ItemQuadro>[];
    final base = itens.fold<double>(40, (m, i) => max(m, i.y + i.h));
    if (raiz == null) fonte.criarQuadro(FonteQuadro.raiz, fonte.nomeRaiz);
    final z = itens.fold<int>(0, (m, i) => max(m, i.z)) + 1;
    fonte.salvarItem(
      FonteQuadro.raiz,
      ItemQuadro(novoId(), {
        'tipo': TiposQuadro.nota,
        'x': 60.0 + (itens.length % 3) * 240,
        'y': base + 40,
        'w': 220.0,
        'h': 150.0,
        'z': z,
        'texto': t.trim(),
      }),
    );
  }
}

class _NotaMural extends StatelessWidget {
  final ItemQuadro item;
  final int indice;
  final Color cor;
  final String elemento;
  final void Function(int) aoMarcar;
  final VoidCallback aoAbrir;
  const _NotaMural({
    required this.item,
    required this.indice,
    required this.cor,
    required this.elemento,
    required this.aoMarcar,
    required this.aoAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final i = item;
    final h = _hash(i.id);
    final giro = ((h % 7) - 3) * 0.008;
    final comFita = i.tipo == TiposQuadro.imagem || (h % 3 == 0);
    final circulo = switch (i.tipo) {
      TiposQuadro.tarefas => 2,
      TiposQuadro.imagem => 3,
      _ => 1,
    };

    if (i.tipo == TiposQuadro.titulo) {
      // a faixa do título tem a largura do texto (as fitas ficam nas pontas dela)
      return Align(
        alignment: Alignment.centerLeft,
        child: Transform.rotate(
        angle: giro / 2,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            color: const Color(0xFFE9E2CF).withValues(alpha: 0.92),
            child: Text(i.texto.isEmpty ? 'Título' : i.texto,
                style: estiloMao(30, cor: const Color(0xFF1B1622), peso: FontWeight.w700)),
          ),
          const Positioned(top: -9, left: 18, child: Fita(largura: 54, giro: -0.12)),
          const Positioned(top: -9, right: 18, child: Fita(largura: 54, giro: 0.1)),
        ]),
        ),
      );
    }

    final tinta = cor.computeLuminance() > 0.45 ? const Color(0xFF1B1622) : Cores.texto;
    Widget conteudo;
    switch (i.tipo) {
      case TiposQuadro.tarefas:
        final l = i.tarefas;
        conteudo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.titulo.isEmpty ? 'Tarefas' : i.titulo, style: estiloMao(22, cor: tinta, peso: FontWeight.w700)),
          const SizedBox(height: 4),
          for (var k = 0; k < l.length; k++)
            InkWell(
              onTap: () => aoMarcar(k),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(l[k]['ok'] == true ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 19, color: l[k]['ok'] == true ? Cores.ok : tinta.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(asStr(l[k]['t']),
                        style: estiloMao(19, cor: l[k]['ok'] == true ? tinta.withValues(alpha: 0.5) : tinta).copyWith(
                            decoration: l[k]['ok'] == true ? TextDecoration.lineThrough : null)),
                  ),
                ]),
              ),
            ),
        ]);
      case TiposQuadro.imagem:
        conteudo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 1,
            child: i.imagem.isNotEmpty
                ? ImagemSalva(id: i.imagem)
                : (i.url.isNotEmpty
                    ? Image.network(i.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined))
                    : const Icon(Icons.image_outlined, size: 40)),
          ),
          if (i.texto.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(i.texto, textAlign: TextAlign.center, style: estiloMao(19, cor: const Color(0xFF1B1622))),
            ),
        ]);
      case TiposQuadro.link:
        conteudo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.titulo.isEmpty ? 'Link' : i.titulo, style: estiloMao(21, cor: tinta, peso: FontWeight.w700)),
          if (i.texto.isNotEmpty) Text(i.texto, style: estiloMao(18, cor: tinta.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => abrirLink(context, i.url),
            child: Text(i.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Cores.destaque, decoration: TextDecoration.underline)),
          ),
        ]);
      default:
        conteudo = DefaultTextStyle.merge(
          style: TextStyle(color: tinta),
          child: i.texto.isEmpty
              ? Text('Nota vazia', style: estiloMao(20, cor: tinta.withValues(alpha: 0.6)))
              : textoNota(i.texto),
        );
    }

    final polaroid = i.tipo == TiposQuadro.imagem;
    return Transform.rotate(
      angle: giro,
      child: Stack(clipBehavior: Clip.none, children: [
        Material(
          color: polaroid ? const Color(0xFFEDE9E0) : cor,
          elevation: 3,
          shadowColor: Colors.black,
          child: InkWell(
            onTap: aoAbrir,
            child: Padding(
              padding: EdgeInsets.fromLTRB(polaroid ? 8 : 12, polaroid ? 8 : 16, polaroid ? 8 : 12, polaroid ? 10 : 26),
              child: conteudo,
            ),
          ),
        ),
        // runa da nota no canto
        if (!polaroid)
          Positioned(
            right: 6,
            bottom: 5,
            child: IgnorePointer(
              child: Runa(
                elemento: elemento,
                circulo: circulo,
                semente: i.id,
                cor: Cores.destaque.withValues(alpha: 0.55),
                tamanho: 20,
              ),
            ),
          ),
        if (comFita)
          const Positioned(top: -9, left: 0, right: 0, child: Center(child: Fita(largura: 56)))
        else
          const Positioned(top: -7, left: 0, right: 0, child: Center(child: _Alfinete())),
      ]),
    );
  }
}

/// Alfinete de cabeça redonda na cor da afinidade.
class _Alfinete extends StatelessWidget {
  const _Alfinete();
  @override
  Widget build(BuildContext context) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [Color.lerp(Cores.destaque, Colors.white, 0.55)!, Cores.destaque, Color.lerp(Cores.destaque, Colors.black, 0.5)!],
            stops: const [0, 0.45, 1],
          ),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(1.5, 2.5))],
        ),
      );
}
