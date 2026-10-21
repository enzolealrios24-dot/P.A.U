import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dice.dart';
import '../core/theme.dart';

/// Campo de texto que salva sozinho (com atraso) e nao "pula" enquanto voce
/// digita, mesmo recebendo atualizacoes em tempo real.
class CampoSync extends StatefulWidget {
  final String valor;
  final ValueChanged<String> aoSalvar;
  final String? rotulo;
  final int maxLinhas;
  final bool numerico;
  final TextAlign alinhamento;
  final TextStyle? estilo;
  final String? dica;
  const CampoSync({
    super.key,
    required this.valor,
    required this.aoSalvar,
    this.rotulo,
    this.maxLinhas = 1,
    this.numerico = false,
    this.alinhamento = TextAlign.start,
    this.estilo,
    this.dica,
  });

  @override
  State<CampoSync> createState() => _CampoSyncState();
}

class _CampoSyncState extends State<CampoSync> {
  late final TextEditingController _c = TextEditingController(text: widget.valor);
  final _foco = FocusNode();
  Timer? _t;
  String? _pendente;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _salvarAgora();
    });
  }

  @override
  void didUpdateWidget(covariant CampoSync old) {
    super.didUpdateWidget(old);
    if (!_foco.hasFocus && _pendente == null && _c.text != widget.valor) {
      _c.text = widget.valor;
    }
  }

  void _salvarAgora() {
    _t?.cancel();
    final p = _pendente;
    if (p != null) {
      _pendente = null;
      if (p != widget.valor) widget.aoSalvar(p);
    }
  }

  @override
  void dispose() {
    _salvarAgora();
    _t?.cancel();
    _foco.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _foco,
      maxLines: widget.maxLinhas,
      minLines: 1,
      textAlign: widget.alinhamento,
      style: widget.estilo,
      keyboardType: widget.numerico
          ? const TextInputType.numberWithOptions(signed: true)
          : (widget.maxLinhas > 1 ? TextInputType.multiline : TextInputType.text),
      inputFormatters: widget.numerico
          ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))]
          : null,
      decoration: InputDecoration(labelText: widget.rotulo, hintText: widget.dica),
      onChanged: (v) {
        _pendente = v;
        _t?.cancel();
        _t = Timer(const Duration(milliseconds: 700), _salvarAgora);
      },
      onSubmitted: (_) => _salvarAgora(),
    );
  }
}

class CampoNumero extends StatelessWidget {
  final int valor;
  final ValueChanged<int> aoSalvar;
  final String? rotulo;
  const CampoNumero(
      {super.key, required this.valor, required this.aoSalvar, this.rotulo});
  @override
  Widget build(BuildContext context) => CampoSync(
        valor: '$valor',
        numerico: true,
        rotulo: rotulo,
        alinhamento: TextAlign.center,
        aoSalvar: (s) => aoSalvar(int.tryParse(s) ?? 0),
      );
}

/// Barra de PV/PE/SAN: « -5, ‹ -1, toque no número para digitar, › +1, » +5.
class BarraStatus extends StatelessWidget {
  final String rotulo;
  final int atual;
  final int max;
  final Color cor;
  final ValueChanged<int> aoMudar; // novo valor
  final bool compacta;
  const BarraStatus({
    super.key,
    required this.rotulo,
    required this.atual,
    required this.max,
    required this.cor,
    required this.aoMudar,
    this.compacta = false,
  });

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (atual / max).clamp(0.0, 1.0);
    // Barra cheia com « ‹ valor › », como no CRIS original.
    Widget seta(IconData icone, int d) => InkWell(
          onTap: () => aoMudar(atual + d),
          borderRadius: BorderRadius.circular(6),
          child: Tooltip(
            message: d > 0 ? '+$d' : '$d',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compacta ? 2 : 5),
              child: Icon(icone, size: compacta ? 18 : 22, color: Colors.white),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rotulo,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: cor,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: compacta ? 11 : 13)),
        const SizedBox(height: 3),
        Container(
          height: compacta ? 30 : 38,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cor.withValues(alpha: 0.6)),
          ),
          child: Stack(fit: StackFit.expand, children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [cor.withValues(alpha: 0.7), cor]),
                ),
              ),
            ),
            Row(children: [
              seta(Icons.keyboard_double_arrow_left, -5),
              seta(Icons.chevron_left, -1),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final v = await pedirNumero(context, rotulo, atual);
                    if (v != null) aoMudar(v);
                  },
                  child: Center(
                    child: Text('$atual / $max',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: compacta ? 14 : 17,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 3)
                            ])),
                  ),
                ),
              ),
              seta(Icons.chevron_right, 1),
              seta(Icons.keyboard_double_arrow_right, 5),
            ]),
          ]),
        ),
      ],
    );
  }
}

Future<int?> pedirNumero(BuildContext context, String titulo, int atual) {
  final c = TextEditingController(text: '$atual');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: const InputDecoration(
            helperText: 'Use +N ou -N para somar/subtrair'),
        onSubmitted: (_) => Navigator.pop(ctx, _interpretar(c.text, atual)),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, _interpretar(c.text, atual)),
            child: const Text('OK')),
      ],
    ),
  );
}

int? _interpretar(String s, int atual) {
  final t = s.trim();
  if (t.startsWith('+')) {
    final v = int.tryParse(t.substring(1));
    return v == null ? null : atual + v;
  }
  if (t.startsWith('-') && t.length > 1) {
    final v = int.tryParse(t.substring(1));
    return v == null ? null : atual - v;
  }
  return int.tryParse(t);
}

Future<String?> pedirTexto(BuildContext context, String titulo,
    {String inicial = '', String? dica}) {
  final c = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: dica),
        onSubmitted: (_) => Navigator.pop(ctx, c.text.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirmar(BuildContext context, String texto) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(texto),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar')),
      ],
    ),
  );
  return r ?? false;
}

void mostrarRolagem(BuildContext context, Rolagem r) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Cores.painel,
      title: Text(r.titulo, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${r.total}',
              style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: r.critico
                      ? Cores.ok
                      : (r.falhaCritica ? Cores.destaque : Cores.texto))),
          if (r.critico)
            const Text('CRÍTICO!',
                style: TextStyle(color: Cores.ok, fontWeight: FontWeight.bold)),
          if (r.falhaCritica)
            Text('Resultado natural 1',
                style: TextStyle(color: Cores.destaque)),
          const SizedBox(height: 8),
          Text(r.detalhe,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Cores.textoFraco)),
          if (r.danoTotal != null) ...[
            const Divider(height: 24),
            Text('Dano: ${r.danoTotal}',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Cores.destaque)),
            Text(r.danoDetalhe ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Cores.textoFraco)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))
      ],
    ),
  );
}

class Secao extends StatelessWidget {
  final String titulo;
  final Widget child;
  final List<Widget> acoes;
  const Secao(
      {super.key, required this.titulo, required this.child, this.acoes = const []});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 3,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Cores.destaque, Cores.roxo]),
                  ),
                ),
                Expanded(
                  child: Text(titulo.toUpperCase(),
                      style: TextStyle(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                          color: Cores.destaque,
                          fontSize: 12)),
                ),
                ...acoes,
              ]),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

/// Seletor simples (dropdown) que aceita valor fora da lista.
class Seletor extends StatelessWidget {
  final String rotulo;
  final String valor;
  final List<String> opcoes;
  final ValueChanged<String> aoMudar;
  const Seletor(
      {super.key,
      required this.rotulo,
      required this.valor,
      required this.opcoes,
      required this.aoMudar});
  @override
  Widget build(BuildContext context) {
    final ops = [...opcoes];
    if (valor.isNotEmpty && !ops.contains(valor)) ops.insert(0, valor);
    return InputDecorator(
      decoration: InputDecoration(labelText: rotulo),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor.isEmpty ? null : valor,
          isDense: true,
          isExpanded: true,
          hint: const Text('—'),
          items: [
            for (final o in ops) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) {
            if (v != null) aoMudar(v);
          },
        ),
      ),
    );
  }
}

String formatarHora(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}
