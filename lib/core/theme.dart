import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/material.dart';

import '../widgets/sigilos.dart';

/// Paleta de um tema de cores do app. Cada tema leva o nome de um elemento
/// do Outro Lado.
class TemaCores {
  final String id;
  final String nome; // cor ("Amarelo")
  final String elemento; // "Conhecimento"
  final Color destaque; // botões, abas, títulos
  final Color sobreDestaque; // texto em cima do destaque
  final Color roxo; // cor secundária
  final Color roxoClaro;
  final Color fundo;
  final Color painel;
  final Color painel2;
  final Color borda;
  // Brilhos do fundo: um em cima e outro embaixo (o meio é só para a amostra).
  final Color degradeTopo;
  final Color degradeMeio;
  final Color degradeBase;
  /// Fonte dos títulos (nomes, títulos de tela e de janelas).
  final String fonteTitulo;
  const TemaCores({
    required this.id,
    required this.nome,
    required this.elemento,
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
    this.fonteTitulo = 'Cinzel',
  });
}

const temasCores = <TemaCores>[
  TemaCores(
    id: 'amarelo',
    nome: 'Amarelo',
    elemento: 'Conhecimento',
    destaque: Color(0xFFE9BC4E),
    sobreDestaque: Color(0xFF1A1407),
    roxo: Color(0xFF8E6CF0),
    roxoClaro: Color(0xFFBBA6FF),
    fundo: Color(0xFF0B0A0F),
    painel: Color(0xF00C0B10),
    painel2: Color(0xFF18161E),
    borda: Color(0xFF2A2532),
    degradeTopo: Color(0xFFE9BC4E),
    degradeMeio: Color(0xFF2A2340),
    degradeBase: Color(0xFF6B3FD4),
  ),
  TemaCores(
    id: 'roxo',
    nome: 'Roxo',
    elemento: 'Energia',
    destaque: Color(0xFFB9A1FF),
    sobreDestaque: Color(0xFF130A26),
    roxo: Color(0xFF7443F0),
    roxoClaro: Color(0xFFD9CCFF),
    fundo: Color(0xFF0B0911),
    painel: Color(0xF00C0A14),
    painel2: Color(0xFF181427),
    borda: Color(0xFF2C2542),
    degradeTopo: Color(0xFFC14BE0),
    degradeMeio: Color(0xFF2B1F4D),
    degradeBase: Color(0xFF22C7E0),
  ),
  TemaCores(
    id: 'preto',
    nome: 'Preto',
    elemento: 'Morte',
    destaque: Color(0xFFE7E4EC),
    sobreDestaque: Color(0xFF0B0B0D),
    roxo: Color(0xFF77727F),
    roxoClaro: Color(0xFFB2ADBA),
    fundo: Color(0xFF09090B),
    painel: Color(0xF00B0B0D),
    painel2: Color(0xFF17171A),
    borda: Color(0xFF29292E),
    degradeTopo: Color(0xFFA19DAA),
    degradeMeio: Color(0xFF1E1E23),
    degradeBase: Color(0xFF4A4753),
  ),
  TemaCores(
    id: 'vermelho',
    nome: 'Vermelho',
    elemento: 'Sangue',
    destaque: Color(0xFFEC4A55),
    sobreDestaque: Color(0xFFFFFFFF),
    roxo: Color(0xFF9B2335),
    roxoClaro: Color(0xFFFF9AA2),
    fundo: Color(0xFF0D0708),
    painel: Color(0xF00E090A),
    painel2: Color(0xFF1C1214),
    borda: Color(0xFF37222A),
    degradeTopo: Color(0xFFEC4A55),
    degradeMeio: Color(0xFF3A1219),
    degradeBase: Color(0xFF7A1029),
  ),
];

/// Paletas da ficha conforme a afinidade escolhida no dossiê. Os painéis são
/// translúcidos, para o fundo aparecer por trás.
const temasAfinidade = <String, TemaCores>{
  'Conhecimento': TemaCores(
    id: 'af-conhecimento',
    nome: 'Dourado',
    elemento: 'Conhecimento',
    destaque: Color(0xFFD6A72B),
    sobreDestaque: Color(0xFF17110A),
    roxo: Color(0xFF7A5CE0),
    roxoClaro: Color(0xFFB8A4FF),
    fundo: Color(0xFF0B0A0F),
    painel: Color(0xB00E0C12),
    painel2: Color(0xFF1A1720),
    borda: Color(0xFF332C3E),
    degradeTopo: Color(0xFFD6A72B),
    degradeMeio: Color(0xFF2A2340),
    degradeBase: Color(0xFF5B3FC0),
  ),
  'Energia': TemaCores(
    id: 'af-energia',
    nome: 'Roxo',
    elemento: 'Energia',
    destaque: Color(0xFF9B5CFF),
    sobreDestaque: Color(0xFFFFFFFF),
    roxo: Color(0xFF1FC8E0),
    roxoClaro: Color(0xFF8DF3FF),
    fundo: Color(0xFF0A0812),
    painel: Color(0xB00D0A18),
    painel2: Color(0xFF181428),
    borda: Color(0xFF332A52),
    degradeTopo: Color(0xFF9B5CFF),
    degradeMeio: Color(0xFF2B1F4D),
    degradeBase: Color(0xFF1FC8E0),
    fonteTitulo: 'ChakraPetch',
  ),
  'Morte': TemaCores(
    id: 'af-morte',
    nome: 'Preto e branco',
    elemento: 'Morte',
    destaque: Color(0xFFF2F2F2),
    sobreDestaque: Color(0xFF060606),
    roxo: Color(0xFF5C5C5C),
    roxoClaro: Color(0xFFC9C9C9),
    fundo: Color(0xFF060606),
    painel: Color(0xB00B0B0B),
    painel2: Color(0xFF151515),
    borda: Color(0xFF2E2E2E),
    degradeTopo: Color(0xFFF2F2F2),
    degradeMeio: Color(0xFF1A1A1A),
    degradeBase: Color(0xFF3A3A3A),
    fonteTitulo: 'IMFellEnglishSC',
  ),
  'Sangue': TemaCores(
    id: 'af-sangue',
    nome: 'Vermelho',
    elemento: 'Sangue',
    destaque: Color(0xFFFF3B4F),
    sobreDestaque: Color(0xFFFFFFFF),
    roxo: Color(0xFF8B1022),
    roxoClaro: Color(0xFFFF8F9B),
    fundo: Color(0xFF0D0606),
    painel: Color(0xB0120909),
    painel2: Color(0xFF1E1013),
    borda: Color(0xFF3E2229),
    degradeTopo: Color(0xFFFF3B4F),
    degradeMeio: Color(0xFF3A1219),
    degradeBase: Color(0xFF7A1029),
    fonteTitulo: 'MetalMania',
  ),
};

class Cores {
  /// Tema aplicado agora (o do app, ou o da afinidade quando uma ficha está
  /// aberta).
  static TemaCores atual = temasCores.first;
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
    atual = t;
    Fontes.titulo = t.fonteTitulo;
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

  static const texto = Color(0xFFEDE9F3);
  static const textoFraco = Color(0xFF9D96AB);
  /// Linhas bem sutis (divisórias, contornos de campos).
  static const linha = Color(0x1FFFFFFF);
  static const pv = Color(0xFFE5484D);
  static const pe = Color(0xFFF0A93B);
  static const san = Color(0xFF4C8DFF);
  static const pd = Color(0xFFA57BFF);
  // Pontos temporários: tons mais claros das barras de origem.
  static const pvTemp = Color(0xFFFF9AA0);
  static const peTemp = Color(0xFFFFD27A);
  static const pdTemp = Color(0xFFCDB4FF);
  static const ok = Color(0xFF3CCB85);

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

/// Famílias de fonte do app.
class Fontes {
  /// Títulos e nomes: letras romanas, com minúsculas em versalete.
  static String titulo = 'Cinzel';
  static const texto = 'Barlow';
  /// Números, rótulos, abas e botões.
  static const condensada = 'BarlowCondensed';
  /// Máquina de escrever: números de arquivo, carimbos, anotações.
  static const maquina = 'SpecialElite';
}

/// Texto de máquina de escrever (dossiê).
TextStyle estiloMaquina(double tamanho, {Color? cor, double espaco = 0.6}) => TextStyle(
      fontFamily: Fontes.maquina,
      fontSize: tamanho,
      color: cor,
      letterSpacing: espaco,
      height: 1.2,
    );

/// Título em Cinzel. A fonte é variável: o peso vai também como variação.
TextStyle estiloTitulo(double tamanho,
        {Color? cor, FontWeight peso = FontWeight.w700, double espaco = 0.4, double altura = 1.15}) =>
    TextStyle(
      fontFamily: Fontes.titulo,
      fontSize: tamanho,
      fontWeight: peso,
      fontVariations: [FontVariation.weight(peso.value.toDouble())],
      color: cor,
      letterSpacing: espaco,
      height: altura,
    );

/// Rótulo em Barlow Condensed (em maiúsculas fica com cara de ficha oficial).
TextStyle estiloRotulo(double tamanho,
        {Color? cor, FontWeight peso = FontWeight.w600, double espaco = 1.2}) =>
    TextStyle(
      fontFamily: Fontes.condensada,
      fontSize: tamanho,
      fontWeight: peso,
      color: cor,
      letterSpacing: espaco,
      height: 1.1,
    );

/// Números de ficha: condensados e com largura fixa, para não "pularem".
TextStyle estiloNumero(double tamanho, {Color? cor, FontWeight peso = FontWeight.w700}) =>
    TextStyle(
      fontFamily: Fontes.condensada,
      fontSize: tamanho,
      fontWeight: peso,
      color: cor,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData temaCris() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Cores.roxo,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Cores.destaque,
    onPrimary: Cores.sobreDestaque,
    primaryContainer: Color.alphaBlend(Cores.destaque.withValues(alpha: 0.22), Cores.painel2),
    onPrimaryContainer: Cores.destaque,
    secondary: Cores.roxoClaro,
    onSecondary: Cores.sobreDestaque,
    secondaryContainer: Color.alphaBlend(Cores.roxo.withValues(alpha: 0.32), Cores.painel2),
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
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final textos = base.textTheme.apply(
    fontFamily: Fontes.texto,
    bodyColor: Cores.texto,
    displayColor: Cores.texto,
  );
  final linha = UnderlineInputBorder(borderSide: BorderSide(color: Cores.borda));
  const cantos = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4)));
  final botao = estiloRotulo(16, peso: FontWeight.w700, espaco: 0.9);
  return base.copyWith(
    // As telas são transparentes: o fundo vem da transição de página.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Cores.painel2,
    textTheme: textos.copyWith(
      displayLarge: estiloTitulo(48, cor: Cores.texto),
      displayMedium: estiloTitulo(38, cor: Cores.texto),
      displaySmall: estiloTitulo(30, cor: Cores.texto),
      headlineLarge: estiloTitulo(28, cor: Cores.texto),
      headlineMedium: estiloTitulo(24, cor: Cores.texto),
      headlineSmall: estiloTitulo(21, cor: Cores.texto),
      titleLarge: estiloTitulo(19, cor: Cores.texto),
      titleMedium: textos.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall: estiloRotulo(15, cor: Cores.texto, espaco: 0.5),
      bodyLarge: textos.bodyLarge?.copyWith(fontSize: 16, height: 1.35),
      bodyMedium: textos.bodyMedium?.copyWith(fontSize: 14.5, height: 1.35),
      bodySmall: textos.bodySmall?.copyWith(fontSize: 12.5, color: Cores.textoFraco),
      labelLarge: estiloRotulo(15.5, cor: Cores.texto, espaco: 0.8),
      labelMedium: estiloRotulo(13.5, cor: Cores.texto, espaco: 0.8),
      labelSmall: estiloRotulo(12, cor: Cores.textoFraco, espaco: 1),
    ),
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values) p: const TransicaoComFundo(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Cores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: estiloTitulo(20, cor: Cores.texto),
    ),
    cardTheme: CardThemeData(
      color: Cores.painel,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Cores.borda),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Cores.painel2,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: estiloTitulo(19, cor: Cores.texto),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: Cores.borda),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Cores.painel2,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Cores.textoFraco.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    ),
    // Campos como no CRIS original: só a linha de baixo.
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      labelStyle: const TextStyle(color: Cores.textoFraco, fontSize: 15),
      floatingLabelStyle: estiloRotulo(15, cor: Cores.destaque, espaco: 0.6),
      hintStyle: TextStyle(color: Cores.textoFraco.withValues(alpha: 0.6)),
      border: linha,
      enabledBorder: linha,
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Cores.destaque, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: botao,
        shape: cantos,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minimumSize: const Size(0, 44),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Cores.painel2,
        foregroundColor: Cores.destaque,
        textStyle: botao,
        shape: cantos,
        minimumSize: const Size(0, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Cores.destaque,
        side: const BorderSide(color: Color(0x2EFFFFFF)),
        textStyle: botao,
        shape: cantos,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: const Size(0, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Cores.destaque,
        textStyle: estiloRotulo(15.5, peso: FontWeight.w600, espaco: 0.6),
        shape: cantos,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Cores.destaque,
      foregroundColor: Cores.sobreDestaque,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 4,
      extendedTextStyle: estiloRotulo(16, peso: FontWeight.w700, espaco: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(estiloRotulo(14.5, espaco: 0.5)),
        side: const WidgetStatePropertyAll(BorderSide(color: Color(0x2EFFFFFF))),
        shape: const WidgetStatePropertyAll(cantos),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Cores.destaque,
      unselectedLabelColor: Cores.textoFraco,
      indicatorColor: Cores.destaque,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: Cores.destaque, width: 2.5),
      ),
      dividerColor: Cores.linha,
      dividerHeight: 1,
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      labelStyle: estiloRotulo(15, peso: FontWeight.w700, espaco: 1.4),
      unselectedLabelStyle: estiloRotulo(15, peso: FontWeight.w600, espaco: 1.4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Color.alphaBlend(Cores.painel2.withValues(alpha: 0.6), Cores.fundo),
      surfaceTintColor: Colors.transparent,
      height: 66,
      indicatorColor: Cores.destaque.withValues(alpha: 0.16),
      indicatorShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Cores.destaque : Cores.textoFraco)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => estiloRotulo(13,
          peso: FontWeight.w600,
          espaco: 1,
          cor: s.contains(WidgetState.selected) ? Cores.destaque : Cores.textoFraco)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: Cores.destaque.withValues(alpha: 0.16),
      selectedIconTheme: IconThemeData(color: Cores.destaque),
      unselectedIconTheme: const IconThemeData(color: Cores.textoFraco),
      selectedLabelTextStyle: estiloRotulo(13, cor: Cores.destaque, espaco: 1),
      unselectedLabelTextStyle: estiloRotulo(13, cor: Cores.textoFraco, espaco: 1),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Cores.painel2,
      selectedColor: Cores.destaque.withValues(alpha: 0.22),
      side: BorderSide(color: Cores.borda),
      labelStyle: estiloRotulo(14, cor: Cores.texto, espaco: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Cores.textoFraco,
      titleTextStyle: const TextStyle(
          fontFamily: Fontes.texto, fontSize: 15.5, fontWeight: FontWeight.w600, color: Cores.texto),
      subtitleTextStyle:
          const TextStyle(fontFamily: Fontes.texto, fontSize: 13.5, color: Cores.textoFraco),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Cores.sobreDestaque : Cores.textoFraco),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Cores.destaque : Cores.painel2),
      trackOutlineColor: WidgetStatePropertyAll(Cores.borda),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Cores.destaque : Colors.transparent),
      checkColor: WidgetStatePropertyAll(Cores.sobreDestaque),
      side: const BorderSide(color: Cores.textoFraco, width: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Cores.painel2,
      contentTextStyle: const TextStyle(fontFamily: Fontes.texto, color: Cores.texto, fontSize: 14.5),
      actionTextColor: Cores.destaque,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), side: BorderSide(color: Cores.borda)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Cores.painel2,
      surfaceTintColor: Colors.transparent,
      textStyle: const TextStyle(fontFamily: Fontes.texto, fontSize: 15, color: Cores.texto),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6), side: BorderSide(color: Cores.borda)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Cores.painel2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cores.borda),
      ),
      textStyle: const TextStyle(fontFamily: Fontes.texto, fontSize: 13, color: Cores.texto),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: Cores.destaque),
    dividerTheme: const DividerThemeData(color: Cores.linha, thickness: 1, space: 1),
    dividerColor: Cores.linha,
  );
}
