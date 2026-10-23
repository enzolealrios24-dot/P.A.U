import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/runa.dart';
import 'rolar.dart';
import 'tab_listas.dart';

/// Grupo da tag de cada poder: Classe (inclui trilha e origem), Geral
/// (inclui homebrew) ou Paranormal.
String grupoPoder(Map<String, dynamic> p) {
  final t = asStr(p['tipo']).toLowerCase();
  if (t.startsWith('paranormal')) return 'Paranormal';
  if (t.startsWith('geral') || t.startsWith('homebrew')) return 'Geral';
  return 'Classe';
}

String romano(int n) {
  const valores = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const letras = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
  var resto = n, s = '';
  for (var i = 0; i < valores.length; i++) {
    while (resto >= valores[i]) {
      s += letras[i];
      resto -= valores[i];
    }
  }
  return s;
}

/// Aba PODERES & NOTAS: cada poder é uma carta arcana (moldura dupla na cor
/// da afinidade, runa na arte, numeral romano e a tag do tipo), em grade.
class TabPoderes extends StatefulWidget {
  final CtxFicha ctx;
  const TabPoderes({super.key, required this.ctx});
  @override
  State<TabPoderes> createState() => _TabPoderesState();
}

class _TabPoderesState extends State<TabPoderes> {
  String? _grupo;

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final l = ctx.f.poderes;
    final indices = [
      for (var i = 0; i < l.length; i++)
        if (_grupo == null || grupoPoder(l[i]) == _grupo) i
    ];
    int conta(String g) => l.where((p) => grupoPoder(p) == g).length;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 28), children: [
      Text('Cartas arcanas', style: estiloTitulo(26, cor: Cores.texto)),
      const SizedBox(height: 4),
      Text('${l.length} ${l.length == 1 ? 'poder' : 'poderes'} · toque numa carta para ler',
          style: estiloMaquina(12.5, cor: Cores.textoFraco)),
      const SizedBox(height: 12),
      botoesAdicionarPoder(context, ctx),
      const SizedBox(height: 10),
      FaixaRolavel(altura: 42, quebrarAcima: 0, children: [
        for (final (g, rotulo) in [
          (null, 'Todos  ${l.length}'),
          ('Classe', 'Classe  ${conta('Classe')}'),
          ('Geral', 'Geral  ${conta('Geral')}'),
          ('Paranormal', 'Paranormal  ${conta('Paranormal')}'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: ChoiceChip(
              label: Text(rotulo),
              selected: _grupo == g,
              onSelected: (_) => setState(() => _grupo = g),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      if (indices.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l.isEmpty ? 'Nenhum poder ainda.' : 'Nenhum poder deste tipo.',
              textAlign: TextAlign.center, style: estiloMao(22, cor: Cores.textoFraco)),
        )
      else
        LayoutBuilder(builder: (context, c) {
          final colunas = (c.maxWidth / 175).floor().clamp(2, 6);
          final largura = (c.maxWidth - 10 * (colunas - 1)) / colunas;
          return Wrap(spacing: 10, runSpacing: 12, children: [
            for (final i in indices)
              SizedBox(
                width: largura,
                child: CartaArcana(
                  poder: l[i],
                  numero: i + 1,
                  elementoFicha: ctx.f.elementoDaFicha,
                  aoTocar: () => _abrir(context, i),
                  aoSegurar: () => editarPoder(context, ctx, i),
                ),
              ),
          ]);
        }),
      const SizedBox(height: 18),
      Secao(
        titulo: 'Anotações',
        acoes: [
          TextButton.icon(
            onPressed: () => abrirQuadroFicha(context, ctx),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Quadro'),
          ),
        ],
        child: CampoSync(
            valor: ctx.f.notas,
            maxLinhas: 14,
            dica: 'Pistas, NPCs, segredos...',
            estilo: estiloMao(21, cor: Cores.texto),
            aoSalvar: (v) => Repo.set(ctx.f.id, 'notas', v)),
      ),
    ]);
  }

  /// Carta aberta: texto inteiro, afinidade e editar.
  void _abrir(BuildContext context, int i) {
    final ctx = widget.ctx;
    final p = ctx.f.poderes[i];
    final temAfinidade = asStr(Catalogo.instance.porRef(asStr(p['ref']))?['afinidade']).isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx2) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Runa(
                elemento: _elementoDaCarta(p, ctx.f.elementoDaFicha),
                circulo: _circuloDaCarta(p),
                semente: asStr(p['nome']),
                tamanho: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${romano(i + 1)} · ${asStr(p['tipo'], 'Poder').toUpperCase()}',
                      style: estiloRotulo(12.5, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.8)),
                  Text(asStr(p['nome'], 'Poder'), style: estiloTitulo(21, cor: Cores.texto)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx2).height * 0.5),
              child: SingleChildScrollView(
                child: Text(asStr(p['descricao'], 'Sem descrição.'),
                    style: const TextStyle(fontSize: 14.5, height: 1.4)),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx2);
                  editarPoder(context, ctx, i);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
              ),
              if (temAfinidade)
                OutlinedButton.icon(
                  onPressed: () {
                    alternarAfinidadePoder(ctx, i);
                    Navigator.pop(ctx2);
                  },
                  icon: Icon(asBool(p['afinidade']) ? Icons.star : Icons.star_border, size: 18),
                  label: Text(asBool(p['afinidade']) ? 'Tirar afinidade' : 'Escolher com afinidade'),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

String _elementoDaCarta(Map<String, dynamic> p, String elementoFicha) {
  final e = asStr(p['elemento']);
  if (e.isNotEmpty) return e;
  return elementoFicha.isEmpty ? 'medo' : elementoFicha;
}

int _circuloDaCarta(Map<String, dynamic> p) => switch (grupoPoder(p)) {
      'Paranormal' => asBool(p['afinidade']) ? 4 : 3,
      'Classe' => 2,
      _ => 1,
    };

/// Carta de um poder.
class CartaArcana extends StatelessWidget {
  final Map<String, dynamic> poder;
  final int numero;
  final String elementoFicha;
  final VoidCallback aoTocar, aoSegurar;
  const CartaArcana({
    super.key,
    required this.poder,
    required this.numero,
    required this.elementoFicha,
    required this.aoTocar,
    required this.aoSegurar,
  });

  @override
  Widget build(BuildContext context) {
    final grupo = grupoPoder(poder);
    final elemento = _elementoDaCarta(poder, elementoFicha);
    final corRuna = grupo == 'Paranormal' ? Runa.corDo(elemento) : Cores.destaque;
    final corTag = switch (grupo) {
      'Paranormal' => Runa.corDo(elemento),
      'Classe' => Cores.destaque,
      _ => Cores.textoFraco,
    };
    final afinidade = asBool(poder['afinidade']);
    return AspectRatio(
      aspectRatio: 0.62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: aoTocar,
          onLongPress: aoSegurar,
          child: CustomPaint(
            painter: _PintorMoldura(Cores.destaque),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(children: [
                Text(romano(numero), style: estiloTitulo(14, cor: Cores.destaque, espaco: 2)),
                const SizedBox(height: 6),
                // arte da carta: a runa sobre um fundo escuro
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Cores.destaque.withValues(alpha: 0.35)),
                      gradient: RadialGradient(
                        colors: [corRuna.withValues(alpha: 0.18), Colors.black.withValues(alpha: 0.55)],
                      ),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      LayoutBuilder(
                        builder: (context, c) => Runa(
                          elemento: elemento,
                          circulo: _circuloDaCarta(poder),
                          semente: asStr(poder['nome']),
                          cor: corRuna,
                          tamanho: (c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth) * 0.82,
                        ),
                      ),
                      if (afinidade)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(Icons.star, size: 16, color: corRuna),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(asStr(poder['nome'], 'Poder'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: estiloTitulo(14.5, cor: Cores.texto, altura: 1.1)),
                const SizedBox(height: 5),
                Etiqueta(grupo == 'Classe' && asStr(poder['tipo']).isNotEmpty && asStr(poder['tipo']) != 'Classe'
                    ? '${grupo.toUpperCase()} · ${asStr(poder['tipo']).toUpperCase()}'
                    : grupo.toUpperCase(), cor: corTag),
                const SizedBox(height: 6),
                Expanded(
                  flex: 3,
                  child: Text(asStr(poder['descricao']),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(fontSize: 11.5, height: 1.3, color: Cores.textoFraco)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Moldura dupla da carta, com cantos marcados.
class _PintorMoldura extends CustomPainter {
  final Color cor;
  _PintorMoldura(this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = Cores.painel);
    final fora = Paint()
      ..color = cor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final dentro = Paint()
      ..color = cor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(6)), fora);
    canvas.drawRect(r.deflate(5), dentro);
    final cheio = Paint()..color = cor;
    for (final c in [r.deflate(5).topLeft, r.deflate(5).topRight, r.deflate(5).bottomLeft, r.deflate(5).bottomRight]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 3.5)
          ..lineTo(c.dx + 3.5, c.dy)
          ..lineTo(c.dx, c.dy + 3.5)
          ..lineTo(c.dx - 3.5, c.dy)
          ..close(),
        cheio,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorMoldura old) => old.cor != cor;
}
