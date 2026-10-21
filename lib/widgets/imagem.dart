import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../data/imagens.dart';

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
  const ImagemSalva({super.key, required this.id, this.fit = BoxFit.cover});

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

  @override
  Widget build(BuildContext context) {
    final pronta = Imagens.naMemoria(widget.id);
    if (pronta != null) {
      return Image.memory(pronta, fit: widget.fit, gaplessPlayback: true);
    }
    return FutureBuilder<Uint8List?>(
      future: _dados,
      builder: (context, s) {
        final b = s.data;
        if (b != null) {
          return Image.memory(b, fit: widget.fit, gaplessPlayback: true);
        }
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

/// Foto redonda do personagem, ou as iniciais quando não tem foto.
class AvatarFicha extends StatelessWidget {
  final String foto;
  final String nome;
  final double tamanho;
  /// Transformações ganham a borda roxa.
  final bool transformacao;
  final VoidCallback? aoTocar;
  const AvatarFicha({
    super.key,
    required this.foto,
    required this.nome,
    this.tamanho = 44,
    this.transformacao = false,
    this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final iniciais = nome
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    final borda = transformacao ? Cores.roxoClaro : Cores.destaque;
    final circulo = Container(
      width: tamanho,
      height: tamanho,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borda, width: tamanho >= 60 ? 3 : 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Cores.painel2, Cores.roxo.withValues(alpha: 0.6)],
        ),
      ),
      child: foto.isEmpty
          ? Center(
              child: Text(iniciais.isEmpty ? '?' : iniciais,
                  style: TextStyle(
                      fontSize: tamanho * 0.36,
                      fontWeight: FontWeight.w900,
                      color: borda)))
          : ImagemSalva(id: foto),
    );
    if (aoTocar == null) return circulo;
    return InkWell(
        onTap: aoTocar, customBorder: const CircleBorder(), child: circulo);
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
