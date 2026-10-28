import 'package:flutter/material.dart';

import '../core/tema_app.dart';
import '../core/theme.dart';

/// Amostra de um tema em cores sólidas: a cor de destaque com um miolo no
/// tom mais escuro do mesmo tema.
class AmostraTema extends StatelessWidget {
  final TemaCores t;
  final double tamanho;
  final bool escolhido;
  const AmostraTema({super.key, required this.t, this.tamanho = 52, this.escolhido = false});
  @override
  Widget build(BuildContext context) => Container(
        width: tamanho,
        height: tamanho,
        padding: EdgeInsets.all(tamanho * (escolhido ? 0.16 : 0.2)),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.destaque,
          border: escolhido ? Border.all(color: t.roxoClaro, width: 2.5) : null,
          boxShadow: escolhido
              ? [BoxShadow(color: t.destaque.withValues(alpha: 0.45), blurRadius: 14)]
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: t.roxo),
          child: escolhido ? Icon(Icons.check, color: t.roxoClaro, size: tamanho * 0.36) : null,
        ),
      );
}

/// Janela para escolher o tema de cores do app.
Future<void> escolherTema(BuildContext context) async {
  final id = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Tema de cores'),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        for (final t in temasCores)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.pop(ctx, t.id),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: TemaApp.atual.value == t.id ? t.destaque.withValues(alpha: 0.08) : null,
                  border: Border.all(
                      color: TemaApp.atual.value == t.id
                          ? t.destaque.withValues(alpha: 0.5)
                          : Colors.transparent),
                ),
                child: Row(children: [
                  AmostraTema(t: t, tamanho: 46, escolhido: TemaApp.atual.value == t.id),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.nome, style: estiloTitulo(17, cor: t.destaque)),
                      const SizedBox(height: 2),
                      Text(t.descricao,
                          style: const TextStyle(fontSize: 13, color: Cores.textoFraco)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
      ],
    ),
  );
  if (id != null && id != TemaApp.atual.value) await TemaApp.escolher(id);
}

/// Fileira de amostras para trocar o tema com um toque (tela de entrada).
class AmostrasTema extends StatelessWidget {
  const AmostrasTema({super.key});
  @override
  Widget build(BuildContext context) {
    final atual = temasCores.firstWhere((t) => t.id == TemaApp.atual.value,
        orElse: () => temasCores.first);
    return Column(children: [
      Text('TEMA · ${atual.nome.toUpperCase()}',
          style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 2.2)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final t in temasCores)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Tooltip(
              message: '${t.nome} (${t.descricao.toLowerCase()})',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => TemaApp.escolher(t.id),
                child: AmostraTema(t: t, tamanho: 36, escolhido: t.id == atual.id),
              ),
            ),
          ),
      ]),
    ]);
  }
}
