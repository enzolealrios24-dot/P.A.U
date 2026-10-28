import 'package:flutter/material.dart';

import '../../core/acoes_ameaca.dart';
import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/area_alvo.dart';
import '../../widgets/common.dart';
import '../campaign/campaign_screen.dart';
import '../sheet/tab_agente.dart';
import 'acao_ameaca.dart';

/// Combate do mestre, em duas partes: Combate (iniciativa, turnos e o
/// espaço do alvo, com os agentes em arco e a ameaça que age embaixo) e
/// Ação (os ataques e habilidades dessa ameaça contra o alvo). No
/// computador ficam lado a lado; no celular, em duas abas.
class AbaCombate extends StatefulWidget {
  final Campanha camp;
  const AbaCombate({super.key, required this.camp});

  @override
  State<AbaCombate> createState() => _AbaCombateState();
}

class _AbaCombateState extends State<AbaCombate> {
  /// Ficha escolhida como alvo.
  String? _alvo;
  /// Ameaça (entrada da ordem) escolhida para agir fora da vez dela, e o
  /// turno em que foi escolhida: passando o turno, volta a agir a da vez.
  String? _atuante;
  int? _atuanteNoTurno;
  UsoAcao? _uso;
  bool _secreto = true;
  final _rolagemAcao = ScrollController();

  Campanha get camp => widget.camp;
  Map<String, dynamic> get _cb => camp.combate;
  List<Map<String, dynamic>> get _ordem => asMapList(_cb['ordem']);

  @override
  void dispose() {
    _rolagemAcao.dispose();
    super.dispose();
  }

  void _salvar(Map<String, dynamic> cb) => Repo.setCamp(camp.id, {'combate': cb});

  static int _porIniciativa(Map<String, dynamic> a, Map<String, dynamic> b) {
    final v = asInt(b['valor']).compareTo(asInt(a['valor']));
    return v != 0 ? v : asInt(b['desempate']).compareTo(asInt(a['desempate']));
  }

  /// Grava a ordem já arrumada pela iniciativa. Sem [turno], a vez fica com
  /// quem estava nela, mesmo que entre alguém antes.
  void _salvarOrdem(List<Map<String, dynamic>> ordem,
      {int? turno, int? rodada, bool? ativo, List<String>? fora}) {
    final antes = _ordem;
    final vez = turno == null && antes.isNotEmpty
        ? asStr(antes[asInt(_cb['turno']).clamp(0, antes.length - 1)]['id'])
        : null;
    ordem.sort(_porIniciativa);
    var t = turno ?? asInt(_cb['turno']);
    if (vez != null) {
      final i = ordem.indexWhere((e) => asStr(e['id']) == vez);
      if (i >= 0) t = i;
    }
    _salvar({
      ..._cb,
      'ativo': ativo ?? asBool(_cb['ativo']),
      'rodada': rodada ?? asInt(_cb['rodada'], 1),
      'turno': t.clamp(0, ordem.isEmpty ? 0 : ordem.length - 1),
      'ordem': ordem,
      if (fora != null) 'fora': fora,
    });
  }

  /// Agente na iniciativa, com o teste rolado e registrado na mesa.
  Map<String, dynamic> _entradaAgente(Ficha f) {
    final c = Calc(f, camp.regras);
    final r = Dados.rolarTeste(
        titulo: '${f.nome}: Iniciativa', nDados: c.dadosPericia('Iniciativa'), bonus: c.bonusPericia('Iniciativa'));
    Repo.registrarRolagem(camp.id, r, personagem: f.nome);
    return {
      'id': novoId(),
      'tipo': 'agente',
      'ref': f.id,
      'nome': f.nome,
      'valor': r.total,
      'desempate': c.agi,
    };
  }

  /// Os agentes da mesa que ainda não estão na ordem (sem eles, a vez
  /// nunca chegava aos agentes), menos os que o mestre tirou do combate.
  List<Map<String, dynamic>> _agentesQueFaltam(
      List<Map<String, dynamic>> ordem, List<Ficha> fichas, Map<String, Ficha> porId) {
    final presentes = {
      for (final e in ordem)
        if (asStr(e['tipo']) == 'agente') porId[asStr(e['ref'])]?.id ?? asStr(e['ref']),
    };
    final fora = asStrList(_cb['fora']).toSet();
    return [
      for (final f in fichas)
        if (!presentes.contains(f.id) && !fora.contains(f.id)) _entradaAgente(f),
    ];
  }

  void _rolarAgentes(List<Ficha> fichas) {
    final ordem = [
      ..._ordem.where((e) => asStr(e['tipo']) != 'agente'),
      for (final f in fichas) _entradaAgente(f),
    ];
    _salvarOrdem(ordem, turno: 0, rodada: 1, ativo: true, fora: const []);
  }

  Future<void> _addAmeaca(BuildContext context, List<Ficha> fichas, Map<String, Ficha> porId) async {
    final lista = await Repo.stream(Repo.ameacas(camp.id)).first;
    if (!context.mounted) return;
    final escolha = await showDialog<(String, Map<String, dynamic>)?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Adicionar ao combate'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ('', <String, dynamic>{})),
            child: Text('+ Participante avulso (só nome)',
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
    // começando o combate pela ameaça, os agentes entram junto
    ordem.addAll(_agentesQueFaltam(ordem, fichas, porId));
    _salvarOrdem(ordem, ativo: true);
  }

  void _proximo(int delta, List<Ficha> fichas, Map<String, Ficha> porId) {
    var ordem = _ordem;
    if (ordem.isEmpty) return;
    var turno = asInt(_cb['turno']).clamp(0, ordem.length - 1);
    final novos = _agentesQueFaltam(ordem, fichas, porId);
    if (novos.isNotEmpty) {
      final vez = asStr(ordem[turno]['id']);
      ordem = [...ordem, ...novos]..sort(_porIniciativa);
      turno = ordem.indexWhere((e) => asStr(e['id']) == vez);
    }
    turno += delta;
    var rodada = asInt(_cb['rodada'], 1);
    if (turno >= ordem.length) {
      turno = 0;
      rodada++;
    } else if (turno < 0) {
      turno = ordem.length - 1;
      rodada = (rodada - 1).clamp(1, 9999);
    }
    _salvar({..._cb, 'ativo': true, 'turno': turno, 'rodada': rodada, 'ordem': ordem});
  }

  void _usar(AcaoAmeaca a, String ameacaId, Map<String, dynamic> ameaca, Ficha? alvo) {
    final uso = usarAcao(camp: camp, ameacaId: ameacaId, ameaca: ameaca, acao: a, alvo: alvo, secreto: _secreto);
    setState(() => _uso = uso);
    mostrarDadosDoUso(context, uso);
    if (_rolagemAcao.hasClients) {
      _rolagemAcao.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ficha>>(
      stream: Repo.fichasDaCampanha(camp.id),
      builder: (context, fs) {
        final fichas = fs.data ?? [];
        // Quem se transformou (ou voltou) no meio do combate continua achado
        // pela entrada antiga da iniciativa.
        final porId = <String, Ficha>{};
        for (final f in fichas) {
          porId[f.id] = f;
          final de = f.transformacaoDe;
          if (de != null) porId[de] = f;
          for (final t in f.transformacoes.keys) {
            porId.putIfAbsent(t, () => f);
          }
        }
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
            final vez = ativo && ordem.isNotEmpty ? ordem[turno.clamp(0, ordem.length - 1)] : null;

            // agentes do combate (ou da mesa, antes da iniciativa)
            final vistos = <String>{};
            final agentes = <Ficha>[
              for (final e in ordem)
                if (asStr(e['tipo']) == 'agente')
                  if (porId[asStr(e['ref'])] case final f? when vistos.add(f.id)) f,
            ];
            if (agentes.isEmpty) agentes.addAll(fichas.where((f) => f.transformacaoDe == null));
            final alvo = agentes.where((f) => f.id == _alvo).firstOrNull;

            // a ameaça que age: a da vez, ou a escolhida neste turno
            final entradas = [
              for (final e in ordem)
                if (asStr(e['tipo']) == 'ameaca' && ameacas.containsKey(asStr(e['ref']))) e,
            ];
            final daVez = vez != null && entradas.contains(vez) ? vez : null;
            final escolhida = _atuanteNoTurno == turno || daVez == null
                ? entradas.where((e) => asStr(e['id']) == _atuante).firstOrNull
                : null;
            final atuante = escolhida ?? daVez ?? entradas.firstOrNull;
            final atuanteId = atuante == null ? null : asStr(atuante['ref']);
            final ameaca = atuanteId == null ? null : ameacas[atuanteId];
            final cor = ameaca == null ? Cores.destaque : corDaAmeaca(ameaca);

            final combate = _painelCombate(context,
                fichas: fichas,
                porId: porId,
                ameacas: ameacas,
                agentes: agentes,
                alvo: alvo,
                entradas: entradas,
                atuante: atuante,
                vez: vez,
                cor: cor);
            final acao = _painelAcao(context,
                fichas: fichas, porId: porId, ameacas: ameacas, alvo: alvo, ameacaId: atuanteId, ameaca: ameaca, cor: cor);

            return LayoutBuilder(builder: (context, c) {
              if (c.maxWidth >= 980) {
                return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 6, child: combate),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 5, child: acao),
                ]);
              }
              return DefaultTabController(
                length: 2,
                child: Column(children: [
                  const TabBar(tabs: [Tab(text: 'COMBATE'), Tab(text: 'AÇÃO')]),
                  Expanded(child: TabBarView(children: [combate, acao])),
                ]),
              );
            });
          },
        );
      },
    );
  }

  Widget _titulo(String texto, {String? dica}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(texto, style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 1.6)),
          if (dica != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(dica,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
            ),
          ],
        ]),
      );

  Widget _painelCombate(
    BuildContext context, {
    required List<Ficha> fichas,
    required Map<String, Ficha> porId,
    required Map<String, Map<String, dynamic>> ameacas,
    required List<Ficha> agentes,
    required Ficha? alvo,
    required List<Map<String, dynamic>> entradas,
    required Map<String, dynamic>? atuante,
    required Map<String, dynamic>? vez,
    required Color cor,
  }) {
    final ordem = _ordem;
    final turno = asInt(_cb['turno']);
    final ativo = asBool(_cb['ativo']);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          onPressed: fichas.isEmpty ? null : () => _rolarAgentes(fichas),
          icon: const Icon(Icons.casino_outlined),
          label: const Text('Rolar iniciativa dos agentes'),
        ),
        OutlinedButton.icon(
          onPressed: () => _addAmeaca(context, fichas, porId),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar ameaça'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirmar(context, 'Encerrar o combate?')) {
              _salvar({'ativo': false, 'rodada': 1, 'turno': 0, 'ordem': <dynamic>[], 'fora': <dynamic>[]});
              setState(() {
                _alvo = null;
                _atuante = null;
                _uso = null;
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
            IconButton(onPressed: () => _proximo(-1, fichas, porId), icon: const Icon(Icons.skip_previous)),
            Expanded(
              child: Text(
                ativo
                    ? 'RODADA ${asInt(_cb['rodada'], 1)}${vez != null ? ' • vez de ${asStr(vez['nome'])}' : ''}'
                    : 'Sem combate ativo',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton(onPressed: () => _proximo(1, fichas, porId), child: const Text('Próximo turno')),
          ]),
        ),
      ),
      if (ordem.isNotEmpty) ...[
        _titulo('ALVO',
            dica: alvo == null
                ? 'Toque num agente para mirar nele e numa ameaça para ela agir.'
                : 'Mirando em ${alvo.nome}.'),
        AreaAlvo(
          cor: cor,
          alvo: alvo?.id,
          atuante: atuante == null ? null : asStr(atuante['id']),
          agentes: [
            for (final f in agentes)
              if (Calc(f, camp.regras) case final c)
                Participante(
                  id: f.id,
                  nome: f.nome,
                  foto: f.foto,
                  ajuste: f.fotoAjuste,
                  pv: f.pvAtual,
                  pvMax: c.pvMax,
                  naVez: vez != null && porId[asStr(vez['ref'])]?.id == f.id,
                  linha: [
                    'Defesa ${c.defesa}',
                    ...f.condicoes,
                    if (ordem.where((e) => asStr(e['id']) == asStr(f.d['alvo'])).firstOrNull case final m?)
                      'mira ${asStr(m['nome'])}',
                  ].join(' · '),
                ),
          ],
          ameacas: [
            for (final e in ordem)
              if (asStr(e['tipo']) != 'agente')
                if (ameacas[asStr(e['ref'])] case final d)
                  Participante(
                    id: asStr(e['id']),
                    nome: asStr(e['nome']),
                    pv: d == null ? null : asInt(d['pv']),
                    pvMax: d == null ? null : asInt(d['pvMax']),
                    naVez: vez != null && asStr(e['id']) == asStr(vez['id']),
                    linha: d == null
                        ? 'Participante'
                        : ['Defesa ${asInt(d['defesa'])}', ...asStrList(d['condicoes'])].join(' · '),
                  ),
          ],
          aoTocarAgente: (p) => setState(() => _alvo = _alvo == p.id ? null : p.id),
          aoTocarAmeaca: (p) {
            if (!entradas.any((e) => asStr(e['id']) == p.id)) return;
            setState(() {
              _atuante = p.id;
              _atuanteNoTurno = turno;
            });
          },
        ),
      ],
      _titulo('ORDEM DE INICIATIVA'),
      if (ordem.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Role a iniciativa dos agentes e adicione as ameaças para começar.',
              textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
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
            final saiu = ordem[i];
            final o = _ordem..removeAt(i);
            final f = porId[asStr(saiu['ref'])];
            _salvarOrdem(o,
                turno: turno > i ? turno - 1 : turno,
                fora: asStr(saiu['tipo']) == 'agente' && f != null ? [...asStrList(_cb['fora']), f.id] : null);
          },
        ),
    ]);
  }

  Widget _painelAcao(
    BuildContext context, {
    required List<Ficha> fichas,
    required Map<String, Ficha> porId,
    required Map<String, Map<String, dynamic>> ameacas,
    required Ficha? alvo,
    required String? ameacaId,
    required Map<String, dynamic>? ameaca,
    required Color cor,
  }) {
    final uso = _uso;
    final nome = ameaca == null ? '' : asStr(ameaca['nome'], 'Ameaça');
    return ListView(controller: _rolagemAcao, padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(child: Text('AÇÃO', style: estiloTitulo(20, cor: corDeTexto(cor)))),
        const Text('Secreta', style: TextStyle(fontSize: 13, color: Cores.textoFraco)),
        Tooltip(
          message: 'Rolagens secretas ficam só no registro do mestre',
          child: Switch(value: _secreto, onChanged: (v) => setState(() => _secreto = v)),
        ),
      ]),
      Text(
        ameaca == null
            ? 'Nenhuma ameaça no combate. Adicione uma em Combate.'
            : alvo == null
                ? '$nome age. Escolha o alvo entre os agentes em Combate.'
                : '$nome age contra ${alvo.nome} (Defesa ${Calc(alvo, camp.regras).defesa}).',
        style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco),
      ),
      if (uso != null && uso.ameacaId == ameacaId) ...[
        const SizedBox(height: 12),
        CartaoUso(
          key: ObjectKey(uso),
          uso: uso,
          camp: camp,
          alvo: uso.alvoId == null ? null : porId[uso.alvoId],
          ameaca: ameacas[uso.ameacaId],
          aoFechar: () => setState(() => _uso = null),
        ),
      ],
      if (ameaca != null && ameacaId != null)
        AcoesDaAmeaca(
          acoes: acoesDaAmeaca(ameaca),
          cor: cor,
          aoUsar: (a) => _usar(a, ameacaId, ameaca, alvo),
        ),
    ]);
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
          aoMudar: (v) => Repo.mudarPontos(f, 'pvAtual', v));
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
        borderRadius: BorderRadius.circular(4),
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
                    borderRadius: BorderRadius.circular(4)),
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
