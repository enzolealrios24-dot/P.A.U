import 'package:flutter/material.dart';

import '../core/tema_app.dart';
import '../core/theme.dart';

const _descricao = {
  'amarelo': 'Dourado com roxo',
  'roxo': 'Roxo e magenta',
  'preto': 'Grafite e prata',
  'vermelho': 'Vermelho-sangue',
};

/// Amostra de um tema: o fundo com os dois brilhos e a cor de destaque.
class AmostraTema extends StatelessWidget {
  final TemaCores t;
  final double tamanho;
  final bool escolhido;
  const AmostraTema({super.key, required this.t, this.tamanho = 52, this.escolhido = false});
  @override
  Widget build(BuildContext context) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.fundo,
          gradient: RadialGradient(
            center: const Alignment(0.3, -0.9),
            radius: 1.1,
            colors: [t.degradeTopo.withValues(alpha: 0.85), t.degradeMeio, t.degradeBase],
            stops: const [0, 0.55, 1],
          ),
          border: Border.all(color: escolhido ? t.destaque : t.destaque.withValues(alpha: 0.35), width: escolhido ? 3 : 1.5),
          boxShadow: escolhido
              ? [BoxShadow(color: t.destaque.withValues(alpha: 0.45), blurRadius: 14)]
              : null,
        ),
        child: escolhido ? Icon(Icons.check, color: t.destaque, size: tamanho * 0.42) : null,
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
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(ctx, t.id),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
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
                      Text(t.elemento, style: estiloTitulo(17, cor: t.destaque)),
                      const SizedBox(height: 2),
                      Text(_descricao[t.id] ?? t.nome,
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
      Text('TEMA · ${atual.elemento.toUpperCase()}',
          style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 2.2)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final t in temasCores)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Tooltip(
              message: '${t.elemento} (${t.nome.toLowerCase()})',
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
