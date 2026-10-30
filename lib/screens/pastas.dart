import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/common.dart';
import '../widgets/efeitos.dart';
import '../widgets/imagem.dart';
import 'home.dart';

// Pastas de agentes na tela inicial: cada uma tem nome e data, guarda os
// agentes que o jogador mover para ela e se abre numa tela própria.

/// Lê "24/10/2026" (ou "24/10/26"); null se não for uma data válida.
DateTime? lerData(String texto) {
  final p = texto.trim().split(RegExp(r'[/.\-]'));
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]), m = int.tryParse(p[1]);
  var a = int.tryParse(p[2]);
  if (d == null || m == null || a == null) return null;
  if (a < 100) a += 2000;
  final r = DateTime(a, m, d);
  return r.day == d && r.month == m && r.year == a ? r : null;
}

/// Nome e data de uma pasta (nova, ou [pasta] para editar).
Future<(String, DateTime)?> pedirPasta(BuildContext context, {Pasta? pasta}) {
  final nome = TextEditingController(text: pasta?.nome ?? '');
  final hoje = DateTime.now();
  final data = TextEditingController(
      text: (pasta ?? Pasta('', '', DateTime(hoje.year, hoje.month, hoje.day))).dataTexto);
  String? erro;
  return showDialog<(String, DateTime)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void salvar() {
          final n = nome.text.trim();
          final d = lerData(data.text);
          if (n.isEmpty || d == null) {
            setState(() => erro = n.isEmpty ? 'Dê um nome à pasta.' : 'Data inválida. Use dia/mês/ano.');
            return;
          }
          Navigator.pop(ctx, (n, d));
        }

        return AlertDialog(
          title: Text(pasta == null ? 'Nova pasta' : 'Editar pasta'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nome,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Operação Sangue Velho'),
              onSubmitted: (_) => salvar(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: data,
              keyboardType: TextInputType.datetime,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'))],
              decoration: const InputDecoration(labelText: 'Data', hintText: 'dd/mm/aaaa'),
              onSubmitted: (_) => salvar(),
            ),
            if (erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(erro!, style: TextStyle(color: Cores.pv, fontSize: 13)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: salvar, child: Text(pasta == null ? 'Criar' : 'Salvar')),
          ],
        );
      },
    ),
  );
}

/// Cria uma pasta perguntando nome e data; devolve o id.
Future<String?> criarPasta(BuildContext context) async {
  final r = await pedirPasta(context);
  if (r == null) return null;
  return Repo.criarPasta(r.$1, r.$2);
}

/// Para onde mover o agente: uma das pastas, nova pasta ou fora delas.
Future<void> moverAgente(BuildContext context, Ficha f, List<Pasta> pastas) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text('Mover ${f.nome}', style: estiloTitulo(19, cor: Cores.texto)),
            ),
            for (final p in pastas)
              ListTile(
                leading: Icon(f.pasta == p.id ? Icons.folder : Icons.folder_outlined, color: Cores.destaque),
                title: Text(p.nome),
                subtitle: Text(p.dataTexto),
                trailing: f.pasta == p.id ? Icon(Icons.check, color: Cores.destaque) : null,
                onTap: () {
                  Repo.moverParaPasta(f, p.id);
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Nova pasta…'),
              onTap: () async {
                final id = await criarPasta(ctx);
                if (id == null) return;
                Repo.moverParaPasta(f, id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            if (f.pasta != null)
              ListTile(
                leading: const Icon(Icons.drive_file_move_rtl_outlined),
                title: const Text('Tirar da pasta'),
                onTap: () {
                  Repo.moverParaPasta(f, null);
                  Navigator.pop(ctx);
                },
              ),
          ]),
        ),
      ),
    );

/// Recorte de pasta de arquivo: aba inclinada no alto à esquerda.
class _FormaPasta extends ShapeBorder {
  final Color? cor;
  final double espessura;
  const _FormaPasta({this.cor, this.espessura = 1});

  static const aba = 12.0;

  Path _caminho(Rect r) {
    final largura = min(r.width * 0.42, 150.0);
    return Path()
      ..moveTo(r.left, r.top)
      ..lineTo(r.left + largura - aba, r.top)
      ..lineTo(r.left + largura, r.top + aba)
      ..lineTo(r.right, r.top + aba)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..close();
  }

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
        _caminho(rect.deflate(espessura / 2)),
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = espessura);
  }

  @override
  ShapeBorder scale(double t) => _FormaPasta(cor: cor, espessura: espessura * t);
}

/// Cartão de uma pasta: nome, data, quantos agentes e os rostos deles.
/// Dá para soltar um agente em cima (arrastando o cartão dele).
class CartaoPasta extends StatelessWidget {
  final Pasta pasta;
  final List<Ficha> agentes;
  final VoidCallback aoAbrir;
  const CartaoPasta({super.key, required this.pasta, required this.agentes, required this.aoAbrir});

  @override
  Widget build(BuildContext context) {
    return DragTarget<Ficha>(
      onWillAcceptWithDetails: (d) => d.data.pasta != pasta.id,
      onAcceptWithDetails: (d) {
        Repo.moverParaPasta(d.data, pasta.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${d.data.nome} foi para "${pasta.nome}".')));
      },
      builder: (context, chegando, _) {
        final ativo = chegando.isNotEmpty;
        final rostos = agentes.take(4).toList();
        return AnimatedScale(
          scale: ativo ? 1.04 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Material(
            color: Color.alphaBlend(Cores.destaque.withValues(alpha: ativo ? 0.2 : 0.07), Cores.painel),
            shape: _FormaPasta(
                cor: Cores.destaque.withValues(alpha: ativo ? 0.95 : 0.5), espessura: ativo ? 2 : 1),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: aoAbrir,
              customBorder: const _FormaPasta(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, _FormaPasta.aba + 10, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(ativo ? Icons.folder_open : Icons.folder_outlined, size: 18, color: Cores.destaque),
                    const SizedBox(width: 6),
                    Text(pasta.dataTexto, style: estiloMaquina(11.5, cor: Cores.textoFraco, espaco: 0.6)),
                  ]),
                  const SizedBox(height: 6),
                  Text(pasta.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: estiloTitulo(17, cor: Cores.texto)),
                  const SizedBox(height: 10),
                  Row(children: [
                    SizedBox(
                      width: rostos.isEmpty ? 0 : 26.0 + 18 * (rostos.length - 1),
                      height: 26,
                      child: Stack(children: [
                        for (final (i, f) in rostos.indexed)
                          Positioned(
                            left: 18.0 * i,
                            child: AvatarFicha(foto: f.foto, nome: f.nome, ajuste: f.fotoAjuste, tamanho: 26),
                          ),
                      ]),
                    ),
                    if (rostos.isNotEmpty) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        agentes.isEmpty
                            ? 'vazia'
                            : (agentes.length == 1 ? '1 agente' : '${agentes.length} agentes'),
                        style: estiloRotulo(13, cor: Cores.textoFraco, espaco: 0.4),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Agente que pode ser arrastado até uma pasta (segurar e arrastar).
class AgenteArrastavel extends StatelessWidget {
  final Ficha ficha;
  final Widget child;
  const AgenteArrastavel({super.key, required this.ficha, required this.child});
  @override
  Widget build(BuildContext context) => LongPressDraggable<Ficha>(
        data: ficha,
        hapticFeedbackOnStart: true,
        feedback: Material(
          color: Cores.painel2,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: Cores.destaque.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AvatarFicha(foto: ficha.foto, nome: ficha.nome, ajuste: ficha.fotoAjuste, tamanho: 34),
              const SizedBox(width: 10),
              Text(ficha.nome, style: estiloTitulo(16, cor: Cores.texto)),
            ]),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: child),
        child: child,
      );
}

/// Tela de uma pasta: os agentes dela, com editar nome/data e apagar.
class TelaPasta extends StatelessWidget {
  final String pastaId;
  const TelaPasta({super.key, required this.pastaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pasta>>(
      stream: Repo.minhasPastas(),
      builder: (context, ps) {
        final pastas = ps.data ?? const <Pasta>[];
        final pasta = pastas.where((p) => p.id == pastaId).firstOrNull;
        return StreamBuilder<List<Ficha>>(
          stream: Repo.fichasEditaveis(),
          builder: (context, snap) {
            final todas = snap.data ?? const <Ficha>[];
            final meus = todas.where((f) => f.ownerUid == Repo.uid && !f.eTransformacao).toList();
            final dentro = meus.where((f) => f.pasta == pastaId).toList();
            return Scaffold(
              appBar: AppBar(
                title: pasta == null
                    ? const SizedBox()
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(pasta.nome, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: estiloTitulo(19, cor: Cores.texto)),
                        Text(
                          '${pasta.dataTexto} · ${dentro.length == 1 ? '1 agente' : '${dentro.length} agentes'}',
                          style: estiloRotulo(13, cor: Cores.textoFraco, peso: FontWeight.w500, espaco: 0.4),
                        ),
                      ]),
                actions: [
                  if (pasta != null) ...[
                    IconButton(
                      tooltip: 'Nome e data',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final r = await pedirPasta(context, pasta: pasta);
                        if (r != null) Repo.mudarPasta(pasta.copiar(nome: r.$1, data: r.$2));
                      },
                    ),
                    IconButton(
                      tooltip: 'Apagar pasta',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirmar(context,
                            'Apagar a pasta "${pasta.nome}"? Os agentes dela não são apagados: voltam para fora das pastas.')) {
                          return;
                        }
                        Repo.apagarPasta(pasta, dentro);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ],
              ),
              floatingActionButton: pasta == null
                  ? null
                  : FloatingActionButton.extended(
                      heroTag: 'pastaAdicionar',
                      onPressed: () => _adicionar(context, pasta, meus),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Adicionar agentes'),
                    ),
              body: !snap.hasData || !ps.hasData
                  ? const SizedBox.expand()
                  : dentro.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.folder_open, size: 64, color: Cores.destaque.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text('Pasta vazia', style: estiloTitulo(20, cor: Cores.texto)),
                              const SizedBox(height: 6),
                              const Text('Adicione agentes pelo botão abaixo ou arraste o cartão de um agente até a pasta na tela inicial.',
                                  textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
                            ]),
                          ),
                        )
                      : StreamBuilder<Map<String, String>>(
                          stream: nomesDasMesas(),
                          builder: (context, ms) => LayoutBuilder(builder: (context, cons) {
                            final colunas = cons.maxWidth >= 1150 ? 3 : (cons.maxWidth >= 760 ? 2 : 1);
                            final largura = (cons.maxWidth - 40 - 16 * (colunas - 1)) / colunas;
                            return ListView(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                              children: [
                                Wrap(spacing: 16, children: [
                                  for (final (i, f) in dentro.indexed)
                                    SizedBox(
                                      width: colunas == 1 ? double.infinity : largura,
                                      child: Surgir(
                                        ordem: i,
                                        child: CartaoAgente(
                                          ficha: f,
                                          mesa: ms.data?[f.campaignId],
                                          formas: todas.where((t) => t.transformacaoDe == f.id).toList(),
                                          aoMover: () => moverAgente(context, f, pastas),
                                        ),
                                      ),
                                    ),
                                ]),
                              ],
                            );
                          }),
                        ),
            );
          },
        );
      },
    );
  }

  /// Escolher vários agentes de fora para trazer para a pasta.
  Future<void> _adicionar(BuildContext context, Pasta pasta, List<Ficha> meus) {
    final fora = meus.where((f) => f.pasta != pasta.id).toList();
    final escolhidos = <String>{};
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Adicionar a "${pasta.nome}"', style: estiloTitulo(19, cor: Cores.texto)),
              ),
              if (fora.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Todos os seus agentes já estão nesta pasta.', style: TextStyle(color: Cores.textoFraco)),
                ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final f in fora)
                    CheckboxListTile(
                      value: escolhidos.contains(f.id),
                      onChanged: (v) => setState(() => v == true ? escolhidos.add(f.id) : escolhidos.remove(f.id)),
                      secondary: AvatarFicha(foto: f.foto, nome: f.nome, ajuste: f.fotoAjuste, tamanho: 36),
                      title: Text(f.nome),
                      subtitle: Text(f.pasta == null ? 'sem pasta' : 'em outra pasta'),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: escolhidos.isEmpty
                      ? null
                      : () {
                          for (final f in fora) {
                            if (escolhidos.contains(f.id)) Repo.moverParaPasta(f, pasta.id);
                          }
                          Navigator.pop(ctx);
                        },
                  child: Text(escolhidos.isEmpty ? 'ESCOLHA OS AGENTES' : 'ADICIONAR ${escolhidos.length}'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
