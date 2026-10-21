int asInt(dynamic v, [int def = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

bool asBool(dynamic v, [bool def = false]) => v is bool ? v : def;

String asStr(dynamic v, [String def = '']) => v == null ? def : v.toString();

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is! List) return [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<String> asStrList(dynamic v) {
  if (v is! List) return [];
  return v.map((e) => e.toString()).toList();
}

String novoId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    (DateTime.now().hashCode & 0xfff).toRadixString(36);

/// Ficha de agente (documento em /characters/{id}).
class Ficha {
  final String id;
  final Map<String, dynamic> d;
  Ficha(this.id, this.d);

  String get nome => asStr(d['nome'], 'Agente sem nome');
  String get jogador => asStr(d['jogador']);
  String get ownerUid => asStr(d['ownerUid']);
  List<String> get editors => asStrList(d['editors']);
  String? get campaignId {
    final c = d['campaignId'];
    return (c is String && c.isNotEmpty) ? c : null;
  }

  /// Foto do personagem (id em /imagens).
  String get foto => asStr(d['foto']);

  /// Transformação: ficha separada, ligada ao agente [transformacaoDe].
  String? get transformacaoDe {
    final t = d['transformacaoDe'];
    return (t is String && t.isNotEmpty) ? t : null;
  }

  bool get eTransformacao => transformacaoDe != null;

  /// No agente: a transformação em uso agora (null = forma normal).
  String? get formaAtiva {
    final t = d['formaAtiva'];
    return (t is String && t.isNotEmpty) ? t : null;
  }

  /// No agente: id de cada transformação e o que ela divide com ele.
  Map<String, dynamic> get transformacoes => asMap(d['transformacoes']);

  /// Na transformação: o que ela divide com o agente ('pv', 'pe', 'san').
  Map<String, dynamic> get compartilha => asMap(d['compartilha']);

  String get classe => asStr(d['classe'], 'Combatente');
  String get origem => asStr(d['origem']);
  String get trilha => asStr(d['trilha']);
  int get nex => asInt(d['nex'], 5);
  int get nivel => asInt(d['nivel'], 1);
  int get estagio => asInt(d['estagio'], 1);
  String get modoSanidade => asStr(d['modoSanidade'], 'san');
  String get modoProgressao => asStr(d['modoProgressao'], 'nex');
  String get afinidade => asStr(d['afinidade']);
  int get pp => asInt(d['pp']);

  Map<String, dynamic> get atributos => asMap(d['atributos']);
  int attr(String k) => asInt(atributos[k], 1);

  Map<String, dynamic> get pericias => asMap(d['pericias']);
  int grau(String p) => asInt(asMap(pericias[p])['grau']);
  int bonusPericia(String p) => asInt(asMap(pericias[p])['bonus']);

  int get pvAtual => asInt(d['pvAtual']);
  int get peAtual => asInt(d['peAtual']);
  int get sanAtual => asInt(d['sanAtual']);
  int get pdAtual => asInt(d['pdAtual']);

  /// Pontos temporários: PV e PE (ou PD, sem sanidade). Os "Max" guardam
  /// quanto foi ganho, só para o tamanho da barra.
  int get pvTemp => asInt(d['pvTemp']);
  int get peTemp => asInt(d['peTemp']);
  int get pvTempMax => asInt(d['pvTempMax']);
  int get peTempMax => asInt(d['peTempMax']);

  Map<String, dynamic> get bonus => asMap(d['bonus']);
  int b(String k) => asInt(bonus[k]);

  List<String> get condicoes => asStrList(d['condicoes']);
  List<Map<String, dynamic>> get inventario => asMapList(d['inventario']);
  List<Map<String, dynamic>> get rituais => asMapList(d['rituais']);
  List<Map<String, dynamic>> get poderes => asMapList(d['poderes']);
  String get notas => asStr(d['notas']);
}

/// Campanha (documento em /campaigns/{id}).
class Campanha {
  final String id;
  final Map<String, dynamic> d;
  Campanha(this.id, this.d);

  String get nome => asStr(d['nome'], 'Campanha');
  String get masterUid => asStr(d['masterUid']);
  String get joinCode => asStr(d['joinCode']);
  List<String> get memberUids => asStrList(d['memberUids']);
  Map<String, dynamic> get members => asMap(d['members']);
  Map<String, dynamic> get regras => asMap(d['regras']);
  Map<String, dynamic> get combate => asMap(d['combate']);
  String get notasMestre => asStr(d['notasMestre']);
  String get missao => asStr(d['missao']);
  List<Map<String, dynamic>> get ledger => asMapList(d['ledger']);
}
