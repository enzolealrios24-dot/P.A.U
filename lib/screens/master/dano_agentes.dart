import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/acoes_ameaca.dart';
import '../../core/dano.dart';
import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/imagem.dart';
import '../sheet/tab_combate.dart' show tirarDano;
import 'acao_ameaca.dart';

/// Um golpe de agente (ataque ou ritual com dano) contra alguém do combate:
/// o id do registro, a rolagem e a entrada da iniciativa do alvo.
typedef GolpeAgente = ({String id, Map<String, dynamic> r, Map<String, dynamic> alvo});

/// Os golpes contra quem ainda está na ordem deste combate (os de combates
/// encerrados ficam de fora: as entradas da ordem são novas a cada combate).
List<GolpeAgente> golpesDoCombate(List<(String, Map<String, dynamic>)> registros, List<Map<String, dynamic>> ordem) {
  final porId = {for (final e in ordem) asStr(e['id']): e};
  return [
    for (final (id, r) in registros)
      if (porId[asStr(r['alvo'])] case final e?) (id: id, r: r, alvo: e),
  ];
}

bool golpeResolvido(Map<String, dynamic> marcas, String id) => asStr(asMap(marcas[id])['estado']).isNotEmpty;

/// A terceira parte do combate do mestre: os ataques e rituais dos agentes.
/// Cada um diz se acertou a Defesa do alvo e quanto dano ele sofre (com RD,
/// imunidade e vulnerabilidade); o mestre aplica ou dispensa.
class DanoDosAgentes extends StatelessWidget {
  final Campanha camp;
  final List<GolpeAgente> golpes;
  /// O que o mestre já fez com cada golpe, pelo id.
  final Map<String, dynamic> marcas;
  final Map<String, Ficha> porId;
  final Map<String, Map<String, dynamic>> ameacas;
  const DanoDosAgentes({
    super.key,
    required this.camp,
    required this.golpes,
    required this.marcas,
    required this.porId,
    required this.ameacas,
  });

  @override
  Widget build(BuildContext context) {
    // a conferir na ordem em que chegaram; os resolvidos, o mais novo antes
    final pendentes = golpes.where((g) => !golpeResolvido(marcas, g.id)).toList().reversed.toList();
    final resolvidos = golpes.where((g) => golpeResolvido(marcas, g.id)).take(8).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text('DANO', style: estiloTitulo(20, cor: Cores.destaque))),
        if (pendentes.isNotEmpty)
          Text('${pendentes.length} para conferir',
              style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w600, espaco: 0.4)),
      ]),
      Text(
        pendentes.isEmpty
            ? 'Quando um agente atacar ou conjurar um ritual com dano contra alguém do combate, o golpe aparece aqui para você conferir e aplicar.'
            : 'Golpes dos agentes: confira se acertou e aplique o dano no alvo.',
        style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco),
      ),
      for (final g in pendentes) ...[
        const SizedBox(height: 12),
        _CartaoGolpe(
          key: ValueKey(g.id),
          camp: camp,
          golpe: g,
          marca: asMap(marcas[g.id]),
          atacante: porId[asStr(g.r['fichaId'])],
          agenteAlvo: asStr(g.alvo['tipo']) == 'agente' ? porId[asStr(g.alvo['ref'])] : null,
          ameaca: asStr(g.alvo['tipo']) == 'agente' ? null : ameacas[asStr(g.alvo['ref'])],
        ),
      ],
      if (resolvidos.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: Text('RESOLVIDOS',
              style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 1.6)),
        ),
        for (final g in resolvidos) _LinhaResolvida(camp: camp, golpe: g, marca: asMap(marcas[g.id])),
      ],
    ]);
  }
}

String _nomeDoGolpe(Map<String, dynamic> golpe) {
  final nome = asStr(golpe['nome']);
  return asStr(golpe['acao']) == 'ritual'
      ? '$nome${asStr(golpe['forma'], 'Padrão') == 'Padrão' ? '' : ' (${asStr(golpe['forma']).toLowerCase()})'}'
      : 'Ataque com $nome';
}

class _CartaoGolpe extends StatefulWidget {
  final Campanha camp;
  final GolpeAgente golpe;
  final Map<String, dynamic> marca;
  final Ficha? atacante;
  /// O alvo, se for um agente (fogo amigo).
  final Ficha? agenteAlvo;
  /// O alvo, se for uma ameaça da mesa.
  final Map<String, dynamic>? ameaca;
  const _CartaoGolpe({
    super.key,
    required this.camp,
    required this.golpe,
    required this.marca,
    required this.atacante,
    required this.agenteAlvo,
    required this.ameaca,
  });

  @override
  State<_CartaoGolpe> createState() => _CartaoGolpeState();
}

class _CartaoGolpeState extends State<_CartaoGolpe> {
  String? _tipo;
  bool _metadeManual = false;
  bool _contarAcerto = false;

  Map<String, dynamic> get _r => widget.golpe.r;
  Map<String, dynamic> get _golpe => asMap(_r['golpe']);
  String get _alvoNome => asStr(widget.golpe.alvo['nome'], 'Alvo');

  /// Teste de resistência do alvo contra o ritual, guardado com o golpe.
  void _rolarResistencia(String pericia, int dt) {
    final Rolagem t;
    final ameaca = widget.ameaca;
    final agente = widget.agenteAlvo;
    if (agente != null) {
      final c = Calc(agente, widget.camp.regras);
      t = Dados.rolarTeste(
          titulo: '${agente.nome}: $pericia (DT $dt)', nDados: c.dadosPericia(pericia), bonus: c.bonusPericia(pericia));
      Repo.registrarRolagem(widget.camp.id, t, personagem: agente.nome);
    } else {
      // a ficha da ameaça anota "Fortitude 2d20+5"; sem anotação, 1d20
      final m = RegExp('$pericia\\s+([^•,;\\n]+)').firstMatch(asStr(ameaca?['pericias']));
      final (n, b) = testeDoLivro(m?[1] ?? '1d20');
      t = Dados.rolarTeste(titulo: '$_alvoNome: $pericia (DT $dt)', nDados: n, bonus: b);
      Repo.registrarRolagem(widget.camp.id, t, personagem: _alvoNome, secreta: true);
    }
    Repo.marcarGolpe(widget.camp.id, widget.golpe.id, {
      'resistencia': {'pericia': pericia, 'total': t.total, 'detalhe': t.detalhe},
    });
  }

  void _aplicar(int sofrido, String tipo) {
    final ameaca = widget.ameaca;
    final agente = widget.agenteAlvo;
    if (ameaca != null) {
      Repo.salvarDoc(Repo.ameacas(widget.camp.id), asStr(widget.golpe.alvo['ref']),
          {'pv': max(0, asInt(ameaca['pv']) - sofrido)});
    } else if (agente != null) {
      tirarDano(agente, Calc(agente, widget.camp.regras), sofrido, mental: tipo == 'mental');
    }
    Repo.marcarGolpe(widget.camp.id, widget.golpe.id, {'estado': 'aplicado', 'sofreu': sofrido, 'tipo': tipo});
  }

  void _dispensar() => Repo.marcarGolpe(widget.camp.id, widget.golpe.id, {'estado': 'dispensado'});

  @override
  Widget build(BuildContext context) {
    final cor = Cores.destaque;
    final golpe = _golpe;
    final ritual = asStr(golpe['acao']) == 'ritual';
    final ameaca = widget.ameaca;
    final agente = widget.agenteAlvo;
    final calc = agente == null ? null : Calc(agente, widget.camp.regras);
    final res = ameaca == null ? null : ResistenciasAmeaca.doTexto(asStr(ameaca['resistencias']));
    final semFicha = ameaca == null && agente == null;
    final dano = asInt(_r['danoTotal']);

    int rdContra(String tipo) => res?.rdContra(tipo) ?? calc?.rdContra(tipo) ?? 0;
    int sofre(String tipo, {bool metade = false}) =>
        res?.danoSofrido(dano, tipo, metade: metade) ?? danoFinal(dano, rdContra(tipo), metade: metade);

    // com mais de um tipo possível ("corte ou perfuração"), o que fere mais
    final tipos = asStrList(golpe['tiposDano']);
    final tipo = _tipo ?? (tipos.isEmpty ? '' : tipos.reduce((a, b) => sofre(b) > sofre(a) ? b : a));
    final nomeTipo = tipoDanoPorId(tipo)?.nome.toLowerCase() ?? '';

    // acerto: o ataque contra a Defesa do alvo (ritual não rola ataque)
    final total = asInt(_r['total']);
    final critico = asBool(_r['critico']);
    final defesa = ameaca != null ? asInt(ameaca['defesa']) : calc?.defesa;
    final acertou = ritual || defesa == null ? null : total >= defesa;
    final conta = acertou != false || _contarAcerto;

    // resistência contra o ritual: "reduz à metade" e "anula" valem sozinhos
    final textoRes = asStr(golpe['resistencia']);
    final pericia = RegExp(r'Fortitude|Reflexos|Vontade').firstMatch(textoRes)?[0];
    final dt = asInt(golpe['dt']);
    final salvo = asMap(widget.marca['resistencia']);
    final passou = salvo.isEmpty ? null : asInt(salvo['total']) >= dt;
    final modo = semAcento(textoRes.toLowerCase());
    final metadeSozinha = passou == true && modo.contains('metade');
    final evita = passou == true && modo.contains('anula');
    final metade = metadeSozinha || _metadeManual;
    final sofrido = !conta || evita ? 0 : sofre(tipo, metade: metade);

    final rd = rdContra(tipo);
    final imune = res?.imuneA(tipo) ?? false;
    final vulneravel = res?.vulneravel.contains(tipo) ?? false;
    final ajustes = [
      if (imune) 'imune'
      else ...[
        if (metade) 'metade ${dano ~/ 2}',
        if (vulneravel) 'vulnerável: dobro',
        if (rd > 0) 'RD $rd',
      ],
    ];
    final recurso = tipo == 'mental' && calc != null ? (calc.determinacao ? 'PD' : 'SAN') : 'PV';

    final linhas = <Widget>[
      if (!ritual)
        LinhaResultado(
          titulo: 'Ataque $total',
          detalhe: asStr(_r['detalhe']),
          resultado: acertou == null
              ? (critico ? 'crítico' : null)
              : acertou
                  ? (critico ? 'acertou, crítico' : 'acertou')
                  : 'errou (Defesa $defesa)',
          bom: acertou,
          cor: cor,
        ),
      if (ritual && dt > 0)
        LinhaResultado(
          titulo: 'DT $dt',
          detalhe: textoRes,
          resultado: textoRes.isEmpty ? null : textoRes,
          cor: cor,
        ),
      if (salvo.isNotEmpty)
        LinhaResultado(
          titulo: '$_alvoNome: ${asStr(salvo['pericia'])} ${asInt(salvo['total'])} contra DT $dt',
          detalhe: asStr(salvo['detalhe']),
          resultado: passou!
              ? (metadeSozinha ? 'passou: metade do dano' : evita ? 'passou: anula' : 'passou')
              : 'falhou',
          bom: !passou,
          cor: cor,
        ),
      if (conta)
        LinhaResultado(
          titulo: 'dano $dano${nomeTipo.isEmpty ? '' : ' $nomeTipo'}'
              '${evita ? ' · anulado' : '${ajustes.isEmpty ? '' : ' · ${ajustes.join(' · ')}'}'
                  '${semFicha || sofrido == dano ? '' : ' · sofre $sofrido'}'}',
          detalhe: asStr(_r['danoDetalhe']),
          cor: cor,
        ),
    ];

    final chips = <Widget>[
      if (ritual && pericia != null && salvo.isEmpty && !semFicha)
        ActionChip(
          avatar: Icon(Icons.casino_outlined, size: 16, color: cor),
          label: Text('Rolar $pericia de ${_alvoNome.split(' ').first}'),
          onPressed: () => _rolarResistencia(pericia, dt),
        ),
      if (acertou == false)
        FilterChip(
          label: const Text('Contar como acerto'),
          selected: _contarAcerto,
          onSelected: (v) => setState(() => _contarAcerto = v),
        ),
      if (ritual && !metadeSozinha && !evita)
        FilterChip(
          label: const Text('Metade do dano'),
          selected: _metadeManual,
          onSelected: (v) => setState(() => _metadeManual = v),
        ),
      if (conta) ...[
        for (final t in tipos.length > 1 ? tipos : const <String>[])
          ChoiceChip(
            label: Text(tipoDanoPorId(t)?.nome ?? t),
            selected: tipo == t,
            onSelected: (_) => setState(() => _tipo = t),
          ),
        if (!semFicha) _TrocarTipo(tipo: tipo, rdContra: rdContra, aoEscolher: (t) => setState(() => _tipo = t)),
      ],
    ];

    final atacante = widget.atacante;
    final quem = asStr(_r['personagem'], atacante?.nome ?? 'Agente');
    return Material(
      color: cor.withValues(alpha: 0.06),
      shape: CorteCantos(corte: 14, cor: cor.withValues(alpha: 0.6)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            RetratoFicha(
              foto: atacante?.foto ?? '',
              nome: quem,
              ajuste: atacante?.fotoAjuste ?? const {},
              largura: 38,
              proporcao: 1,
              raio: 4,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nomeDoGolpe(golpe), style: estiloTitulo(17, cor: Cores.texto)),
                Text('$quem contra $_alvoNome', style: TextStyle(fontSize: 13, color: corDeTexto(cor))),
              ]),
            ),
            Icon(ritual ? Icons.auto_awesome : Icons.gps_fixed, size: 20, color: corDeTexto(cor)),
          ]),
          const SizedBox(height: 6),
          ...linhas,
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: chips),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(
                semFicha
                    ? 'Sem ficha para aplicar o dano.'
                    : !conta
                        ? 'Errou: sem dano'
                        : evita
                            ? 'Anulado: sem dano'
                            : imune
                                ? 'Imune: sem dano'
                                : '−$sofrido $recurso',
                style: semFicha || !conta || evita || imune
                    ? const TextStyle(fontSize: 14, color: Cores.textoFraco)
                    : estiloNumero(17, cor: Cores.pv),
              ),
            ),
            TextButton(onPressed: _dispensar, child: const Text('Dispensar')),
            if (!semFicha && conta && sofrido > 0) ...[
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () => _aplicar(sofrido, tipo),
                icon: const Icon(Icons.south, size: 18),
                label: const Text('Aplicar dano'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// Troca o tipo do dano (a arma sem tipo anotado, ou o ritual de outro
/// elemento), mostrando a RD do alvo contra cada um.
class _TrocarTipo extends StatelessWidget {
  final String tipo;
  final int Function(String) rdContra;
  final ValueChanged<String> aoEscolher;
  const _TrocarTipo({required this.tipo, required this.rdContra, required this.aoEscolher});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Trocar o tipo do dano',
        onSelected: aoEscolher,
        itemBuilder: (_) => [
          for (final t in ['', ...tiposDano.map((t) => t.id)])
            PopupMenuItem(
              value: t,
              child: Row(children: [
                Expanded(child: Text(t.isEmpty ? 'Sem tipo' : tipoDanoPorId(t)!.nome)),
                if (rdContra(t) > 0)
                  Text('RD ${rdContra(t)}', style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
              ]),
            ),
        ],
        child: Chip(
          avatar: const Icon(Icons.swap_horiz, size: 16),
          label: Text(tipo.isEmpty ? 'Tipo do dano' : 'Tipo: ${tipoDanoPorId(tipo)?.nome ?? tipo}'),
        ),
      );
}

class _LinhaResolvida extends StatelessWidget {
  final Campanha camp;
  final GolpeAgente golpe;
  final Map<String, dynamic> marca;
  const _LinhaResolvida({required this.camp, required this.golpe, required this.marca});

  @override
  Widget build(BuildContext context) {
    final aplicado = asStr(marca['estado']) == 'aplicado';
    final g = asMap(golpe.r['golpe']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(aplicado ? Icons.check : Icons.remove, size: 16, color: aplicado ? Cores.destaque : Cores.textoFraco),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${asStr(golpe.r['personagem'], 'Agente')}: ${_nomeDoGolpe(g)} contra ${asStr(golpe.alvo['nome'])}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Cores.textoFraco),
          ),
        ),
        const SizedBox(width: 8),
        if (aplicado)
          Text('−${asInt(marca['sofreu'])}', style: estiloNumero(14, cor: Cores.texto))
        else
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => Repo.marcarGolpe(camp.id, golpe.id, {'estado': ''}),
            child: const Text('Reabrir'),
          ),
      ]),
    );
  }
}
