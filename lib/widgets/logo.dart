import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Marca em texto do app. Para usar uma imagem propria, coloque o arquivo em
/// assets/logo.png e troque este widget por Image.asset('assets/logo.png').
class LogoCris extends StatelessWidget {
  final double tamanho;
  const LogoCris({super.key, this.tamanho = 40});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'C.R.I.S',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: tamanho,
            fontWeight: FontWeight.w900,
            letterSpacing: tamanho * 0.18,
            color: Cores.texto,
            shadows: const [Shadow(color: Cores.destaque, blurRadius: 18)],
          ),
        ),
        Container(
          height: 2,
          width: tamanho * 3,
          margin: const EdgeInsets.only(top: 4),
          color: Cores.destaque,
        ),
      ],
    );
  }
}
