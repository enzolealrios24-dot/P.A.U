import 'package:flutter/material.dart';

import '../widgets/sigilos.dart';

class Cores {
  // Base escura arroxeada; as telas ficam sobre o degradê do FundoCris.
  static const fundo = Color(0xFF0E0A14);
  static const painel = Color(0xE6170F22);
  static const painel2 = Color(0xFF221832);
  static const borda = Color(0xFF3F3058);
  static const texto = Color(0xFFF3EEF8);
  static const textoFraco = Color(0xFFB4AAC6);
  static const destaque = Color(0xFFF5C42C); // amarelo do Conhecimento
  static const sobreDestaque = Color(0xFF1B1024); // texto em cima do amarelo
  static const roxo = Color(0xFF8A4DFF);
  static const roxoClaro = Color(0xFFB98CFF);
  // Degradê do fundo: amarelo em cima, roxo embaixo.
  static const degradeTopo = Color(0xFF6A520A);
  static const degradeMeio = Color(0xFF2A1A35);
  static const degradeBase = Color(0xFF34105E);
  static const pv = Color(0xFFD7263D);
  static const pe = Color(0xFFE0A526);
  static const san = Color(0xFF3D7BFF);
  static const pd = Color(0xFF9B59E0);
  // Pontos temporários: tons mais claros das barras de origem.
  static const pvTemp = Color(0xFFF2788A);
  static const peTemp = Color(0xFFF2CF6B);
  static const pdTemp = Color(0xFFC79BF2);
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
    seedColor: Cores.roxo,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Cores.destaque,
    onPrimary: Cores.sobreDestaque,
    primaryContainer: const Color(0xFF4A3A08),
    onPrimaryContainer: Cores.destaque,
    secondary: Cores.roxoClaro,
    onSecondary: Cores.sobreDestaque,
    secondaryContainer: const Color(0xFF3A2266),
    onSecondaryContainer: Cores.texto,
    tertiary: Cores.roxo,
    surface: Cores.painel2,
    onSurface: Cores.texto,
    onSurfaceVariant: Cores.textoFraco,
    surfaceContainerLowest: const Color(0xFF120C1A),
    surfaceContainerLow: const Color(0xFF181022),
    surfaceContainer: const Color(0xFF1D142A),
    surfaceContainerHigh: const Color(0xFF231931),
    surfaceContainerHighest: const Color(0xFF2B1F3B),
    outline: Cores.borda,
    outlineVariant: Cores.borda,
    error: const Color(0xFFFF6B6B),
  );
  const bordaLinha = UnderlineInputBorder(borderSide: BorderSide(color: Cores.borda));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // As telas são transparentes: o fundo em degradê vem da transição de página.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Cores.painel2,
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values) p: const TransicaoComFundo(),
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Cores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
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
    dialogTheme: DialogThemeData(
      backgroundColor: Cores.painel2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Cores.destaque.withValues(alpha: 0.35)),
      ),
    ),
    // Campos como no CRIS original: só a linha de baixo.
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: false,
      labelStyle: TextStyle(color: Cores.textoFraco),
      floatingLabelStyle: TextStyle(color: Cores.destaque),
      border: bordaLinha,
      enabledBorder: bordaLinha,
      focusedBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: Cores.destaque, width: 2)),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Cores.destaque,
      unselectedLabelColor: Cores.textoFraco,
      indicatorColor: Cores.destaque,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xF0190F26),
      surfaceTintColor: Colors.transparent,
      indicatorColor: Cores.destaque.withValues(alpha: 0.22),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Cores.destaque : Cores.textoFraco)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected) ? Cores.destaque : Cores.textoFraco)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: Cores.destaque.withValues(alpha: 0.22),
      selectedIconTheme: const IconThemeData(color: Cores.destaque),
      unselectedIconTheme: const IconThemeData(color: Cores.textoFraco),
      selectedLabelTextStyle:
          const TextStyle(color: Cores.destaque, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: const TextStyle(color: Cores.textoFraco),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Cores.painel2,
      selectedColor: Cores.destaque.withValues(alpha: 0.25),
      side: const BorderSide(color: Cores.borda),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Cores.painel2,
      contentTextStyle: TextStyle(color: Cores.texto),
      actionTextColor: Cores.destaque,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: Cores.painel2),
    dividerColor: Cores.borda,
  );
}
