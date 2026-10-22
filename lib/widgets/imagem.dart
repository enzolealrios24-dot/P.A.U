import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../data/imagens.dart';
import 'sigilos.dart';

/// Escolhe uma imagem do aparelho (no celular, da galeria ou da câmera),
/// comprime e grava. Devolve null se a pessoa desistir.
Future<ImagemEnviada?> escolherImagem(BuildContext context,
    {int lado = 1280}) async {
  var fonte = ImageSource.gallery;
  final celular = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (celular) {
    final f = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (f == null) return null;
    fonte = f;
  }
  XFile? x;
  try {
    x = await ImagePicker().pickImage(
        source: fonte,
        maxWidth: lado * 1.5,
        maxHeight: lado * 1.5,
        imageQuality: 92);
  } catch (e) {
    if (context.mounted) _aviso(context, 'Não consegui abrir as imagens: $e');
    return null;
  }
  if (x == null || !context.mounted) return null;
  final bytes = await x.readAsBytes();
  if (!context.mounted) return null;
  final r = await _esperando(context, Imagens.enviar(bytes, lado: lado));
  if (r == null && context.mounted) {
    _aviso(context, 'Não consegui ler essa imagem.');
  }
  return r;
}

/// Mostra "preparando" enquanto a imagem é comprimida.
Future<T?> _esperando<T>(BuildContext context, Future<T> trabalho) async {
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator()),
          SizedBox(width: 16),
          Expanded(child: Text('Preparando a imagem...')),
        ]),
      ),
    ),
  );
  try {
    return await trabalho;
  } catch (_) {
    return null;
  } finally {
    nav.pop();
  }
}

void _aviso(BuildContext context, String texto) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(texto)));

/// Imagem guardada em /imagens.
class ImagemSalva extends StatefulWidget {
  final String id;
  final BoxFit fit;
  final Alignment alinhamento;
  const ImagemSalva(
      {super.key, required this.id, this.fit = BoxFit.cover, this.alinhamento = Alignment.center});

  @override
  State<ImagemSalva> createState() => _ImagemSalvaState();
}

class _ImagemSalvaState extends State<ImagemSalva> {
  late Future<Uint8List?> _dados = Imagens.ler(widget.id);

  @override
  void didUpdateWidget(covariant ImagemSalva old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _dados = Imagens.ler(widget.id);
  }

  Widget _imagem(Uint8List b) => Image.memory(b,
      fit: widget.fit,
      alignment: widget.alinhamento,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium);

  @override
  Widget build(BuildContext context) {
    final pronta = Imagens.naMemoria(widget.id);
    if (pronta != null) return _imagem(pronta);
    return FutureBuilder<Uint8List?>(
      future: _dados,
      builder: (context, s) {
        final b = s.data;
        if (b != null) return _imagem(b);
        if (s.connectionState != ConnectionState.done) {
          return const Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return const Center(
            child: Icon(Icons.broken_image_outlined, color: Cores.textoFraco));
      },
    );
  }
}

double _n(dynamic v, double padrao) => v is num ? v.toDouble() : padrao;

/// Foto com o enquadramento escolhido pela pessoa: o ponto de foco (x, y de
/// -1 a 1) e o zoom. Sem ajuste, mostra o alto da foto, onde fica o rosto.
class FotoEnquadrada extends StatelessWidget {
  final String id;
  final Map<String, dynamic> ajuste;
  const FotoEnquadrada({super.key, required this.id, this.ajuste = const {}});

  static Alignment foco(Map<String, dynamic> a) =>
      Alignment(_n(a['x'], 0).clamp(-1.0, 1.0), _n(a['y'], -0.35).clamp(-1.0, 1.0));
  static double zoom(Map<String, dynamic> a) => _n(a['z'], 1).clamp(1.0, 4.0);

  @override
  Widget build(BuildContext context) {
    final f = foco(ajuste);
    return ClipRect(
      child: Transform.scale(
        scale: zoom(ajuste),
        alignment: f,
        child: ImagemSalva(id: id, alinhamento: f),
      ),
    );
  }
}

/// Retrato do personagem: foto em pé (3:4) com cantos arredondados, moldura
/// fina e volume; sem foto, o sigilo e as iniciais no lugar.
class RetratoFicha extends StatelessWidget {
  final String foto;
  final String nome;
  final Map<String, dynamic> ajuste;
  final double largura;
  /// Altura dividida pela largura.
  final double proporcao;
  final double? raio;
  /// Transformações ganham a moldura na cor secundária.
  final bool transformacao;
  final VoidCallback? aoTocar;
  /// Algo preso no canto de baixo (ex.: o botão da câmera).
  final Widget? canto;
  /// Liga este retrato ao de outra tela, para a foto "voar" entre elas.
  final String? heroi;
  const RetratoFicha({
    super.key,
    required this.foto,
    required this.nome,
    this.ajuste = const {},
    this.largura = 96,
    this.proporcao = 4 / 3,
    this.raio,
    this.transformacao = false,
    this.aoTocar,
    this.canto,
    this.heroi,
  });

  @override
  Widget build(BuildContext context) {
    final altura = largura * proporcao;
    final r = raio ?? 3.0;
    final grande = largura >= 60;
    final moldura = transformacao ? Cores.roxoClaro : Cores.destaque;
    Widget retrato = Container(
      width: largura,
      height: altura,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: grande
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: largura * 0.18,
                    offset: Offset(0, largura * 0.06)),
              ]
            : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
            color: moldura.withValues(alpha: grande ? 0.55 : 0.7), width: grande ? 1.5 : 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(fit: StackFit.expand, children: [
          if (foto.isEmpty)
            _SemFoto(nome: nome, largura: largura, cor: moldura)
          else
            FotoEnquadrada(id: foto, ajuste: ajuste),
          // brilho no alto e sombra embaixo dão volume à foto
          if (grande)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x17FFFFFF), Color(0x00FFFFFF), Color(0x00000000), Color(0x66000000)],
                  stops: [0, 0.22, 0.62, 1],
                ),
              ),
            ),
        ]),
      ),
    );
    if (heroi != null) retrato = Hero(tag: heroi!, child: retrato);
    if (canto != null) {
      retrato = Stack(clipBehavior: Clip.none, children: [
        retrato,
        Positioned(right: -8, bottom: -8, child: canto!),
      ]);
    }
    if (aoTocar == null) return retrato;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: aoTocar, child: retrato),
    );
  }
}

class _SemFoto extends StatelessWidget {
  final String nome;
  final double largura;
  final Color cor;
  const _SemFoto({required this.nome, required this.largura, required this.cor});

  @override
  Widget build(BuildContext context) {
    final iniciais = nome
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Cores.painel2, Color.lerp(Cores.painel2, Cores.roxo, 0.35)!],
        ),
      ),
      child: Stack(alignment: Alignment.center, children: [
        if (largura >= 40)
          SigiloConhecimento(
              tamanho: largura * 0.92, cor: cor.withValues(alpha: 0.13), espessura: 1),
        Text(iniciais.isEmpty ? '?' : iniciais,
            style: estiloTitulo(largura * 0.32, cor: cor, peso: FontWeight.w800, espaco: 1)),
      ]),
    );
  }
}

/// Foto pequena e quadrada do personagem, para listas e cabeçalhos.
class AvatarFicha extends StatelessWidget {
  final String foto;
  final String nome;
  final Map<String, dynamic> ajuste;
  final double tamanho;
  /// Transformações ganham a moldura na cor secundária.
  final bool transformacao;
  final VoidCallback? aoTocar;
  const AvatarFicha({
    super.key,
    required this.foto,
    required this.nome,
    this.ajuste = const {},
    this.tamanho = 44,
    this.transformacao = false,
    this.aoTocar,
  });

  @override
  Widget build(BuildContext context) => RetratoFicha(
        foto: foto,
        nome: nome,
        ajuste: ajuste,
        largura: tamanho,
        proporcao: 1,
        raio: tamanho * 0.14,
        transformacao: transformacao,
        aoTocar: aoTocar,
      );
}

/// Janela para escolher o enquadramento da foto: arrastar move, dois dedos
/// (ou a barra) dão zoom. Devolve o ajuste novo ou null.
Future<Map<String, dynamic>?> escolherEnquadramento(BuildContext context,
        {required String foto, String nome = '', Map<String, dynamic> ajuste = const {}}) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditorEnquadramento(foto: foto, nome: nome, ajuste: ajuste),
    );

class _EditorEnquadramento extends StatefulWidget {
  final String foto;
  final String nome;
  final Map<String, dynamic> ajuste;
  const _EditorEnquadramento({required this.foto, required this.nome, required this.ajuste});
  @override
  State<_EditorEnquadramento> createState() => _EditorEnquadramentoState();
}

class _EditorEnquadramentoState extends State<_EditorEnquadramento> {
  static const _largura = 210.0;
  late double _x = FotoEnquadrada.foco(widget.ajuste).x;
  late double _y = FotoEnquadrada.foco(widget.ajuste).y;
  late double _z = FotoEnquadrada.zoom(widget.ajuste);
  double _zInicio = 1;

  Map<String, dynamic> get _ajuste => {'x': _x, 'y': _y, 'z': _z};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enquadrar foto'),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Arraste para centralizar o rosto. Use dois dedos, a rodinha ou a barra para o zoom.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Cores.textoFraco)),
          const SizedBox(height: 16),
          GestureDetector(
            onScaleStart: (_) => _zInicio = _z,
            onScaleUpdate: (d) => setState(() {
              _z = (_zInicio * d.scale).clamp(1.0, 4.0);
              // arrastar para a direita mostra mais do lado esquerdo da foto
              _x = (_x - d.focalPointDelta.dx * 2.2 / (_largura * _z)).clamp(-1.0, 1.0);
              _y = (_y - d.focalPointDelta.dy * 2.2 / (_largura * 4 / 3 * _z)).clamp(-1.0, 1.0);
            }),
            child: Listener(
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  setState(() => _z = (_z - e.scrollDelta.dy / 400).clamp(1.0, 4.0));
                }
              },
              child: RetratoFicha(foto: widget.foto, nome: widget.nome, ajuste: _ajuste, largura: _largura),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.zoom_out, size: 20, color: Cores.textoFraco),
            Expanded(
              child: Slider(
                value: _z,
                min: 1,
                max: 4,
                onChanged: (v) => setState(() => _z = v),
              ),
            ),
            const Icon(Icons.zoom_in, size: 20, color: Cores.textoFraco),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AvatarFicha(foto: widget.foto, nome: widget.nome, ajuste: _ajuste, tamanho: 44),
            const SizedBox(width: 14),
            RetratoFicha(foto: widget.foto, nome: widget.nome, ajuste: _ajuste, largura: 60),
            const SizedBox(width: 14),
            const Text('Assim fica\nnas listas',
                style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
          ]),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _x = 0;
            _y = -0.35;
            _z = 1;
          }),
          child: const Text('Desfazer'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _ajuste), child: const Text('Salvar')),
      ],
    );
  }
}

/// Abre a imagem em tela cheia, com zoom.
void verImagem(BuildContext context, String id, {String titulo = ''}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: InteractiveViewer(
          maxScale: 6,
          child: Center(child: ImagemSalva(id: id, fit: BoxFit.contain)),
        ),
      ),
    ),
  );
}
