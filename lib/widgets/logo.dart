import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'sigilos.dart';

/// Marca do app: sigilo de Conhecimento e "P.A.U." em degradê de amarelo
/// para roxo. Para usar uma imagem própria, troque por Image.asset.
class LogoCris extends StatelessWidget {
  final double tamanho;
  const LogoCris({super.key, this.tamanho = 40});
  @override
  Widget build(BuildContext context) {
    final grande = tamanho >= 40;
    final texto = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Cores.destaque, Color(0xFFE59B3A), Cores.roxoClaro],
      ).createShader(r),
      child: Text(
        'P.A.U.',
        style: TextStyle(
          fontSize: tamanho,
          fontWeight: FontWeight.w900,
          letterSpacing: tamanho * 0.16,
          height: 1,
        ),
      ),
    );
    if (!grande) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        SigiloConhecimento(tamanho: tamanho * 1.35, espessura: 1.1),
        SizedBox(width: tamanho * 0.4),
        texto,
      ]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SigiloConhecimento(tamanho: tamanho * 2.2, espessura: 1.6),
        SizedBox(height: tamanho * 0.3),
        texto,
        Container(
          height: 2,
          width: tamanho * 3.4,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Cores.destaque, Cores.roxo]),
          ),
        ),
      ],
    );
  }
}
