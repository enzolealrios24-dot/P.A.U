import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Ordem de iniciativa (somente leitura) - usada pelos jogadores.
class IniciativaView extends StatelessWidget {
  final Campanha camp;
  const IniciativaView({super.key, required this.camp});

  @override
  Widget build(BuildContext context) {
    final cb = camp.combate;
    final ordem = asMapList(cb['ordem']);
    final turno = asInt(cb['turno']);
    return Secao(
      titulo: 'Combate • rodada ${asInt(cb['rodada'], 1)}',
      child: Column(children: [
        for (var i = 0; i < ordem.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: i == turno
                  ? Cores.destaque.withValues(alpha: 0.25)
                  : Cores.painel2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: i == turno ? Cores.destaque : Cores.borda),
            ),
            child: Row(children: [
              SizedBox(
                  width: 34,
                  child: Text('${asInt(ordem[i]['valor'])}',
                      style: const TextStyle(fontWeight: FontWeight.w900))),
              Expanded(
                child: Text(
                    asBool(ordem[i]['oculto'])
                        ? '???'
                        : asStr(ordem[i]['nome']),
                    style: TextStyle(
                        fontWeight:
                            i == turno ? FontWeight.w800 : FontWeight.w400)),
              ),
              if (i == turno)
                const Text('VEZ', style: TextStyle(color: Cores.destaque)),
            ]),
          ),
      ]),
    );
  }
}
