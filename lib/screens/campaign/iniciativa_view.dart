import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/arquivo.dart';
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
    return BlocoMesa(
      titulo: 'Combate, rodada ${asInt(cb['rodada'], 1)}',
      forte: true,
      acoes: [
        if (cb['inicio'] != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.timer_outlined, size: 16, color: Cores.textoFraco),
            const SizedBox(width: 4),
            Cronometro(inicio: asInt(cb['inicio']), estilo: estiloNumero(16, cor: Cores.texto)),
          ]),
      ],
      child: Column(children: [
        for (var i = 0; i < ordem.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
            decoration: BoxDecoration(
              color: i == turno ? Color.alphaBlend(Cores.destaque.withValues(alpha: 0.16), Cores.painel2) : null,
              border: Border(
                left: BorderSide(color: i == turno ? Cores.destaque : Colors.transparent, width: 3),
                bottom: const BorderSide(color: Cores.linha),
              ),
            ),
            child: Row(children: [
              SizedBox(
                width: 46,
                child: Text('${asInt(ordem[i]['valor'])}',
                    textAlign: TextAlign.center,
                    style: estiloNumero(18, cor: i == turno ? Cores.destaque : Cores.textoFraco)),
              ),
              Expanded(
                child: Text(asBool(ordem[i]['oculto']) ? '???' : asStr(ordem[i]['nome']),
                    style: TextStyle(fontSize: 15, fontWeight: i == turno ? FontWeight.w700 : FontWeight.w400)),
              ),
              if (i == turno) Carimbo('VEZ', tamanho: 10.5, giro: 0.03),
            ]),
          ),
      ]),
    );
  }
}
