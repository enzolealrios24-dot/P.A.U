import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/acoes_ameaca.dart';
import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/imagem.dart';
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

  void _rolarAgentes(List<Ficha> fichas) {
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
    final a = atuante == null ? null : ameacas[asStr(atuante['ref'])];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          onPressed: fichas.isEmpty ? null : () => _rolarAgentes(fichas),
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
              _salvar({'ativo': false, 'rodada': 1, 'turno': 0, 'ordem': <dynamic>[]});
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
            IconButton(onPressed: () => _proximo(-1), icon: const Icon(Icons.skip_previous)),
            Expanded(
              child: Text(
                ativo
                    ? 'RODADA ${asInt(_cb['rodada'], 1)}${vez != null ? ' • vez de ${asStr(vez['nome'])}' : ''}'
                    : 'Sem combate ativo',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton(onPressed: () => _proximo(1), child: const Text('Próximo turno')),
          ]),
        ),
      ),
      if (ordem.isNotEmpty) ...[
        _titulo('ALVO', dica: alvo == null ? 'Toque num agente para mirar nele.' : 'Mirando em ${alvo.nome}.'),
        Material(
          color: Colors.black.withValues(alpha: 0.18),
          shape: CorteCantos(corte: 18, cor: cor.withValues(alpha: 0.35)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('AGENTES',
                  textAlign: TextAlign.center,
                  style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 2)),
              const SizedBox(height: 8),
              _ArcoAgentes(
                agentes: agentes,
                regras: camp.regras,
                alvo: alvo?.id,
                cor: cor,
                aoEscolher: (id) => setState(() => _alvo = _alvo == id ? null : id),
              ),
              const SizedBox(height: 14),
              Text('AMEAÇA',
                  textAlign: TextAlign.center,
                  style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 2)),
              const SizedBox(height: 8),
              if (entradas.length > 1) ...[
                Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                  for (final e in entradas)
                    ChoiceChip(
                      label: Text(asStr(e['nome'])),
                      selected: identical(e, atuante),
                      onSelected: (_) => setState(() {
                        _atuante = asStr(e['id']);
                        _atuanteNoTurno = turno;
                      }),
                    ),
                ]),
                const SizedBox(height: 10),
              ],
              if (a != null)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _CartaoAtuante(
                      camp: camp,
                      id: asStr(atuante!['ref']),
                      d: a,
                      naVez: identical(atuante, vez),
                      cor: cor,
                    ),
                  ),
                )
              else
                const Text('Adicione uma ameaça ao combate para ela agir contra o alvo.',
                    textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco, fontSize: 13)),
            ]),
          ),
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
            final o = _ordem..removeAt(i);
            _salvarOrdem(o, turno: turno > i ? turno - 1 : turno);
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

/// Os agentes em arco, como em volta de uma mesa: as pontas mais baixas e
/// inclinadas. Tocar escolhe o alvo (tocar de novo desfaz).
class _ArcoAgentes extends StatelessWidget {
  final List<Ficha> agentes;
  final Map<String, dynamic> regras;
  final String? alvo;
  final Color cor;
  final ValueChanged<String> aoEscolher;
  const _ArcoAgentes(
      {required this.agentes, required this.regras, required this.alvo, required this.cor, required this.aoEscolher});

  @override
  Widget build(BuildContext context) {
    if (agentes.isEmpty) {
      return const Text('Nenhum agente na mesa.',
          textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco, fontSize: 13));
    }
    Widget cartao(Ficha f) => _CartaoAlvo(
          f: f,
          c: Calc(f, regras),
          escolhido: f.id == alvo,
          cor: cor,
          aoTocar: () => aoEscolher(f.id),
        );
    return LayoutBuilder(builder: (context, c) {
      const espaco = 12.0, alto = 118.0;
      final n = agentes.length;
      final largura = min(176.0, (c.maxWidth - espaco * (n - 1)) / n);
      if (largura < 118) {
        return Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (final f in agentes) SizedBox(width: 150, height: alto, child: cartao(f)),
        ]);
      }
      final queda = n <= 1 ? 0.0 : (n == 2 ? 12.0 : 30.0);
      final inicio = (c.maxWidth - (largura * n + espaco * (n - 1))) / 2;
      return SizedBox(
        height: alto + queda + 10,
        child: Stack(clipBehavior: Clip.none, children: [
          for (final (i, f) in agentes.indexed)
            if (n == 1 ? 0.0 : (i - (n - 1) / 2) / ((n - 1) / 2) case final u)
              Positioned(
                left: inicio + i * (largura + espaco),
                top: 4 + queda * u * u,
                width: largura,
                height: alto,
                child: Transform.rotate(angle: u * 0.11, child: cartao(f)),
              ),
        ]),
      );
    });
  }
}

class _CartaoAlvo extends StatelessWidget {
  final Ficha f;
  final Calc c;
  final bool escolhido;
  final Color cor;
  final VoidCallback aoTocar;
  const _CartaoAlvo(
      {required this.f, required this.c, required this.escolhido, required this.cor, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final max = c.pvMax;
    final frac = max <= 0 ? 0.0 : (f.pvAtual / max).clamp(0.0, 1.0);
    final conds = f.condicoes;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: escolhido ? Color.alphaBlend(cor.withValues(alpha: 0.16), Cores.painel2) : Cores.painel2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: escolhido ? cor : Cores.borda, width: escolhido ? 2 : 1),
            boxShadow: escolhido ? [BoxShadow(color: cor.withValues(alpha: 0.35), blurRadius: 18)] : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: aoTocar,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    RetratoFicha(foto: f.foto, nome: f.nome, ajuste: f.fotoAjuste, largura: 34, proporcao: 1, raio: 4),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.15)),
                    ),
                  ]),
                  const Spacer(),
                  Row(children: [
                    Text('PV ', style: estiloRotulo(11.5, cor: Cores.pv, peso: FontWeight.w700)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 5,
                          color: Cores.pv,
                          backgroundColor: Cores.pv.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${f.pvAtual}/$max', style: estiloNumero(13, cor: Cores.texto)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Defesa ${c.defesa}${conds.isEmpty ? '' : ' · ${conds.join(', ')}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Cores.textoFraco),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (escolhido)
        Positioned(
          top: -9,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3)),
            child: Text('ALVO', style: estiloRotulo(10.5, cor: Cores.fundo, peso: FontWeight.w800, espaco: 1.2)),
          ),
        ),
    ]);
  }
}

/// A ameaça que age, embaixo dos agentes: PV, Defesa e condições.
class _CartaoAtuante extends StatelessWidget {
  final Campanha camp;
  final String id;
  final Map<String, dynamic> d;
  final bool naVez;
  final Color cor;
  const _CartaoAtuante({required this.camp, required this.id, required this.d, required this.naVez, required this.cor});

  @override
  Widget build(BuildContext context) {
    final elem = asStr(d['elemento']);
    return Material(
      color: Color.alphaBlend(cor.withValues(alpha: 0.08), Cores.painel2),
      shape: CorteCantos(corte: 16, cor: cor.withValues(alpha: 0.7)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(asStr(d['nome'], 'Ameaça'), style: estiloTitulo(19, cor: Cores.texto))),
            if (naVez)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    border: Border.all(color: cor), borderRadius: BorderRadius.circular(3)),
                child: Text('NA VEZ', style: estiloRotulo(10.5, cor: corDeTexto(cor), peso: FontWeight.w800, espaco: 1.2)),
              ),
          ]),
          Text(
            [
              'VD ${asInt(d['vd'])}',
              if (elem.isNotEmpty && elem != 'Nenhum') elem,
              'Defesa ${asInt(d['defesa'])}',
              if (asStr(d['deslocamento']).isNotEmpty) asStr(d['deslocamento']),
            ].join(' • '),
            style: const TextStyle(fontSize: 12, color: Cores.textoFraco),
          ),
          const SizedBox(height: 8),
          BarraStatus(
            rotulo: 'PV',
            atual: asInt(d['pv']),
            max: asInt(d['pvMax']),
            cor: Cores.pv,
            compacta: true,
            aoMudar: (v) => Repo.salvarDoc(Repo.ameacas(camp.id), id, {'pv': v}),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final cd in asStrList(d['condicoes']))
              Chip(label: Text(cd, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
            ActionChip(
              label: const Text('Condições', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              onPressed: () => editarCondicoesAmeaca(context, camp, id, d),
            ),
          ]),
        ]),
      ),
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
