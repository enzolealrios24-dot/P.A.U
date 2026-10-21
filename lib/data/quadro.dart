import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'repo.dart';

/// Tipos de cartão do quadro (como no Milanote).
class TiposQuadro {
  static const nota = 'nota';
  static const titulo = 'titulo';
  static const tarefas = 'tarefas';
  static const link = 'link';
  static const imagem = 'imagem';
  static const cor = 'cor';
  static const coluna = 'coluna';
  static const quadro = 'quadro';

  static const nomes = {
    nota: 'Nota',
    titulo: 'Título',
    tarefas: 'Lista de tarefas',
    link: 'Link',
    imagem: 'Imagem',
    cor: 'Cor',
    coluna: 'Coluna',
    quadro: 'Quadro',
  };

  /// Tamanho inicial de cada tipo.
  static const tamanho = {
    nota: (220.0, 150.0),
    titulo: (320.0, 70.0),
    tarefas: (240.0, 200.0),
    link: (260.0, 110.0),
    imagem: (260.0, 200.0),
    cor: (150.0, 150.0),
    coluna: (270.0, 0.0),
    quadro: (200.0, 150.0),
  };
}

/// Um cartão do quadro.
class ItemQuadro {
  final String id;
  final Map<String, dynamic> d;
  ItemQuadro(this.id, this.d);

  String get tipo => asStr(d['tipo'], TiposQuadro.nota);
  double get x => _n(d['x']);
  double get y => _n(d['y']);
  double get w => _n(d['w'], TiposQuadro.tamanho[tipo]?.$1 ?? 220);
  double get h => _n(d['h'], TiposQuadro.tamanho[tipo]?.$2 ?? 150);
  int get z => asInt(d['z']);
  int? get cor => d['cor'] is int ? d['cor'] as int : null;
  String get texto => asStr(d['texto']);
  String get titulo => asStr(d['titulo']);
  String get url => asStr(d['url']);
  /// Coluna onde o cartão está (null = solto no quadro).
  String? get coluna {
    final c = d['coluna'];
    return c is String && c.isNotEmpty ? c : null;
  }

  double get ordem => _n(d['ordem']);
  /// Para cartões do tipo quadro: o id do quadro de dentro.
  String get subquadro => asStr(d['subquadro']);
  List<Map<String, dynamic>> get tarefas => asMapList(d['tarefas']);

  ItemQuadro copia(Map<String, dynamic> mudancas) =>
      ItemQuadro(id, {...d, ...mudancas});

  static double _n(dynamic v, [double padrao = 0]) =>
      v is num ? v.toDouble() : padrao;
}

/// Ligação (seta ou linha) entre dois cartões.
class LigacaoQuadro {
  final String id;
  final Map<String, dynamic> d;
  LigacaoQuadro(this.id, this.d);
  String get de => asStr(d['de']);
  String get para => asStr(d['para']);
  String get texto => asStr(d['texto']);
  bool get seta => d['seta'] != false;
}

/// Um quadro: cartões e ligações. Pode haver quadros dentro de quadros.
class Quadro {
  final String id;
  final Map<String, dynamic> d;
  Quadro(this.id, this.d);
  String get nome => asStr(d['nome'], 'Quadro');
  Map<String, ItemQuadro> get itens => {
        for (final e in asMap(d['itens']).entries)
          if (e.value is Map) e.key: ItemQuadro(e.key, asMap(e.value)),
      };
  Map<String, LigacaoQuadro> get ligacoes => {
        for (final e in asMap(d['ligacoes']).entries)
          if (e.value is Map) e.key: LigacaoQuadro(e.key, asMap(e.value)),
      };
}

/// Onde o quadro fica guardado: um campo da ficha ou o documento do mestre.
/// Tudo é gravado com merge, só nos pedaços que mudaram.
class FonteQuadro {
  final DocumentReference<Map<String, dynamic>> doc;
  /// Caminho até o mapa "quadros" dentro do documento.
  final List<String> prefixo;
  final String nomeRaiz;
  const FonteQuadro(this.doc, this.prefixo, this.nomeRaiz);

  static const raiz = 'raiz';

  /// Quadro da ficha: campo "quadro" do documento do agente.
  factory FonteQuadro.ficha(String fichaId) => FonteQuadro(
      FirebaseFirestore.instance.collection('characters').doc(fichaId),
      const ['quadro'],
      'Quadro do agente');

  /// Quadro do mestre: documento privado da mesa (só o mestre lê).
  factory FonteQuadro.mestre(String campanhaId) => FonteQuadro(
      FirebaseFirestore.instance
          .collection('campaigns')
          .doc(campanhaId)
          .collection('gm')
          .doc('quadro'),
      const [],
      'Quadro do mestre');

  Map<String, dynamic> _quadros(Map<String, dynamic>? dados) {
    dynamic atual = dados ?? const {};
    for (final p in prefixo) {
      atual = atual is Map ? atual[p] : null;
    }
    return asMap(atual is Map ? atual['quadros'] : null);
  }

  Stream<Map<String, Quadro>> get todos => doc.snapshots().map((s) {
        final q = _quadros(s.data());
        return {
          for (final e in q.entries)
            if (e.value is Map) e.key: Quadro(e.key, asMap(e.value)),
        };
      });

  Map<String, dynamic> _embrulhar(Map<String, dynamic> m) {
    Map<String, dynamic> atual = {'quadros': m};
    for (final p in prefixo.reversed) {
      atual = {p: atual};
    }
    return atual;
  }

  void _gravar(Map<String, dynamic> m) =>
      doc.set(_embrulhar(m), SetOptions(merge: true)).catchError((Object e) => Repo.onErro?.call(e));

  void salvarItem(String quadroId, ItemQuadro i) => _gravar({
        quadroId: {
          'itens': {i.id: i.d}
        }
      });

  /// Só alguns campos de um cartão (ex.: posição depois de arrastar).
  void mudarItem(String quadroId, String itemId, Map<String, dynamic> campos) =>
      _gravar({
        quadroId: {
          'itens': {itemId: campos}
        }
      });

  void apagarItem(String quadroId, String itemId) => _gravar({
        quadroId: {
          'itens': {itemId: FieldValue.delete()}
        }
      });

  void salvarLigacao(String quadroId, LigacaoQuadro l) => _gravar({
        quadroId: {
          'ligacoes': {l.id: l.d}
        }
      });

  void apagarLigacao(String quadroId, String ligacaoId) => _gravar({
        quadroId: {
          'ligacoes': {ligacaoId: FieldValue.delete()}
        }
      });

  void criarQuadro(String quadroId, String nome) => _gravar({
        quadroId: {'nome': nome}
      });

  void apagarQuadro(String quadroId) => _gravar({quadroId: FieldValue.delete()});
}
