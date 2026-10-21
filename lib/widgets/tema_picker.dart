import 'package:flutter/material.dart';

import '../core/tema_app.dart';
import '../core/theme.dart';

/// Janela para escolher o tema de cores do app.
Future<void> escolherTema(BuildContext context) async {
  final id = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Tema de cores'),
      children: [
        for (final t in temasCores)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, t.id),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.degradeTopo, t.degradeMeio, t.degradeBase],
                  ),
                  border: Border.all(color: t.destaque, width: 3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(t.nome,
                    style: TextStyle(
                        color: t.destaque,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
              if (TemaApp.atual.value == t.id)
                Icon(Icons.check_circle, color: t.destaque),
            ]),
          ),
      ],
    ),
  );
  if (id != null && id != TemaApp.atual.value) await TemaApp.escolher(id);
}
