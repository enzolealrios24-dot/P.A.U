import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Tema de cores escolhido, guardado no aparelho.
class TemaApp {
  static const _chave = 'tema_cores';
  static final atual = ValueNotifier<String>(temasCores.first.id);

  /// Tema do app (fora das fichas).
  static TemaCores get tema => _porId(atual.value);

  static TemaCores _porId(String id) =>
      temasCores.firstWhere((t) => t.id == id, orElse: () => temasCores.first);

  static Future<void> carregar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final id = p.getString(_chave) ?? temasCores.first.id;
      Cores.aplicar(_porId(id));
      atual.value = _porId(id).id;
    } catch (_) {
      // sem acesso ao armazenamento: fica no tema padrão
    }
  }

  /// Troca o tema: o app se redesenha inteiro com as cores novas.
  static Future<void> escolher(String id) async {
    final t = _porId(id);
    Cores.aplicar(t);
    atual.value = t.id;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_chave, t.id);
    } catch (_) {}
  }
}
