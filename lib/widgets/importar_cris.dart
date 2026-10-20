import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/cris_import.dart';
import '../data/models.dart';
import '../data/repo.dart';

/// Grava agentes do site do CRIS como fichas minhas. Um agente que já veio
/// antes é atualizado em vez de duplicado. Devolve quantos foram gravados.
Future<int> gravarAgentesCris(List<AgenteCris> agentes) async {
  if (agentes.isEmpty) return 0;
  final minhas = await Repo.minhasFichas().first;
  final porCris = {
    for (final f in minhas)
      if (asStr(f.d['crisId']).isNotEmpty) asStr(f.d['crisId']): f,
  };
  for (final a in agentes) {
    final ficha = CrisImport.paraFicha(a, Repo.uid, Repo.nomeUsuario);
    final existente = porCris[a.id];
    if (existente == null) {
      Repo.importarFicha(ficha);
    } else {
      Repo.atualizarFichaImportada(existente, ficha);
    }
  }
  return agentes.length;
}

/// Agentes lidos na tela de login: grava assim que a pessoa entra.
Future<void> gravarPendentesCris(BuildContext context) async {
  if (CrisImport.pendentes.isEmpty) return;
  final l = List<AgenteCris>.from(CrisImport.pendentes);
  CrisImport.pendentes.clear();
  final n = await gravarAgentesCris(l);
  if (context.mounted && n > 0) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 1
            ? '1 agente veio do site do CRIS.'
            : '$n agentes vieram do site do CRIS.')));
  }
}

/// Janela para colar os links de compartilhar dos agentes do site do CRIS.
/// Antes do login só guarda os agentes; logado, já cria as fichas.
Future<void> abrirImportarCris(BuildContext context, {required bool logado}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _JanelaCris(logado: logado),
    );

class _JanelaCris extends StatefulWidget {
  final bool logado;
  const _JanelaCris({required this.logado});
  @override
  State<_JanelaCris> createState() => _JanelaCrisState();
}

class _Resultado {
  final String id;
  final AgenteCris? agente;
  final String? erro;
  bool marcado;
  _Resultado(this.id, {this.agente, this.erro}) : marcado = agente != null;
}

class _JanelaCrisState extends State<_JanelaCris> {
  final _links = TextEditingController();
  final _resultados = <_Resultado>[];
  bool _buscando = false;
  bool _gravando = false;
  String? _aviso;

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final ids = CrisImport.idsNoTexto(_links.text);
    if (ids.isEmpty) {
      setState(() => _aviso =
          'Não achei nenhum link de agente. Ele é assim: crisordemparanormal.com/agente/código');
      return;
    }
    setState(() {
      _buscando = true;
      _aviso = null;
    });
    for (final id in ids) {
      if (_resultados.any((r) => r.id == id)) continue;
      _Resultado r;
      try {
        r = _Resultado(id, agente: await CrisImport.ler(id));
      } on CrisErro catch (e) {
        r = _Resultado(id, erro: e.mensagem);
      }
      if (!mounted) return;
      setState(() => _resultados.add(r));
    }
    if (mounted) {
      setState(() {
        _buscando = false;
        _links.clear();
      });
    }
  }

  Future<void> _concluir() async {
    final escolhidos = [
      for (final r in _resultados)
        if (r.marcado && r.agente != null) r.agente!,
    ];
    if (escolhidos.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!widget.logado) {
      CrisImport.pendentes
        ..removeWhere((p) => escolhidos.any((e) => e.id == p.id))
        ..addAll(escolhidos);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
          content: Text('Agentes guardados. Entre ou crie sua conta para terminar.')));
      return;
    }
    setState(() => _gravando = true);
    try {
      final n = await gravarAgentesCris(escolhidos);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(n == 1 ? '1 agente importado.' : '$n agentes importados.')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _gravando = false;
          _aviso = 'Não consegui gravar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final prontos = _resultados.where((r) => r.marcado && r.agente != null).length;
    return AlertDialog(
      title: const Text('Trazer agentes do site do CRIS'),
      content: SizedBox(
        width: tela.width > 600 ? 520 : tela.width - 40,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'No site do CRIS, abra Agentes e toque em compartilhar no agente: o link é copiado. Cole aqui; pode colar vários, um por linha.',
                style: TextStyle(fontSize: 13, color: Cores.textoFraco),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _links,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Links dos agentes',
                  hintText: 'https://crisordemparanormal.com/agente/...',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _buscando ? null : _buscar,
                  icon: _buscando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(_buscando ? 'Buscando…' : 'Buscar agentes'),
                ),
              ),
              if (_aviso != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_aviso!, style: const TextStyle(color: Cores.destaque)),
                ),
              for (final r in _resultados)
                r.agente == null
                    ? ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.error_outline, color: Cores.destaque),
                        title: Text(r.id, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(r.erro ?? ''),
                      )
                    : CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: r.marcado,
                        onChanged: (v) => setState(() => r.marcado = v ?? false),
                        title: Text(r.agente!.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(r.agente!.resumo),
                      ),
              if (_resultados.any((r) => r.agente != null))
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Vêm atributos, perícias, PV/PE/SAN/PD, poderes, rituais, inventário e anotações. Um agente que você já trouxe antes é atualizado. Mesas e a foto da ficha ficam no site.',
                    style: TextStyle(fontSize: 12, color: Cores.textoFraco),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        FilledButton(
          onPressed: prontos == 0 || _gravando ? null : _concluir,
          child: Text(widget.logado
              ? 'Importar ($prontos)'
              : 'Guardar para depois do login ($prontos)'),
        ),
      ],
    );
  }
}
