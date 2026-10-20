import 'package:flutter/material.dart';

import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../campaign/campaign_screen.dart';
import '../sheet/tab_agente.dart';

/// Rastreador de iniciativa, turnos e condicoes (mestre).
class AbaCombate extends StatelessWidget {
  final Campanha camp;
  const AbaCombate({super.key, required this.camp});

  Map<String, dynamic> get _cb => camp.combate;
  List<Map<String, dynamic>> get _ordem => asMapList(_cb['ordem']);

  void _salvar(Map<String, dynamic> cb) => Repo.setCamp(camp.id, {'combate': cb});

  void _salvarOrdem(List<Map<String, dynamic>> ordem,
      {int? turno, int? rodada, bool? ativo}) {
    ordem.sort((a, b) {
      final v = asInt(b['valor']).compareTo(asInt(a['valor']));
      return v != 0 ? v : asInt(b['desempate']).compareTo(asInt(a['desempate']));
    });
    _salvar({
      'ativo': ativo ?? asBool(_cb['ativo']),
      'rodada': rodada ?? asInt(_cb['rodada'], 1),
      'turno': (turno ?? asInt(_cb['turno'])).clamp(0, ordem.isEmpty ? 0 : ordem.length - 1),
      'ordem': ordem,
    });
  }

  void _rolarAgentes(BuildContext context, List<Ficha> fichas) {
    final ordem = _ordem.where((e) => asStr(e['tipo']) != 'agente').toList();
    for (final f in fichas) {
      final c = Calc(f, camp.regras);
      final r = Dados.rolarTeste(
          titulo: '${f.nome}: Iniciativa',
          nDados: c.dadosPericia('Iniciativa'),
          bonus: c.bonusPericia('Iniciativa'));
      Repo.registrarRolagem(camp.id, r, personagem: f.nome);
      ordem.add({
        'id': novoId(),
        'tipo': 'agente',
        'ref': f.id,
        'nome': f.nome,
        'valor': r.total,
        'desempate': c.agi,
      });
    }
    _salvarOrdem(ordem, turno: 0, rodada: 1, ativo: true);
  }

  Future<void> _addAmeaca(BuildContext context) async {
    final lista = await Repo.stream(Repo.ameacas(camp.id)).first;
    if (!context.mounted) return;
    final escolha = await showDialog<(String, Map<String, dynamic>)?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Adicionar ao combate'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ('', <String, dynamic>{})),
            child: const Text('+ Participante avulso (só nome)',
                style: TextStyle(color: Cores.roxo)),
          ),
          for (final a in lista)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, a),
              child: Text(asStr(a.$2['nome'], 'Ameaça')),
            ),
        ],
      ),
    );
    if (escolha == null || !context.mounted) return;
    var nome = asStr(escolha.$2['nome']);
    if (escolha.$1.isEmpty) {
      final n = await pedirTexto(context, 'Nome do participante');
      if (n == null || n.isEmpty) return;
      nome = n;
    }
    final mod = asInt(escolha.$2['iniciativaBonus']);
    final dados = asInt(escolha.$2['iniciativaDados'], 1);
    final t = Dados.teste(dados);
    final ordem = _ordem
      ..add({
        'id': novoId(),
        'tipo': escolha.$1.isEmpty ? 'avulso' : 'ameaca',
        'ref': escolha.$1,
        'nome': nome,
        'valor': t.escolhido + mod,
        'desempate': 0,
        'oculto': false,
      });
    _salvarOrdem(ordem, ativo: true);
  }

  void _proximo(int delta) {
    final ordem = _ordem;
    if (ordem.isEmpty) return;
    var turno = asInt(_cb['turno']) + delta;
    var rodada = asInt(_cb['rodada'], 1);
    if (turno >= ordem.length) {
      turno = 0;
      rodada++;
    } else if (turno < 0) {
      turno = ordem.length - 1;
      rodada = (rodada - 1).clamp(1, 9999);
    }
    _salvar({..._cb, 'turno': turno, 'rodada': rodada});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ficha>>(
      stream: Repo.fichasDaCampanha(camp.id),
      builder: (context, fs) {
        final fichas = fs.data ?? [];
        final porId = {for (final f in fichas) f.id: f};
        return StreamBuilder<List<(String, Map<String, dynamic>)>>(
          stream: Repo.stream(Repo.ameacas(camp.id)),
          builder: (context, amSnap) {
            final ameacas = <String, Map<String, dynamic>>{
              for (final a in amSnap.data ?? const <(String, Map<String, dynamic>)>[])
                a.$1: a.$2
            };
            final ordem = _ordem;
            final turno = asInt(_cb['turno']);
            final ativo = asBool(_cb['ativo']);
            return ListView(padding: const EdgeInsets.all(12), children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: fichas.isEmpty
                      ? null
                      : () => _rolarAgentes(context, fichas),
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Rolar iniciativa dos agentes'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addAmeaca(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar ameaça'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (await confirmar(context, 'Encerrar o combate?')) {
                      _salvar({
                        'ativo': false,
                        'rodada': 1,
                        'turno': 0,
                        'ordem': <dynamic>[]
                      });
                    }
                  },
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Encerrar'),
                ),
              ]),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(
                        onPressed: () => _proximo(-1),
                        icon: const Icon(Icons.skip_previous)),
                    Expanded(
                      child: Text(
                        ativo
                            ? 'RODADA ${asInt(_cb['rodada'], 1)}${ordem.isNotEmpty ? ' • vez de ${asStr(ordem[turno.clamp(0, ordem.length - 1)]['nome'])}' : ''}'
                            : 'Sem combate ativo',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    FilledButton(
                        onPressed: () => _proximo(1),
                        child: const Text('Próximo turno')),
                  ]),
                ),
              ),
              if (ordem.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'Role a iniciativa dos agentes e adicione as ameaças para começar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Cores.textoFraco)),
                ),
              for (var i = 0; i < ordem.length; i++)
                _LinhaIniciativa(
                  entrada: ordem[i],
                  vez: i == turno && ativo,
                  ficha: porId[asStr(ordem[i]['ref'])],
                  ameaca: ameacas[asStr(ordem[i]['ref'])],
                  camp: camp,
                  aoMudarValor: (v) {
                    final o = _ordem;
                    o[i] = {...o[i], 'valor': v};
                    _salvarOrdem(o);
                  },
                  aoOcultar: () {
                    final o = _ordem;
                    o[i] = {...o[i], 'oculto': !asBool(o[i]['oculto'])};
                    _salvarOrdem(o);
                  },
                  aoRemover: () {
                    final o = _ordem..removeAt(i);
                    _salvarOrdem(o, turno: turno > i ? turno - 1 : turno);
                  },
                ),
            ]);
          },
        );
      },
    );
  }
}

class _LinhaIniciativa extends StatelessWidget {
  final Map<String, dynamic> entrada;
  final bool vez;
  final Ficha? ficha;
  final Map<String, dynamic>? ameaca;
  final Campanha camp;
  final ValueChanged<int> aoMudarValor;
  final VoidCallback aoOcultar;
  final VoidCallback aoRemover;
  const _LinhaIniciativa({
    required this.entrada,
    required this.vez,
    required this.ficha,
    required this.ameaca,
    required this.camp,
    required this.aoMudarValor,
    required this.aoOcultar,
    required this.aoRemover,
  });

  @override
  Widget build(BuildContext context) {
    final f = ficha;
    final a = ameaca;
    Widget? barra;
    List<String> conds = const [];
    if (f != null) {
      final c = Calc(f, camp.regras);
      barra = BarraStatus(
          rotulo: 'PV',
          atual: f.pvAtual,
          max: c.pvMax,
          cor: Cores.pv,
          compacta: true,
          aoMudar: (v) => Repo.set(f.id, 'pvAtual', v));
      conds = f.condicoes;
    } else if (a != null) {
      final id = asStr(entrada['ref']);
      barra = BarraStatus(
          rotulo: 'PV',
          atual: asInt(a['pv']),
          max: asInt(a['pvMax']),
          cor: Cores.pv,
          compacta: true,
          aoMudar: (v) => Repo.salvarDoc(Repo.ameacas(camp.id), id, {'pv': v}));
      conds = asStrList(a['condicoes']);
    }
    return Card(
      color: vez ? Cores.destaque.withValues(alpha: 0.18) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: vez ? Cores.destaque : Cores.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            InkWell(
              onTap: () async {
                final v = await pedirNumero(
                    context, 'Iniciativa', asInt(entrada['valor']));
                if (v != null) aoMudarValor(v);
              },
              child: Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                    color: Cores.painel2,
                    borderRadius: BorderRadius.circular(6)),
                child: Text('${asInt(entrada['valor'])}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asStr(entrada['nome']),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                      asStr(entrada['tipo']) == 'agente'
                          ? 'Agente'
                          : (asStr(entrada['tipo']) == 'ameaca'
                              ? 'Ameaça • Defesa ${asInt(a?['defesa'])}'
                              : 'Participante'),
                      style: const TextStyle(
                          fontSize: 12, color: Cores.textoFraco)),
                ],
              ),
            ),
            if (asStr(entrada['tipo']) != 'agente')
              IconButton(
                tooltip: 'Esconder nome dos jogadores',
                icon: Icon(asBool(entrada['oculto'])
                    ? Icons.visibility_off
                    : Icons.visibility_outlined),
                onPressed: aoOcultar,
              ),
            if (f != null)
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => abrirFicha(context, f.id),
              ),
            IconButton(
                icon: const Icon(Icons.close, size: 20), onPressed: aoRemover),
          ]),
          if (barra != null) ...[const SizedBox(height: 6), barra],
          const SizedBox(height: 4),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final cd in conds)
              Chip(
                label: Text(cd, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            if (f != null)
              ActionChip(
                label: const Text('Condições', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () => editarCondicoes(context, f),
              ),
            if (a != null)
              ActionChip(
                label: const Text('Condições', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    editarCondicoesAmeaca(context, camp, asStr(entrada['ref']), a),
              ),
          ]),
        ]),
      ),
    );
  }
}

Future<void> editarCondicoesAmeaca(BuildContext context, Campanha camp,
    String id, Map<String, dynamic> a) async {
  final sel = {...asStrList(a['condicoes'])};
  final r = await showDialog<Set<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Condições: ${asStr(a['nome'])}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in nomesCondicoes())
                FilterChip(
                  label: Text(c),
                  selected: sel.contains(c),
                  onSelected: (v) => set(() => v ? sel.add(c) : sel.remove(c)),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, sel),
              child: const Text('Salvar')),
        ],
      ),
    ),
  );
  if (r != null) {
    Repo.salvarDoc(Repo.ameacas(camp.id), id, {'condicoes': r.toList()});
  }
}
