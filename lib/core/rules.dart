import '../data/models.dart';

/// Tudo que e "regra do livro" fica aqui e pode ser sobrescrito por campanha
/// (aba Regras do mestre). Confira os numeros no seu exemplar do livro.

const atributosChaves = ['agi', 'for', 'int', 'pre', 'vig'];
const atributosNomes = {
  'agi': 'Agilidade',
  'for': 'Força',
  'int': 'Intelecto',
  'pre': 'Presença',
  'vig': 'Vigor',
};
const atributosSigla = {
  'agi': 'AGI',
  'for': 'FOR',
  'int': 'INT',
  'pre': 'PRE',
  'vig': 'VIG',
};

class PericiaDef {
  final String nome;
  final String attr;
  final bool soTreinada;
  final bool carga;
  const PericiaDef(this.nome, this.attr,
      {this.soTreinada = false, this.carga = false});
}

const periciasDef = <PericiaDef>[
  PericiaDef('Acrobacia', 'agi', carga: true),
  PericiaDef('Adestramento', 'pre', soTreinada: true),
  PericiaDef('Artes', 'pre', soTreinada: true),
  PericiaDef('Atletismo', 'for'),
  PericiaDef('Atualidades', 'int'),
  PericiaDef('Ciências', 'int', soTreinada: true),
  PericiaDef('Crime', 'agi', soTreinada: true, carga: true),
  PericiaDef('Diplomacia', 'pre'),
  PericiaDef('Enganação', 'pre'),
  PericiaDef('Fortitude', 'vig'),
  PericiaDef('Furtividade', 'agi', carga: true),
  PericiaDef('Iniciativa', 'agi'),
  PericiaDef('Intimidação', 'pre'),
  PericiaDef('Intuição', 'pre'),
  PericiaDef('Investigação', 'int'),
  PericiaDef('Luta', 'for'),
  PericiaDef('Medicina', 'int'),
  PericiaDef('Ocultismo', 'int', soTreinada: true),
  PericiaDef('Percepção', 'pre'),
  PericiaDef('Pilotagem', 'agi', soTreinada: true),
  PericiaDef('Pontaria', 'agi'),
  PericiaDef('Profissão', 'int', soTreinada: true),
  PericiaDef('Reflexos', 'agi'),
  PericiaDef('Religião', 'pre', soTreinada: true),
  PericiaDef('Sobrevivência', 'int'),
  PericiaDef('Tática', 'int', soTreinada: true),
  PericiaDef('Tecnologia', 'int', soTreinada: true),
  PericiaDef('Vontade', 'pre'),
];

PericiaDef? periciaPorNome(String n) {
  for (final p in periciasDef) {
    if (p.nome == n) return p;
  }
  return null;
}

const grausTreino = {0: 'Destreinado', 5: 'Treinado', 10: 'Veterano', 15: 'Expert'};

const classes = ['Combatente', 'Especialista', 'Ocultista'];

/// Constantes padrao por classe (livro basico v1.x).
/// pd* = Pontos de Determinacao (regra opcional do Sobrevivendo ao Horror) -
/// valores editaveis pelo mestre.
const classesPadrao = <String, Map<String, int>>{
  'Combatente': {
    'pvIni': 20, 'pvNex': 4, 'peIni': 2, 'peNex': 2, 'sanIni': 12, 'sanNex': 3,
    'pdIni': 6, 'pdNex': 3, 'pericias': 1,
  },
  'Especialista': {
    'pvIni': 16, 'pvNex': 3, 'peIni': 3, 'peNex': 3, 'sanIni': 16, 'sanNex': 4,
    'pdIni': 8, 'pdNex': 4, 'pericias': 7,
  },
  'Ocultista': {
    'pvIni': 12, 'pvNex': 2, 'peIni': 4, 'peNex': 4, 'sanIni': 20, 'sanNex': 5,
    'pdIni': 10, 'pdNex': 5, 'pericias': 3,
  },
};

const classesPericiasTexto = {
  'Combatente': 'Luta ou Pontaria; Fortitude ou Reflexos; + 1 + INT à escolha',
  'Especialista': '7 + INT à escolha',
  'Ocultista': 'Ocultismo e Vontade; + 3 + INT à escolha',
};

const trilhas = <String, List<String>>{
  'Combatente': [
    'Aniquilador', 'Comandante de Campo', 'Guerreiro', 'Operações Especiais',
    'Tropa de Choque', 'Agente Secreto', 'Caçador', 'Monstruoso',
  ],
  'Especialista': [
    'Atirador de Elite', 'Infiltrador', 'Médico de Campo', 'Negociador',
    'Técnico', 'Bibliotecário', 'Perseverante', 'Muambeiro',
  ],
  'Ocultista': [
    'Conduíte', 'Flagelador', 'Graduado', 'Intuitivo', 'Lâmina Paranormal',
    'Exorcista', 'Possuído', 'Parapsicólogo',
  ],
};

/// Origens do livro basico com as duas pericias treinadas.
const origens = <String, List<String>>{
  'Acadêmico': ['Ciências', 'Investigação'],
  'Agente de Saúde': ['Intuição', 'Medicina'],
  'Amnésico': [],
  'Artista': ['Artes', 'Enganação'],
  'Atleta': ['Acrobacia', 'Atletismo'],
  'Chef': ['Fortitude', 'Profissão'],
  'Criminoso': ['Crime', 'Furtividade'],
  'Cultista Arrependido': ['Ocultismo', 'Religião'],
  'Desgarrado': ['Fortitude', 'Sobrevivência'],
  'Engenheiro': ['Profissão', 'Tecnologia'],
  'Executivo': ['Diplomacia', 'Profissão'],
  'Investigador': ['Investigação', 'Percepção'],
  'Lutador': ['Luta', 'Reflexos'],
  'Magnata': ['Diplomacia', 'Pilotagem'],
  'Mercenário': ['Iniciativa', 'Intimidação'],
  'Militar': ['Pontaria', 'Tática'],
  'Operário': ['Fortitude', 'Profissão'],
  'Policial': ['Percepção', 'Pontaria'],
  'Religioso': ['Religião', 'Vontade'],
  'Servidor Público': ['Intuição', 'Vontade'],
  'Teórico da Conspiração': ['Investigação', 'Ocultismo'],
  'T.I.': ['Investigação', 'Tecnologia'],
  'Trabalhador Rural': ['Adestramento', 'Sobrevivência'],
  'Trambiqueiro': ['Crime', 'Enganação'],
  'Universitário': ['Atualidades', 'Investigação'],
  'Vítima': ['Reflexos', 'Vontade'],
};

const elementos = ['Sangue', 'Morte', 'Conhecimento', 'Energia', 'Medo'];

const condicoesLista = [
  'Abalado', 'Agarrado', 'Alquebrado', 'Apavorado', 'Atordoado', 'Caído',
  'Cego', 'Confuso', 'Debilitado', 'Desprevenido', 'Enjoado', 'Enlouquecendo',
  'Enredado', 'Envenenado', 'Esmorecido', 'Exausto', 'Fatigado', 'Fraco',
  'Frustrado', 'Imóvel', 'Inconsciente', 'Indefeso', 'Lento', 'Machucado',
  'Morrendo', 'Ofuscado', 'Paralisado', 'Pasmo', 'Sangrando', 'Surdo',
  'Surpreendido', 'Vulnerável',
];

const nexValores = [
  5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 99
];

class Patente {
  final int pp;
  final String nome;
  final String credito;
  final List<int> limites; // categorias I..IV
  const Patente(this.pp, this.nome, this.credito, this.limites);
}

const patentes = [
  Patente(0, 'Recruta', 'Baixo', [2, 0, 0, 0]),
  Patente(20, 'Operador', 'Médio', [3, 1, 0, 0]),
  Patente(50, 'Agente Especial', 'Médio', [3, 2, 1, 0]),
  Patente(100, 'Oficial de Operações', 'Alto', [3, 3, 2, 1]),
  Patente(200, 'Agente de Elite', 'Ilimitado', [3, 3, 3, 2]),
];

Patente patentePorPP(int pp) {
  var p = patentes.first;
  for (final x in patentes) {
    if (pp >= x.pp) p = x;
  }
  return p;
}

const custoRitualPadrao = {1: 1, 2: 3, 3: 6, 4: 10};

const eventosPP = <String, int>{
  'Solução do caso': 10,
  'Pista adicional': 2,
  'Morte de inocente': -2,
  'Morte de membro do grupo': -5,
};

Map<String, dynamic> novaFicha(String ownerUid, String jogador) => {
      'ownerUid': ownerUid,
      'editors': [ownerUid],
      'campaignId': null,
      'nome': 'Novo agente',
      'jogador': jogador,
      'classe': 'Combatente',
      'origem': '',
      'trilha': '',
      'nex': 5,
      'pp': 0,
      'atributos': {'agi': 1, 'for': 1, 'int': 1, 'pre': 1, 'vig': 1},
      'pericias': <String, dynamic>{},
      'pvAtual': 21,
      'peAtual': 3,
      'sanAtual': 12,
      'pdAtual': 7,
      'bonus': <String, dynamic>{},
      'condicoes': <String>[],
      'inventario': <dynamic>[],
      'rituais': <dynamic>[],
      'poderes': <dynamic>[],
      'notas': '',
      'aparencia': '',
      'historia': '',
      'criadoEm': DateTime.now().millisecondsSinceEpoch,
    };

/// Calculos automaticos da ficha considerando as regras da campanha.
class Calc {
  final Ficha f;
  final Map<String, dynamic> regras;
  Calc(this.f, [Map<String, dynamic>? regras]) : regras = regras ?? const {};

  bool get determinacao => asBool(regras['determinacao']);

  Map<String, int> get _cls {
    final base = Map<String, int>.from(
        classesPadrao[f.classe] ?? classesPadrao['Combatente']!);
    final over = asMap(asMap(regras['classes'])[f.classe]);
    over.forEach((k, v) => base[k] = asInt(v, base[k] ?? 0));
    return base;
  }

  int c(String k) => _cls[k] ?? 0;

  /// 5% = 1 ... 95% = 19, 99% = 20
  int get nivel {
    final n = f.nex;
    if (n >= 99) return 20;
    return (n ~/ 5).clamp(1, 20);
  }

  int get agi => f.attr('agi');
  int get forca => f.attr('for');
  int get intel => f.attr('int');
  int get pre => f.attr('pre');
  int get vig => f.attr('vig');

  int get pvMax =>
      c('pvIni') + vig + (nivel - 1) * (c('pvNex') + vig) + f.b('pv');
  int get peMax =>
      c('peIni') + pre + (nivel - 1) * (c('peNex') + pre) + f.b('pe');
  int get sanMax => c('sanIni') + (nivel - 1) * c('sanNex') + f.b('san');
  int get pdMax =>
      c('pdIni') + pre + (nivel - 1) * (c('pdNex') + pre) + f.b('pd');

  int get limitePE => nivel + f.b('limitePE');

  int get cargaMax {
    if (forca <= 0) return 2 + f.b('carga');
    final base = asInt(regras['cargaBase'], 0);
    final por = asInt(regras['cargaPorFor'], 5);
    return base + por * forca + f.b('carga');
  }

  int get cargaAtual {
    var t = 0;
    for (final i in f.inventario) {
      t += asInt(i['espacos'], 1) * asInt(i['qtd'], 1);
    }
    return t;
  }

  bool get sobrecarregado => cargaAtual > cargaMax;

  int get defesa {
    var d = 10 + agi + f.b('defesa');
    for (final i in f.inventario) {
      if (asStr(i['tipo']) == 'protecao' && asBool(i['equipado'], true)) {
        d += asInt(i['defesa']);
      }
    }
    if (sobrecarregado) d -= 5;
    return d;
  }

  int get deslocamento {
    final base = 9 + f.b('deslocamento');
    return sobrecarregado ? base - 3 : base;
  }

  int bonusPericia(String nome) {
    final def = periciaPorNome(nome);
    var b = f.grau(nome) + f.bonusPericia(nome);
    if (def != null && def.carga && sobrecarregado) b -= 5;
    return b;
  }

  int dadosPericia(String nome) {
    final def = periciaPorNome(nome);
    return f.attr(def?.attr ?? 'agi');
  }

  int get dtRitual => 10 + limitePE + pre + f.b('dtRitual');

  int custoRitual(int circulo) {
    final over = asMap(regras['custoRitual']);
    return asInt(over['$circulo'], custoRitualPadrao[circulo] ?? 1);
  }

  Patente get patente => patentePorPP(f.pp);

  /// itens usados por categoria (1..4)
  List<int> get itensPorCategoria {
    final r = [0, 0, 0, 0];
    for (final i in f.inventario) {
      final cat = asInt(i['categoria']);
      if (cat >= 1 && cat <= 4) r[cat - 1] += asInt(i['qtd'], 1);
    }
    return r;
  }

  int get periciasTreinadasPermitidas => c('pericias') + intel;

  /// Validacao dos atributos na criacao (4 pontos, max 3, 0 devolve 1 ponto)
  int get pontosAtributoGastos {
    var t = 0;
    for (final k in atributosChaves) {
      t += f.attr(k) - 1;
    }
    return t;
  }
}
