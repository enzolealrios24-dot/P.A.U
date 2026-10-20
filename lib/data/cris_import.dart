import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/rules.dart';
import 'catalogo.dart';
import 'models.dart';

/// Erro com mensagem pronta para mostrar na tela.
class CrisErro implements Exception {
  final String mensagem;
  const CrisErro(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Um agente lido do site crisordemparanormal.com.
class AgenteCris {
  final String id;
  final Map<String, dynamic> dados;
  const AgenteCris(this.id, this.dados);

  String get nome => asStr(dados['name'], 'Agente sem nome');
  String get classe => asStr(dados['className']);
  String get nex => asStr(dados['nex']);
  String get origem => asStr(dados['backgroundName']);
  String get resumo =>
      [classe, if (nex.isNotEmpty) 'NEX $nex', origem].where((s) => s.isNotEmpty).join(' • ');
}

/// Traz agentes do site do CRIS pelo link de compartilhar de cada agente.
/// O site libera a leitura da ficha para quem tem o link, sem login.
class CrisImport {
  static const _base =
      'https://firestore.googleapis.com/v1/projects/cris-ordem-paranormal/databases/(default)/documents/characters';
  // Chave pública da versão web do site (a mesma que o navegador recebe).
  static const _chave = 'AIzaSyADXkE6U5j_hlSRxK3nfqyylmPXgUeGWsQ';

  /// Agentes lidos na tela de login, gravados assim que a pessoa entra.
  static final pendentes = <AgenteCris>[];

  /// Códigos de agente em um texto com um ou vários links (ou só os códigos).
  static List<String> idsNoTexto(String texto) {
    final ids = <String>{};
    for (final m in RegExp(r'agente/([A-Za-z0-9]{10,40})').allMatches(texto)) {
      ids.add(m.group(1)!);
    }
    for (final p in texto.split(RegExp(r'[\s,;]+'))) {
      if (RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(p)) ids.add(p);
    }
    return ids.toList();
  }

  static Future<AgenteCris> ler(String id) async {
    final http.Response r;
    try {
      r = await http
          .get(Uri.parse('$_base/$id?key=$_chave'))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const CrisErro('Sem conexão com o site do CRIS.');
    }
    if (r.statusCode == 404) {
      throw const CrisErro('Agente não encontrado. Confira o link.');
    }
    if (r.statusCode == 403) {
      throw const CrisErro(
          'O site do CRIS não liberou este agente. Ele pode estar privado.');
    }
    if (r.statusCode != 200) {
      throw CrisErro('O site do CRIS não respondeu (erro ${r.statusCode}).');
    }
    final doc = jsonDecode(utf8.decode(r.bodyBytes));
    return AgenteCris(id, _campos(asMap(asMap(doc)['fields'])));
  }

  // ---------------- formato do Firestore -> mapa simples ----------------

  static Map<String, dynamic> _campos(Map<String, dynamic> f) =>
      {for (final e in f.entries) e.key: _valor(e.value)};

  static dynamic _valor(dynamic v) {
    final m = asMap(v);
    if (m.containsKey('stringValue')) return m['stringValue'];
    if (m.containsKey('integerValue')) return int.tryParse('${m['integerValue']}') ?? 0;
    if (m.containsKey('doubleValue')) return m['doubleValue'];
    if (m.containsKey('booleanValue')) return m['booleanValue'];
    if (m.containsKey('timestampValue')) return m['timestampValue'];
    if (m.containsKey('mapValue')) return _campos(asMap(asMap(m['mapValue'])['fields']));
    if (m.containsKey('arrayValue')) {
      final l = asMap(m['arrayValue'])['values'];
      return l is List ? l.map(_valor).toList() : <dynamic>[];
    }
    return null;
  }

  // ---------------- ficha do CRIS -> ficha do app ----------------

  /// HTML das descrições do site em texto puro.
  static String _texto(dynamic html) {
    var s = asStr(html)
        .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>|</h\d>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    const ent = {
      '&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'",
    };
    ent.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static int _numero(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(RegExp(r'-?\d+').firstMatch(asStr(v))?.group(0) ?? '') ?? 0;
  }

  static num _espacos(dynamic v) {
    if (v is num) return v;
    return num.tryParse(asStr(v).replaceAll(',', '.')) ?? 1;
  }

  static int _categoria(dynamic v) {
    const romanos = {'0': 0, 'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5};
    return romanos[asStr(v).trim().toUpperCase()] ?? _numero(v);
  }

  static Map<String, dynamic>? _doLivro(List<Map<String, dynamic>> lista, String nome) {
    final n = Catalogo.normalizar(nome);
    if (n.isEmpty) return null;
    for (final e in lista) {
      if (Catalogo.normalizar(asStr(e['nome'])) == n) return e;
    }
    return null;
  }

  static Map<String, dynamic> _ligarAoLivro(Map<String, dynamic>? e) => e == null
      ? const {}
      : {'ref': e['ref'], 'fonte': e['fonte'], if (e['pag'] != null) 'pag': e['pag']};

  static String _classe(String nome) {
    final n = Catalogo.normalizar(nome);
    if (n == 'mundano') return 'Sobrevivente';
    for (final c in nomesClasses()) {
      if (Catalogo.normalizar(c) == n) return c;
    }
    return nome.isEmpty ? 'Combatente' : nome;
  }

  static String _critico(Map<String, dynamic> a) {
    final mult = _numero(a['criticalMult']);
    final margem = _numero(a['criticalRange']);
    final x = mult > 0 ? mult : 2;
    return margem > 0 && margem < 20 ? '$margem/x$x' : 'x$x';
  }

  static Map<String, dynamic> _item(Map<String, dynamic> i) {
    final tipoCris = asStr(i['itemType']);
    final nome = asStr(i['name'], 'Item');
    final livro = _doLivro(Catalogo.instance.itens, nome);
    final mods = [
      for (final m in asMapList(i['mods'])) asStr(m['name']),
    ].where((s) => s.isNotEmpty).toList();
    final desc = [
      _texto(i['description']),
      if (mods.isNotEmpty) 'Modificações: ${mods.join(', ')}',
    ].where((s) => s.isNotEmpty).join('\n');
    final base = <String, dynamic>{
      'nome': nome,
      'categoria': _categoria(i['category']),
      'espacos': _espacos(i['slots']),
      'qtd': i['quantity'] == null ? 1 : _numero(i['quantity']),
      'equipado': i['equipped'] is bool ? i['equipped'] : tipoCris != 'misc',
      'descricao': desc,
      ..._ligarAoLivro(livro),
    };
    switch (tipoCris) {
      case 'weapon':
        final tipo = Catalogo.normalizar(asStr(i['type']));
        final corpo = tipo.contains('corpo');
        return {
          ...base,
          'tipo': 'arma',
          'categoriaLivro': 'arma',
          'dano': asStr(i['damage']),
          'critico': _critico(i),
          'pericia': corpo ? 'Luta' : 'Pontaria',
          'ataque': corpo ? 'corpo' : (tipo.contains('disparo') ? 'disparo' : 'fogo'),
          if (asStr(i['range']).isNotEmpty && asStr(i['range']) != '-')
            'alcance': asStr(i['range']),
          if (asStr(i['damageType']).isNotEmpty) 'tipoDano': asStr(i['damageType']),
        };
      case 'protection':
        return {
          ...base,
          'tipo': 'protecao',
          'categoriaLivro': 'protecao',
          'defesa': _numero(i['defense']),
          if (Catalogo.normalizar(nome).contains('pesada')) 'pesada': true,
        };
      case 'ammunition':
        return {...base, 'tipo': 'geral', 'categoriaLivro': 'municao'};
      case 'cursedItem':
        return {...base, 'tipo': 'geral', 'categoriaLivro': 'amaldicoado'};
      default:
        return {...base, 'tipo': 'geral', 'categoriaLivro': asStr(livro?['tipo'], 'geral')};
    }
  }

  /// Ataques da ficha do site que não são de uma arma já no inventário.
  static Map<String, dynamic> _ataque(Map<String, dynamic> a) {
    final pericia = asStr(a['skill']);
    final extras = [
      for (final d in asMapList(a['extraDamage'] ?? a['extraDamages']))
        asStr(d['value']),
    ].where((s) => s.isNotEmpty);
    final dano = [asStr(a['damage']), ...extras].where((s) => s.isNotEmpty && s != '-');
    return {
      'nome': asStr(a['name'], 'Ataque'),
      'tipo': 'arma',
      'categoriaLivro': 'arma',
      'categoria': 0,
      'espacos': 0,
      'qtd': 1,
      'equipado': true,
      'dano': dano.join('+'),
      'critico': _critico(a),
      'pericia': Catalogo.normalizar(pericia).contains('luta') ? 'Luta' : 'Pontaria',
      if (_numero(a['attackBonus']) != 0) 'bonusAtaque': _numero(a['attackBonus']),
      if (asStr(a['range']).isNotEmpty && asStr(a['range']) != '-')
        'alcance': asStr(a['range']),
      if (asStr(a['damageType']).isNotEmpty) 'tipoDano': asStr(a['damageType']),
      'descricao': 'Ataque trazido do site do CRIS.',
    };
  }

  static Map<String, dynamic> _ritual(Map<String, dynamic> r) {
    final nome = asStr(r['name'], 'Ritual');
    final livro = _doLivro(Catalogo.instance.rituais, nome);
    final elemento = asStr(r['element'], asStr(livro?['elemento']));
    String campo(String k) => asStr(r[k]);
    return {
      'nome': nome,
      'elemento': elemento,
      'circulo': _numero(r['circle']).clamp(1, 4),
      'execucao': campo('execution'),
      'alcance': campo('range'),
      'alvo': [campo('target'), campo('area')].where((s) => s.isNotEmpty).join(' / '),
      'duracao': campo('duration'),
      'resistencia': campo('save'),
      if (campo('normalDice').isNotEmpty) 'dano': campo('normalDice'),
      if (campo('discenteDice').isNotEmpty) 'danoDiscente': campo('discenteDice'),
      if (campo('verdadeiroDice').isNotEmpty) 'danoVerdadeiro': campo('verdadeiroDice'),
      if (livro?['custoDiscente'] != null) 'custoDiscente': livro!['custoDiscente'],
      if (livro?['custoVerdadeiro'] != null) 'custoVerdadeiro': livro!['custoVerdadeiro'],
      'descricao': _texto(r['description']),
      ..._ligarAoLivro(livro),
    };
  }

  static Map<String, dynamic> _poder(Map<String, dynamic> p) {
    final nome = asStr(p['name'], 'Poder');
    final livro = _doLivro(Catalogo.instance.poderes, nome);
    final tipoLivro = asStr(livro?['tipo']);
    final elemento = asStr(p['element'], asStr(livro?['elemento']));
    return {
      'nome': nome,
      'tipo': tipoLivro == 'paranormal' || (livro == null && elemento.isNotEmpty)
          ? 'Paranormal'
          : (tipoLivro == 'geral' ? 'Geral' : 'Classe'),
      if (elemento.isNotEmpty) 'elemento': elemento,
      'descricao': _texto(p['description']).isNotEmpty
          ? _texto(p['description'])
          : asStr(livro?['resumo']),
      ..._ligarAoLivro(livro),
    };
  }

  /// Trilha da classe cujas habilidades aparecem entre os poderes da ficha.
  static String _trilha(String classe, List<String> poderes) {
    final nomes = poderes.map(Catalogo.normalizar).toList();
    for (final t in Catalogo.instance.trilhasDaClasse(classe)) {
      for (final h in asMapList(t['habilidades'])) {
        final n = Catalogo.normalizar(asStr(h['nome']));
        if (n.isNotEmpty && nomes.any((p) => p.contains(n))) return asStr(t['nome']);
      }
    }
    return '';
  }

  /// Monta a ficha do app. Os máximos de PV, PE, SAN e PD do site viram
  /// bônus, para a ficha abrir com os mesmos valores.
  static Map<String, dynamic> paraFicha(AgenteCris a, String ownerUid, String jogador) {
    final c = a.dados;
    final at = asMap(c['attributes']);
    final classe = _classe(asStr(c['className'], asStr(c['statsClass'])));
    final nex = _numero(c['nex']).clamp(0, 99);
    final poderesCris = asMapList(c['powers']);

    final pericias = <String, dynamic>{};
    for (final s in asMapList(c['skills'])) {
      final def = periciaPorNome(asStr(s['name']));
      if (def == null) continue;
      final grau = _numero(s['trainingDegree']);
      final bonus = _numero(s['otherBonus']);
      if (grau == 0 && bonus == 0) continue;
      pericias[def.nome] = {'grau': grau, if (bonus != 0) 'bonus': bonus};
    }

    final inventario = [
      for (final i in asMapList(c['inventory'])) {..._item(i), 'id': novoId()},
    ];
    final armas = inventario
        .where((i) => i['tipo'] == 'arma')
        .map((i) => Catalogo.normalizar(asStr(i['nome'])))
        .toSet();
    for (final atk in asMapList(c['attacks'])) {
      if (armas.contains(Catalogo.normalizar(asStr(atk['name'])))) continue;
      inventario.add({..._ataque(atk), 'id': novoId()});
    }

    final desc = asMap(c['description']);
    String d(String k) => asStr(desc[k]).trim();
    final notas = [
      d('anotation'),
      if (d('personal').isNotEmpty) 'Personalidade: ${d('personal')}',
      if (d('goal').isNotEmpty) 'Objetivo: ${d('goal')}',
      if (asStr(c['resistances']).isNotEmpty) 'Resistências: ${asStr(c['resistances'])}',
      if (asStr(c['proficiencies']).isNotEmpty)
        'Proficiências: ${asStr(c['proficiencies'])}',
    ].where((s) => s.isNotEmpty).join('\n\n');

    final m = novaFicha(ownerUid, asStr(c['player'], jogador))
      ..addAll({
        'nome': asStr(c['name'], 'Agente do CRIS'),
        'classe': classe,
        'origem': _nomeOrigem(asStr(c['backgroundName'])),
        'trilha': _trilha(classe, [for (final p in poderesCris) asStr(p['name'])]),
        'nex': nex < 5 ? 5 : nex,
        'nivel': (nex ~/ 5).clamp(1, 20),
        'modoSanidade': asBool(c['isPdOn']) ? 'pd' : 'san',
        'pp': _numero(c['prestigePoints']),
        'atributos': {
          'agi': _numero(at['dex']),
          'for': _numero(at['str']),
          'int': _numero(at['int']),
          'pre': _numero(at['pre']),
          'vig': _numero(at['con']),
        },
        'pericias': pericias,
        'pvAtual': _numero(c['currentPv']),
        'peAtual': _numero(c['currentPe']),
        'sanAtual': _numero(c['currentSan']),
        'pdAtual': _numero(c['currentPd']),
        'inventario': inventario,
        'rituais': [for (final r in asMapList(c['rituals'])) {..._ritual(r), 'id': novoId()}],
        'poderes': [for (final p in poderesCris) {..._poder(p), 'id': novoId()}],
        'notas': notas,
        'aparencia': d('physical'),
        'historia': d('history'),
        'crisId': a.id,
        'crisImportadoEm': DateTime.now().millisecondsSinceEpoch,
      });

    // Ajusta os máximos e a DT de rituais para baterem com o site.
    final calc = Calc(Ficha('_', m));
    final bonus = <String, dynamic>{
      'pv': _numero(c['maxPv']) - calc.pvMax,
      'pe': _numero(c['maxPe']) - calc.peMax,
      'san': _numero(c['maxSan']) - calc.sanMax,
      'pd': _numero(c['maxPd']) - calc.pdMax,
      'defesa': _numero(c['bonusDefense']),
      'deslocamento': c['movement'] == null ? 0 : _numero(c['movement']) - 9,
      if (_numero(c['ritualsDc']) > 0) 'dtRitual': _numero(c['ritualsDc']) - calc.dtRitual,
    }..removeWhere((_, v) => v == 0);
    m['bonus'] = bonus;
    return m;
  }

  static String _nomeOrigem(String nome) =>
      asStr(Catalogo.instance.origemPorNome(nome)?['nome'], nome);
}
