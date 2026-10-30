import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/quadro.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/efeitos.dart';
import '../../widgets/imagem.dart';
import '../../widgets/sigilos.dart';
import '../campaign/campaign_screen.dart';
import '../campaign/jogadores.dart';
import '../campaign/sessao.dart';
import '../sheet/tab_agente.dart';
import '../quadro/quadro_screen.dart';
import 'ameacas.dart';
import 'combate.dart';
import 'nomes.dart';
import 'regras.dart';

class TelaMestre extends StatefulWidget {
  final Campanha camp;
  const TelaMestre({super.key, required this.camp});
  @override
  State<TelaMestre> createState() => _TelaMestreState();
}

class _TelaMestreState extends State<TelaMestre> {
  int _aba = 0;
  static const _abas = [
    (Icons.dashboard_outlined, 'Painel'),
    (Icons.flash_on_outlined, 'Combate'),
    (Icons.pest_control_outlined, 'Ameaças'),
    (Icons.casino_outlined, 'Rolagens'),
    (Icons.event_note_outlined, 'Sessões'),
    (Icons.forum_outlined, 'Jogadores'),
    (Icons.person_search_outlined, 'Nomes'),
    (Icons.tune, 'Regras'),
    (Icons.settings_outlined, 'Mesa'),
  ];

  /// No celular, a barra de baixo mostra as primeiras; as outras ficam em
  /// "Mais".
  static const _naBarra = 4;
  static const _jogadores = 5;

  /// As fichas da mesa, para contar as notas e os pedidos dos jogadores.
  late final _fichas = Repo.todasDaCampanha(widget.camp.id);

  /// O ícone da aba, com quantas coisas esperam o mestre (em Jogadores).
  Widget _icone(int i, int pendentes) => i == _jogadores && pendentes > 0
      ? Badge(label: Text('$pendentes'), child: Icon(_abas[i].$1))
      : Icon(_abas[i].$1);

  Future<void> _mais(int pendentes) async {
    final i = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = _naBarra; i < _abas.length; i++)
            ListTile(
              leading: _icone(i, pendentes),
              title: Text(_abas[i].$2),
              selected: i == _aba,
              onTap: () => Navigator.pop(ctx, i),
            ),
        ]),
      ),
    );
    if (i != null) setState(() => _aba = i);
  }

  Widget _corpo() {
    final c = widget.camp;
    switch (_aba) {
      case 0:
        return PainelAoVivo(camp: c);
      case 1:
        return AbaCombate(camp: c);
      case 2:
        return AbaAmeacas(camp: c);
      case 3:
        return _AbaRolagensMestre(camp: c);
      case 4:
        return AbaSessoesMestre(camp: c);
      case 5:
        return AbaJogadoresMestre(camp: c);
      case 6:
        return AbaNomes(camp: c);
      case 7:
        return AbaRegras(camp: c);
      default:
        return _AbaMesa(camp: c);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Ficha>>(
        stream: _fichas,
        builder: (context, snap) => _tela(context, pendentesDoMestre(snap.data ?? const [])),
      );

  Widget _tela(BuildContext context, int pendentes) {
    final largo = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        bottom: const LinhaCris(),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.camp.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('Escudo do mestre · código ${widget.camp.joinCode}',
              style: estiloRotulo(13.5, cor: Cores.textoFraco, peso: FontWeight.w500, espaco: 0.6)),
        ]),
      ),
      body: largo
          ? Row(children: [
              // com a janela baixa, a coluna de abas rola
              LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: _aba,
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.transparent,
                        onDestinationSelected: (i) => setState(() => _aba = i),
                        destinations: [
                          for (var i = 0; i < _abas.length; i++)
                            NavigationRailDestination(icon: _icone(i, pendentes), label: Text(_abas[i].$2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _corpo()),
            ])
          : _corpo(),
      bottomNavigationBar: largo
          ? null
          : NavigationBar(
              selectedIndex: _aba < _naBarra ? _aba : _naBarra,
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (i) => i < _naBarra ? setState(() => _aba = i) : _mais(pendentes),
              destinations: [
                for (var i = 0; i < _naBarra; i++)
                  NavigationDestination(icon: _icone(i, pendentes), label: _abas[i].$2),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pendentes > 0,
                    label: Text('$pendentes'),
                    child: Icon(_aba < _naBarra ? Icons.more_horiz : _abas[_aba].$1),
                  ),
                  label: _aba < _naBarra ? 'Mais' : _abas[_aba].$2,
                ),
              ],
            ),
    );
  }
}

// ---------------- PAINEL AO VIVO ----------------

class PainelAoVivo extends StatelessWidget {
  final Campanha camp;
  const PainelAoVivo({super.key, required this.camp});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ficha>>(
      stream: Repo.fichasDaCampanha(camp.id),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final fichas = snap.data!;
        final largura = MediaQuery.sizeOf(context).width;
        final w = largura < 720 ? largura - 24 : 340.0;
        return ListView(padding: const EdgeInsets.all(12), children: [
          if (camp.masterUid == Repo.uid) ...[
            CartaoSessao(camp: camp),
            const SizedBox(height: 12),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: fichas.isEmpty
                  ? null
                  : () => pedirTesteGrupo(context, camp, fichas),
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Pedir teste a todos'),
            ),
            OutlinedButton.icon(
              onPressed: fichas.isEmpty
                  ? null
                  : () => _aplicarTodos(context, fichas),
              icon: const Icon(Icons.exposure),
              label: const Text('Dano/cura em grupo'),
            ),
            OutlinedButton.icon(
              onPressed: fichas.isEmpty
                  ? null
                  : () async {
                      if (!await confirmar(context,
                          'Recuperar PV, PE, SAN e PD de todos ao máximo?')) {
                        return;
                      }
                      for (final f in fichas) {
                        final c = Calc(f, camp.regras);
                        Repo.mudarRecursos(f, {
                          'pvAtual': c.pvMax,
                          'peAtual': c.peMax,
                          'sanAtual': c.sanMax,
                          'pdAtual': c.pdMax,
                        });
                      }
                    },
              icon: const Icon(Icons.restore),
              label: const Text('Recuperar todos'),
            ),
          ]),
          const SizedBox(height: 12),
          if (fichas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nenhum agente vinculado ainda.\nPasse o código ${camp.joinCode} para os jogadores: eles entram na mesa e vinculam o agente deles.',
                textAlign: TextAlign.center,
              ),
            ),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final (i, f) in fichas.indexed)
              SizedBox(width: w, child: Surgir(ordem: i, child: _CartaoPainel(ficha: f, camp: camp))),
          ]),
        ]);
      },
    );
  }

  Future<void> _aplicarTodos(BuildContext context, List<Ficha> fichas) async {
    final calc0 = Calc(fichas.first, camp.regras);
    final opcoes =
        calc0.determinacao ? ['PV', 'PD'] : ['PV', 'PE', 'SAN'];
    var stat = 'PV';
    final ctl = TextEditingController(text: '-');
    final r = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Aplicar a todos os agentes'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: [
                for (final o in opcoes) ButtonSegment(value: o, label: Text(o))
              ],
              selected: {stat},
              onSelectionChanged: (s) => set(() => stat = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                  labelText: 'Valor', helperText: 'Negativo = dano/perda'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, int.tryParse(ctl.text.trim())),
                child: const Text('Aplicar')),
          ],
        ),
      ),
    );
    if (r == null) return;
    final campo = {
      'PV': 'pvAtual',
      'PE': 'peAtual',
      'SAN': 'sanAtual',
      'PD': 'pdAtual'
    }[stat]!;
    for (final f in fichas) {
      Repo.mudarPontos(f, campo, asInt(f.d[campo]) + r);
    }
  }
}

/// O mestre rola o mesmo teste para todos os agentes e ve quem passou.
Future<void> pedirTesteGrupo(
    BuildContext context, Campanha camp, List<Ficha> fichas) async {
  var pericia = 'Percepção';
  var secreto = false;
  final dt = TextEditingController(text: '15');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Teste em grupo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Seletor(
            rotulo: 'Perícia',
            valor: pericia,
            opcoes: [for (final p in periciasDef) p.nome],
            aoMudar: (v) => set(() => pericia = v),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: dt,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'DT')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Secreto (só o mestre vê)'),
            value: secreto,
            onChanged: (v) => set(() => secreto = v),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rolar para todos')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final valorDt = int.tryParse(dt.text.trim()) ?? 15;
  final resultados = <(Ficha, Rolagem)>[];
  for (final f in fichas) {
    final c = Calc(f, camp.regras);
    final r = Dados.rolarTeste(
      titulo: '${f.nome}: $pericia (DT $valorDt)',
      nDados: c.dadosPericia(pericia),
      bonus: c.bonusPericia(pericia),
    );
    resultados.add((f, r));
    Repo.registrarRolagem(camp.id, r, personagem: f.nome, secreta: secreto);
  }
  resultados.sort((a, b) => b.$2.total.compareTo(a.$2.total));
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$pericia • DT $valorDt'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in resultados)
            ListTile(
              dense: true,
              leading: Icon(
                e.$2.total >= valorDt ? Icons.check_circle : Icons.cancel,
                color: e.$2.total >= valorDt ? Cores.ok : Cores.destaque,
              ),
              title: Text(e.$1.nome),
              subtitle: Text(e.$2.detalhe),
              trailing: Text('${e.$2.total}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))
      ],
    ),
  );
}

class _CartaoPainel extends StatelessWidget {
  final Ficha ficha;
  final Campanha camp;
  const _CartaoPainel({required this.ficha, required this.camp});
  @override
  Widget build(BuildContext context) {
    final f = ficha;
    final c = Calc(f, camp.regras);
    final morrendo = f.pvAtual <= 0;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: morrendo ? Cores.destaque : Cores.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AvatarFicha(
                foto: f.foto,
                nome: f.nome,
                ajuste: f.fotoAjuste,
                tamanho: 52,
                transformacao: f.eTransformacao,
                aoTocar: () => abrirFicha(context, f.id),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => abrirFicha(context, f.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (f.eTransformacao)
                      Text('TRANSFORMADO',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w900,
                              color: Cores.roxoClaro)),
                    Text(f.nome, style: estiloTitulo(17, cor: Cores.texto)),
                    Text(
                        '${f.jogador.isEmpty ? asStr(camp.members[f.ownerUid]) : f.jogador} • ${f.classe} • ${c.resumoProgressao}',
                        style: const TextStyle(
                            fontSize: 12, color: Cores.textoFraco)),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Abrir ficha completa',
              icon: const Icon(Icons.open_in_new, size: 20),
              onPressed: () => abrirFicha(context, f.id),
            ),
          ]),
          const SizedBox(height: 8),
          BarraStatus(
              rotulo: 'PV',
              atual: f.pvAtual,
              max: c.pvMax,
              cor: Cores.pv,
              aoMudar: (v) => Repo.mudarPontos(f, 'pvAtual', v)),
          if (f.pvTemp > 0) ...[
            const SizedBox(height: 6),
            BarraStatus(
                rotulo: 'PV TEMP',
                atual: f.pvTemp,
                max: f.pvTempMax < f.pvTemp ? f.pvTemp : f.pvTempMax,
                cor: Cores.pvTemp,
                compacta: true,
                aoMudar: (v) => Repo.mudarTemporario(f, 'pvTemp', v)),
          ],
          const SizedBox(height: 6),
          if (c.determinacao)
            BarraStatus(
                rotulo: 'PD',
                atual: f.pdAtual,
                max: c.pdMax,
                cor: Cores.pd,
                aoMudar: (v) => Repo.mudarPontos(f, 'pdAtual', v))
          else
            BarraStatus(
                rotulo: 'PE',
                atual: f.peAtual,
                max: c.peMax,
                cor: Cores.pe,
                aoMudar: (v) => Repo.mudarPontos(f, 'peAtual', v)),
          if (f.peTemp > 0) ...[
            const SizedBox(height: 6),
            BarraStatus(
                rotulo: c.determinacao ? 'PD TEMP' : 'PE TEMP',
                atual: f.peTemp,
                max: f.peTempMax < f.peTemp ? f.peTemp : f.peTempMax,
                cor: c.determinacao ? Cores.pdTemp : Cores.peTemp,
                compacta: true,
                aoMudar: (v) => Repo.mudarTemporario(f, 'peTemp', v)),
          ],
          if (!c.determinacao) ...[
            const SizedBox(height: 6),
            BarraStatus(
                rotulo: 'SAN',
                atual: f.sanAtual,
                max: c.sanMax,
                cor: Cores.san,
                aoMudar: (v) => Repo.mudarRecursos(f, {'sanAtual': v})),
          ],
          const SizedBox(height: 8),
          Text(
              'Defesa ${c.defesa} • Desl. ${c.deslocamento} m • Carga ${c.cargaAtual}/${c.cargaMax} • ${c.patente.nome} (${f.pp} PP)',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final cd in f.condicoes)
                  Chip(
                    label: Text(cd, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Cores.destaque.withValues(alpha: 0.2),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Condição', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => editarCondicoes(context, f),
                ),
              ]),
        ]),
      ),
    );
  }
}

// ---------------- ROLAGENS DO MESTRE ----------------

class _AbaRolagensMestre extends StatefulWidget {
  final Campanha camp;
  const _AbaRolagensMestre({required this.camp});
  @override
  State<_AbaRolagensMestre> createState() => _AbaRolagensMestreState();
}

class _AbaRolagensMestreState extends State<_AbaRolagensMestre> {
  bool _secretas = false;
  bool _rolarSecreto = true;
  final _expr = TextEditingController(text: '1d20');

  @override
  void dispose() {
    _expr.dispose();
    super.dispose();
  }

  void _rolar() {
    final e = Dados.expressao(_expr.text);
    final r = Rolagem(
        titulo: 'Mestre: ${_expr.text}', detalhe: e.detalhe, total: e.total);
    mostrarRolagem(context, r);
    Repo.registrarRolagem(widget.camp.id, r,
        personagem: 'Mestre', secreta: _rolarSecreto);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _expr,
              decoration: const InputDecoration(
                  labelText: 'Rolar dados', hintText: 'ex.: 3d6+2'),
              onSubmitted: (_) => _rolar(),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Secreta'),
            selected: _rolarSecreto,
            onSelected: (v) => setState(() => _rolarSecreto = v),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _rolar, child: const Text('Rolar')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Mesa')),
              ButtonSegment(value: true, label: Text('Secretas')),
            ],
            selected: {_secretas},
            onSelectionChanged: (s) => setState(() => _secretas = s.first),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () async {
              if (await confirmar(context,
                  'Apagar o log de rolagens ${_secretas ? 'secretas' : 'da mesa'}?')) {
                await Repo.limparLog(widget.camp.id, secretas: _secretas);
              }
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Limpar'),
          ),
        ]),
      ),
      Expanded(
        child: LogRolagens(
            key: ValueKey(_secretas),
            cid: widget.camp.id,
            secretas: _secretas),
      ),
    ]);
  }
}

// ---------------- MESA (configuracoes) ----------------

class _AbaMesa extends StatelessWidget {
  final Campanha camp;
  const _AbaMesa({required this.camp});

  Future<void> _evento(BuildContext context) async {
    var evento = eventosPP.keys.first;
    final valor = TextEditingController(text: '${eventosPP[evento]}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Evento de missão'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Seletor(
              rotulo: 'Evento',
              valor: evento,
              opcoes: [...eventosPP.keys, 'Outro'],
              aoMudar: (v) => set(() {
                evento = v;
                if (eventosPP.containsKey(v)) valor.text = '${eventosPP[v]}';
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: valor,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                  labelText: 'Pontos de prestígio para cada agente'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Aplicar a todos')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final v = int.tryParse(valor.text.trim()) ?? 0;
    final fichas = await Repo.agentesDaCampanha(camp.id).first;
    for (final f in fichas) {
      Repo.set(f.id, 'pp', f.pp + v);
    }
    Repo.setCamp(camp.id, {
      'ledger': FieldValue.arrayUnion([
        {
          'evento': evento,
          'pp': v,
          'at': DateTime.now().millisecondsSinceEpoch,
        }
      ])
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledger = camp.ledger.reversed.toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      Secao(
        titulo: 'Mesa',
        child: Column(children: [
          CampoSync(
              valor: camp.nome,
              rotulo: 'Nome da campanha',
              aoSalvar: (v) => Repo.setCamp(camp.id, {'nome': v})),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Código para os jogadores: '),
            SelectableText(camp.joinCode,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Cores.destaque)),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: camp.joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')));
              },
            ),
          ]),
          const SizedBox(height: 10),
          CampoSync(
              valor: camp.missao,
              rotulo: 'Missão atual (os jogadores veem)',
              maxLinhas: 4,
              aoSalvar: (v) => Repo.setCamp(camp.id, {'missao': v})),
        ]),
      ),
      Secao(
        titulo: 'Membros',
        child: Column(children: [
          for (final e in camp.members.entries)
            ListTile(
              dense: true,
              leading: Icon(e.key == camp.masterUid
                  ? Icons.shield_moon_outlined
                  : Icons.person_outline),
              title: Text(asStr(e.value)),
              subtitle: Text(e.key == camp.masterUid ? 'Mestre' : 'Jogador'),
              trailing: e.key == camp.masterUid
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () async {
                        if (await confirmar(
                            context, 'Remover ${e.value} da mesa?')) {
                          await Repo.removerMembro(camp, e.key);
                        }
                      },
                    ),
            ),
        ]),
      ),
      Secao(
        titulo: 'Prestígio da missão',
        acoes: [
          TextButton.icon(
            onPressed: () => _evento(context),
            icon: const Icon(Icons.military_tech_outlined, size: 18),
            label: const Text('Registrar evento'),
          ),
        ],
        child: ledger.isEmpty
            ? const Text(
                'Registre solução do caso (+10), pistas (+2), mortes (-2/-5)... os PP são somados em todas as fichas da mesa.',
                style: TextStyle(color: Cores.textoFraco))
            : Column(children: [
                for (final l in ledger.take(20))
                  ListTile(
                    dense: true,
                    title: Text(asStr(l['evento'])),
                    trailing: Text(
                        '${asInt(l['pp']) >= 0 ? '+' : ''}${asInt(l['pp'])} PP',
                        style: TextStyle(
                            color: asInt(l['pp']) >= 0
                                ? Cores.ok
                                : Cores.destaque,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(_data(asInt(l['at']))),
                  ),
              ]),
      ),
      Secao(
        titulo: 'Quadro do mestre',
        child: StreamBuilder<Map<String, Quadro>>(
          stream: FonteQuadro.mestre(camp.id).todos,
          builder: (context, s) {
            final raiz = s.data?[FonteQuadro.raiz];
            void abrir() => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TelaQuadro(fonte: FonteQuadro.mestre(camp.id))));
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: abrir,
                    borderRadius: BorderRadius.circular(4),
                    child: MiniQuadro(quadro: raiz),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: abrir,
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Abrir quadro do mestre'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                      'Quadro estilo Milanote para planejar a campanha: só você vê.',
                      style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
                ]);
          },
        ),
      ),
      Secao(
        titulo: 'Notas privadas do mestre',
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: Repo.notasMestre(camp.id).snapshots(),
          builder: (context, s) {
            if (!s.hasData) return const LinearProgressIndicator();
            return CampoSync(
              valor: asStr(s.data!.data()?['texto']),
              maxLinhas: 12,
              dica: 'Segredos, ganchos, NPCs... só você vê.',
              aoSalvar: (v) => Repo.notasMestre(camp.id)
                  .set({'texto': v}, SetOptions(merge: true)),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Cores.destaque),
        onPressed: () async {
          if (await confirmar(context,
              'Apagar a mesa "${camp.nome}"? As fichas dos jogadores continuam existindo.')) {
            final fichas = await Repo.todasDaCampanha(camp.id).first;
            for (final f in fichas) {
              if (f.ownerUid != Repo.uid) {
                // o dono desvincula depois; aqui so tiramos o mestre dos editores
                Repo.setVarios(f.id, {
                  'campaignId': null,
                  'editors': [f.ownerUid]
                });
              } else {
                Repo.desvincularFicha(f);
              }
            }
            await Repo.apagarCampanha(camp);
            if (context.mounted) Navigator.pop(context);
          }
        },
        icon: const Icon(Icons.delete_forever_outlined),
        label: const Text('Apagar mesa'),
      ),
    ]);
  }

  String _data(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${formatarHora(ms)}';
  }
}
