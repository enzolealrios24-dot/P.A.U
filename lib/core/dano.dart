/// Tipos de dano do livro (OPRPG p. 82) e as regras de resistência a dano
/// (RD, p. 180 e 312).
class TipoDano {
  final String id;
  final String nome;
  final String grupo;
  const TipoDano(this.id, this.nome, this.grupo);
}

/// Grupos na ordem em que aparecem na ficha.
const gruposDano = ['Físico', 'Outros', 'Paranormal', 'Mente'];

const tiposDano = [
  TipoDano('balistico', 'Balístico', 'Físico'),
  TipoDano('corte', 'Corte', 'Físico'),
  TipoDano('impacto', 'Impacto', 'Físico'),
  TipoDano('perfuracao', 'Perfuração', 'Físico'),
  TipoDano('eletricidade', 'Eletricidade', 'Outros'),
  TipoDano('fogo', 'Fogo', 'Outros'),
  TipoDano('frio', 'Frio', 'Outros'),
  TipoDano('quimico', 'Químico', 'Outros'),
  TipoDano('conhecimento', 'Conhecimento', 'Paranormal'),
  TipoDano('energia', 'Energia', 'Paranormal'),
  TipoDano('medo', 'Medo', 'Paranormal'),
  TipoDano('morte', 'Morte', 'Paranormal'),
  TipoDano('sangue', 'Sangue', 'Paranormal'),
  TipoDano('mental', 'Mental', 'Mente'),
];

/// Resistências que valem para vários tipos de uma vez.
const rdGeral = TipoDano('geral', 'Geral', 'Geral');
const rdParanormal = TipoDano('paranormal', 'Paranormal', 'Geral');

/// Os quatro tipos físicos (proteções e rituais como Armadura de Sangue).
const tiposFisicos = ['balistico', 'corte', 'impacto', 'perfuracao'];

/// Subtipos do dano paranormal (um por elemento).
const tiposParanormais = ['conhecimento', 'energia', 'medo', 'morte', 'sangue'];

TipoDano? tipoDanoPorId(String id) {
  if (id == rdGeral.id) return rdGeral;
  if (id == rdParanormal.id) return rdParanormal;
  for (final t in tiposDano) {
    if (t.id == id) return t;
  }
  return null;
}

/// Acha o tipo pelo nome escrito numa arma ou ritual ("Corte", "perfuração",
/// "Energia"...). Devolve o id ou '' se não reconhecer.
String tipoDanoDoTexto(String texto) {
  final t = semAcento(texto.toLowerCase());
  for (final d in tiposDano) {
    if (t.contains(semAcento(d.nome.toLowerCase()))) return d.id;
  }
  if (t.contains('eletric')) return 'eletricidade';
  if (t.contains('acido') || t.contains('veneno')) return 'quimico';
  return '';
}

/// Tira os acentos das letras minúsculas, para comparar textos dos livros.
String semAcento(String s) {
  const de = 'áàâãéêíóôõúç';
  const para = 'aaaaeeiooouc';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : para[i]);
  }
  return b.toString();
}

/// Dano depois da resistência. Metade (teste de resistência) vem antes da RD,
/// com arredondamento para baixo, e o dano nunca fica negativo.
int danoFinal(int dano, int rd, {bool metade = false}) {
  final base = metade ? dano ~/ 2 : dano;
  final r = base - rd;
  return r < 0 ? 0 : r;
}

/// Todos os tipos de dano citados num texto, na ordem ("Corte ou
/// perfuração" dá os dois).
List<String> tiposDanoDoTexto(String texto) => [
      for (final parte in texto.split(RegExp(r',|\s+(?:e|ou)\s+|/')))
        if (tipoDanoDoTexto(parte) case final t when t.isNotEmpty) t,
    ];

/// Resistências de uma ameaça, lidas do texto da ficha dela, como os livros
/// escrevem: "Resistências: Balístico, corte e perfuração 5; Sangue 10 •
/// Imunidades: Fogo • Vulnerabilidades: Energia". Texto sem rótulo conta
/// como resistência.
class ResistenciasAmeaca {
  /// RD por tipo; 'geral' vale para todos e 'paranormal' para os elementos.
  final Map<String, int> rd;
  /// Tipos que a RD geral não reduz ("RD 10/Morte": tudo, menos Morte).
  final Set<String> rdExceto;
  final Set<String> imune;
  /// Imune a todo dano, menos os tipos em [imune] (que aqui são exceções).
  final bool imuneATudo;
  final Set<String> vulneravel;
  const ResistenciasAmeaca({
    this.rd = const {},
    this.rdExceto = const {},
    this.imune = const {},
    this.imuneATudo = false,
    this.vulneravel = const {},
  });

  factory ResistenciasAmeaca.doTexto(String texto) {
    final rd = <String, int>{};
    final rdExceto = <String>{};
    final imune = <String>{};
    var tudo = false;
    final vulneravel = <String>{};
    for (final secao in texto.split('•')) {
      final s = semAcento(secao.toLowerCase()).trim();
      final i = s.indexOf(':');
      final rotulo = i < 0 ? '' : s.substring(0, i);
      final corpo = i < 0 ? s : s.substring(i + 1);
      if (rotulo.startsWith('imun')) {
        // "Dano (exceto fogo)": imune a tudo menos fogo; "dano e efeitos de
        // Morte": só o dano de Morte
        final exceto = RegExp(r'\(exceto([^)]*)\)').firstMatch(corpo);
        final resto = corpo.replaceAll(RegExp(r'\([^)]*\)'), '');
        final itens = resto.split(RegExp(r',|\s+e\s+')).map((x) => x.trim()).toList();
        final deUmTipo = RegExp(r'\bde\s+\w+').allMatches(resto).any((m) => tipoDanoDoTexto(m[0]!).isNotEmpty);
        for (final item in itens) {
          final t = tipoDanoDoTexto(item);
          if (t.isNotEmpty) {
            imune.add(t);
          } else if (item.startsWith('dano') && !deUmTipo) {
            tudo = true;
          }
        }
        if (tudo) {
          imune
            ..clear()
            ..addAll(tiposDanoDoTexto(exceto?[1] ?? ''));
        }
      } else if (rotulo.startsWith('vulner')) {
        vulneravel.addAll(tiposDanoDoTexto(corpo));
      } else {
        for (final grupo in corpo.split(';')) {
          final barra = RegExp(r'^\s*(?:rd|dano)\s*(\d+)\s*/(.+)$').firstMatch(grupo);
          if (barra != null) {
            rd[rdGeral.id] = int.parse(barra[1]!);
            rdExceto.addAll(tiposDanoDoTexto(barra[2]!));
            continue;
          }
          final pendentes = <String>[];
          for (final item in grupo.split(RegExp(r',|\s+e\s+'))) {
            final m = RegExp(r'^(.*?)(\d+)\s*$').firstMatch(item.trim());
            final nome = (m?[1] ?? item).trim();
            final t = switch (nome) {
              'dano' || 'rd' || 'geral' || '' => rdGeral.id,
              'paranormal' => rdParanormal.id,
              _ => tipoDanoDoTexto(nome),
            };
            if (t.isNotEmpty && (nome.isNotEmpty || m != null)) pendentes.add(t);
            if (m != null) {
              for (final p in pendentes) {
                rd[p] = int.parse(m[2]!);
              }
              pendentes.clear();
            }
          }
        }
      }
    }
    return ResistenciasAmeaca(rd: rd, rdExceto: rdExceto, imune: imune, imuneATudo: tudo, vulneravel: vulneravel);
  }

  bool imuneA(String tipo) => imuneATudo ? !imune.contains(tipo) : imune.contains(tipo);

  int rdContra(String tipo) {
    var t = (rdExceto.contains(tipo) ? 0 : rd[rdGeral.id] ?? 0) + (rd[tipo] ?? 0);
    if (tiposParanormais.contains(tipo)) t += rd[rdParanormal.id] ?? 0;
    return t;
  }

  /// Dano que a ameaça sofre: metade (passou na resistência), o dobro se for
  /// vulnerável, menos a RD; imune não sofre nada.
  int danoSofrido(int dano, String tipo, {bool metade = false}) {
    if (imuneA(tipo)) return 0;
    final base = metade ? dano ~/ 2 : dano;
    return danoFinal(vulneravel.contains(tipo) ? base * 2 : base, rdContra(tipo));
  }
}
