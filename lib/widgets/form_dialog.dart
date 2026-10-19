import 'package:flutter/material.dart';

import '../data/models.dart';

enum TipoCampo { texto, numero, multi, opcoes, booleano }

class CampoDef {
  final String chave;
  final String rotulo;
  final TipoCampo tipo;
  final List<String> opcoes;
  final String? dica;
  final bool meiaLargura;
  const CampoDef(this.chave, this.rotulo,
      {this.tipo = TipoCampo.texto,
      this.opcoes = const [],
      this.dica,
      this.meiaLargura = false});
}

class ResultadoForm {
  final Map<String, dynamic>? dados;
  final bool apagar;
  const ResultadoForm({this.dados, this.apagar = false});
}

/// Dialogo generico de edicao (itens, rituais, poderes, ameacas...).
Future<ResultadoForm?> editarFormulario(
  BuildContext context, {
  required String titulo,
  required Map<String, dynamic> inicial,
  required List<CampoDef> campos,
  bool podeApagar = false,
}) {
  return showDialog<ResultadoForm>(
    context: context,
    builder: (ctx) => _FormDialog(
        titulo: titulo, inicial: inicial, campos: campos, podeApagar: podeApagar),
  );
}

class _FormDialog extends StatefulWidget {
  final String titulo;
  final Map<String, dynamic> inicial;
  final List<CampoDef> campos;
  final bool podeApagar;
  const _FormDialog(
      {required this.titulo,
      required this.inicial,
      required this.campos,
      required this.podeApagar});
  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final Map<String, dynamic> _v = Map<String, dynamic>.from(widget.inicial);
  final Map<String, TextEditingController> _ctl = {};

  @override
  void initState() {
    super.initState();
    for (final c in widget.campos) {
      if (c.tipo == TipoCampo.texto ||
          c.tipo == TipoCampo.numero ||
          c.tipo == TipoCampo.multi) {
        _ctl[c.chave] = TextEditingController(text: asStr(_v[c.chave]));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _coletar() {
    final r = Map<String, dynamic>.from(_v);
    for (final c in widget.campos) {
      final t = _ctl[c.chave];
      if (t == null) continue;
      r[c.chave] = c.tipo == TipoCampo.numero
          ? (int.tryParse(t.text.trim()) ?? 0)
          : t.text.trim();
    }
    return r;
  }

  Widget _campo(CampoDef c) {
    switch (c.tipo) {
      case TipoCampo.texto:
      case TipoCampo.numero:
      case TipoCampo.multi:
        return TextField(
          controller: _ctl[c.chave],
          maxLines: c.tipo == TipoCampo.multi ? 5 : 1,
          minLines: 1,
          keyboardType: c.tipo == TipoCampo.numero
              ? const TextInputType.numberWithOptions(signed: true)
              : (c.tipo == TipoCampo.multi
                  ? TextInputType.multiline
                  : TextInputType.text),
          decoration: InputDecoration(labelText: c.rotulo, hintText: c.dica),
        );
      case TipoCampo.opcoes:
        final atual = asStr(_v[c.chave]);
        final ops = [...c.opcoes];
        if (atual.isNotEmpty && !ops.contains(atual)) ops.insert(0, atual);
        return InputDecorator(
          decoration: InputDecoration(labelText: c.rotulo),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              isExpanded: true,
              value: atual.isEmpty ? null : atual,
              items: [
                for (final o in ops) DropdownMenuItem(value: o, child: Text(o))
              ],
              onChanged: (x) => setState(() => _v[c.chave] = x ?? ''),
            ),
          ),
        );
      case TipoCampo.booleano:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(c.rotulo),
          value: asBool(_v[c.chave]),
          onChanged: (x) => setState(() => _v[c.chave] = x),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final w = largura > 640 ? 520.0 : (largura - 130).clamp(200.0, 520.0);
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: w,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in widget.campos)
                SizedBox(
                  width: c.meiaLargura ? (w - 10) / 2 : w,
                  child: _campo(c),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.podeApagar)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const ResultadoForm(apagar: true)),
            child: const Text('Apagar', style: TextStyle(color: Colors.redAccent)),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, ResultadoForm(dados: _coletar())),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
