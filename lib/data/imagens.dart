import 'dart:collection';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'repo.dart';

/// Imagem já gravada: o id em /imagens e o tamanho dela em pixels.
class ImagemEnviada {
  final String id;
  final int largura, altura;
  const ImagemEnviada(this.id, this.largura, this.altura);
  double get proporcao => altura == 0 ? 1 : largura / altura;
}

/// Fotos dos personagens e imagens do quadro, guardadas no próprio Firestore
/// (sem Firebase Storage): cada imagem é comprimida para caber num documento
/// de /imagens. O id é sorteado; quem tem o id (as fichas e os quadros que
/// usam a imagem) consegue ler, e só quem enviou apaga.
class Imagens {
  static CollectionReference<Json> get col => Repo.db.collection('imagens');

  /// Tamanho máximo de cada imagem, abaixo do limite de 1 MB do documento.
  static const limiteBytes = 900 * 1024;

  // Imagens já abertas nesta sessão (as mais antigas saem primeiro).
  static final _cache = LinkedHashMap<String, Uint8List>();
  static final _lendo = <String, Future<Uint8List?>>{};

  static Uint8List? naMemoria(String id) => _cache[id];

  static void _guardar(String id, Uint8List b) {
    _cache.remove(id);
    _cache[id] = b;
    while (_cache.length > 80) {
      _cache.remove(_cache.keys.first);
    }
  }

  static Future<Uint8List?> ler(String id) {
    if (id.isEmpty) return Future.value(null);
    final c = _cache[id];
    if (c != null) return Future.value(c);
    return _lendo.putIfAbsent(id, () async {
      try {
        final s = await col.doc(id).get();
        final d = s.data()?['dados'];
        if (d is! Blob) return null;
        _guardar(id, d.bytes);
        return d.bytes;
      } finally {
        _lendo.remove(id);
      }
    });
  }

  /// Comprime e grava uma imagem. Ela já pode ser mostrada na hora; o envio
  /// ao servidor segue em segundo plano (também funciona offline).
  static Future<ImagemEnviada?> enviar(Uint8List original,
      {int lado = 1280}) async {
    final r = await compute(_comprimir, (original, lado));
    if (r == null) return null;
    return _gravar(r.$1, r.$2, r.$3);
  }

  static ImagemEnviada _gravar(Uint8List bytes, int largura, int altura) {
    final ref = col.doc();
    _guardar(ref.id, bytes);
    ref.set({
      'dono': Repo.uid,
      'dados': Blob(bytes),
      'largura': largura,
      'altura': altura,
      'criadoEm': DateTime.now().millisecondsSinceEpoch,
    }).catchError((Object e) => Repo.onErro?.call(_mensagem(e)));
    return ImagemEnviada(ref.id, largura, altura);
  }

  /// Grava uma cópia própria da imagem (para fichas e cartões duplicados,
  /// que assim podem trocar ou apagar a foto sem mexer no original).
  static Future<String?> copiar(String id) async {
    try {
      final d = (await col.doc(id).get()).data();
      final b = d?['dados'];
      if (d == null || b is! Blob) return null;
      return _gravar(b.bytes, (d['largura'] as num?)?.toInt() ?? 0,
              (d['altura'] as num?)?.toInt() ?? 0)
          .id;
    } catch (_) {
      return null;
    }
  }

  /// Apaga a imagem do servidor. Se ela foi enviada por outra pessoa, o
  /// Firestore não deixa e a imagem só fica sem uso.
  static void apagar(String id) {
    if (id.isEmpty) return;
    _cache.remove(id);
    col.doc(id).delete().catchError((Object _) {});
  }

  static Object _mensagem(Object e) =>
      e is FirebaseException && e.code == 'permission-denied'
          ? 'sem permissão para guardar imagens. Cole as regras novas do arquivo firestore.rules no Firebase (Firestore Database > Regras).'
          : e;
}

/// Diminui a imagem até caber no limite. Fotos viram JPEG; imagens com
/// transparência continuam PNG quando cabem.
(Uint8List, int, int)? _comprimir((Uint8List, int) entrada) {
  final (bytes, lado) = entrada;
  var im = img.decodeImage(bytes);
  if (im == null) return null;
  im = img.bakeOrientation(im);
  var limite = lado;
  var qualidade = 85;
  while (true) {
    var r = im;
    if (im.width > limite || im.height > limite) {
      r = im.width >= im.height
          ? img.copyResize(im,
              width: limite, interpolation: img.Interpolation.linear)
          : img.copyResize(im,
              height: limite, interpolation: img.Interpolation.linear);
    }
    if (r.numChannels == 4) {
      final png = img.encodePng(r);
      if (png.length < Imagens.limiteBytes) return (png, r.width, r.height);
      // transparente demais para PNG: vira JPEG com o fundo escuro do app
      final fundo = img.Image(width: r.width, height: r.height);
      img.fill(fundo, color: img.ColorRgb8(26, 20, 38));
      r = img.compositeImage(fundo, r);
    }
    final jpg = img.encodeJpg(r, quality: qualidade);
    if (jpg.length < Imagens.limiteBytes || limite <= 320) {
      return (jpg, r.width, r.height);
    }
    if (qualidade > 60) {
      qualidade -= 10;
    } else {
      limite = (limite * 0.75).round();
    }
  }
}
