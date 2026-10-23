import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'efeitos.dart';
import 'sigilos.dart';

/// Marca do app: sigilo de Conhecimento e "P.A.U." em Cinzel gasto, com uma
/// falha de tela de vez em quando. Pequena, fica em linha (topo das telas);
/// grande, empilhada e com o sigilo girando devagar (tela de entrada).
class LogoCris extends StatelessWidget {
  final double tamanho;
  const LogoCris({super.key, this.tamanho = 40});
  @override
  Widget build(BuildContext context) {
    final grande = tamanho >= 40;
    final claro = Color.lerp(Cores.destaque, Colors.white, 0.45)!;
    final texto = Glitch(
      intervalo: Duration(seconds: grande ? 5 : 9),
      child: Gasto(
        escala: grande ? 0.9 : 0.6,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [claro, Cores.destaque],
          ).createShader(r),
          child: Text(
            'P.A.U.',
            style: estiloTitulo(tamanho, peso: FontWeight.w800, espaco: tamanho * 0.12, altura: 1),
          ),
        ),
      ),
    );
    if (!grande) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        SigiloConhecimento(tamanho: tamanho * 1.3, espessura: 1),
        SizedBox(width: tamanho * 0.45),
        texto,
      ]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Cores.destaque.withValues(alpha: 0.18),
                  blurRadius: tamanho * 1.2,
                  spreadRadius: tamanho * 0.1),
            ],
          ),
          child: _SigiloGirando(tamanho: tamanho * 2.3),
        ),
        SizedBox(height: tamanho * 0.45),
        texto,
      ],
    );
  }
}

/// Sigilo que dá uma volta inteira a cada minuto e meio.
class _SigiloGirando extends StatefulWidget {
  final double tamanho;
  const _SigiloGirando({required this.tamanho});
  @override
  State<_SigiloGirando> createState() => _SigiloGirandoState();
}

class _SigiloGirandoState extends State<_SigiloGirando> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: RotationTransition(
          turns: _c,
          // o sigilo é desenhado uma vez; o giro só move a imagem pronta
          child: RepaintBoundary(child: SigiloConhecimento(tamanho: widget.tamanho, espessura: 1.3)),
        ),
      );
}
