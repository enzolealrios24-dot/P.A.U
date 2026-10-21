import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'sigilos.dart';

/// Marca do app: sigilo de Conhecimento e "P.A.U." em Cinzel, com um brilho
/// da cor do tema. Pequena, fica em linha (topo das telas); grande, empilhada
/// (tela de entrada).
class LogoCris extends StatelessWidget {
  final double tamanho;
  const LogoCris({super.key, this.tamanho = 40});
  @override
  Widget build(BuildContext context) {
    final grande = tamanho >= 40;
    final claro = Color.lerp(Cores.destaque, Colors.white, 0.45)!;
    final texto = ShaderMask(
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
          child: SigiloConhecimento(tamanho: tamanho * 2.3, espessura: 1.3),
        ),
        SizedBox(height: tamanho * 0.45),
        texto,
      ],
    );
  }
}
