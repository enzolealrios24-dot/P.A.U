import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/quadro.dart';
import '../../widgets/form_dialog.dart';

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

const _lado = 4000.0; // tamanho da área do quadro

/// Quadro de anotações no estilo do Milanote: cartões soltos que se movem e
/// mudam de tamanho, colunas, listas de tarefas, links, imagens, cores,
/// quadros dentro de quadros e setas entre os cartões.
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
  String? _selecionado;
  bool _conectando = false;
  String? _origemLigacao;
  // Posições e tamanhos locais enquanto o dedo arrasta (gravados ao soltar).
  final _pos = <String, Offset>{};
  final _tam = <String, Size>{};
  Map<String, Quadro> _quadros = const {};

  FonteQuadro get _f => widget.fonte;
  Quadro get _quadro => _quadros[widget.quadroId] ?? Quadro(widget.quadroId, const {});

  @override
  void dispose() {
    _vista.dispose();
    super.dispose();
  }

  // ---------------- criar ----------------

  Offset _centroDaVista() {
    final caixa = _chaveArea.currentContext?.findRenderObject() as RenderBox?;
    final tamanho = caixa?.size ?? const Size(400, 600);
    final p = _vista.toScene(Offset(tamanho.width / 2, tamanho.height / 2));
    return Offset(p.dx.clamp(0.0, _lado - 300), p.dy.clamp(0.0, _lado - 300));
  }

  int get _zTopo =>
      _quadro.itens.values.fold<int>(0, (m, i) => max(m, i.z)) + 1;

  Future<void> _adicionar(String tipo) async {
    final dados = await _editar(tipo, const {});
    if (dados == null) return;
    final c = _centroDaVista();
    final tam = TiposQuadro.tamanho[tipo]!;
    final id = novoId();
    final m = <String, dynamic>{
      'tipo': tipo,
      'x': c.dx - tam.$1 / 2,
      'y': c.dy - (tam.$2 == 0 ? 60 : tam.$2 / 2),
      'w': tam.$1,
      'h': tam.$2,
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
        campos = const [CampoDef('texto', 'Nota', tipo: TipoCampo.multi)];
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

  // ---------------- ações do cartão selecionado ----------------

  ItemQuadro? get _itemSel => _selecionado == null ? null : _quadro.itens[_selecionado];

  Future<void> _editarSelecionado() async {
    final i = _itemSel;
    if (i == null) return;
    if (i.tipo == TiposQuadro.quadro && i.subquadro.isNotEmpty) {
      // renomeia o quadro de dentro junto
      final d = await _editar(i.tipo, i.d);
      if (d == null) return;
      _f.mudarItem(widget.quadroId, i.id, d);
      _f.criarQuadro(i.subquadro, asStr(d['titulo'], 'Quadro'));
      return;
    }
    final d = await _editar(i.tipo, i.d);
    if (d != null) _f.mudarItem(widget.quadroId, i.id, d);
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
      ..remove('coluna');
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
          }[i.tipo] ??
          50.0;
      _tam[i.id] = Size(max(120.0, t.width + delta.dx), max(minAlt, t.height + delta.dy));
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

  void _tocarItem(ItemQuadro i) {
    if (!_conectando) {
      setState(() => _selecionado = i.id);
      return;
    }
    if (i.coluna != null) return;
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
    final r = await editarFormulario(context,
        titulo: 'Ligação',
        inicial: {'texto': l.texto, 'seta': l.seta},
        campos: const [
          CampoDef('texto', 'Texto na ligação'),
          CampoDef('seta', 'Com ponta de seta', tipo: TipoCampo.booleano),
        ],
        podeApagar: true);
    if (r == null) return;
    if (r.apagar) {
      _f.apagarLigacao(widget.quadroId, l.id);
    } else if (r.dados != null) {
      _f.salvarLigacao(widget.quadroId,
          LigacaoQuadro(l.id, {...l.d, 'texto': asStr(r.dados!['texto']), 'seta': r.dados!['seta'] == true}));
    }
  }

  Rect _retangulo(ItemQuadro i) {
    final p = _posDe(i);
    final t = _tamDe(i);
    final h = i.tipo == TiposQuadro.coluna ? _alturaColuna(i) : t.height;
    return Rect.fromLTWH(p.dx, p.dy, t.width, h);
  }

  // ---------------- montagem ----------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, Quadro>>(
      stream: _f.todos,
      builder: (context, snap) {
        if (snap.hasData) _quadros = snap.data!;
        final q = _quadro;
        final itens = q.itens.values.toList()..sort((a, b) => a.z.compareTo(b.z));
        final soltos = itens
            .where((i) => i.coluna == null || q.itens[i.coluna!]?.tipo != TiposQuadro.coluna)
            .toList();
        final sel = _itemSel;
        return Scaffold(
          appBar: AppBar(
            title: Text(q.d.isEmpty ? _f.nomeRaiz : q.nome),
            actions: [
              IconButton(
                tooltip: 'Voltar ao começo do quadro',
                icon: const Icon(Icons.center_focus_strong_outlined),
                onPressed: () => _vista.value = Matrix4.identity(),
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
            if (_conectando)
              _Aviso(
                texto: _origemLigacao == null
                    ? 'Toque no cartão de onde a seta sai.'
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
                aoAbrir: sel.tipo == TiposQuadro.quadro ? () => _abrirSub(sel) : null,
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
                  boundaryMargin: const EdgeInsets.all(400),
                  child: GestureDetector(
                    onTap: () => setState(() => _selecionado = null),
                    child: SizedBox(
                      width: _lado,
                      height: _lado,
                      child: Stack(clipBehavior: Clip.none, children: [
                        const Positioned.fill(
                            child: RepaintBoundary(child: CustomPaint(painter: _PintorPontos()))),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PintorLigacoes(
                              [
                                for (final l in q.ligacoes.values)
                                  if (q.itens[l.de] != null &&
                                      q.itens[l.para] != null &&
                                      q.itens[l.de]!.coluna == null &&
                                      q.itens[l.para]!.coluna == null)
                                    (_retangulo(q.itens[l.de]!), _retangulo(q.itens[l.para]!), l.seta),
                              ],
                              Cores.roxoClaro,
                            ),
                          ),
                        ),
                        for (final i in soltos) _cartaoPosicionado(i),
                        for (final l in q.ligacoes.values) ..._rotuloLigacao(q, l),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          bottomNavigationBar: _BarraFerramentas(
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
    final a = q.itens[l.de], b = q.itens[l.para];
    if (a == null || b == null || a.coluna != null || b.coluna != null) return const [];
    final meio = Offset.lerp(_retangulo(a).center, _retangulo(b).center, 0.5)!;
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Cores.roxoClaro.withValues(alpha: 0.6)),
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
        onDoubleTap: () {
          setState(() => _selecionado = i.id);
          if (i.tipo == TiposQuadro.quadro) {
            _abrirSub(i);
          } else {
            _editarSelecionado();
          }
        },
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
                    alturaFilho: _alturaNaColuna,
                    aoTocarFilho: (c) => setState(() => _selecionado = c.id),
                    aoMarcar: (c, k) => _marcarTarefa(c, k),
                  )
                : _CartaoQuadro(
                    item: i,
                    selecionado: selecionado,
                    aoMarcar: (k) => _marcarTarefa(i, k),
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
            '• Use a barra de baixo para criar notas, títulos, listas de tarefas, links, imagens, cores, colunas e quadros.\n'
            '• Arraste um cartão para mover. Arraste o fundo para andar pelo quadro e use dois dedos (ou a rodinha do mouse) para o zoom.\n'
            '• Toque num cartão para selecionar: em cima aparecem editar, cor, duplicar, trazer para a frente e apagar. A bolinha no canto muda o tamanho.\n'
            '• Dois toques editam o cartão; num quadro, abrem o quadro de dentro.\n'
            '• Solte um cartão em cima de uma coluna para guardá-lo nela.\n'
            '• "Ligar" cria uma seta: toque no cartão de origem e depois no de destino. Toque no texto da seta para escrever nela ou apagar.\n'
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
  const _CartaoQuadro({required this.item, required this.selecionado, required this.aoMarcar});

  @override
  Widget build(BuildContext context) {
    final i = item;
    final semFundo = i.tipo == TiposQuadro.titulo;
    final cor = Color(i.cor ?? coresCartao.first);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: semFundo
            ? Colors.transparent
            : (i.tipo == TiposQuadro.cor ? Color(i.cor ?? 0xFFF5C42C) : cor),
        borderRadius: BorderRadius.circular(8),
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
      child: conteudoCartao(context, i, aoMarcar),
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
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, color: Cores.destaque)),
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
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: i.url.isEmpty
              ? const Center(child: Icon(Icons.image_outlined, size: 40))
              : Image.network(i.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Não consegui abrir a imagem.', textAlign: TextAlign.center)))),
        ),
        if (i.texto.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(i.texto, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ),
      ]);
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
        child: Text(i.texto.isEmpty ? 'Nota vazia' : i.texto,
            overflow: TextOverflow.fade,
            style: TextStyle(fontSize: 14, color: i.texto.isEmpty ? Cores.textoFraco : Cores.texto)),
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
  final double Function(ItemQuadro) alturaFilho;
  final void Function(ItemQuadro) aoTocarFilho;
  final void Function(ItemQuadro, int) aoMarcar;
  const _ColunaQuadro({
    required this.coluna,
    required this.filhos,
    required this.selecionado,
    required this.selecionadoFilho,
    required this.alturaFilho,
    required this.aoTocarFilho,
    required this.aoMarcar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(coluna.cor ?? 0xFF1A1426).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
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
              child: SizedBox(
                height: alturaFilho(c),
                child: _CartaoQuadro(
                  item: c,
                  selecionado: selecionadoFilho == c.id,
                  aoMarcar: (k) => aoMarcar(c, k),
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
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6), children: [
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: ativo
              ? BoxDecoration(color: Cores.destaque.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8))
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
  final VoidCallback aoEditar, aoCor, aoDuplicar, aoFrente, aoApagar, aoFechar;
  final VoidCallback? aoAbrir, aoTirarDaColuna, aoSubir, aoDescer;
  const _BarraSelecao({
    required this.item,
    required this.aoEditar,
    required this.aoCor,
    required this.aoDuplicar,
    required this.aoFrente,
    required this.aoApagar,
    required this.aoFechar,
    this.aoAbrir,
    this.aoTirarDaColuna,
    this.aoSubir,
    this.aoDescer,
  });

  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, String dica, VoidCallback? f) =>
        IconButton(tooltip: dica, icon: Icon(i), onPressed: f);
    return Material(
      color: Cores.painel2,
      child: SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Text(TiposQuadro.nomes[item.tipo] ?? '',
                style: TextStyle(color: Cores.destaque, fontWeight: FontWeight.w800)),
          ),
          if (aoAbrir != null) b(Icons.open_in_new, 'Abrir quadro', aoAbrir),
          b(Icons.edit_outlined, 'Editar', aoEditar),
          if (item.tipo != TiposQuadro.titulo) b(Icons.format_color_fill, 'Cor', aoCor),
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

class _PintorLigacoes extends CustomPainter {
  final List<(Rect, Rect, bool)> ligacoes;
  final Color cor;
  _PintorLigacoes(this.ligacoes, this.cor);

  @override
  void paint(Canvas canvas, Size size) {
    final traco = Paint()
      ..color = cor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (a, b, seta) in ligacoes) {
      final ini = _borda(a, b.center);
      final fim = _borda(b, a.center);
      canvas.drawLine(ini, fim, traco);
      if (seta) {
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Cores.borda),
        ),
        child: const Text('Quadro vazio. Abra para criar notas, listas, colunas e setas.',
            textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
      );
    }
    return Container(
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Cores.painel2,
        borderRadius: BorderRadius.circular(10),
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
