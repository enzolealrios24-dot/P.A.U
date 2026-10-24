import '../data/catalogo.dart';
import '../data/models.dart';
import 'dano.dart';

/// Tudo que e "regra do livro" fica aqui ou nos dados de assets/data, e pode
/// ser sobrescrito por campanha (aba Regras do mestre).

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

const periciasResistencia = ['Fortitude', 'Reflexos', 'Vontade'];

PericiaDef? periciaPorNome(String n) {
  for (final p in periciasDef) {
    if (p.nome == n) return p;
  }
  return null;
}

const grausTreino = {0: 'Destreinado', 5: 'Treinado', 10: 'Veterano', 15: 'Expert'};

/// Valores de reserva caso os dados dos livros nao carreguem.
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

/// Nomes das classes disponiveis (livros carregados).
List<String> nomesClasses() {
  final l = [for (final c in Catalogo.instance.classes) asStr(c['nome'])];
  return l.isEmpty ? classesPadrao.keys.toList() : l;
}

/// Valores numericos de uma classe no formato pvIni/pvNex/... (para a aba
/// Regras do mestre e para o Calc).
Map<String, int> valoresClasse(String nome) {
  final c = Catalogo.instance.classePorNome(nome);
  if (c == null) {
    return Map<String, int>.from(
        classesPadrao[nome] ?? classesPadrao['Combatente']!);
  }
  int at(String k, int i) {
    final l = c[k];
    return l is List && l.length > i ? asInt(l[i]) : 0;
  }

  return {
    'pvIni': at('pv', 0), 'pvNex': at('pv', 1),
    'peIni': at('pe', 0), 'peNex': at('pe', 1),
    'sanIni': at('san', 0), 'sanNex': at('san', 1),
    'pdIni': at('pd', 0), 'pdNex': at('pd', 1),
    'pericias': asInt(c['periciasLivres']),
  };
}

const elementos = ['Sangue', 'Morte', 'Conhecimento', 'Energia', 'Medo'];
const elementosAfinidade = ['Sangue', 'Morte', 'Conhecimento', 'Energia'];

const condicoesLista = [
  'Abalado', 'Agarrado', 'Alquebrado', 'Apavorado', 'Atordoado', 'Caído',
  'Cego', 'Confuso', 'Debilitado', 'Desprevenido', 'Enjoado', 'Enlouquecendo',
  'Enredado', 'Envenenado', 'Esmorecido', 'Exausto', 'Fatigado', 'Fraco',
  'Frustrado', 'Imóvel', 'Inconsciente', 'Indefeso', 'Lento', 'Machucado',
  'Morrendo', 'Ofuscado', 'Paralisado', 'Pasmo', 'Sangrando', 'Surdo',
  'Surpreendido', 'Vulnerável',
];

List<String> nomesCondicoes() {
  final l = [for (final c in Catalogo.instance.condicoes) asStr(c['nome'])];
  return l.isEmpty ? condicoesLista : l;
}

const nexValores = [
  5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 99
];

const modosProgressao = {
  'nex': 'Somente NEX',
  'nivel': 'Nível + NEX',
  'patente': 'Evolução por patentes',
};

const modosSanidade = {
  'san': 'Com sanidade (PE e SAN)',
  'pd': 'Sem sanidade (PD)',
};

class Patente {
  final int pp;
  final String nome;
  final String credito;
  final List<int> limites; // categorias I..IV
  final int limitePD;
  const Patente(this.pp, this.nome, this.credito, this.limites, this.limitePD);
}

const patentes = [
  Patente(0, 'Recruta', 'Baixo', [2, 0, 0, 0], 1),
  Patente(20, 'Operador', 'Médio', [3, 1, 0, 0], 3),
  Patente(50, 'Agente Especial', 'Médio', [3, 2, 1, 0], 6),
  Patente(100, 'Oficial de Operações', 'Alto', [3, 3, 2, 1], 10),
  Patente(200, 'Agente de Elite', 'Ilimitado', [3, 3, 3, 2], 15),
];

const chavesPatente = ['recruta', 'operador', 'agente_especial', 'oficial', 'elite'];

int indicePatente(int pp) {
  var i = 0;
  for (var k = 0; k < patentes.length; k++) {
    if (pp >= patentes[k].pp) i = k;
  }
  return i;
}

Patente patentePorPP(int pp) => patentes[indicePatente(pp)];

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
      'nivel': 1,
      'estagio': 1,
      'modoSanidade': 'san',
      'modoProgressao': 'nex',
      'afinidade': '',
      'pp': 0,
      'atributos': {'agi': 1, 'for': 1, 'int': 1, 'pre': 1, 'vig': 1},
      'pericias': <String, dynamic>{},
      'pvAtual': 21,
      'peAtual': 3,
      'sanAtual': 12,
      'pdAtual': 7,
      'bonus': <String, dynamic>{},
      'escolhas': <String, dynamic>{},
      'condicoes': <String>[],
      'inventario': <dynamic>[],
      'rituais': <dynamic>[],
      'poderes': <dynamic>[],
      'notas': '',
      'aparencia': '',
      'historia': '',
      'criadoEm': DateTime.now().millisecondsSinceEpoch,
    };

/// Alvos de efeito que pertencem ao item (aplicados ao escolher a
/// modificacao), e nao ao personagem.
const _alvosDeItem = {
  'bonusAtaque', 'bonusDano', 'margem', 'multiplicador', 'dadoDano',
  'danoExtra', 'espacos',
};

/// Calculos automaticos da ficha considerando as regras da campanha.
class Calc {
  final Ficha f;
  final Map<String, dynamic> regras;
  /// Sem os efeitos que dependem de condição ("machucado"...): é com esse
  /// cálculo que se descobre se a condição vale, sem girar em círculo.
  final bool semCondicionais;
  Calc(this.f, [Map<String, dynamic>? regras, this.semCondicionais = false]) : regras = regras ?? const {};

  late final Map<String, dynamic>? classeDados =
      Catalogo.instance.classePorNome(f.classe);
  late final Map<String, dynamic>? origemDados =
      Catalogo.instance.origemPorNome(f.origem);
  late final Map<String, dynamic>? trilhaDados =
      Catalogo.instance.trilhaPorNome(f.trilha, f.classe);

  // ---------------- modos ----------------

  /// Modo de progressao: 'nex', 'nivel' ou 'patente'. A mesa decide, se houver.
  String get modoProgressao {
    final r = asStr(regras['progressao']);
    final m = r.isNotEmpty ? r : f.modoProgressao;
    return modosProgressao.containsKey(m) ? m : 'nex';
  }

  bool get modoNivel => modoProgressao == 'nivel';
  bool get modoPatente => modoProgressao == 'patente';

  /// Jogando sem sanidade (Pontos de Determinacao). A mesa decide, se houver.
  /// A evolucao por patentes sempre usa PD.
  bool get determinacao {
    if (modoPatente) return true;
    if (regras.containsKey('determinacao')) {
      return asBool(regras['determinacao']);
    }
    return f.modoSanidade == 'pd';
  }

  bool get sobrevivente => asInt(classeDados?['estagios']) > 0;
  int get maxEstagio => asInt(classeDados?['estagios'], 5);

  int get indicePat => indicePatente(f.pp);
  Patente get patente => patentes[indicePat];

  /// Nivel efetivo da classe (1..20). Patentes: limite de PD da patente.
  /// Sobrevivente: estagio.
  int get nivel {
    if (sobrevivente) return f.estagio.clamp(1, maxEstagio);
    if (modoPatente) return patente.limitePD;
    if (modoNivel) return f.nivel.clamp(1, 20);
    final n = f.nex;
    if (n >= 99) return 20;
    return (n ~/ 5).clamp(1, 20);
  }

  /// NEX equivalente para habilidades e pre-requisitos de classe.
  int get nexClasse {
    if (sobrevivente) return 0;
    if (modoNivel || modoPatente) return nivel >= 20 ? 99 : nivel * 5;
    return f.nex;
  }

  /// NEX de exposicao paranormal (afinidade, poderes paranormais).
  int get nexExposicao => f.nex;

  /// A habilidade de trilha do NEX indicado ja foi liberada?
  bool trilhaLiberada(int nexHab) {
    if (sobrevivente) return f.estagio >= nexHab;
    if (modoPatente) {
      if (nexHab <= 10) return indicePat >= 2;
      if (nexHab <= 40) return indicePat >= 3;
      return indicePat >= 4;
    }
    return nexHab <= nexClasse;
  }

  // ---------------- efeitos ----------------

  late final Set<String> condicoesAtivas = _expandirCondicoes();

  Set<String> _expandirCondicoes() {
    final cat = Catalogo.instance;
    final r = <String>{};
    void add(String nome) {
      final c = cat.condicao(nome);
      final id = c == null ? Catalogo.normalizar(nome) : asStr(c['id']);
      if (!r.add(id) || c == null) return;
      for (final i in asStrList(c['inclui'])) {
        final ci = cat.condicao(i);
        add(ci == null ? i : asStr(ci['nome']));
      }
    }

    for (final c in f.condicoes) {
      add(c);
    }
    if (r.contains('indefeso')) r.remove('desprevenido');
    return r;
  }

  late final List<Map<String, dynamic>> efeitos = _coletarEfeitos();

  /// Chave de cada habilidade na ficha (a mesma das edições, das escolhas e
  /// dos ativáveis).
  static String chaveOrigem(Map<String, dynamic> o) => 'origem:${asStr(o['nome'])}';
  static String chaveClasse(Map<String, dynamic> cd, Map<String, dynamic> h) =>
      'classe:${asStr(cd['nome'])}:${asStr(h['nome'])}';
  static String chaveTrilha(Map<String, dynamic> t, Map<String, dynamic> h) =>
      'trilha:${asStr(t['nome'])}:${asStr(h['nome'])}';
  static String chavePoder(Map<String, dynamic> p) => 'poder:${asStr(p['id'])}';

  /// Habilidades que a pessoa ocultou: não aparecem e não valem na ficha.
  late final Set<String> ocultas = asStrList(f.d['habilidadesOcultas']).toSet();

  /// Poderes ativáveis ligados agora (até o fim da cena), pela chave.
  late final Set<String> ativos = asStrList(f.d['ativos']).toSet();

  /// O que a pessoa escolheu num poder (perícias, atributo, elemento, ritual).
  List<String> escolhasDe(String chave) => asStrList(asMap(f.d['escolhasPoder'])[chave]);

  /// Custo em PE de um poder ou habilidade ("custo", "custoNex" ou o do
  /// ativável); null quando não custa nada.
  int? custoPoder(Map<String, dynamic> meta) {
    final porNex = asMap(meta['custoNex']);
    if (porNex.isNotEmpty) {
      int? r;
      var melhor = -1;
      porNex.forEach((k, v) {
        final n = int.tryParse(k) ?? 0;
        if (n <= nexClasse && n > melhor) {
          melhor = n;
          r = asInt(v);
        }
      });
      return r ?? asInt(porNex.values.first);
    }
    final a = asMap(meta['ativavel']);
    if (a.isNotEmpty) return asInt(a['custo']);
    return meta['custo'] == null ? null : asInt(meta['custo']);
  }

  /// Habilidade de classe já recebida no NEX (ou estágio) atual?
  bool habilidadeClasseLiberada(Map<String, dynamic> h) =>
      asInt(h['nex']) <= (sobrevivente ? f.estagio : nexClasse);

  List<Map<String, dynamic>> _coletarEfeitos() {
    final cat = Catalogo.instance;
    final l = <Map<String, dynamic>>[];
    // [fonte] fica gravada no efeito para a ficha mostrar de onde ele vem
    void add(dynamic efs, {bool soPersonagem = false, String fonte = ''}) {
      for (final e in asMapList(efs)) {
        if (soPersonagem && _alvosDeItem.contains(asStr(e['alvo']))) continue;
        l.add(fonte.isEmpty ? e : {...e, 'fonte': fonte});
      }
    }

    // Poderes e habilidades: os efeitos fixos, os da afinidade, os do
    // ativável (se estiver ligado) e as escolhas no lugar de "@escolha".
    void addHabilidade(Map<String, dynamic> meta, String chave, String fonte,
        {dynamic base, bool afinidade = false}) {
      if (ocultas.contains(chave)) return;
      final ativavel = asMap(meta['ativavel']);
      final ligado = ativos.contains(chave);
      final efs = [
        ...asMapList(base ?? meta['efeitos']),
        if (afinidade) ...asMapList(meta['efeitosAfinidade']),
        if (ligado) ...asMapList(ativavel['efeitos']),
        if (ligado && afinidade) ...asMapList(ativavel['efeitosAfinidade']),
      ];
      // "escolhaDe": usa a escolha de outra habilidade da mesma trilha
      final de = asStr(meta['escolhaDe']);
      final escolhas = escolhasDe(de.isEmpty ? chave : '${chave.substring(0, chave.lastIndexOf(':') + 1)}$de');

      String irma(String nome) => '${chave.substring(0, chave.lastIndexOf(':') + 1)}$nome';
      for (final e in efs) {
        final seAtivo = asStr(e['seAtivo']);
        if (seAtivo.isNotEmpty && !ativos.contains(irma(seAtivo))) continue;
        for (final x in comEscolhas(e, escolhas)) {
          l.add({...x, 'fonte': fonte, 'chave': chave});
        }
      }
    }

    final o = origemDados;
    if (o != null) {
      final poder = asMap(o['poder']);
      addHabilidade(poder, chaveOrigem(o), asStr(poder['nome'], asStr(o['nome'])),
          base: [...asMapList(o['efeitos']), ...asMapList(poder['efeitos'])]);
    }
    final cd = classeDados;
    if (cd != null) {
      for (final h in asMapList(cd['habilidades'])) {
        if (habilidadeClasseLiberada(h)) addHabilidade(h, chaveClasse(cd, h), asStr(h['nome']));
      }
    }
    final t = trilhaDados;
    if (t != null) {
      for (final h in asMapList(t['habilidades'])) {
        if (trilhaLiberada(asInt(h['nex']))) addHabilidade(h, chaveTrilha(t, h), asStr(h['nome']));
      }
    }
    for (final p in f.poderes) {
      final c = cat.porRef(asStr(p['ref']));
      if (c == null) continue;
      addHabilidade(c, chavePoder(p), asStr(p['nome'], asStr(c['nome'])), afinidade: asBool(p['afinidade']));
    }
    for (final i in f.inventario) {
      if (!asBool(i['equipado'], true)) continue;
      final c = cat.porRef(asStr(i['ref']));
      if (c != null && asStr(c['tipo']) != 'modificacao') {
        add(c['efeitos'], soPersonagem: true, fonte: asStr(i['nome'], asStr(c['nome'])));
      }
      for (final m in asStrList(i['maldicoes'])) {
        final mal = cat.porRef(m);
        add(mal?['efeitos'], soPersonagem: true, fonte: '${asStr(i['nome'])} (${asStr(mal?['nome'])})');
      }
    }
    for (final id in condicoesAtivas) {
      final c = cat.condicao(id);
      add(c?['efeitos'], fonte: asStr(c?['nome']));
    }
    if (modoNivel) {
      for (final a in alteracoesNex) {
        add(a['efeitos'], fonte: asStr(a['nome']));
      }
    }
    // efeitos que só valem numa condição (machucado, com proteção pesada...)
    return [
      for (final e in l)
        if (semCondicionais ? e['se'] == null : condicaoVale(asStr(e['se']))) e,
    ];
  }

  /// Troca "@escolha" pelo que a pessoa escolheu (um efeito por escolha).
  /// Sem escolha feita, o efeito ainda não vale.
  static Iterable<Map<String, dynamic>> comEscolhas(Map<String, dynamic> e, List<String> escolhas) sync* {
    // "seEscolha": só vale se essa opção foi a escolhida (ex.: o elemento)
    final se = e['seEscolha'];
    if (se != null) {
      if (!escolhas.contains(asStr(se))) return;
      e = {...e}..remove('seEscolha');
    }
    final campos = [for (final k in e.keys) if (e[k] == '@escolha') k];
    if (campos.isEmpty) {
      yield e;
      return;
    }
    for (final v in escolhas) {
      yield {...e, for (final k in campos) k: v};
    }
  }

  /// Condições dos efeitos (campo "se").
  bool condicaoVale(String se) => switch (se) {
        '' => true,
        'machucado' => machucado,
        'protecaoPesada' => usandoProtecaoPesada,
        'semProtecao' =>
          !f.inventario.any((i) => asStr(i['tipo']) == 'protecao' && asBool(i['equipado'], true)),
        'protecaoLeve' => f.inventario.any((i) =>
            asStr(i['tipo']) == 'protecao' &&
            asBool(i['equipado'], true) &&
            !protecaoPesada(i) &&
            !asStr(i['nome']).toLowerCase().contains('escudo')),
        // "treinado:Luta+Fortitude": treinado nessas (pelo grau da ficha)
        final s when s.startsWith('treinado:') => s.substring(9).split('+').every((p) => f.grau(p) >= 5),
        _ => false,
      };

  /// Alteracoes de NEX ja recebidas (regra NEX & Experiencia).
  List<Map<String, dynamic>> get alteracoesNex {
    final alt = asMap(asMap(Catalogo.instance.regra('nexExperiencia'))['alteracoes']);
    final r = <Map<String, dynamic>>[];
    for (final a in asMapList(alt['geral'])) {
      if (nexExposicao >= asInt(a['nex'])) r.add(a);
    }
    final af = f.afinidade;
    if (af.isNotEmpty) {
      for (final a in asMapList(alt[af])) {
        if (nexExposicao >= asInt(a['nex'])) r.add({...a, 'elemento': af});
      }
    }
    return r;
  }

  int _mult(Map<String, dynamic> e) {
    final v = asInt(e['valor']);
    switch (asStr(e['por'])) {
      case 'nivel':
        return v * nivel;
      case 'nivelImpar':
        return v * ((nivel + 1) ~/ 2);
      case 'nivelMetade':
        return v * (nivel ~/ 2);
      default:
        return v;
    }
  }

  int soma(String alvo) {
    var t = 0;
    for (final e in efeitos) {
      if (asStr(e['alvo']) != alvo) continue;
      // os que valem só num elemento, ritual, alcance ou tipo de ataque têm
      // contas próprias (dtRitualDe, custoRitualFinal, margemAtaque...)
      if (e['elemento'] != null || e['ritual'] != null || e['alcance'] != null || e['escopo'] != null) {
        continue;
      }
      t += _valorEfeito(e);
    }
    return t;
  }

  bool tem(String alvo) => efeitos.any((e) => asStr(e['alvo']) == alvo);

  // ---------------- atributos ----------------

  int attrBase(String k) => f.attr(k);

  /// Atributo com bonus de itens e efeitos (para testes).
  int attr(String k) {
    var v = f.attr(k);
    for (final e in efeitos) {
      if (asStr(e['alvo']) == 'atributo' && asStr(e['attr']) == k) {
        v += _mult(e);
      }
    }
    return v;
  }

  int get agi => attr('agi');
  int get forca => attr('for');
  int get intel => attr('int');
  int get pre => attr('pre');
  int get vig => attr('vig');

  // ---------------- valores da classe ----------------

  Map<String, int> get _cls {
    final base = valoresClasse(f.classe);
    final over = asMap(asMap(regras['classes'])[f.classe]);
    over.forEach((k, v) => base[k] = asInt(v, base[k] ?? 0));
    return base;
  }

  int c(String k) => _cls[k] ?? 0;

  bool get _somaAttr => asBool(classeDados?['somaAttrPorNivel'], true);

  List<int> _patenteClasse(String k) {
    final p = asMap(asMap(classeDados?['patente'])[k]);
    final l = asMap(classeDados?['patente'])[k];
    if (l is List && l.length >= 2) return [asInt(l[0]), asInt(l[1])];
    return [asInt(p['0']), asInt(p['1'])];
  }

  int get qtdTranscender => f.poderes
      .where((p) => Catalogo.normalizar(asStr(p['nome'])) == 'transcender')
      .length;

  int get pvMax {
    final v = attrBase('vig');
    if (modoPatente && !sobrevivente) {
      final p = _patenteClasse('pv');
      return p[0] + v + indicePat * (p[1] + v) + soma('pv') + f.b('pv');
    }
    return c('pvIni') +
        v +
        (nivel - 1) * (c('pvNex') + (_somaAttr ? v : 0)) +
        soma('pv') +
        f.b('pv');
  }

  int get peMax {
    final p = attrBase(atributoPE);
    return c('peIni') +
        p +
        (nivel - 1) * (c('peNex') + (_somaAttr ? p : 0)) +
        soma('pe') +
        _bonusPEAlteracao +
        f.b('pe');
  }

  int get sanMax {
    var ini = c('sanIni');
    if (tem('sanInicialMetade')) ini = ini ~/ 2;
    final t = modoNivel ? 0 : qtdTranscender;
    return ini +
        (nivel - 1) * c('sanNex') -
        t * c('sanNex') +
        soma('san') +
        f.b('san');
  }

  int get pdMax {
    final p = attrBase(atributoPE);
    if (modoPatente && !sobrevivente) {
      final pd = _patenteClasse('pd');
      return pd[0] + p + indicePat * (pd[1] + p) + soma('pe') + soma('pd') + f.b('pd');
    }
    return c('pdIni') +
        p +
        (nivel - 1) * (c('pdNex') + (_somaAttr ? p : 0)) +
        soma('pe') +
        soma('pd') +
        _bonusPEAlteracao +
        f.b('pd');
  }

  int get _bonusPEAlteracao {
    if (!modoNivel || nexExposicao < 35) return 0;
    final a = asStr(asMap(f.d['escolhas'])['nex35attr']);
    return a.isEmpty ? 0 : attrBase(a);
  }

  /// Limite base (sem bonus), usado na DT.
  int get limiteBase {
    if (sobrevivente) return asInt(classeDados?['limitePE'], 1);
    if (modoPatente) return patente.limitePD;
    return nivel;
  }

  int get limitePE => limiteBase + soma('limitePE') + f.b('limitePE');

  int get cargaMax {
    var forc = attrBase('for');
    for (final e in efeitos) {
      if (asStr(e['alvo']) == 'cargaAtributo') forc += attrBase(asStr(e['attr']));
    }
    if (forc <= 0) return 2 + soma('carga') + f.b('carga');
    final base = asInt(regras['cargaBase'], 0);
    final por = asInt(regras['cargaPorFor'], 5);
    return base + por * forc + soma('carga') + f.b('carga');
  }

  int get cargaAtual {
    num t = 0;
    for (final i in f.inventario) {
      final e = i['espacos'];
      t += (e is num ? e : asInt(e, 1)) * asInt(i['qtd'], 1);
    }
    return t.ceil();
  }

  bool get sobrecarregado => cargaAtual > cargaMax;

  static bool protecaoPesada(Map<String, dynamic> i) =>
      asBool(i['pesada']) || asStr(i['ref']).endsWith('/protecao_pesada');

  bool get usandoProtecaoPesada => f.inventario.any((i) =>
      asStr(i['tipo']) == 'protecao' && asBool(i['equipado'], true) && protecaoPesada(i));

  /// Machucado: com metade ou menos dos PV totais (os PV totais saem do
  /// cálculo sem efeitos condicionais, que podem depender disto).
  late final bool machucado =
      f.pvAtual * 2 <= (semCondicionais ? pvMax : Calc(f, regras, true).pvMax);

  // ---------------- resistência a dano ----------------

  /// RD que a ficha recebe sozinha (proteções, poderes, origem, trilha,
  /// itens, maldições e condições), com o tipo, o valor e a fonte.
  late final List<({String tipo, int valor, String fonte})> rdAutomatica = _rdAutomatica();

  List<({String tipo, int valor, String fonte})> _rdAutomatica() {
    final r = <({String tipo, int valor, String fonte})>[];
    void add(String tipo, int valor, String fonte) {
      if (valor != 0) r.add((tipo: tipo, valor: valor, fonte: fonte));
    }

    for (final e in efeitos) {
      if (asStr(e['alvo']) != 'rd') continue;
      final tipo = asStr(e['tipo']);
      final id = tipoDanoPorId(tipo) != null ? tipo : tipoDanoDoTexto(tipo);
      add(id.isEmpty ? tipo : id, _valorEfeito(e), asStr(e['fonte']));
    }
    // proteções: a RD delas vale para os quatro tipos físicos (pesada: 2,
    // Blindada sobe para 5, Tanque de Guerra soma +2); a maldição Cinética
    // dá RD a todos os danos
    for (final i in f.inventario) {
      if (asStr(i['tipo']) != 'protecao' || !asBool(i['equipado'], true)) continue;
      final nome = asStr(i['nome']).isEmpty ? 'Proteção' : asStr(i['nome']);
      final pesada = protecaoPesada(i);
      var v = i['rd'] != null ? asInt(i['rd']) : (pesada ? 2 : 0);
      if (pesada && v < 5 && asStrList(i['mods']).any((m) => m.endsWith('mod.blindada'))) v = 5;
      if (pesada && v > 0) v += soma('rdProtecaoPesada');
      for (final t in tiposFisicos) {
        add(t, v, nome);
      }
      if (asStrList(i['maldicoes']).any((m) => m.endsWith('mal.cinetica'))) {
        add(rdGeral.id, pesada ? 5 : 2, '$nome (Cinética)');
      }
    }
    // Resistir a Elemento: 10 (20 com afinidade) contra o elemento do poder
    for (final p in f.poderes) {
      if (!asStr(p['ref']).endsWith('p.resistir_elemento')) continue;
      final t = tipoDanoDoTexto(asStr(p['elemento']));
      if (tiposParanormais.contains(t)) {
        add(t, asBool(p['afinidade']) ? 20 : 10, asStr(p['nome'], 'Resistir a Elemento'));
      }
    }
    return r;
  }

  /// RD anotada à mão na ficha (rituais, itens de outros livros...).
  int rdManual(String tipo) => asInt(asMap(f.d['rd'])[tipo]);

  /// RD de um tipo (ou 'geral'/'paranormal'): automática mais a anotada.
  int rdDe(String tipo) {
    var t = rdManual(tipo);
    for (final r in rdAutomatica) {
      if (r.tipo == tipo) t += r.valor;
    }
    return t;
  }

  /// RD que vale contra um tipo de dano. Fontes diferentes se somam: a do
  /// tipo, a geral (que não reduz dano mental) e, nos cinco elementos, a
  /// paranormal.
  int rdContra(String tipo) {
    if (tipo == 'mental') return rdDe('mental');
    var t = rdDe(rdGeral.id) + rdDe(tipo);
    if (tiposParanormais.contains(tipo)) t += rdDe(rdParanormal.id);
    return t;
  }

  /// Valor de um efeito: fixo, por nível ou igual a um atributo ('attr').
  int _valorEfeito(Map<String, dynamic> e) =>
      e['attr'] != null ? attr(asStr(e['attr'])) * asInt(e['valor'], 1) : _mult(e);

  // ---------------- bloqueio e esquiva ----------------

  /// Bloqueio (OPRPG p. 88): exige Fortitude treinada; reação contra um
  /// ataque corpo a corpo que dá RD igual ao bônus de Fortitude.
  bool get podeBloquear => grau('Fortitude') >= 5;

  /// Esquiva (OPRPG p. 88): exige Reflexos treinado; reação contra um
  /// ataque que soma o bônus de Reflexos na Defesa.
  bool get podeEsquivar => grau('Reflexos') >= 5;

  /// De onde vem a RD do bloqueio: Fortitude, itens e habilidades equipados
  /// ('rdBloqueio') e o bônus anotado na ficha.
  late final List<({String fonte, int valor})> partesBloqueio = [
    (fonte: 'Fortitude', valor: bonusPericia('Fortitude')),
    for (final e in efeitos)
      if (asStr(e['alvo']) == 'rdBloqueio') (fonte: asStr(e['fonte']), valor: _valorEfeito(e)),
    if (asInt(f.d['bonusBloqueio']) != 0) (fonte: 'Anotado', valor: asInt(f.d['bonusBloqueio'])),
  ];

  int get rdBloqueio => partesBloqueio.fold(0, (s, p) => s + p.valor);

  /// De onde vem a Defesa da esquiva: Defesa, Reflexos, itens ('esquiva') e
  /// o bônus anotado.
  late final List<({String fonte, int valor})> partesEsquiva = [
    (fonte: 'Defesa', valor: defesa),
    (fonte: 'Reflexos', valor: bonusPericia('Reflexos')),
    for (final e in efeitos)
      if (asStr(e['alvo']) == 'esquiva') (fonte: asStr(e['fonte']), valor: _valorEfeito(e)),
    if (asInt(f.d['bonusEsquiva']) != 0) (fonte: 'Anotado', valor: asInt(f.d['bonusEsquiva'])),
  ];

  int get defesaEsquiva => partesEsquiva.fold(0, (s, p) => s + p.valor);

  /// Opções com custo que itens e habilidades dão ao bloquear ou esquivar
  /// ('extraBloqueio'/'extraEsquiva'), com a fonte e o texto.
  List<({String fonte, String texto})> extrasDefesa(String alvo) => [
        for (final e in efeitos)
          if (asStr(e['alvo']) == alvo) (fonte: asStr(e['fonte']), texto: asStr(e['texto'])),
      ];

  int get defesa {
    var d = 10 + attr(_melhorAtributo('agi', 'atributoDefesa')) + f.b('defesa') + soma('defesa');
    for (final i in f.inventario) {
      if (asStr(i['tipo']) == 'protecao' && asBool(i['equipado'], true)) {
        d += asInt(i['defesa']);
      }
    }
    if (sobrecarregado) d -= 5;
    return d;
  }

  int get deslocamento {
    var base = 9 + f.b('deslocamento') + soma('deslocamento');
    if (sobrecarregado) base -= 3;
    if (tem('deslocamentoMetade')) base = ((base / 1.5) ~/ 2 * 1.5).floor();
    if (condicoesAtivas.contains('imovel')) base = 0;
    return base;
  }

  int bonusPericia(String nome) {
    final def = periciaPorNome(nome);
    var b = grau(nome) + f.bonusPericia(nome);
    for (final e in efeitos) {
      final alvo = asStr(e['alvo']);
      if (alvo == 'treino' && asStr(e['pericia']) == nome) {
        // já treinado (ou acima) por conta própria: ganha o "ou +2"
        if (f.grau(nome) >= asInt(e['grau'], 5)) b += asInt(e['ou']);
      } else if (alvo == 'treinoCascata' && asStrList(e['pericias']).contains(nome)) {
        if (asStrList(e['pericias']).every((p) => f.grau(p) >= 5)) b += asInt(e['ou']);
      } else if (alvo == 'todasPericias' && !asStrList(e['exceto']).contains(nome)) {
        b += _valorEfeito(e);
      } else if (alvo == 'pericia' && asStr(e['pericia']) == nome) {
        if (asBool(e['seTreinado']) && grau(nome) < 5) continue;
        b += _valorEfeito(e);
      } else if (alvo == 'resistencias' && periciasResistencia.contains(nome)) {
        b += _valorEfeito(e);
      } else if (alvo == 'periciaAttr' && asStr(e['pericia']) == nome) {
        b += attr(asStr(e['attr'])) * asInt(e['valor'], 1);
      } else if (alvo == 'escolhaPenalidade') {
        final escolha = asStr(asMap(f.d['escolhas'])[asStr(e['chave'])]);
        if (escolha == nome) b += _mult(e);
      }
    }
    if (def != null && def.carga) {
      if (sobrecarregado) b -= 5;
      if (usandoProtecaoPesada) b -= 5;
    }
    return b;
  }

  /// Ajuste em quantidade de d20 vindo de condicoes e efeitos.
  int modDados({String? pericia, String? attrTeste, bool ataque = false, bool corpo = false}) {
    final a = attrTeste ??
        (pericia == null ? null : periciaPorNome(pericia)?.attr);
    var t = 0;
    for (final e in efeitos) {
      final alvoE = asStr(e['alvo']);
      // "treino ... ou +1d20": quem já tinha o grau ganha o dado
      if (alvoE == 'treino') {
        if (pericia != null && asStr(e['pericia']) == pericia && f.grau(pericia) >= asInt(e['grau'], 5)) {
          t += asInt(e['ouDados']);
        }
        continue;
      }
      if (alvoE != 'dados') continue;
      final esc = asStr(e['escopo']);
      bool vale;
      if (esc == 'todos') {
        vale = true;
      } else if (esc == 'pericia') {
        // sem "pericia": vale em todas; com ela, só nessa
        vale = pericia != null && (e['pericia'] == null || asStr(e['pericia']) == pericia);
      } else if (esc == 'ataque') {
        vale = ataque;
      } else if (esc == 'ataqueCorpo') {
        vale = ataque && corpo;
      } else if (esc.startsWith('attr:')) {
        vale = a != null && esc.substring(5).split(',').contains(a);
      } else if (esc.startsWith('pericia:')) {
        vale = pericia != null && esc.substring(8) == pericia;
      } else {
        vale = false;
      }
      if (vale) t += asInt(e['valor']);
    }
    return t;
  }

  int dadosPericia(String nome) => attr(atributoDaPericia(nome)) + modDados(pericia: nome);

  /// Grau de treinamento contando o que os poderes dão ("treino em X":
  /// quem não era treinado passa a ser; quem já era ganha o bônus "ou").
  int grau(String nome) {
    final base = f.grau(nome);
    var g = base;
    for (final e in efeitos) {
      if (asStr(e['alvo']) == 'treinoCascata') {
        final ps = asStrList(e['pericias']);
        final primeira = ps.where((p) => f.grau(p) < 5).firstOrNull;
        if (primeira == nome && g < 5) g = 5;
        continue;
      }
      if (asStr(e['alvo']) != 'treino' || asStr(e['pericia']) != nome) continue;
      final alvo = asInt(e['grau'], 5);
      if (base < alvo && g < alvo) g = alvo;
    }
    return g;
  }

  /// Atributo usado numa perícia: o do livro ou outro que um poder permita
  /// usar no lugar (fica o maior).
  String atributoDaPericia(String nome) {
    var a = periciaPorNome(nome)?.attr ?? 'agi';
    for (final e in efeitos) {
      if (asStr(e['alvo']) == 'atributoPericia' && asStr(e['pericia']) == nome) {
        final b = asStr(e['attr']);
        if (attr(b) > attr(a)) a = b;
      }
    }
    return a;
  }

  /// Atributo dos PE (ou PD): Presença ou outro que um poder permita usar
  /// no lugar (fica o maior).
  String get atributoPE {
    var a = 'pre';
    for (final e in efeitos) {
      if (asStr(e['alvo']) != 'atributoPE') continue;
      final b = asStr(e['attr']);
      if (attrBase(b) > attrBase(a)) a = b;
    }
    return a;
  }

  /// Bonus de dano por tipo de ataque: 'corpo', 'disparo' ou 'fogo'.
  int bonusDanoArma(String ataque) {
    switch (ataque) {
      case 'corpo':
        return soma('danoCorpo');
      case 'fogo':
        return soma('danoFogo') + soma('danoDisparo');
      default:
        return soma('danoDisparo');
    }
  }

  int get bonusDanoRitual {
    var t = 0;
    for (final e in efeitos) {
      if (asStr(e['alvo']) == 'danoRitual') {
        final a = asStr(e['attr']);
        t += a.isEmpty ? _mult(e) : attr(a) * asInt(e['valor'], 1);
      }
    }
    return t;
  }

  int get dtRitual => 10 + limiteBase + attr(_melhorAtributo('pre', 'atributoDT')) + f.b('dtRitual') + soma('dtRitual');

  /// O atributo do livro ou outro que um efeito ([alvo]) permita usar no
  /// lugar (fica o maior).
  String _melhorAtributo(String base, String alvo) {
    var a = base;
    for (final e in efeitos) {
      if (asStr(e['alvo']) != alvo) continue;
      final b = asStr(e['attr']);
      if (attr(b) > attr(a)) a = b;
    }
    return a;
  }

  /// DT dos rituais de um elemento (Especialista em Elemento soma só nele).
  int dtRitualDe(String elemento) {
    var t = dtRitual;
    for (final e in efeitos) {
      if (asStr(e['alvo']) == 'dtRitual' &&
          e['elemento'] != null &&
          Catalogo.normalizar(asStr(e['elemento'])) == Catalogo.normalizar(elemento)) {
        t += _valorEfeito(e);
      }
    }
    return t;
  }

  /// Custo de um ritual depois das reduções (Ritual Predileto, Mestre em
  /// Elemento, Tatuagem Ritualística...). Nunca fica abaixo de 1.
  int custoRitualFinal(Map<String, dynamic> ritual, int custo) {
    String n(dynamic v) => Catalogo.normalizar(asStr(v));
    var t = custo;
    for (final e in efeitos) {
      if (asStr(e['alvo']) != 'custoRitual') continue;
      if (e['elemento'] != null && n(e['elemento']) != n(ritual['elemento'])) continue;
      if (e['ritual'] != null && n(e['ritual']) != n(ritual['nome'])) continue;
      if (e['alcance'] != null && !n(ritual['alcance']).startsWith(n(e['alcance']))) continue;
      t += _valorEfeito(e);
    }
    return t < 1 ? 1 : t;
  }

  int _somaAtaque(String alvo, bool corpo) {
    var t = 0;
    for (final e in efeitos) {
      if (asStr(e['alvo']) != alvo) continue;
      final esc = asStr(e['escopo'], 'todos');
      if (esc == 'todos' || (esc == 'corpo' && corpo) || (esc == 'distancia' && !corpo)) t += _valorEfeito(e);
    }
    return t;
  }

  /// Margem de ameaça a mais (Golpe de Sorte, Técnica Letal...).
  int margemAtaque({required bool corpo}) => _somaAtaque('margem', corpo);

  /// Multiplicador de crítico a mais.
  int multAtaque({required bool corpo}) => _somaAtaque('multiplicador', corpo);

  /// Dados de dano da arma a mais (Golpe Pesado...).
  int dadosDanoArma({required bool corpo}) => _somaAtaque('dadosDano', corpo);

  int custoRitual(int circulo) {
    final over = asMap(regras['custoRitual']);
    return asInt(over['$circulo'], custoRitualPadrao[circulo] ?? 1);
  }

  /// Maior circulo de ritual que a classe conjura.
  int get circuloMaximo {
    if (Catalogo.normalizar(f.classe) != 'ocultista') {
      return 1;
    }
    final n = nexClasse;
    if (n >= 85) return 4;
    if (n >= 55) return 3;
    if (n >= 25) return 2;
    return 1;
  }

  /// itens usados por categoria (1..4)
  List<int> get itensPorCategoria {
    final r = [0, 0, 0, 0];
    for (final i in f.inventario) {
      final cat = asInt(i['categoria']);
      if (cat >= 1 && cat <= 4) r[cat - 1] += asInt(i['qtd'], 1);
    }
    return r;
  }

  int get periciasTreinadasPermitidas => c('pericias') + attrBase('int');

  int get pontosAtributoIniciais => asInt(classeDados?['pontosAtributo'], 4);

  /// Validacao dos atributos na criacao (4 pontos, max 3, 0 devolve 1 ponto)
  int get pontosAtributoGastos {
    var t = 0;
    for (final k in atributosChaves) {
      t += f.attr(k) - 1;
    }
    return t;
  }

  /// Texto curto da progressao (NEX, nivel, estagio ou patente).
  String get resumoProgressao {
    if (sobrevivente) return 'Estágio ${f.estagio}';
    if (modoPatente) return patente.nome;
    if (modoNivel) return 'Nível $nivel • NEX ${f.nex}%';
    return 'NEX ${f.nex}%';
  }

  /// Habilidades de classe recebidas ate agora (texto da progressao).
  List<String> get progressaoAtual {
    final cd = classeDados;
    if (cd == null) return const [];
    if (modoPatente && !sobrevivente) {
      final p = asMap(cd['progressaoPatente']);
      return [
        for (var i = 0; i <= indicePat && i < chavesPatente.length; i++)
          if (p[chavesPatente[i]] != null)
            '${patentes[i].nome}: ${asStr(p[chavesPatente[i]])}'
      ];
    }
    final p = asMap(cd['progressao']);
    final chaves = p.keys.map((k) => asInt(k)).toList()..sort();
    final limite = sobrevivente ? f.estagio : nexClasse;
    return [
      for (final k in chaves)
        if (k <= limite)
          '${sobrevivente ? 'Estágio $k' : 'NEX $k%'}: ${asStr(p['$k'])}'
    ];
  }
}
