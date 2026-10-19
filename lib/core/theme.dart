import 'package:flutter/material.dart';

class Cores {
  static const fundo = Color(0xFF09090D);
  static const painel = Color(0xFF13131A);
  static const painel2 = Color(0xFF1C1C26);
  static const borda = Color(0xFF2A2A38);
  static const texto = Color(0xFFE8E6EF);
  static const textoFraco = Color(0xFF9A98A8);
  static const destaque = Color(0xFFD7263D); // vermelho Ordem
  static const roxo = Color(0xFF7B4DFF);
  static const pv = Color(0xFFD7263D);
  static const pe = Color(0xFFE0A526);
  static const san = Color(0xFF3D7BFF);
  static const pd = Color(0xFF9B59E0);
  static const ok = Color(0xFF3DBE7A);

  static Color elemento(String? e) {
    switch (e) {
      case 'Sangue':
        return const Color(0xFFC1121F);
      case 'Morte':
        return const Color(0xFF8D8D8D);
      case 'Conhecimento':
        return const Color(0xFFE8B931);
      case 'Energia':
        return const Color(0xFF9D4EDD);
      case 'Medo':
        return const Color(0xFFF1F1F1);
      default:
        return roxo;
    }
  }
}

ThemeData temaCris() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Cores.destaque,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Cores.destaque,
    secondary: Cores.roxo,
    surface: Cores.painel,
    onSurface: Cores.texto,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Cores.fundo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.fundo,
      foregroundColor: Cores.texto,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Cores.painel,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Cores.borda),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Cores.painel2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Cores.borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Cores.borda),
      ),
    ),
    dividerColor: Cores.borda,
  );
}
