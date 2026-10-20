import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Dados dos livros (assets/data/<fonte>/<tipo>.json): origens, classes,
/// trilhas, poderes, rituais, itens, condicoes, ameacas e regras.
/// Cada entrada ganha a chave "ref" = "<fonte>/<id>", usada nas fichas.
class Catalogo {
  Catalogo._();
  static final instance = Catalogo._();

  static const nomesFontes = {
    'OPRPG': 'Livro de Regras',
    'SaH': 'Sobrevivendo ao Horror',
    'AS1': 'Arquivos Secretos 1',
    'AS2': 'Arquivos Secretos 2',
    'AS3': 'Arquivos Secretos 3',
    'AS4': 'Arquivos Secretos 4',
    'AS5': 'Arquivos Secretos 5',
    'AS6': 'Arquivos Secretos 6',
    'AS7': 'Arquivos Secretos 7',
    'AS9': 'Arquivos Secretos 9',
  };

  final Map<String, List<Map<String, dynamic>>> _listas = {};
  final Map<String, Map<String, dynamic>> _porRef = {};
  final Map<String, Map<String, dynamic>> regras = {};
  bool carregado = false;

  List<Map<String, dynamic>> lista(String tipo) => _listas[tipo] ?? const [];
  List<Map<String, dynamic>> get origens => lista('origens');
  List<Map<String, dynamic>> get classes => lista('classes');
  List<Map<String, dynamic>> get trilhas => lista('trilhas');
  List<Map<String, dynamic>> get poderes => lista('poderes');
  List<Map<String, dynamic>> get rituais => lista('rituais');
  List<Map<String, dynamic>> get itens => lista('itens');
  List<Map<String, dynamic>> get condicoes => lista('condicoes');
  List<Map<String, dynamic>> get ameacas => lista('ameacas');

  Map<String, dynamic>? porRef(String? ref) =>
      ref == null || ref.isEmpty ? null : _porRef[ref];

  Future<void> carregar() async {
    if (carregado) return;
    List<String> arquivos;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      arquivos = manifest
          .listAssets()
          .where((a) => a.startsWith('assets/data/') && a.endsWith('.json'))
          .toList()
        ..sort();
    } catch (_) {
      arquivos = const [];
    }
    for (final a in arquivos) {
      final partes = a.split('/');
      if (partes.length < 4) continue;
      final fonte = partes[2];
      final tipo = partes[3].replaceAll('.json', '');
      try {
        final dado = jsonDecode(await rootBundle.loadString(a));
        if (tipo == 'regras' && dado is Map) {
          regras[fonte] = Map<String, dynamic>.from(dado);
          continue;
        }
        if (dado is! List) continue;
        final l = _listas.putIfAbsent(tipo, () => []);
        for (final e in dado.whereType<Map>()) {
          final m = Map<String, dynamic>.from(e);
          final ref = '$fonte/${asStr(m['id'])}';
          m['ref'] = ref;
          l.add(m);
          _porRef['$tipo:$ref'] = m;
          _porRef[ref] = m;
        }
      } catch (_) {
        // arquivo com erro: ignora para nao derrubar o app
      }
    }
    for (final l in _listas.values) {
      l.sort((a, b) => _sem(asStr(a['nome'])).compareTo(_sem(asStr(b['nome']))));
    }
    carregado = true;
  }

  Map<String, dynamic>? doTipo(String tipo, String? ref) =>
      ref == null ? null : _porRef['$tipo:$ref'];

  Map<String, dynamic>? classePorNome(String nome) => _porNome(classes, nome);
  Map<String, dynamic>? origemPorNome(String nome) => _porNome(origens, nome);

  Map<String, dynamic>? trilhaPorNome(String nome, String classe) {
    final n = _sem(nome);
    final c = _sem(classe);
    for (final t in trilhas) {
      if (_sem(asStr(t['nome'])) == n &&
          (_sem(asStr(t['classe'])) == c ||
              asStrList(t['classes']).map(_sem).contains(c))) {
        return t;
      }
    }
    return _porNome(trilhas, nome);
  }

  List<Map<String, dynamic>> trilhasDaClasse(String classe) {
    final c = _sem(classe);
    return trilhas
        .where((t) =>
            _sem(asStr(t['classe'])) == c ||
            asStrList(t['classes']).map(_sem).contains(c))
        .toList();
  }

  Map<String, dynamic>? condicao(String nome) => _porNome(condicoes, nome);

  Map<String, dynamic>? _porNome(List<Map<String, dynamic>> l, String nome) {
    final n = _sem(nome);
    if (n.isEmpty) return null;
    for (final e in l) {
      if (_sem(asStr(e['nome'])) == n || asStr(e['id']) == nome) return e;
    }
    return null;
  }

  /// Regra de uma fonte qualquer (procura nas fontes carregadas).
  dynamic regra(String chave) {
    for (final r in regras.values) {
      if (r.containsKey(chave)) return r[chave];
    }
    return null;
  }

  static String fonteCurta(Map<String, dynamic> e) {
    final f = asStr(e['fonte']);
    final p = e['pag'];
    return p == null ? f : '$f p. $p';
  }

  static String _sem(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final b = StringBuffer();
    for (final ch in s.trim().split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? para[i] : ch);
    }
    return b.toString().toLowerCase();
  }

  /// Normaliza texto para busca (sem acentos, minusculo).
  static String normalizar(String s) => _sem(s);
}
