import 'package:flutter/material.dart';

import '../widgets/sigilos.dart';

/// Paleta de um tema de cores do app.
class TemaCores {
  final String id;
  final String nome;
  final Color destaque; // botões, abas, títulos
  final Color sobreDestaque; // texto em cima do destaque
  final Color roxo; // cor secundária
  final Color roxoClaro;
  final Color fundo;
  final Color painel;
  final Color painel2;
  final Color borda;
  // Degradê do fundo, de cima para baixo.
  final Color degradeTopo;
  final Color degradeMeio;
  final Color degradeBase;
  const TemaCores({
    required this.id,
    required this.nome,
    required this.destaque,
    required this.sobreDestaque,
    required this.roxo,
    required this.roxoClaro,
    required this.fundo,
    required this.painel,
    required this.painel2,
    required this.borda,
    required this.degradeTopo,
    required this.degradeMeio,
    required this.degradeBase,
  });
}

const temasCores = <TemaCores>[
  TemaCores(
    id: 'amarelo',
    nome: 'Amarelo',
    destaque: Color(0xFFF5C42C),
    sobreDestaque: Color(0xFF1B1024),
    roxo: Color(0xFF8A4DFF),
    roxoClaro: Color(0xFFB98CFF),
    fundo: Color(0xFF0E0A14),
    painel: Color(0xE6170F22),
    painel2: Color(0xFF221832),
    borda: Color(0xFF3F3058),
    degradeTopo: Color(0xFF6A520A),
    degradeMeio: Color(0xFF2A1A35),
    degradeBase: Color(0xFF34105E),
  ),
  TemaCores(
    id: 'roxo',
    nome: 'Roxo',
    destaque: Color(0xFFB98CFF),
    sobreDestaque: Color(0xFF14091F),
    roxo: Color(0xFF7B3FF2),
    roxoClaro: Color(0xFFD9C2FF),
    fundo: Color(0xFF0D0716),
    painel: Color(0xE6170C26),
    painel2: Color(0xFF231538),
    borda: Color(0xFF473266),
    degradeTopo: Color(0xFF4E2290),
    degradeMeio: Color(0xFF23133A),
    degradeBase: Color(0xFF0E0719),
  ),
  TemaCores(
    id: 'preto',
    nome: 'Preto',
    destaque: Color(0xFFE9E7F0),
    sobreDestaque: Color(0xFF0B0B0F),
    roxo: Color(0xFF8A4DFF),
    roxoClaro: Color(0xFFB98CFF),
    fundo: Color(0xFF09090C),
    painel: Color(0xE6131317),
    painel2: Color(0xFF1C1C23),
    borda: Color(0xFF30303B),
    degradeTopo: Color(0xFF222229),
    degradeMeio: Color(0xFF121216),
    degradeBase: Color(0xFF050507),
  ),
  TemaCores(
    id: 'vermelho',
    nome: 'Vermelho',
    destaque: Color(0xFFEF3B53),
    sobreDestaque: Color(0xFFFFFFFF),
    roxo: Color(0xFFB0283F),
    roxoClaro: Color(0xFFFF8A99),
    fundo: Color(0xFF0F0708),
    painel: Color(0xE61A0B0E),
    painel2: Color(0xFF281317),
    borda: Color(0xFF4D2329),
    degradeTopo: Color(0xFF63101C),
    degradeMeio: Color(0xFF280A0F),
    degradeBase: Color(0xFF0B0405),
  ),
];

class Cores {
  // Cores do tema escolhido (mudam com aplicar). As demais são fixas.
  static Color fundo = temasCores.first.fundo;
  static Color painel = temasCores.first.painel;
  static Color painel2 = temasCores.first.painel2;
  static Color borda = temasCores.first.borda;
  static Color destaque = temasCores.first.destaque;
  static Color sobreDestaque = temasCores.first.sobreDestaque;
  static Color roxo = temasCores.first.roxo;
  static Color roxoClaro = temasCores.first.roxoClaro;
  static Color degradeTopo = temasCores.first.degradeTopo;
  static Color degradeMeio = temasCores.first.degradeMeio;
  static Color degradeBase = temasCores.first.degradeBase;

  static void aplicar(TemaCores t) {
    fundo = t.fundo;
    painel = t.painel;
    painel2 = t.painel2;
    borda = t.borda;
    destaque = t.destaque;
    sobreDestaque = t.sobreDestaque;
    roxo = t.roxo;
    roxoClaro = t.roxoClaro;
    degradeTopo = t.degradeTopo;
    degradeMeio = t.degradeMeio;
    degradeBase = t.degradeBase;
  }

  static const texto = Color(0xFFF3EEF8);
  static const textoFraco = Color(0xFFB4AAC6);
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
    primaryContainer: Color.alphaBlend(Cores.destaque.withValues(alpha: 0.28), Cores.painel2),
    onPrimaryContainer: Cores.destaque,
    secondary: Cores.roxoClaro,
    onSecondary: Cores.sobreDestaque,
    secondaryContainer: Color.alphaBlend(Cores.roxo.withValues(alpha: 0.35), Cores.painel2),
    onSecondaryContainer: Cores.texto,
    tertiary: Cores.roxo,
    surface: Cores.painel2,
    onSurface: Cores.texto,
    onSurfaceVariant: Cores.textoFraco,
    surfaceContainerLowest: Color.lerp(Cores.fundo, Cores.painel2, 0.2)!,
    surfaceContainerLow: Color.lerp(Cores.fundo, Cores.painel2, 0.45)!,
    surfaceContainer: Color.lerp(Cores.fundo, Cores.painel2, 0.7)!,
    surfaceContainerHigh: Cores.painel2,
    surfaceContainerHighest: Color.lerp(Cores.painel2, Cores.borda, 0.35)!,
    outline: Cores.borda,
    outlineVariant: Cores.borda,
    error: const Color(0xFFFF6B6B),
  );
  final bordaLinha = UnderlineInputBorder(borderSide: BorderSide(color: Cores.borda));
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
        side: BorderSide(color: Cores.borda),
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
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: false,
      labelStyle: TextStyle(color: Cores.textoFraco),
      floatingLabelStyle: TextStyle(color: Cores.destaque),
      border: bordaLinha,
      enabledBorder: bordaLinha,
      focusedBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: Cores.destaque, width: 2)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Cores.destaque,
      unselectedLabelColor: Cores.textoFraco,
      indicatorColor: Cores.destaque,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Cores.painel2.withValues(alpha: 0.94),
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
      selectedIconTheme: IconThemeData(color: Cores.destaque),
      unselectedIconTheme: const IconThemeData(color: Cores.textoFraco),
      selectedLabelTextStyle:
          TextStyle(color: Cores.destaque, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: const TextStyle(color: Cores.textoFraco),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Cores.painel2,
      selectedColor: Cores.destaque.withValues(alpha: 0.25),
      side: BorderSide(color: Cores.borda),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Cores.painel2,
      contentTextStyle: TextStyle(color: Cores.texto),
      actionTextColor: Cores.destaque,
    ),
    popupMenuTheme: PopupMenuThemeData(color: Cores.painel2),
    dividerColor: Cores.borda,
  );
}
