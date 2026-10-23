import 'package:flutter/material.dart';

import '../../core/tema_app.dart';
import '../../core/theme.dart';
import '../../widgets/sigilos.dart';

/// Aplica as cores e a fonte da afinidade do dossiê enquanto a ficha (e o que
/// se abre a partir dela) está na tela, e devolve o tema do app ao sair.
/// Sem afinidade escolhida, a ficha fica com o tema do app.
class PaletaFicha extends StatefulWidget {
  final String elemento;
  final Widget child;
  const PaletaFicha({super.key, required this.elemento, required this.child});

  static TemaCores temaDe(String elemento) => temasAfinidade[elemento] ?? TemaApp.tema;

  @override
  State<PaletaFicha> createState() => _PaletaFichaState();
}

class _PaletaFichaState extends State<PaletaFicha> {
  // Fichas abertas agora (agente e transformação podem se trocar na pilha).
  static int _abertas = 0;

  @override
  void initState() {
    super.initState();
    _abertas++;
  }

  @override
  void dispose() {
    _abertas--;
    if (_abertas == 0) {
      Cores.aplicar(TemaApp.tema);
      // as telas de trás podem ter sido redesenhadas com as cores da ficha
      WidgetsBinding.instance.addPostFrameCallback((_) => _reconstruirTudo());
      WidgetsBinding.instance.scheduleFrame();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = PaletaFicha.temaDe(widget.elemento);
    if (!identical(Cores.atual, t)) Cores.aplicar(t);
    return Theme(data: temaCris(), child: FundoCris(child: widget.child));
  }
}

void _reconstruirTudo() {
  void marcar(Element e) {
    e.markNeedsBuild();
    e.visitChildren(marcar);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(marcar);
}
