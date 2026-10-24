import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/quadro.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import '../../widgets/imagem.dart';
import '../sheet/sheet_screen.dart';

/// Cores para os cartões (como as etiquetas do Milanote).
const coresCartao = <int>[
  0xFF2A2238, // padrão
  0xFF6B5410, // amarelo
  0xFF7A3E12, // laranja
  0xFF6E1824, // vermelho
  0xFF6A1F4E, // rosa
  0xFF3E237A, // roxo
  0xFF17406E, // azul
  0xFF175A3C, // verde
  0xFF3A3A44, // cinza
];

/// Cores e espessuras da caneta.
const coresCaneta = <int>[
  0xFFF5C42C, 0xFFFFFFFF, 0xFFE5484D, 0xFFFF9F43, 0xFF3DD68C, 0xFF4EA8FF,
  0xFFB78CFF, 0xFF111111,
];
const espessurasCaneta = <double>[2.5, 5, 10];

/// Cores das setas (null = a cor do tema).
const coresLigacao = <String, int?>{
  'Lilás': null,
  'Amarelo': 0xFFF5C42C,
  'Vermelho': 0xFFE5484D,
  'Verde': 0xFF3DD68C,
  'Azul': 0xFF4EA8FF,
  'Branco': 0xFFEDEDED,
};

const _lado = 4000.0; // tamanho da área do quadro

/// Um traço de caneta.
class _Traco {
  final int cor;
  final double esp;
  final List<Offset> pts;
  _Traco(this.cor, this.esp, this.pts);
}

List<_Traco> _lerTracos(ItemQuadro i) => [
      for (final t in i.tracos)
        _Traco(asInt(t['c'], coresCaneta.first),
            t['e'] is num ? (t['e'] as num).toDouble() : 4.0, _pontos(t['p'])),
    ];

List<Offset> _pontos(dynamic l) {
  if (l is! List) return const <Offset>[];
  final v = [for (final x in l) x is num ? x.toDouble() : 0.0];
  return [for (var k = 0; k + 1 < v.length; k += 2) Offset(v[k], v[k + 1])];
}

/// Escala e deslocamento para o desenho (medido em bw x bh) caber em [tam].
(double, Offset) _encaixe(double bw, double bh, Size tam) {
  if (bw <= 0 || bh <= 0) return (1.0, Offset.zero);
  final s = min(tam.width / bw, tam.height / bh);
  return (s, Offset((tam.width - bw * s) / 2, (tam.height - bh * s) / 2));
}

double _distSegmento(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (l2 == 0) return (p - a).distance;
  final ap = p - a;
  final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / l2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Quadro de anotações no estilo do Milanote: cartões soltos que se movem e
/// mudam de tamanho, colunas, listas de tarefas, links, imagens, desenhos,
/// fichas, cores, quadros dentro de quadros, setas e comentários.
class TelaQuadro extends StatefulWidget {
  final FonteQuadro fonte;
  final String quadroId;
  const TelaQuadro({super.key, required this.fonte, this.quadroId = FonteQuadro.raiz});

  @override
  State<TelaQuadro> createState() => _TelaQuadroState();
}

class _TelaQuadroState extends State<TelaQuadro> {
  final _vista = TransformationController();
  final _chaveArea = GlobalKey();
  late final Stream<Map<String, Quadro>> _dados = widget.fonte.todos;
  String? _selecionado;
  bool _conectando = false;
  String? _origemLigacao;
  // Posições e tamanhos locais enquanto o dedo arrasta (gravados ao soltar).
  final _pos = <String, Offset>{};
  final _tam = <String, Size>{};
  Map<String, Quadro> _quadros = const {};

  // Caneta: os traços ficam aqui até "Concluir" virar um cartão de desenho.
  bool _caneta = false;
  bool _borracha = false;
  String? _editandoDesenho;
  int _corCaneta = coresCaneta.first;
  double _espessura = espessurasCaneta[1];
  final _tracos = <_Traco>[];
  final _tinta = ValueNotifier<int>(0);
  int? _ponteiro;
  bool _tracoAberto = false;

  FonteQuadro get _f => widget.fonte;
  Quadro get _quadro => _quadros[widget.quadroId] ?? Quadro(widget.quadroId, const {});

  @override
  void dispose() {
    _vista.dispose();
    _tinta.dispose();
    super.dispose();
  }

  // ---------------- vista ----------------

  Size get _tamVista {
    final caixa = _chaveArea.currentContext?.findRenderObject() as RenderBox?;
    return caixa?.size ?? const Size(400, 600);
  }

  Offset _centroDaVista() {
    final t = _tamVista;
    final p = _vista.toScene(Offset(t.width / 2, t.height / 2));
    return Offset(p.dx.clamp(0.0, _lado - 300), p.dy.clamp(0.0, _lado - 300));
  }

  /// Põe o ponto [centro] do quadro no meio da tela, com a escala pedida.
  void _verComo(double escala, Offset centro) {
    final t = _tamVista;
    final s = escala.clamp(0.2, 2.5);
    _vista.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(2, 2, s)
      ..setEntry(0, 3, t.width / 2 - centro.dx * s)
      ..setEntry(1, 3, t.height / 2 - centro.dy * s);
  }

  void _zoom(double fator) {
    final t = _tamVista;
    _verComo(_vista.value.getMaxScaleOnAxis() * fator,
        _vista.toScene(Offset(t.width / 2, t.height / 2)));
  }

  /// Enquadra todos os cartões.
  void _verTudo() {
    final q = _quadro;
    final rs = [
      for (final i in q.itens.values)
        if (_solto(q, i)) _retangulo(i)
    ];
    if (rs.isEmpty) {
      _vista.value = Matrix4.identity();
      return;
    }
    var r = rs.first;
    for (final x in rs) {
      r = r.expandToInclude(x);
    }
    r = r.inflate(40);
    final t = _tamVista;
    _verComo(min(t.width / r.width, t.height / r.height).clamp(0.2, 1.2), r.center);
  }

  // ---------------- criar ----------------

  int get _zTopo =>
      _quadro.itens.values.fold<int>(0, (m, i) => max(m, i.z)) + 1;

  Future<void> _adicionar(String tipo) async {
    if (tipo == TiposQuadro.desenho) {
      _comecarDesenho(null);
      return;
    }
    Map<String, dynamic>? dados;
    (double, double)? tam;
    if (tipo == TiposQuadro.imagem) {
      final r = await _novaImagem();
      if (r == null) return;
      dados = r.$1;
      tam = r.$2;
    } else if (tipo == TiposQuadro.ficha) {
      dados = await _escolherFicha();
    } else {
      dados = await _editar(tipo, const {});
    }
    if (dados == null) return;
    _criar(tipo, dados, tam: tam);
  }

  /// Grava um cartão novo no meio da tela (ou com o canto em [canto]).
  String _criar(String tipo, Map<String, dynamic> dados,
      {(double, double)? tam, Offset? canto}) {
    final c = _centroDaVista();
    final t = tam ?? TiposQuadro.tamanho[tipo]!;
    final id = novoId();
    final m = <String, dynamic>{
      'tipo': tipo,
      'x': canto?.dx ?? c.dx - t.$1 / 2,
      'y': canto?.dy ?? c.dy - (t.$2 == 0 ? 60 : t.$2 / 2),
      'w': t.$1,
      'h': t.$2,
      'z': _zTopo,
      ...dados,
    };
    if (tipo == TiposQuadro.quadro) {
      final sub = novoId();
      m['subquadro'] = sub;
      _f.criarQuadro(sub, asStr(dados['titulo'], 'Novo quadro'));
    }
    if (widget.quadroId == FonteQuadro.raiz && _quadros[FonteQuadro.raiz] == null) {
      _f.criarQuadro(FonteQuadro.raiz, _f.nomeRaiz);
    }
    _f.salvarItem(widget.quadroId, ItemQuadro(id, m));
    setState(() => _selecionado = id);
    return id;
  }

  /// Formulário de cada tipo de cartão. Devolve só os campos de conteúdo.
  Future<Map<String, dynamic>?> _editar(String tipo, Map<String, dynamic> atual) async {
    final List<CampoDef> campos;
    switch (tipo) {
      case TiposQuadro.titulo:
        campos = const [CampoDef('texto', 'Título')];
      case TiposQuadro.tarefas:
        campos = const [
          CampoDef('titulo', 'Nome da lista'),
          CampoDef('linhas', 'Tarefas (uma por linha)', tipo: TipoCampo.multi),
        ];
      case TiposQuadro.link:
        campos = const [
          CampoDef('titulo', 'Título'),
          CampoDef('url', 'Endereço', dica: 'https://...'),
          CampoDef('texto', 'Descrição', tipo: TipoCampo.multi),
        ];
      case TiposQuadro.imagem:
        campos = const [
          CampoDef('url', 'Endereço da imagem', dica: 'https://.../imagem.jpg'),
          CampoDef('texto', 'Legenda'),
        ];
      case TiposQuadro.cor:
        campos = const [
          CampoDef('titulo', 'Nome da cor'),
          CampoDef('hex', 'Código', dica: '#F5C42C'),
        ];
      case TiposQuadro.coluna:
        campos = const [CampoDef('titulo', 'Nome da coluna')];
      case TiposQuadro.quadro:
        campos = const [CampoDef('titulo', 'Nome do quadro')];
      default:
        campos = const [
          CampoDef('texto', 'Nota',
              tipo: TipoCampo.multi,
              dica: '**negrito**, *itálico*, ~~riscado~~, # título, - lista, [ ] tarefa'),
        ];
    }
    final inicial = Map<String, dynamic>.from(atual);
    if (tipo == TiposQuadro.tarefas) {
      inicial['linhas'] = [for (final t in asMapList(atual['tarefas'])) asStr(t['t'])].join('\n');
    }
    if (tipo == TiposQuadro.cor && atual['cor'] is int) {
      inicial['hex'] = '#${(atual['cor'] as int).toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    }
    final r = await editarFormulario(context,
        titulo: atual.isEmpty
            ? 'Novo: ${TiposQuadro.nomes[tipo]}'
            : 'Editar ${TiposQuadro.nomes[tipo]?.toLowerCase()}',
        inicial: inicial,
        campos: campos);
    final d = r?.dados;
    if (d == null) return null;
    final saida = <String, dynamic>{
      for (final c in campos)
        if (c.chave != 'linhas' && c.chave != 'hex') c.chave: asStr(d[c.chave]).trim(),
    };
    if (tipo == TiposQuadro.tarefas) {
      final feitas = {
        for (final t in asMapList(atual['tarefas']))
          if (t['ok'] == true) asStr(t['t']),
      };
      saida['tarefas'] = [
        for (final l in asStr(d['linhas']).split('\n'))
          if (l.trim().isNotEmpty) {'t': l.trim(), 'ok': feitas.contains(l.trim())},
      ];
    }
    if (tipo == TiposQuadro.cor) {
      saida['cor'] = _lerHex(asStr(d['hex'])) ?? Cores.destaque.toARGB32();
    }
    return saida;
  }

  static int? _lerHex(String s) {
    final h = s.replaceAll('#', '').trim();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }

  // ---------------- imagens e fichas ----------------

  static double _alturaImagem(double largura, double proporcao, String legenda) =>
      (largura / proporcao).clamp(80.0, 600.0) + (legenda.isEmpty ? 0 : 32);

  Future<String?> _perguntarFonteImagem({bool trocar = false}) =>
      showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: Text(trocar ? 'Trocar por uma imagem do aparelho' : 'Imagem do aparelho'),
              onTap: () => Navigator.pop(ctx, 'aparelho'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Endereço de uma imagem da internet'),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
          ]),
        ),
      );

  Future<(Map<String, dynamic>, (double, double))?> _novaImagem() async {
    final fonte = await _perguntarFonteImagem();
    if (fonte == null || !mounted) return null;
    if (fonte == 'link') {
      final d = await _editar(TiposQuadro.imagem, const {});
      return d == null ? null : (d, TiposQuadro.tamanho[TiposQuadro.imagem]!);
    }
    final r = await escolherImagem(context);
    if (r == null) return null;
    const w = 260.0;
    return (
      <String, dynamic>{'imagem': r.id, 'url': '', 'texto': ''},
      (w, _alturaImagem(w, r.proporcao, '')),
    );
  }

  Future<void> _editarImagem(ItemQuadro i) async {
    final temImagem = i.imagem.isNotEmpty || i.url.isNotEmpty;
    final op = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (temImagem)
            ListTile(
              leading: const Icon(Icons.zoom_in),
              title: const Text('Ver em tela cheia'),
              onTap: () => Navigator.pop(ctx, 'ver'),
            ),
          ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Trocar por uma imagem do aparelho'),
            onTap: () => Navigator.pop(ctx, 'aparelho'),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Usar o endereço de uma imagem'),
            onTap: () => Navigator.pop(ctx, 'link'),
          ),
          ListTile(
            leading: const Icon(Icons.short_text),
            title: const Text('Legenda'),
            onTap: () => Navigator.pop(ctx, 'legenda'),
          ),
        ]),
      ),
    );
    if (op == null || !mounted) return;
    if (op == 'ver') {
      _verImagem(i);
    } else if (op == 'aparelho') {
      final r = await escolherImagem(context);
      if (r == null) return;
      _f.mudarItem(widget.quadroId, i.id, {
        'imagem': r.id,
        'url': '',
        'h': _alturaImagem(i.w, r.proporcao, i.texto),
      });
    } else if (op == 'link') {
      final d = await _editar(TiposQuadro.imagem, i.d);
      if (d != null) _f.mudarItem(widget.quadroId, i.id, {...d, 'imagem': ''});
    } else if (op == 'legenda') {
      final t = await pedirTexto(context, 'Legenda', inicial: i.texto);
      if (t != null) _f.mudarItem(widget.quadroId, i.id, {'texto': t});
    }
  }

  void _verImagem(ItemQuadro i) {
    if (i.imagem.isNotEmpty) {
      verImagem(context, i.imagem, titulo: i.texto);
    } else if (i.url.isNotEmpty) {
      abrirLink(context, i.url);
    }
  }

  Future<Map<String, dynamic>?> _escolherFicha() async {
    final l = await Repo.fichasEditaveis().first;
    if (!mounted) return null;
    if (l.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nenhuma ficha para mostrar.')));
      return null;
    }
    final f = await showDialog<Ficha>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Qual ficha?'),
        children: [
          for (final f in l)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f),
              child: Row(children: [
                AvatarFicha(
                    foto: f.foto, nome: f.nome, tamanho: 36, transformacao: f.eTransformacao),
                const SizedBox(width: 10),
                Expanded(child: Text(f.nome)),
              ]),
            ),
        ],
      ),
    );
    return f == null ? null : {'ficha': f.id, 'titulo': f.nome};
  }

  void _abrirFicha(ItemQuadro i) {
    if (i.ficha.isEmpty) return;
    Navigator.push(
        context, rotaFicha(i.ficha));
  }

  // ---------------- ações do cartão selecionado ----------------

  ItemQuadro? get _itemSel => _selecionado == null ? null : _quadro.itens[_selecionado];

  Future<void> _editarSelecionado() async {
    final i = _itemSel;
    if (i == null) return;
    if (i.tipo == TiposQuadro.imagem) {
      await _editarImagem(i);
    } else if (i.tipo == TiposQuadro.desenho) {
      _comecarDesenho(i);
    } else if (i.tipo == TiposQuadro.ficha) {
      final d = await _escolherFicha();
      if (d != null) _f.mudarItem(widget.quadroId, i.id, d);
    } else if (i.tipo == TiposQuadro.quadro && i.subquadro.isNotEmpty) {
      // renomeia o quadro de dentro junto
      final d = await _editar(i.tipo, i.d);
      if (d == null) return;
      _f.mudarItem(widget.quadroId, i.id, d);
      _f.criarQuadro(i.subquadro, asStr(d['titulo'], 'Quadro'));
    } else {
      final d = await _editar(i.tipo, i.d);
      if (d != null) _f.mudarItem(widget.quadroId, i.id, d);
    }
  }

  void _doisToques(ItemQuadro i) {
    setState(() => _selecionado = i.id);
    if (i.tipo == TiposQuadro.quadro) {
      _abrirSub(i);
    } else if (i.tipo == TiposQuadro.ficha) {
      _abrirFicha(i);
    } else if (i.tipo == TiposQuadro.imagem && i.imagem.isNotEmpty) {
      _verImagem(i);
    } else {
      _editarSelecionado();
    }
  }

  Future<void> _escolherCor() async {
    final i = _itemSel;
    if (i == null) return;
    final cor = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cor do cartão'),
        content: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final c in coresCartao)
            InkWell(
              onTap: () => Navigator.pop(ctx, c),
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: i.cor == c ? Cores.destaque : Cores.borda, width: 3),
                ),
              ),
            ),
        ]),
      ),
    );
    if (cor != null) _f.mudarItem(widget.quadroId, i.id, {'cor': cor});
  }

  void _duplicar() {
    final i = _itemSel;
    if (i == null) return;
    final id = novoId();
    final m = Map<String, dynamic>.from(i.d)
      ..['x'] = i.x + 30
      ..['y'] = i.y + 30
      ..['z'] = _zTopo
      ..remove('coluna')
      ..remove('comentarios');
    if (i.tipo == TiposQuadro.quadro) {
      // a cópia aponta para um quadro novo, vazio
      final sub = novoId();
      m['subquadro'] = sub;
      _f.criarQuadro(sub, i.titulo);
    }
    _f.salvarItem(widget.quadroId, ItemQuadro(id, m));
    setState(() => _selecionado = id);
  }

  void _paraFrente() {
    final i = _itemSel;
    if (i != null) _f.mudarItem(widget.quadroId, i.id, {'z': _zTopo});
  }

  Future<void> _apagar() async {
    final i = _itemSel;
    if (i == null) return;
    if (i.tipo == TiposQuadro.quadro) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Apagar quadro?'),
          content: Text('"${i.titulo}" e tudo que está dentro dele serão apagados.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final q = _quadro;
    final ligacoes = q.ligacoes.values.where((l) => l.de == i.id || l.para == i.id).toList();
    final filhos = q.itens.values.where((c) => c.coluna == i.id).toList();
    _f.apagarItem(widget.quadroId, i.id);
    for (final l in ligacoes) {
      _f.apagarLigacao(widget.quadroId, l.id);
    }
    for (final (n, c) in filhos.indexed) {
      // cartões de uma coluna apagada ficam soltos ao lado dela
      _f.mudarItem(widget.quadroId, c.id,
          {'coluna': null, 'x': i.x + i.w + 30, 'y': i.y + n * 40.0});
    }
    if (i.tipo == TiposQuadro.quadro && i.subquadro.isNotEmpty) {
      _f.apagarQuadro(i.subquadro);
    }
    setState(() => _selecionado = null);
    if (!mounted || i.tipo == TiposQuadro.quadro) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${TiposQuadro.nomes[i.tipo]} apagado.'),
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () {
          _f.salvarItem(widget.quadroId, i);
          for (final l in ligacoes) {
            _f.salvarLigacao(widget.quadroId, l);
          }
          for (final c in filhos) {
            _f.mudarItem(widget.quadroId, c.id, {'coluna': i.id});
          }
        },
      ),
    ));
  }

  void _tirarDaColuna() {
    final i = _itemSel;
    if (i == null || i.coluna == null) return;
    final col = _quadro.itens[i.coluna];
    _f.mudarItem(widget.quadroId, i.id, {
      'coluna': null,
      'x': (col?.x ?? i.x) + (col?.w ?? 0) + 30,
      'y': col?.y ?? i.y,
      'z': _zTopo,
    });
  }

  void _moverNaColuna(int passo) {
    final i = _itemSel;
    if (i == null || i.coluna == null) return;
    final irmaos = _filhos(i.coluna!);
    final k = irmaos.indexWhere((c) => c.id == i.id);
    final alvo = k + passo;
    if (k < 0 || alvo < 0 || alvo >= irmaos.length) return;
    final outro = irmaos[alvo];
    _f.mudarItem(widget.quadroId, i.id, {'ordem': outro.ordem});
    _f.mudarItem(widget.quadroId, outro.id, {'ordem': i.ordem == outro.ordem ? i.ordem + passo : i.ordem});
  }

  List<ItemQuadro> _filhos(String colunaId) => _quadro.itens.values
      .where((c) => c.coluna == colunaId)
      .toList()
    ..sort((a, b) => a.ordem.compareTo(b.ordem));

  // ---------------- comentários ----------------

  Future<void> _comentarios(ItemQuadro i) async {
    final ctl = TextEditingController();
    void enviar() {
      final t = ctl.text.trim();
      if (t.isEmpty) return;
      _f.comentar(widget.quadroId, i.id, {
        'id': novoId(),
        'uid': Repo.uid,
        'autor': Repo.nomeUsuario,
        'texto': t,
        'em': DateTime.now().millisecondsSinceEpoch,
      });
      ctl.clear();
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Comentários • ${TiposQuadro.nomes[i.tipo]}'),
        content: SizedBox(
          width: 440,
          child: StreamBuilder<Map<String, Quadro>>(
            stream: _f.todos,
            initialData: _quadros,
            builder: (ctx, s) {
              final item = s.data?[widget.quadroId]?.itens[i.id] ?? i;
              final l = item.comentarios;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (l.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Nenhum comentário ainda.',
                          style: TextStyle(color: Cores.textoFraco)),
                    ),
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final c in l)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                              '${asStr(c['autor'], '?')} • ${formatarHora(asInt(c['em']))}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, color: Cores.destaque)),
                          subtitle: Text(asStr(c['texto']),
                              style: const TextStyle(color: Cores.texto, fontSize: 14)),
                          trailing: asStr(c['uid']) == Repo.uid
                              ? IconButton(
                                  tooltip: 'Apagar comentário',
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () =>
                                      _f.apagarComentario(widget.quadroId, i.id, c),
                                )
                              : null,
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ctl,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Escreva um comentário',
                      suffixIcon: IconButton(
                        tooltip: 'Enviar',
                        icon: const Icon(Icons.send),
                        onPressed: enviar,
                      ),
                    ),
                    onSubmitted: (_) => enviar(),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }

  // ---------------- caneta ----------------

  void _comecarDesenho(ItemQuadro? i) {
    _tracos.clear();
    if (i != null) {
      // os traços guardados voltam para a escala do quadro
      final r = _retanguloDe(_quadro, i.id) ?? _retangulo(i);
      final (s, o) = _encaixe(i.bw, i.bh, r.size);
      for (final t in _lerTracos(i)) {
        _tracos.add(_Traco(t.cor, t.esp * s, [
          for (final p in t.pts) r.topLeft + o + p * s,
        ]));
      }
    }
    setState(() {
      _caneta = true;
      _borracha = false;
      _editandoDesenho = i?.id;
      _selecionado = null;
      _conectando = false;
      _origemLigacao = null;
    });
  }

  void _sairDoDesenho() => setState(() {
        _caneta = false;
        _borracha = false;
        _editandoDesenho = null;
        _tracos.clear();
        _ponteiro = null;
        _tracoAberto = false;
      });

  void _concluirDesenho() {
    final tracos = _tracos.where((t) => t.pts.isNotEmpty).toList();
    final editando = _editandoDesenho;
    if (tracos.isEmpty) {
      // apagou tudo de um desenho que já existia: o cartão sai junto
      if (editando != null) _f.apagarItem(widget.quadroId, editando);
      _sairDoDesenho();
      return;
    }
    var esq = double.infinity, topo = double.infinity;
    var dir = -double.infinity, base = -double.infinity;
    for (final t in tracos) {
      for (final p in t.pts) {
        esq = min(esq, p.dx - t.esp / 2);
        topo = min(topo, p.dy - t.esp / 2);
        dir = max(dir, p.dx + t.esp / 2);
        base = max(base, p.dy + t.esp / 2);
      }
    }
    const folga = 10.0;
    esq -= folga;
    topo -= folga;
    final w = max(dir + folga - esq, 40.0);
    final h = max(base + folga - topo, 40.0);
    double r1(double v) => (v * 10).roundToDouble() / 10;
    final dados = <String, dynamic>{
      'tracos': [
        for (final t in tracos)
          {
            'c': t.cor,
            'e': r1(t.esp),
            'p': [
              for (final p in t.pts) ...[r1(p.dx - esq), r1(p.dy - topo)]
            ],
          },
      ],
      'bw': w,
      'bh': h,
    };
    if (editando != null && _quadro.itens[editando] != null) {
      _f.mudarItem(widget.quadroId, editando, {...dados, 'x': esq, 'y': topo, 'w': w, 'h': h});
    } else {
      _criar(TiposQuadro.desenho, dados, tam: (w, h), canto: Offset(esq, topo));
    }
    _sairDoDesenho();
  }

  void _apagarPerto(Offset p) {
    _tracos.removeWhere((t) {
      final raio = 12 + t.esp / 2;
      if (t.pts.length == 1) return (t.pts.first - p).distance <= raio;
      for (var k = 1; k < t.pts.length; k++) {
        if (_distSegmento(p, t.pts[k - 1], t.pts[k]) <= raio) return true;
      }
      return false;
    });
  }

  void _canetaDesce(PointerDownEvent e) {
    if (_ponteiro != null) {
      // segundo dedo: é zoom, não traço
      if (_tracoAberto && _tracos.isNotEmpty) _tracos.removeLast();
      _ponteiro = null;
      _tracoAberto = false;
      _tinta.value++;
      return;
    }
    _ponteiro = e.pointer;
    if (_borracha) {
      _apagarPerto(e.localPosition);
    } else {
      _tracos.add(_Traco(_corCaneta, _espessura, [e.localPosition]));
      _tracoAberto = true;
    }
    _tinta.value++;
  }

  void _canetaMove(PointerMoveEvent e) {
    if (e.pointer != _ponteiro) return;
    if (_borracha) {
      _apagarPerto(e.localPosition);
    } else if (_tracoAberto && _tracos.isNotEmpty) {
      final pts = _tracos.last.pts;
      if ((pts.last - e.localPosition).distance < 2) return;
      pts.add(e.localPosition);
    }
    _tinta.value++;
  }

  void _canetaSobe(PointerEvent e) {
    if (e.pointer != _ponteiro) return;
    setState(() {
      _ponteiro = null;
      _tracoAberto = false;
    });
  }

  // ---------------- arrastar e soltar ----------------

  Offset _posDe(ItemQuadro i) => _pos[i.id] ?? Offset(i.x, i.y);
  Size _tamDe(ItemQuadro i) => _tam[i.id] ?? Size(i.w, i.h);

  void _arrastar(ItemQuadro i, Offset delta) {
    setState(() {
      final p = _posDe(i) + delta;
      _pos[i.id] = Offset(p.dx.clamp(0.0, _lado - 60), p.dy.clamp(0.0, _lado - 60));
    });
  }

  void _soltar(ItemQuadro i) {
    final p = _pos[i.id];
    if (p == null) return;
    final campos = <String, dynamic>{'x': p.dx, 'y': p.dy};
    // Solto em cima de uma coluna: entra nela.
    if (i.tipo != TiposQuadro.coluna) {
      final centro = p + Offset(_tamDe(i).width / 2, 30);
      for (final col in _quadro.itens.values.where((c) => c.tipo == TiposQuadro.coluna)) {
        final r = Rect.fromLTWH(col.x, col.y, col.w, _alturaColuna(col));
        if (r.contains(centro)) {
          final ultimos = _filhos(col.id);
          campos['coluna'] = col.id;
          campos['ordem'] = ultimos.isEmpty ? 0 : ultimos.last.ordem + 1;
          break;
        }
      }
    }
    _f.mudarItem(widget.quadroId, i.id, campos);
    // mantém a posição local até o servidor devolver o valor novo
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _pos.remove(i.id));
    });
  }

  void _redimensionar(ItemQuadro i, Offset delta) {
    setState(() {
      final t = _tamDe(i);
      final minAlt = const {
            TiposQuadro.quadro: 130.0,
            TiposQuadro.link: 90.0,
            TiposQuadro.tarefas: 90.0,
            TiposQuadro.imagem: 80.0,
            TiposQuadro.ficha: 80.0,
          }[i.tipo] ??
          50.0;
      final minLarg = i.tipo == TiposQuadro.desenho ? 40.0 : 120.0;
      _tam[i.id] = Size(max(minLarg, t.width + delta.dx), max(minAlt, t.height + delta.dy));
    });
  }

  void _soltarTamanho(ItemQuadro i) {
    final t = _tam[i.id];
    if (t == null) return;
    _f.mudarItem(widget.quadroId, i.id, {'w': t.width, 'h': t.height});
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _tam.remove(i.id));
    });
  }

  double _alturaColuna(ItemQuadro col) {
    final f = _filhos(col.id);
    return 56.0 + (f.isEmpty ? 40.0 : f.fold<double>(0, (s, c) => s + _alturaNaColuna(c) + 8));
  }

  double _alturaNaColuna(ItemQuadro c) => min(c.h, 240.0);

  // ---------------- ligações ----------------

  static bool _solto(Quadro q, ItemQuadro i) =>
      i.coluna == null || q.itens[i.coluna!]?.tipo != TiposQuadro.coluna;

  void _tocarItem(ItemQuadro i) {
    if (!_conectando) {
      setState(() => _selecionado = i.id);
      return;
    }
    if (_origemLigacao == null) {
      setState(() => _origemLigacao = i.id);
      return;
    }
    if (_origemLigacao != i.id) {
      _f.salvarLigacao(widget.quadroId,
          LigacaoQuadro(novoId(), {'de': _origemLigacao, 'para': i.id, 'seta': true}));
    }
    setState(() {
      _origemLigacao = null;
      _conectando = false;
    });
  }

  Future<void> _editarLigacao(LigacaoQuadro l) async {
    final corAtual = coresLigacao.entries
        .firstWhere((e) => e.value == l.cor, orElse: () => coresLigacao.entries.first)
        .key;
    final r = await editarFormulario(context,
        titulo: 'Ligação',
        inicial: {'texto': l.texto, 'seta': l.seta, 'tracejada': l.tracejada, 'cor': corAtual},
        campos: [
          const CampoDef('texto', 'Texto na ligação'),
          CampoDef('cor', 'Cor', tipo: TipoCampo.opcoes, opcoes: coresLigacao.keys.toList()),
          const CampoDef('seta', 'Com ponta de seta', tipo: TipoCampo.booleano),
          const CampoDef('tracejada', 'Linha tracejada', tipo: TipoCampo.booleano),
        ],
        podeApagar: true);
    if (r == null) return;
    if (r.apagar) {
      _f.apagarLigacao(widget.quadroId, l.id);
    } else if (r.dados != null) {
      final d = r.dados!;
      _f.salvarLigacao(
          widget.quadroId,
          LigacaoQuadro(l.id, {
            ...l.d,
            'texto': asStr(d['texto']),
            'seta': d['seta'] == true,
            'tracejada': d['tracejada'] == true,
            'cor': coresLigacao[asStr(d['cor'])],
          }));
    }
  }

  Rect _retangulo(ItemQuadro i) {
    final p = _posDe(i);
    final t = _tamDe(i);
    final h = i.tipo == TiposQuadro.coluna ? _alturaColuna(i) : t.height;
    return Rect.fromLTWH(p.dx, p.dy, t.width, h);
  }

  /// Retângulo de qualquer cartão, também dos que estão dentro de colunas.
  Rect? _retanguloDe(Quadro q, String id) {
    final i = q.itens[id];
    if (i == null) return null;
    if (_solto(q, i)) return _retangulo(i);
    final col = q.itens[i.coluna!]!;
    final p = _posDe(col);
    var y = p.dy + 41; // cabeçalho da coluna
    for (final c in _filhos(col.id)) {
      if (c.id == id) {
        return Rect.fromLTWH(p.dx + 9, y, _tamDe(col).width - 18, _alturaNaColuna(c));
      }
      y += _alturaNaColuna(c) + 8;
    }
    return _retangulo(col);
  }

  // ---------------- montagem ----------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, Quadro>>(
      stream: _dados,
      builder: (context, snap) {
        if (snap.hasData) _quadros = snap.data!;
        final q = _quadro;
        final itens = q.itens.values.toList()..sort((a, b) => a.z.compareTo(b.z));
        final soltos = itens.where((i) => _solto(q, i)).toList();
        final sel = _itemSel;
        // As setas que tocam cartões de dentro das colunas vão por cima, para
        // a ponta não sumir atrás da coluna.
        final ligacoes = <_Ligacao>[];
        final ligacoesPorCima = <_Ligacao>[];
        for (final l in q.ligacoes.values) {
          final a = _retanguloDe(q, l.de), b = _retanguloDe(q, l.para);
          if (a == null || b == null) continue;
          final lig = _Ligacao(a, b, l.seta, l.tracejada,
              l.cor == null ? Cores.roxoClaro : Color(l.cor!));
          final dentro = !_solto(q, q.itens[l.de]!) || !_solto(q, q.itens[l.para]!);
          (dentro ? ligacoesPorCima : ligacoes).add(lig);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(q.d.isEmpty ? _f.nomeRaiz : q.nome, style: estiloTitulo(17, cor: Cores.texto)),
            actions: [
              IconButton(
                tooltip: 'Afastar',
                icon: const Icon(Icons.zoom_out),
                onPressed: () => _zoom(1 / 1.3),
              ),
              IconButton(
                tooltip: 'Aproximar',
                icon: const Icon(Icons.zoom_in),
                onPressed: () => _zoom(1.3),
              ),
              IconButton(
                tooltip: 'Ver tudo',
                icon: const Icon(Icons.fit_screen),
                onPressed: _verTudo,
              ),
              IconButton(
                tooltip: 'Como usar',
                icon: const Icon(Icons.help_outline),
                onPressed: _ajuda,
              ),
            ],
          ),
          body: Column(children: [
            if (snap.hasError)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Não consegui abrir o quadro: ${snap.error}'),
              ),
            if (_caneta)
              _BarraCaneta(
                cor: _corCaneta,
                espessura: _espessura,
                borracha: _borracha,
                podeDesfazer: _tracos.isNotEmpty,
                aoCor: (c) => setState(() {
                  _corCaneta = c;
                  _borracha = false;
                }),
                aoEspessura: (e) => setState(() {
                  _espessura = e;
                  _borracha = false;
                }),
                aoBorracha: () => setState(() => _borracha = !_borracha),
                aoDesfazer: () => setState(() {
                  if (_tracos.isNotEmpty) _tracos.removeLast();
                  _tinta.value++;
                }),
                aoConcluir: _concluirDesenho,
                aoCancelar: _sairDoDesenho,
              )
            else if (_conectando)
              _Aviso(
                texto: _origemLigacao == null
                    ? 'Toque no cartão de onde a seta sai (pode ser um de dentro de uma coluna).'
                    : 'Agora toque no cartão de destino.',
                aoCancelar: () => setState(() {
                  _conectando = false;
                  _origemLigacao = null;
                }),
              )
            else if (sel != null)
              _BarraSelecao(
                item: sel,
                aoEditar: _editarSelecionado,
                aoCor: _escolherCor,
                aoDuplicar: _duplicar,
                aoFrente: _paraFrente,
                aoApagar: _apagar,
                aoComentar: () => _comentarios(sel),
                aoAbrir: sel.tipo == TiposQuadro.quadro
                    ? () => _abrirSub(sel)
                    : (sel.tipo == TiposQuadro.ficha ? () => _abrirFicha(sel) : null),
                aoVer: sel.tipo == TiposQuadro.imagem && (sel.imagem.isNotEmpty || sel.url.isNotEmpty)
                    ? () => _verImagem(sel)
                    : null,
                aoTirarDaColuna: sel.coluna != null ? _tirarDaColuna : null,
                aoSubir: sel.coluna != null ? () => _moverNaColuna(-1) : null,
                aoDescer: sel.coluna != null ? () => _moverNaColuna(1) : null,
                aoFechar: () => setState(() => _selecionado = null),
              ),
            Expanded(
              child: ClipRect(
                key: _chaveArea,
                child: InteractiveViewer(
                  transformationController: _vista,
                  constrained: false,
                  minScale: 0.2,
                  maxScale: 2.5,
                  // com a caneta, um dedo desenha e dois dão zoom
                  panEnabled: !_caneta,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: GestureDetector(
                    onTap: () => setState(() => _selecionado = null),
                    child: SizedBox(
                      width: _lado,
                      height: _lado,
                      child: Stack(clipBehavior: Clip.none, children: [
                        const Positioned.fill(
                            child: RepaintBoundary(child: CustomPaint(painter: _PintorPontos()))),
                        Positioned.fill(child: CustomPaint(painter: _PintorLigacoes(ligacoes))),
                        for (final i in soltos)
                          if (i.id != _editandoDesenho) _cartaoPosicionado(i),
                        if (ligacoesPorCima.isNotEmpty)
                          Positioned.fill(
                              child: IgnorePointer(
                                  child: CustomPaint(painter: _PintorLigacoes(ligacoesPorCima)))),
                        for (final l in q.ligacoes.values) ..._rotuloLigacao(q, l),
                        if (_caneta)
                          Positioned.fill(
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: _canetaDesce,
                              onPointerMove: _canetaMove,
                              onPointerUp: _canetaSobe,
                              onPointerCancel: _canetaSobe,
                              child: CustomPaint(painter: _PintorTracos(_tracos, repaint: _tinta)),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          bottomNavigationBar: _caneta
              ? null
              : _BarraFerramentas(
                  aoAdicionar: _adicionar,
                  conectando: _conectando,
                  aoConectar: () => setState(() {
                    _conectando = !_conectando;
                    _origemLigacao = null;
                    _selecionado = null;
                  }),
                ),
        );
      },
    );
  }

  List<Widget> _rotuloLigacao(Quadro q, LigacaoQuadro l) {
    final a = _retanguloDe(q, l.de), b = _retanguloDe(q, l.para);
    if (a == null || b == null) return const [];
    final meio = Offset.lerp(a.center, b.center, 0.5)!;
    final cor = l.cor == null ? Cores.roxoClaro : Color(l.cor!);
    return [
      Positioned(
        left: meio.dx - 60,
        top: meio.dy - 14,
        width: 120,
        child: Center(
          child: GestureDetector(
            onTap: () => _editarLigacao(l),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Cores.painel2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: cor.withValues(alpha: 0.6)),
              ),
              child: Text(l.texto.isEmpty ? '•••' : l.texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Cores.texto)),
            ),
          ),
        ),
      ),
    ];
  }

  void _abrirSub(ItemQuadro i) {
    if (i.subquadro.isEmpty) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TelaQuadro(fonte: _f, quadroId: i.subquadro)));
  }

  Widget _cartaoPosicionado(ItemQuadro i) {
    final p = _posDe(i);
    final t = _tamDe(i);
    final coluna = i.tipo == TiposQuadro.coluna;
    final selecionado = _selecionado == i.id || _origemLigacao == i.id;
    return Positioned(
      left: p.dx,
      top: p.dy,
      width: t.width,
      height: coluna ? _alturaColuna(i) : t.height,
      child: GestureDetector(
        onTap: () => _tocarItem(i),
        onDoubleTap: () => _doisToques(i),
        onPanStart: (_) => setState(() => _selecionado = i.id),
        onPanUpdate: (d) => _arrastar(i, d.delta),
        onPanEnd: (_) => _soltar(i),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: coluna
                ? _ColunaQuadro(
                    coluna: i,
                    filhos: _filhos(i.id),
                    selecionado: selecionado,
                    selecionadoFilho: _selecionado,
                    origemLigacao: _origemLigacao,
                    alturaFilho: _alturaNaColuna,
                    aoTocarFilho: _tocarItem,
                    aoDoisToquesFilho: _doisToques,
                    aoComentarios: _comentarios,
                    aoMarcar: (c, k) => _marcarTarefa(c, k),
                  )
                : _CartaoQuadro(
                    item: i,
                    selecionado: selecionado,
                    aoMarcar: (k) => _marcarTarefa(i, k),
                    aoComentarios: () => _comentarios(i),
                  ),
          ),
          if (_selecionado == i.id && !coluna)
            Positioned(
              right: 2,
              bottom: 2,
              child: GestureDetector(
                onPanUpdate: (d) => _redimensionar(i, d.delta),
                onPanEnd: (_) => _soltarTamanho(i),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Cores.destaque,
                    shape: BoxShape.circle,
                    border: Border.all(color: Cores.fundo, width: 2),
                  ),
                  child: Icon(Icons.open_in_full, size: 14, color: Cores.sobreDestaque),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _marcarTarefa(ItemQuadro i, int k) {
    final l = i.tarefas;
    if (k < 0 || k >= l.length) return;
    l[k] = {...l[k], 'ok': l[k]['ok'] != true};
    _f.mudarItem(widget.quadroId, i.id, {'tarefas': l});
  }

  void _ajuda() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Como usar o quadro'),
        content: const SingleChildScrollView(
          child: Text(
            '• Use a barra de baixo para criar notas, títulos, listas de tarefas, links, imagens, desenhos, fichas, cores, colunas e quadros.\n'
            '• Imagens podem vir do aparelho (galeria, câmera ou arquivo) ou de um endereço da internet.\n'
            '• "Desenho" liga a caneta: um dedo (ou o mouse) desenha e dois dedos dão zoom. Escolha cor, espessura ou a borracha em cima e toque em Concluir.\n'
            '• Arraste um cartão para mover. Arraste o fundo para andar pelo quadro e use dois dedos (ou a rodinha do mouse) para o zoom. Os botões de lupa e "Ver tudo" ficam no topo.\n'
            '• Toque num cartão para selecionar: em cima aparecem editar, cor, comentários, duplicar, trazer para a frente e apagar. A bolinha no canto muda o tamanho.\n'
            '• Dois toques editam o cartão; num quadro ou numa ficha, abrem o que está dentro; numa imagem, mostram em tela cheia.\n'
            '• Notas aceitam **negrito**, *itálico*, ~~riscado~~, "# " para título, "- " para lista e "[ ] " para caixinha.\n'
            '• Solte um cartão em cima de uma coluna para guardá-lo nela.\n'
            '• "Ligar" cria uma seta: toque no cartão de origem e depois no de destino (também os de dentro das colunas). Toque no texto da seta para escrever, mudar a cor, deixar tracejada ou apagar.\n'
            '• Nas listas de tarefas, toque nas caixinhas para marcar.',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
      ),
    );
  }
}

// ---------------- cartões ----------------

class _CartaoQuadro extends StatelessWidget {
  final ItemQuadro item;
  final bool selecionado;
  final void Function(int) aoMarcar;
  final VoidCallback? aoComentarios;
  const _CartaoQuadro(
      {required this.item, required this.selecionado, required this.aoMarcar, this.aoComentarios});

  @override
  Widget build(BuildContext context) {
    final i = item;
    final semFundo = i.tipo == TiposQuadro.titulo || i.tipo == TiposQuadro.desenho;
    // sem cor escolhida, o cartão pega o tom da afinidade da ficha
    final cor = i.cor != null ? Color(i.cor!) : Color.lerp(Color(coresCartao.first), Cores.destaque, 0.14)!;
    final conteudo = conteudoCartao(context, i, aoMarcar);
    final n = i.comentarios.length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: semFundo
            ? Colors.transparent
            : (i.tipo == TiposQuadro.cor ? Color(i.cor ?? 0xFFF5C42C) : cor),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selecionado
              ? Cores.destaque
              : (semFundo ? Colors.transparent : Colors.white.withValues(alpha: 0.10)),
          width: selecionado ? 2.5 : 1,
        ),
        boxShadow: semFundo
            ? null
            : const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: n == 0
          ? conteudo
          : Stack(children: [
              Positioned.fill(child: conteudo),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: aoComentarios,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Cores.destaque,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble, size: 11, color: Cores.sobreDestaque),
                      const SizedBox(width: 3),
                      Text('$n',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Cores.sobreDestaque)),
                    ]),
                  ),
                ),
              ),
            ]),
    );
  }
}

/// Conteúdo de um cartão, usado solto e dentro das colunas.
Widget conteudoCartao(BuildContext context, ItemQuadro i, void Function(int) aoMarcar) {
  const pad = EdgeInsets.all(10);
  switch (i.tipo) {
    case TiposQuadro.titulo:
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(i.texto.isEmpty ? 'Título' : i.texto,
              style: estiloTitulo(26, cor: Cores.destaque)),
        ),
      );
    case TiposQuadro.tarefas:
      final l = i.tarefas;
      final feitas = l.where((t) => t['ok'] == true).length;
      return Padding(
        padding: pad,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(i.titulo.isEmpty ? 'Tarefas' : i.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Text('$feitas/${l.length}',
                style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              for (var k = 0; k < l.length; k++)
                InkWell(
                  onTap: () => aoMarcar(k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Icon(
                          l[k]['ok'] == true ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 18,
                          color: l[k]['ok'] == true ? Cores.ok : Cores.textoFraco),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(asStr(l[k]['t']),
                            style: TextStyle(
                                decoration: l[k]['ok'] == true ? TextDecoration.lineThrough : null,
                                color: l[k]['ok'] == true ? Cores.textoFraco : Cores.texto)),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      );
    case TiposQuadro.link:
      return Padding(
        padding: pad,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.link, size: 18, color: Cores.destaque),
            const SizedBox(width: 6),
            Expanded(
              child: Text(i.titulo.isEmpty ? i.url : i.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
          if (i.texto.isNotEmpty)
            Expanded(
              child: Text(i.texto,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(fontSize: 13, color: Cores.textoFraco)),
            )
          else
            const Spacer(),
          InkWell(
            onTap: () => abrirLink(context, i.url),
            child: Text(i.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Cores.roxoClaro, decoration: TextDecoration.underline)),
          ),
        ]),
      );
    case TiposQuadro.imagem:
      final Widget foto;
      if (i.imagem.isNotEmpty) {
        foto = ImagemSalva(id: i.imagem);
      } else if (i.url.isEmpty) {
        foto = const Center(child: Icon(Icons.image_outlined, size: 40));
      } else {
        foto = Image.network(i.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
                child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Não consegui abrir a imagem.', textAlign: TextAlign.center))));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: foto),
        if (i.texto.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(i.texto, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ),
      ]);
    case TiposQuadro.desenho:
      return CustomPaint(
        painter: _PintorTracos(_lerTracos(i), base: Size(i.bw, i.bh)),
        size: Size.infinite,
      );
    case TiposQuadro.ficha:
      return _CartaoFicha(item: i);
    case TiposQuadro.cor:
      final c = Color(i.cor ?? 0xFFF5C42C);
      final escuro = c.computeLuminance() < 0.4;
      final hex = '#${(i.cor ?? 0xFFF5C42C).toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      return Padding(
        padding: pad,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.titulo.isEmpty ? 'Cor' : i.titulo,
              style: TextStyle(fontWeight: FontWeight.w800, color: escuro ? Colors.white : Colors.black)),
          Text(hex, style: TextStyle(fontSize: 12, color: escuro ? Colors.white70 : Colors.black54)),
        ]),
      );
    case TiposQuadro.quadro:
      return Padding(
        padding: pad,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.dashboard_outlined, size: 40, color: Cores.destaque),
          const SizedBox(height: 6),
          Text(i.titulo.isEmpty ? 'Quadro' : i.titulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const Text('dois toques para abrir',
              style: TextStyle(fontSize: 11, color: Cores.textoFraco)),
        ]),
      );
    default:
      return Padding(
        padding: pad,
        child: i.texto.isEmpty
            ? const Text('Nota vazia', style: TextStyle(fontSize: 14, color: Cores.textoFraco))
            : textoNota(i.texto),
      );
  }
}

/// Texto de nota com formatação simples: **negrito**, *itálico*, ~~riscado~~,
/// "# " e "## " para títulos, "- " para lista e "[ ] " / "[x] " para caixinhas.
Widget textoNota(String texto) {
  const base = TextStyle(fontSize: 14, color: Cores.texto);
  final spans = <InlineSpan>[];
  final linhas = texto.split('\n');
  for (var k = 0; k < linhas.length; k++) {
    var l = linhas[k];
    var estilo = base;
    InlineSpan? caixa;
    if (l.startsWith('## ')) {
      l = l.substring(3);
      estilo = base.copyWith(fontSize: 16, fontWeight: FontWeight.w800);
    } else if (l.startsWith('# ')) {
      l = l.substring(2);
      estilo = base.copyWith(fontSize: 19, fontWeight: FontWeight.w900, color: Cores.destaque);
    } else if (l.startsWith('- ') || l.startsWith('* ')) {
      l = '•  ${l.substring(2)}';
    } else if (l.startsWith('[ ] ')) {
      l = ' ${l.substring(4)}';
      caixa = const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.check_box_outline_blank, size: 16, color: Cores.textoFraco));
    } else if (l.toLowerCase().startsWith('[x] ')) {
      l = ' ${l.substring(4)}';
      caixa = const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.check_box, size: 16, color: Cores.ok));
      estilo = base.copyWith(color: Cores.textoFraco, decoration: TextDecoration.lineThrough);
    }
    if (caixa != null) spans.add(caixa);
    spans.addAll(_trechos(l, estilo));
    if (k < linhas.length - 1) spans.add(const TextSpan(text: '\n'));
  }
  return Text.rich(TextSpan(children: spans), overflow: TextOverflow.fade);
}

final _marcas = RegExp(r'\*\*(.+?)\*\*|~~(.+?)~~|\*(.+?)\*');

List<InlineSpan> _trechos(String l, TextStyle estilo) {
  final saida = <InlineSpan>[];
  var i = 0;
  for (final m in _marcas.allMatches(l)) {
    if (m.start > i) saida.add(TextSpan(text: l.substring(i, m.start), style: estilo));
    if (m.group(1) != null) {
      saida.add(TextSpan(text: m.group(1), style: estilo.copyWith(fontWeight: FontWeight.w800)));
    } else if (m.group(2) != null) {
      saida.add(TextSpan(
          text: m.group(2), style: estilo.copyWith(decoration: TextDecoration.lineThrough)));
    } else {
      saida.add(TextSpan(text: m.group(3), style: estilo.copyWith(fontStyle: FontStyle.italic)));
    }
    i = m.end;
  }
  if (i < l.length) saida.add(TextSpan(text: l.substring(i), style: estilo));
  return saida;
}

/// Cartão que mostra uma ficha ao vivo (foto, nome e PV).
class _CartaoFicha extends StatefulWidget {
  final ItemQuadro item;
  const _CartaoFicha({required this.item});
  @override
  State<_CartaoFicha> createState() => _CartaoFichaState();
}

class _CartaoFichaState extends State<_CartaoFicha> {
  late Stream<Ficha?> _ficha = _abrir();

  Stream<Ficha?> _abrir() =>
      widget.item.ficha.isEmpty ? Stream.value(null) : Repo.ficha(widget.item.ficha);

  @override
  void didUpdateWidget(covariant _CartaoFicha old) {
    super.didUpdateWidget(old);
    if (old.item.ficha != widget.item.ficha) _ficha = _abrir();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Ficha?>(
      stream: _ficha,
      builder: (context, s) {
        final f = s.data;
        final i = widget.item;
        final nome = f?.nome ?? (i.titulo.isEmpty ? 'Ficha' : i.titulo);
        final c = f == null ? null : Calc(f, null);
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            AvatarFicha(
                foto: f?.foto ?? '',
                nome: nome,
                tamanho: 56,
                transformacao: f?.eTransformacao ?? false),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (f != null && c != null) ...[
                      Text('${f.classe} • ${c.resumoProgressao}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
                      Text('PV ${f.pvAtual}/${c.pvMax}',
                          style: const TextStyle(fontSize: 12, color: Cores.pv)),
                    ] else if (s.hasError)
                      const Text('Sem acesso a esta ficha.',
                          style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
                  ]),
            ),
          ]),
        );
      },
    );
  }
}

Future<void> abrirLink(BuildContext context, String url) async {
  var u = url.trim();
  if (u.isEmpty) return;
  if (!u.contains('://')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Não consegui abrir $url')));
  }
}

class _ColunaQuadro extends StatelessWidget {
  final ItemQuadro coluna;
  final List<ItemQuadro> filhos;
  final bool selecionado;
  final String? selecionadoFilho;
  final String? origemLigacao;
  final double Function(ItemQuadro) alturaFilho;
  final void Function(ItemQuadro) aoTocarFilho;
  final void Function(ItemQuadro) aoDoisToquesFilho;
  final void Function(ItemQuadro) aoComentarios;
  final void Function(ItemQuadro, int) aoMarcar;
  const _ColunaQuadro({
    required this.coluna,
    required this.filhos,
    required this.selecionado,
    required this.selecionadoFilho,
    required this.origemLigacao,
    required this.alturaFilho,
    required this.aoTocarFilho,
    required this.aoDoisToquesFilho,
    required this.aoComentarios,
    required this.aoMarcar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(coluna.cor ?? 0xFF1A1426).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: selecionado ? Cores.destaque : Cores.borda, width: selecionado ? 2.5 : 1),
      ),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 40,
          child: Row(children: [
            Expanded(
              child: Text(coluna.titulo.isEmpty ? 'Coluna' : coluna.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, color: Cores.destaque, letterSpacing: 1)),
            ),
            Text('${filhos.length}', style: const TextStyle(color: Cores.textoFraco, fontSize: 12)),
          ]),
        ),
        if (filhos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Solte cartões aqui', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
          ),
        for (final c in filhos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => aoTocarFilho(c),
              onDoubleTap: () => aoDoisToquesFilho(c),
              child: SizedBox(
                height: alturaFilho(c),
                child: _CartaoQuadro(
                  item: c,
                  selecionado: selecionadoFilho == c.id || origemLigacao == c.id,
                  aoMarcar: (k) => aoMarcar(c, k),
                  aoComentarios: () => aoComentarios(c),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ---------------- barras ----------------

class _BarraFerramentas extends StatelessWidget {
  final void Function(String) aoAdicionar;
  final bool conectando;
  final VoidCallback aoConectar;
  const _BarraFerramentas({required this.aoAdicionar, required this.conectando, required this.aoConectar});

  @override
  Widget build(BuildContext context) {
    const botoes = [
      (TiposQuadro.nota, Icons.sticky_note_2_outlined),
      (TiposQuadro.titulo, Icons.title),
      (TiposQuadro.tarefas, Icons.checklist),
      (TiposQuadro.link, Icons.link),
      (TiposQuadro.imagem, Icons.image_outlined),
      (TiposQuadro.desenho, Icons.brush_outlined),
      (TiposQuadro.ficha, Icons.badge_outlined),
      (TiposQuadro.cor, Icons.palette_outlined),
      (TiposQuadro.coluna, Icons.view_column_outlined),
      (TiposQuadro.quadro, Icons.dashboard_outlined),
    ];
    return Material(
      color: Cores.painel2,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: FaixaRolavel(padding: const EdgeInsets.symmetric(horizontal: 6), children: [
            for (final b in botoes)
              _BotaoFerramenta(icone: b.$2, rotulo: TiposQuadro.nomes[b.$1]!, aoTocar: () => aoAdicionar(b.$1)),
            const VerticalDivider(width: 12),
            _BotaoFerramenta(
              icone: Icons.arrow_right_alt,
              rotulo: conectando ? 'Cancelar' : 'Ligar',
              ativo: conectando,
              aoTocar: aoConectar,
            ),
          ]),
        ),
      ),
    );
  }
}

class _BotaoFerramenta extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final bool ativo;
  final VoidCallback aoTocar;
  const _BotaoFerramenta({required this.icone, required this.rotulo, required this.aoTocar, this.ativo = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: ativo
              ? BoxDecoration(color: Cores.destaque.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))
              : null,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icone, color: Cores.destaque),
            const SizedBox(height: 2),
            Text(rotulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );
}

class _BarraSelecao extends StatelessWidget {
  final ItemQuadro item;
  final VoidCallback aoEditar, aoCor, aoDuplicar, aoFrente, aoApagar, aoFechar, aoComentar;
  final VoidCallback? aoAbrir, aoVer, aoTirarDaColuna, aoSubir, aoDescer;
  const _BarraSelecao({
    required this.item,
    required this.aoEditar,
    required this.aoCor,
    required this.aoDuplicar,
    required this.aoFrente,
    required this.aoApagar,
    required this.aoFechar,
    required this.aoComentar,
    this.aoAbrir,
    this.aoVer,
    this.aoTirarDaColuna,
    this.aoSubir,
    this.aoDescer,
  });

  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, String dica, VoidCallback? f) =>
        IconButton(tooltip: dica, icon: Icon(i), onPressed: f);
    final n = item.comentarios.length;
    final semCor = item.tipo == TiposQuadro.titulo || item.tipo == TiposQuadro.desenho;
    return Material(
      color: Cores.painel2,
      child: SizedBox(
        height: 48,
        child: FaixaRolavel(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Text(TiposQuadro.nomes[item.tipo] ?? '',
                style: TextStyle(color: Cores.destaque, fontWeight: FontWeight.w800)),
          ),
          if (aoAbrir != null)
            b(Icons.open_in_new,
                item.tipo == TiposQuadro.ficha ? 'Abrir ficha' : 'Abrir quadro', aoAbrir),
          if (aoVer != null) b(Icons.zoom_in, 'Ver em tela cheia', aoVer),
          b(item.tipo == TiposQuadro.desenho ? Icons.brush_outlined : Icons.edit_outlined,
              item.tipo == TiposQuadro.desenho ? 'Desenhar' : 'Editar', aoEditar),
          if (!semCor) b(Icons.format_color_fill, 'Cor', aoCor),
          b(Icons.chat_bubble_outline, n == 0 ? 'Comentários' : 'Comentários ($n)', aoComentar),
          b(Icons.copy_outlined, 'Duplicar', aoDuplicar),
          if (item.coluna == null) b(Icons.flip_to_front, 'Trazer para a frente', aoFrente),
          if (aoSubir != null) b(Icons.arrow_upward, 'Subir na coluna', aoSubir),
          if (aoDescer != null) b(Icons.arrow_downward, 'Descer na coluna', aoDescer),
          if (aoTirarDaColuna != null) b(Icons.logout, 'Tirar da coluna', aoTirarDaColuna),
          b(Icons.delete_outline, 'Apagar', aoApagar),
          b(Icons.close, 'Fechar', aoFechar),
        ]),
      ),
    );
  }
}

class _BarraCaneta extends StatelessWidget {
  final int cor;
  final double espessura;
  final bool borracha, podeDesfazer;
  final ValueChanged<int> aoCor;
  final ValueChanged<double> aoEspessura;
  final VoidCallback aoBorracha, aoDesfazer, aoConcluir, aoCancelar;
  const _BarraCaneta({
    required this.cor,
    required this.espessura,
    required this.borracha,
    required this.podeDesfazer,
    required this.aoCor,
    required this.aoEspessura,
    required this.aoBorracha,
    required this.aoDesfazer,
    required this.aoConcluir,
    required this.aoCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cores.painel2,
      child: SizedBox(
        height: 52,
        child: FaixaRolavel(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (final c in coresCaneta)
              GestureDetector(
                onTap: () => aoCor(c),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  width: 28,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: !borracha && cor == c ? Cores.destaque : Cores.borda,
                        width: !borracha && cor == c ? 3 : 1),
                  ),
                ),
              ),
            const VerticalDivider(width: 16),
            for (final e in espessurasCaneta)
              IconButton(
                tooltip: 'Espessura',
                onPressed: () => aoEspessura(e),
                icon: Container(
                  width: e + 6,
                  height: e + 6,
                  decoration: BoxDecoration(
                    color: !borracha && espessura == e ? Cores.destaque : Cores.textoFraco,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Borracha (apaga o traço que tocar)',
              onPressed: aoBorracha,
              icon: Icon(Icons.auto_fix_normal, color: borracha ? Cores.destaque : null),
            ),
            IconButton(
              tooltip: 'Desfazer',
              onPressed: podeDesfazer ? aoDesfazer : null,
              icon: const Icon(Icons.undo),
            ),
            TextButton(onPressed: aoCancelar, child: const Text('Cancelar')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton(onPressed: aoConcluir, child: const Text('Concluir')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  final VoidCallback aoCancelar;
  const _Aviso({required this.texto, required this.aoCancelar});
  @override
  Widget build(BuildContext context) => Material(
        color: Cores.destaque.withValues(alpha: 0.2),
        child: Row(children: [
          const SizedBox(width: 12),
          Icon(Icons.arrow_right_alt, color: Cores.destaque),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
          TextButton(onPressed: aoCancelar, child: const Text('Cancelar')),
        ]),
      );
}

// ---------------- pintores ----------------

/// Pontinhos de fundo, como o papel do Milanote.
class _PintorPontos extends CustomPainter {
  const _PintorPontos();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (var x = 0.0; x < size.width; x += 40) {
      for (var y = 0.0; y < size.height; y += 40) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Traços de caneta. Com [base], escalam para caber no tamanho do cartão.
class _PintorTracos extends CustomPainter {
  final List<_Traco> tracos;
  final Size? base;
  _PintorTracos(this.tracos, {this.base, super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    var s = 1.0;
    var o = Offset.zero;
    final b = base;
    if (b != null) {
      final (es, desl) = _encaixe(b.width, b.height, size);
      s = es;
      o = desl;
    }
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.scale(s);
    for (final t in tracos) {
      if (t.pts.isEmpty) continue;
      final p = Paint()
        ..color = Color(t.cor)
        ..strokeWidth = t.esp
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (t.pts.length == 1) {
        canvas.drawCircle(t.pts.first, t.esp / 2, p..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(t.pts.first.dx, t.pts.first.dy);
      for (var k = 1; k < t.pts.length; k++) {
        final a = t.pts[k - 1];
        final m = (a + t.pts[k]) / 2;
        path.quadraticBezierTo(a.dx, a.dy, m.dx, m.dy);
      }
      path.lineTo(t.pts.last.dx, t.pts.last.dy);
      canvas.drawPath(path, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PintorTracos old) => true;
}

class _Ligacao {
  final Rect a, b;
  final bool seta, tracejada;
  final Color cor;
  const _Ligacao(this.a, this.b, this.seta, this.tracejada, this.cor);
}

class _PintorLigacoes extends CustomPainter {
  final List<_Ligacao> ligacoes;
  _PintorLigacoes(this.ligacoes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in ligacoes) {
      final traco = Paint()
        ..color = l.cor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final ini = _borda(l.a, l.b.center);
      final fim = _borda(l.b, l.a.center);
      if (l.tracejada) {
        _tracejar(canvas, ini, fim, traco);
      } else {
        canvas.drawLine(ini, fim, traco);
      }
      if (l.seta) {
        final ang = atan2(fim.dy - ini.dy, fim.dx - ini.dx);
        const t = 12.0;
        final ponta = Path()
          ..moveTo(fim.dx, fim.dy)
          ..lineTo(fim.dx - t * cos(ang - 0.45), fim.dy - t * sin(ang - 0.45))
          ..moveTo(fim.dx, fim.dy)
          ..lineTo(fim.dx - t * cos(ang + 0.45), fim.dy - t * sin(ang + 0.45));
        canvas.drawPath(ponta, traco);
      }
    }
  }

  static void _tracejar(Canvas c, Offset a, Offset b, Paint p) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += 14) {
      c.drawLine(a + dir * d, a + dir * min(d + 8, total), p);
    }
  }

  /// Ponto na borda do retângulo na direção do alvo.
  static Offset _borda(Rect r, Offset alvo) {
    final c = r.center;
    final d = alvo - c;
    if (d.dx == 0 && d.dy == 0) return c;
    final sx = d.dx == 0 ? double.infinity : (r.width / 2) / d.dx.abs();
    final sy = d.dy == 0 ? double.infinity : (r.height / 2) / d.dy.abs();
    final s = min(sx, sy);
    return c + d * min(s, 1.0);
  }

  @override
  bool shouldRepaint(covariant _PintorLigacoes old) => true;
}

/// Miniatura do quadro para mostrar dentro da ficha e do escudo.
class MiniQuadro extends StatelessWidget {
  final Quadro? quadro;
  const MiniQuadro({super.key, required this.quadro});

  @override
  Widget build(BuildContext context) {
    final itens = quadro?.itens.values.where((i) => i.coluna == null).toList() ?? const <ItemQuadro>[];
    if (itens.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Cores.painel2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Cores.borda),
        ),
        child: const Text('Quadro vazio. Abra para criar notas, imagens, desenhos, colunas e setas.',
            textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
      );
    }
    return Container(
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Cores.painel2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cores.borda),
      ),
      child: CustomPaint(painter: _PintorMini(itens, Cores.destaque), size: Size.infinite),
    );
  }
}

class _PintorMini extends CustomPainter {
  final List<ItemQuadro> itens;
  final Color destaque;
  _PintorMini(this.itens, this.destaque);

  @override
  void paint(Canvas canvas, Size size) {
    var limites = Rect.fromLTWH(itens.first.x, itens.first.y, itens.first.w, max(itens.first.h, 60.0));
    for (final i in itens) {
      limites = limites.expandToInclude(Rect.fromLTWH(i.x, i.y, i.w, max(i.h, 60.0)));
    }
    limites = limites.inflate(40);
    final escala = min(size.width / limites.width, size.height / limites.height);
    canvas.translate((size.width - limites.width * escala) / 2, (size.height - limites.height * escala) / 2);
    canvas.scale(escala);
    canvas.translate(-limites.left, -limites.top);
    for (final i in itens) {
      if (i.tipo == TiposQuadro.desenho) {
        canvas.save();
        canvas.translate(i.x, i.y);
        _PintorTracos(_lerTracos(i), base: Size(i.bw, i.bh)).paint(canvas, Size(i.w, i.h));
        canvas.restore();
        continue;
      }
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(i.x, i.y, i.w, max(i.h, 60.0)), const Radius.circular(10));
      final cor = i.tipo == TiposQuadro.titulo
          ? destaque.withValues(alpha: 0.6)
          : Color(i.cor ?? coresCartao.first);
      canvas.drawRRect(r, Paint()..color = cor);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorMini old) => true;
}
