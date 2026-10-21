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
    final alto = compacta ? 32.0 : 38.0;
    Widget seta(IconData icone, int d) => SizedBox(
          width: compacta ? 28 : 34,
          height: alto,
          child: InkWell(
            onTap: () => aoMudar(atual + d),
            child: Tooltip(
              message: d > 0 ? '+$d' : '$d',
              child: Icon(icone,
                  size: compacta ? 17 : 20, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(rotulo,
              style: estiloRotulo(compacta ? 12 : 13, cor: cor, peso: FontWeight.w700, espaco: 1.6)),
        ),
        Container(
          height: alto,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cor.withValues(alpha: 0.35)),
          ),
          child: Stack(fit: StackFit.expand, children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [cor.withValues(alpha: 0.55), cor.withValues(alpha: 0.92)]),
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
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '$atual',
                            style: estiloNumero(compacta ? 18 : 21, cor: Colors.white)),
                        TextSpan(
                            text: ' / $max',
                            style: estiloNumero(compacta ? 13 : 15,
                                cor: Colors.white.withValues(alpha: 0.75), peso: FontWeight.w600)),
                      ]),
                      style: const TextStyle(shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                    ),
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

/// Medidor pequeno (só leitura): rótulo, valor e uma barra fina.
class MedidorMini extends StatelessWidget {
  final String rotulo;
  final int atual, max;
  final Color cor;
  /// Pontos temporários, mostrados como "+N".
  final int temp;
  const MedidorMini(
      {super.key,
      required this.rotulo,
      required this.atual,
      required this.max,
      required this.cor,
      this.temp = 0});

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (atual / max).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(rotulo, style: estiloRotulo(11.5, cor: cor, peso: FontWeight.w700, espaco: 1.2)),
        const Spacer(),
        Text.rich(TextSpan(children: [
          TextSpan(text: '$atual', style: estiloNumero(15, cor: Cores.texto)),
          TextSpan(text: '/$max', style: estiloNumero(11.5, cor: Cores.textoFraco, peso: FontWeight.w600)),
          if (temp > 0)
            TextSpan(text: ' +$temp', style: estiloNumero(11.5, cor: cor, peso: FontWeight.w700)),
        ])),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 4,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: cor.withValues(alpha: 0.16)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: ColoredBox(color: cor),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Selo pequeno (NEX, patente, "em uso"...).
class Selo extends StatelessWidget {
  final String texto;
  final Color? cor;
  final IconData? icone;
  /// Preenchido com a cor (em vez de só contornado).
  final bool cheio;
  const Selo(this.texto, {super.key, this.cor, this.icone, this.cheio = false});

  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cores.destaque;
    final frente = cheio ? Cores.sobreDestaque : c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: cheio ? 0.95 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: cheio ? 1 : 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[
          Icon(icone, size: 13, color: frente),
          const SizedBox(width: 4),
        ],
        Text(texto, style: estiloRotulo(12.5, cor: frente, peso: FontWeight.w700, espaco: 1)),
      ]),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Row(children: [
                  const Losango(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(titulo, style: estiloTitulo(15, cor: Cores.destaque, espaco: 0.8)),
                  ),
                  ...acoes,
                ]),
              ),
              const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.only(right: 4), child: child),
            ],
          ),
        ),
      );
}

/// Losango pequeno que marca os títulos das seções.
class Losango extends StatelessWidget {
  final double tamanho;
  final Color? cor;
  const Losango({super.key, this.tamanho = 7, this.cor});
  @override
  Widget build(BuildContext context) {
    final c = cor ?? Cores.destaque;
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: c,
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)],
        ),
      ),
    );
  }
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

/// Título grande no alto das listas (Agentes, Mesas...).
class TituloPagina extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;
  const TituloPagina({super.key, required this.titulo, this.subtitulo, this.acoes = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: estiloTitulo(26, cor: Cores.texto)),
              if (subtitulo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(subtitulo!,
                      style: estiloRotulo(14.5, cor: Cores.textoFraco, peso: FontWeight.w500, espaco: 0.5)),
                ),
            ]),
          ),
          ...acoes,
        ]),
      );
}
