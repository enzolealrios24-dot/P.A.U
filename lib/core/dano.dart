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
