import '../data/catalogo.dart';
import '../data/models.dart';
import 'dano.dart';
import 'rules.dart';

// Ações das ameaças lidas do texto das fichas: cada ataque e cada habilidade
// vira um botão, com as rolagens, os testes de resistência e as condições
// que o texto menciona.

/// Ordem das seções de ações de uma ameaça.
const tiposAcao = ['Ataque', 'Padrão', 'Movimento', 'Completa', 'Livre', 'Reação', 'Passiva', 'Enigma', 'Outra'];

const _tiposHabilidade = ['Passiva', 'Padrão', 'Movimento', 'Completa', 'Livre', 'Reação'];

/// Perícias que aparecem como teste de resistência ("Vontade DT 43").
const _periciasResistencia = [
  'Fortitude', 'Reflexos', 'Vontade', 'Atletismo', 'Acrobacia', 'Luta', 'Pontaria', 'Intuição',
  'Percepção', 'Diplomacia', 'Enganação', 'Intimidação', 'Ocultismo', 'Investigação', 'Furtividade',
];

/// "3d20+10" -> (3, 10). "−2d20" (pior de 2) -> (0, 0). Texto sem dado -> (1, número).
(int, int) testeDoLivro(dynamic v) {
  final s = asStr(v).replaceAll('−', '-').replaceAll(' ', '');
  final m = RegExp(r'^(-?)(\d*)d20([+-]\d+)?').firstMatch(s);
  if (m == null) return (1, int.tryParse(s) ?? 0);
  final n = int.tryParse(m.group(2)!) ?? 1;
  return (m.group(1) == '-' ? 2 - n : n, int.tryParse(m.group(3) ?? '') ?? 0);
}

enum PapelRolagem { dano, cura, teste, outra }

/// Uma rolagem achada no texto: dano (com o tipo, se houver), cura, teste
/// de d20 ou outra (bônus, duração...).
class ParteRolagem {
  final String expressao;
  final String tipoDano;
  final PapelRolagem papel;
  const ParteRolagem(this.expressao, this.tipoDano, this.papel);

  String get rotulo => switch (papel) {
        PapelRolagem.dano => tipoDano.isEmpty
            ? '$expressao de dano'
            : '$expressao ${tipoDanoPorId(tipoDano)?.nome.toLowerCase() ?? tipoDano}',
        PapelRolagem.cura => 'cura $expressao',
        PapelRolagem.teste => 'teste $expressao',
        PapelRolagem.outra => expressao,
      };
}

/// Teste de resistência que a ação pede ao alvo.
class Resistencia {
  final String pericia;
  final int dt;
  /// Passar reduz o dano à metade.
  final bool metade;
  /// Passar evita o efeito (e o dano, quando não é só metade).
  final bool evita;
  const Resistencia(this.pericia, this.dt, {this.metade = false, this.evita = false});

  String get rotulo => '$pericia DT $dt${metade ? ' (metade)' : evita ? ' (evita)' : ''}';
}

/// Um ataque ou uma habilidade de ameaça, pronto para virar botão.
class AcaoAmeaca {
  final String tipo;
  final String nome;
  final String texto;
  // só nos ataques
  final String alcance;
  final int dados;
  final int bonus;
  final String critico;
  /// Ataques por ação ("Corpo a corpo x2").
  final int golpes;
  // o que o texto (ou o dano do ataque) traz
  final List<ParteRolagem> rolagens;
  /// Tipos de dano possíveis (um ataque pode ser "impacto, perfuração ou Sangue").
  final List<String> tiposDano;
  final List<Resistencia> resistencias;
  final List<String> condicoes;
  final String usos;

  const AcaoAmeaca({
    required this.tipo,
    required this.nome,
    this.texto = '',
    this.alcance = '',
    this.dados = 1,
    this.bonus = 0,
    this.critico = '20/x2',
    this.golpes = 1,
    this.rolagens = const [],
    this.tiposDano = const [],
    this.resistencias = const [],
    this.condicoes = const [],
    this.usos = '',
  });

  bool get ataque => tipo == 'Ataque';
  bool get passiva => tipo == 'Passiva' || tipo == 'Enigma';

  /// Uma coisa só a rolar (no máximo duas rolagens e um teste de
  /// resistência): o botão já rola tudo. Com opções ("rola 1d6: 1–2 ...",
  /// listas de rituais), cada rolagem fica num botão próprio.
  bool get direta =>
      ataque ||
      (resistencias.length <= 1 &&
          rolagens.length <= 2 &&
          rolagens.every((r) => r.papel != PapelRolagem.outra));

  String get teste => '${dados}d20${bonus < 0 ? '−${-bonus}' : '+$bonus'}';

  /// O que a ação rola e pede, numa linha (para o botão e o resumo).
  String get mecanica => [
        if (ataque) ...[
          teste,
          for (final r in rolagens) r.rotulo,
          if (critico.isNotEmpty) 'crítico $critico',
          if (golpes > 1) '$golpes ataques',
        ] else ...[
          for (final r in rolagens.take(3)) r.rotulo,
          if (rolagens.length > 3) '…',
          for (final r in resistencias.take(2)) r.rotulo,
        ],
        if (usos.isNotEmpty) usos,
      ].join(' · ');

  /// Ataque: teste, crítico e o texto do dano ("4d10+30 impacto ou Sangue").
  factory AcaoAmeaca.deAtaque({
    required String nome,
    String alcance = '',
    required int dados,
    required int bonus,
    String critico = '20/x2',
    required String dano,
  }) {
    final partes = _rolagens(dano, ataque: true);
    final golpes = RegExp(r'x\s*(\d+)').firstMatch(alcance);
    return AcaoAmeaca(
      tipo: 'Ataque',
      nome: nome,
      texto: [if (alcance.isNotEmpty) alcance, dano].join(' · '),
      alcance: alcance,
      dados: dados,
      bonus: bonus,
      critico: critico.isEmpty ? '20/x2' : critico,
      golpes: golpes == null ? 1 : asInt(golpes.group(1), 1).clamp(1, 6),
      rolagens: partes,
      tiposDano: _tiposNoTexto(dano),
      condicoes: condicoesNoTexto(dano),
    );
  }

  /// Habilidade: as rolagens, resistências, condições e usos vêm do texto.
  factory AcaoAmeaca.deHabilidade({required String tipo, required String nome, required String texto}) =>
      AcaoAmeaca(
        tipo: tipo,
        nome: nome,
        texto: texto,
        rolagens: _rolagens(texto),
        resistencias: _resistencias(texto),
        condicoes: condicoesNoTexto(texto),
        usos: _usos(texto),
      );
}

/// Todas as ações de uma ameaça da mesa: o primeiro ataque (campos próprios)
/// e cada linha do campo de habilidades, no formato em que a ameaça entra
/// do livro ("Padrão — Nome: resumo", "Ataque: ...") ou escrita à mão.
List<AcaoAmeaca> acoesDaAmeaca(Map<String, dynamic> d) {
  final livro = Catalogo.instance.porRef('ameacas:${asStr(d['ref'])}');
  final primeiro = asMapList(livro?['ataques']).firstOrNull;
  final l = <AcaoAmeaca>[
    if (asStr(d['ataqueNome']).isNotEmpty || asStr(d['ataqueDano']).isNotEmpty)
      AcaoAmeaca.deAtaque(
        nome: asStr(d['ataqueNome']).isEmpty ? 'Ataque' : asStr(d['ataqueNome']),
        alcance: asStr(d['ataqueAlcance']).isNotEmpty ? asStr(d['ataqueAlcance']) : asStr(primeiro?['alcance']),
        dados: asInt(d['ataqueDados'], 1),
        bonus: asInt(d['ataqueBonus']),
        critico: asStr(d['ataqueCritico']),
        dano: asStr(d['ataqueDano']).isEmpty ? '1d6' : asStr(d['ataqueDano']),
      ),
  ];
  for (final linha in asStr(d['habilidades']).split('\n')) {
    final a = acaoDaLinha(linha);
    if (a != null) l.add(a);
  }
  return l;
}

// o alcance pode ter parênteses dentro: "Corpo a corpo (4,5m)"
final _linhaAtaque =
    RegExp(r'^Ataque:\s*(.+?)\s*\(((?:[^()]|\([^()]*\))*)\):\s*(.+?)(?:,\s*crítico\s*([^•]+?))?\s*•\s*(.+)$');
final _linhaHabilidade = RegExp('^(${_tiposHabilidade.join('|')})\\s*[—–-]\\s*(.+?):\\s+(.+)\$');

/// Uma linha do campo de habilidades como ação (null se estiver vazia).
AcaoAmeaca? acaoDaLinha(String linha) {
  final s = linha.trim();
  if (s.isEmpty) return null;
  final atk = _linhaAtaque.firstMatch(s);
  if (atk != null) {
    final t = testeDoLivro(atk.group(3));
    return AcaoAmeaca.deAtaque(
      nome: atk.group(1)!,
      alcance: atk.group(2)!,
      dados: t.$1,
      bonus: t.$2,
      critico: (atk.group(4) ?? '').trim(),
      dano: atk.group(5)!,
    );
  }
  final hab = _linhaHabilidade.firstMatch(s);
  if (hab != null) {
    return AcaoAmeaca.deHabilidade(tipo: hab.group(1)!, nome: hab.group(2)!, texto: hab.group(3)!);
  }
  if (s.startsWith('Enigma de Medo:')) {
    return AcaoAmeaca.deHabilidade(tipo: 'Enigma', nome: 'Enigma de Medo', texto: s.substring(15).trim());
  }
  // escrita à mão: "Nome: o que faz", ou só o texto
  final dois = s.indexOf(':');
  final nome = dois > 0 && dois <= 48 ? s.substring(0, dois).trim() : '';
  return AcaoAmeaca.deHabilidade(
    tipo: 'Outra',
    nome: nome.isEmpty ? (s.length > 40 ? '${s.substring(0, 38)}…' : s) : nome,
    texto: nome.isEmpty ? s : s.substring(dois + 1).trim(),
  );
}

// ---------------- leitura do texto ----------------

// o sinal na frente marca bônus ou penalidade ("+1d6 em ataques", "−1d20")
final _dado = RegExp(r'([+-]?)(\d+)d(\d+)((?:\s*[+-]\s*\d+(?:d\d+)?)*)');

String _normal(String t) => t.replaceAll('−', '-').replaceAll('–', '-');

/// Tipos de dano citados no texto, na ordem em que aparecem.
List<String> _tiposNoTexto(String texto) {
  final t = semAcento(_normal(texto).toLowerCase());
  final achados = <(int, String)>[];
  for (final d in tiposDano) {
    final i = t.indexOf(semAcento(d.nome.toLowerCase()));
    if (i >= 0) achados.add((i, d.id));
  }
  for (final (raiz, id) in const [('eletric', 'eletricidade'), ('acido', 'quimico'), ('veneno', 'quimico')]) {
    final i = t.indexOf(raiz);
    if (i >= 0 && !achados.any((a) => a.$2 == id)) achados.add((i, id));
  }
  achados.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final a in achados) a.$2];
}

/// Rolagens do texto. Num ataque, todo dado é dano.
List<ParteRolagem> _rolagens(String texto, {bool ataque = false}) {
  final t = _normal(texto);
  final ms = _dado.allMatches(t).toList();
  final l = <ParteRolagem>[];
  for (var i = 0; i < ms.length; i++) {
    final m = ms[i];
    final expressao = m.group(0)!.replaceAll(' ', '');
    // o que vem depois, até o próximo dado ou o fim da frase
    final fim = i + 1 < ms.length ? ms[i + 1].start : t.length;
    var depois = t.substring(m.end, fim);
    final corte = depois.indexOf(RegExp(r'[.;()]'));
    if (corte >= 0) depois = depois.substring(0, corte);
    if (depois.length > 40) depois = depois.substring(0, 40);
    final antes = semAcento(t.substring(m.start < 28 ? 0 : m.start - 28, m.start).toLowerCase());
    final tipos = _tiposNoTexto(depois);
    final faces = asInt(m.group(3));
    final modificador = m.group(1)!.isNotEmpty;
    final PapelRolagem papel;
    var tipo = tipos.isEmpty ? '' : tipos.first;
    if (ataque) {
      papel = PapelRolagem.dano;
    } else if (RegExp(r'\b(cura|curam|recupera|recuperam)\b').hasMatch(antes)) {
      papel = PapelRolagem.cura;
      tipo = '';
    } else if (tipo.isNotEmpty || semAcento(depois.toLowerCase()).contains('dano')) {
      papel = PapelRolagem.dano;
    } else if (antes.contains('dano') && _tiposNoTexto(antes).isNotEmpty) {
      papel = PapelRolagem.dano;
      tipo = _tiposNoTexto(antes).last;
    } else if (faces == 20 && !modificador) {
      papel = PapelRolagem.teste;
    } else {
      papel = PapelRolagem.outra;
    }
    l.add(ParteRolagem(expressao, tipo, papel));
  }
  return l;
}

final _resistencia = RegExp('(${_periciasResistencia.join('|')})\\s*\\(?\\s*DT\\s*(\\d+)');

List<Resistencia> _resistencias(String texto) {
  final t = _normal(texto);
  final l = <Resistencia>[];
  for (final m in _resistencia.allMatches(t)) {
    var depois = t.substring(m.end);
    final corte = depois.indexOf(RegExp(r'[);.]'));
    if (corte >= 0) depois = depois.substring(0, corte);
    final d = semAcento(depois.toLowerCase());
    final metade = d.contains('metade');
    final evita = RegExp(r'\b(evita|evitam|anula|nega)\b').hasMatch(d) || RegExp(r'^\s*ou\b').hasMatch(d);
    final r = Resistencia(m.group(1)!, asInt(m.group(2)), metade: metade, evita: evita);
    if (!l.any((x) => x.pericia == r.pericia && x.dt == r.dt)) l.add(r);
  }
  return l;
}

/// Condições citadas no texto, com o nome como está no catálogo.
List<String> condicoesNoTexto(String texto) {
  final t = semAcento(texto.toLowerCase());
  final l = <String>[];
  for (final nome in nomesCondicoes()) {
    final n = semAcento(nome.toLowerCase());
    final padrao = n.endsWith('o')
        ? '${n.substring(0, n.length - 1)}(o|a|os|as)'
        : n.endsWith('el')
            ? '${n.substring(0, n.length - 2)}(el|eis)'
            : '${RegExp.escape(n)}s?';
    if (RegExp('\\b$padrao\\b').hasMatch(t)) l.add(nome);
  }
  return l;
}

String _usos(String texto) {
  final t = semAcento(texto.toLowerCase());
  final m = RegExp(r'\b(\d+|uma)\s*(x|vez|vezes)\s*por\s*(rodada|cena|turno|dia|missao|interludio|alvo)').firstMatch(t);
  if (m == null) return '';
  final n = m.group(1) == 'uma' ? '1' : m.group(1);
  final quando = {'missao': 'missão', 'interludio': 'interlúdio'}[m.group(3)] ?? m.group(3);
  return '${n}x por $quando';
}
