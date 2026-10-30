import 'package:flutter/material.dart';

import '../../core/acoes_ameaca.dart' show condicoesNoTexto;
import '../../core/dano.dart';
import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';

/// Contexto de rolagem de uma ficha.
class CtxFicha {
  final Ficha f;
  final Campanha? camp;
  final Calc calc;
  CtxFicha(this.f, this.camp) : calc = Calc(f, camp?.regras);

  /// A entrada da iniciativa que a ficha mira no combate da mesa (null
  /// fora de combate ou sem alvo).
  Map<String, dynamic>? get _alvo {
    final c = camp;
    final id = asStr(f.d['alvo']);
    if (c == null || id.isEmpty || !asBool(c.combate['ativo'])) return null;
    return asMapList(c.combate['ordem']).where((e) => asStr(e['id']) == id).firstOrNull;
  }

  /// Quem a ficha mira, com o nome que os jogadores veem.
  String? get alvoNome {
    final e = _alvo;
    if (e == null) return null;
    return asStr(e['tipo']) != 'agente' && asBool(e['oculto']) ? 'ameaça oculta' : asStr(e['nome']);
  }

  String get _contra => alvoNome == null ? '' : ' contra $alvoNome';

  /// Com [golpe] (ataque, ou ritual com dano, resistência ou área) num
  /// combate ativo, o registro leva o alvo e quem está no combate, para o
  /// mestre conferir o acerto e aplicar o dano e os efeitos. Sem alvo
  /// marcado, o mestre escolhe.
  void _publicar(BuildContext context, Rolagem r, {Map<String, dynamic>? golpe}) {
    mostrarRolagem(context, r);
    final c = camp;
    if (c == null) return;
    final combate = golpe != null && asBool(c.combate['ativo']);
    Repo.registrarRolagem(c.id, r,
        personagem: f.nome,
        extra: !combate
            ? const {}
            : {
                'alvo': asStr(_alvo?['id']),
                'participantes': [for (final e in asMapList(c.combate['ordem'])) asStr(e['id'])],
                'fichaId': f.id,
                'golpe': golpe,
              });
  }

  /// Dado do destino: 1d20 + [modificador]. 20 natural é acerto crítico e
  /// 1 é falha crítica.
  void rolarDestino(BuildContext context, int modificador) {
    final r = Dados.rolarTeste(titulo: '${f.nome}: Dado do destino', nDados: 1, bonus: modificador);
    _publicar(context, r);
  }

  void rolarPericia(BuildContext context, String pericia,
      {int dadosExtra = 0, int bonusExtra = 0}) {
    final r = Dados.rolarTeste(
      titulo: '${f.nome}: ${pericia == 'Profissão' && f.profissao.isNotEmpty ? 'Profissão (${f.profissao})' : pericia}',
      nDados: calc.dadosPericia(pericia) + dadosExtra,
      bonus: calc.bonusPericia(pericia) + bonusExtra,
    );
    _publicar(context, r);
  }

  void rolarAtributo(BuildContext context, String attr,
      {int dadosExtra = 0, int bonusExtra = 0}) {
    final r = Dados.rolarTeste(
      titulo: '${f.nome}: ${atributosNomes[attr]}',
      nDados: calc.attr(attr) + calc.modDados(attrTeste: attr) + dadosExtra,
      bonus: bonusExtra,
    );
    _publicar(context, r);
  }

  void rolarAtaque(BuildContext context, Map<String, dynamic> arma,
      {int dadosExtra = 0, int bonusExtra = 0}) {
    final tipoAtaque = asStr(arma['ataque']);
    final pericia = asStr(arma['pericia'],
        tipoAtaque.isEmpty || tipoAtaque == 'corpo' ? 'Luta' : 'Pontaria');
    final ataque = tipoAtaque.isNotEmpty
        ? tipoAtaque
        : (pericia == 'Luta' ? 'corpo' : 'disparo');
    final agil = asBool(arma['agil']) && pericia == 'Luta';
    final critArma = Dados.critico(asStr(arma['critico'], '20/x2'));
    // poderes que mexem na margem, no multiplicador e nos dados de dano
    final corpo = ataque == 'corpo';
    final crit = (
      margem: (critArma.margem - calc.margemAtaque(corpo: corpo)).clamp(2, 20),
      mult: critArma.mult + calc.multAtaque(corpo: corpo),
    );
    final attrAtaque = agil
        ? (calc.agi > calc.forca ? calc.agi : calc.forca)
        : calc.attr(periciaPorNome(pericia)?.attr ?? 'for');
    final teste = Dados.rolarTeste(
      titulo: '${f.nome}: ataque com ${asStr(arma['nome'], 'arma')}$_contra',
      nDados: attrAtaque +
          calc.modDados(pericia: pericia, ataque: true, corpo: ataque == 'corpo') +
          dadosExtra,
      bonus: calc.bonusPericia(pericia) + asInt(arma['bonusAtaque']) + bonusExtra,
      margemCritico: crit.margem,
    );
    final danoExpr = comDadosExtras(asStr(arma['dano'], '1d4'), calc.dadosDanoArma(corpo: corpo));
    // corpo a corpo (e arremesso) soma FOR ao dano; armas ageis podem usar AGI
    final somaFor = asBool(arma['somaFor'], ataque == 'corpo');
    final attrDano = agil && calc.agi > calc.forca ? calc.agi : calc.forca;
    final dano = Dados.expressao(danoExpr, multDados: teste.critico ? crit.mult : 1);
    final extra = asInt(arma['bonusDano']) +
        (somaFor ? attrDano : 0) +
        calc.bonusDanoArma(ataque);
    final r = Rolagem(
      titulo: teste.titulo,
      detalhe: '${teste.detalhe}  ($pericia)',
      total: teste.total,
      critico: teste.critico,
      falhaCritica: teste.falhaCritica,
      dados: teste.dados,
      natural: teste.natural,
      bonus: teste.bonus,
      pegouMenor: teste.pegouMenor,
      danoTotal: dano.total + extra,
      danoDetalhe:
          '${dano.detalhe}${extra != 0 ? ' ${extra > 0 ? '+' : '-'} ${extra.abs()}' : ''}${teste.critico ? '  (crítico x${crit.mult})' : ''}',
    );
    _publicar(context, r, golpe: {
      'acao': 'ataque',
      'nome': asStr(arma['nome'], 'arma'),
      'tiposDano': tiposDanoDoTexto(asStr(arma['tipoDano'])),
      'corpo': corpo,
    });
  }

  void conjurar(BuildContext context, Map<String, dynamic> ritual,
      {required String forma}) {
    final circulo = asInt(ritual['circulo'], 1);
    final custo = calc.custoConjuracao(ritual, forma);
    if (custo > calc.limitePE) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Custo $custo maior que seu limite de ${calc.determinacao ? 'PD' : 'PE'} por turno (${calc.limitePE}).')));
    }
    // O custo sai primeiro dos PE/PD temporários.
    if (calc.determinacao) {
      Repo.mudarPontos(f, 'pdAtual', f.pdAtual - custo);
    } else {
      Repo.mudarPontos(f, 'peAtual', f.peAtual - custo);
    }
    final danoExpr = asStr(ritual[forma == 'Padrão'
        ? 'dano'
        : (forma == 'Discente' ? 'danoDiscente' : 'danoVerdadeiro')]);
    final d = danoExpr.isEmpty
        ? asStr(ritual['dano']).isEmpty
            ? null
            : Dados.expressao(asStr(ritual['dano']))
        : Dados.expressao(danoExpr);
    final extraRitual = d == null ? 0 : calc.bonusDanoRitual;
    final r = Rolagem(
      titulo: '${f.nome} conjura ${asStr(ritual['nome'], 'ritual')}$_contra',
      detalhe:
          '$forma • ${circulo}º círculo • ${asStr(ritual['elemento'])} • gastou $custo ${calc.determinacao ? 'PD' : 'PE'} • DT ${calc.dtRitualDe(asStr(ritual['elemento']))}',
      total: custo,
      danoTotal: d == null ? null : d.total + extraRitual,
      danoDetalhe: d == null
          ? null
          : '${d.detalhe}${extraRitual != 0 ? ' + $extraRitual' : ''}',
    );
    final elemento = asStr(ritual['elemento']);
    final resistencia = asStr(ritual['resistencia']);
    final textoForma = forma == 'Padrão' ? '' : asStr(ritual[forma == 'Discente' ? 'discente' : 'verdadeiro']);
    final efeito = [asStr(ritual['resumo']), if (textoForma.isNotEmpty) '$forma: $textoForma'].join(' ');
    final area = areaDoRitual(asStr(ritual['alvo']), textoForma);
    // rituais só em si mesmo (sem dano, resistência nem área) não vão ao mestre
    final afetaOutros = d != null || resistencia.isNotEmpty || area.isNotEmpty;
    _publicar(context, r, golpe: !afetaOutros ? null : {
      'acao': 'ritual',
      'nome': asStr(ritual['nome'], 'ritual'),
      'forma': forma,
      // o dano do ritual é do elemento dele (o mestre troca se for outro)
      'tiposDano': tiposDanoDoTexto(asStr(ritual['tipoDano'], elemento)),
      'dt': calc.dtRitualDe(elemento),
      'resistencia': resistencia,
      'area': area,
      'efeito': efeito,
      'condicoes': condicoesNoTexto(efeito),
    });
  }
}

/// A área de um ritual ("Área: nuvem de 6m de raio"), pelo alvo dele ou
/// pelo texto da forma conjurada ("Explosão de 6m de raio..."); '' se ele
/// mira um alvo só.
String areaDoRitual(String alvo, String textoForma) {
  final area = RegExp(r'\barea\b|\braio\b|\blinha de|\bcone\b|esfera|nuvem|cubos|todos os alvos|seres escolhidos|cada alvo|ate \d+ (seres|pessoas)');
  if (textoForma.isNotEmpty && area.hasMatch(semAcento(textoForma.toLowerCase()))) {
    return textoForma.split(RegExp(r'\.\s')).first.replaceAll(RegExp(r'\.$'), '');
  }
  return area.hasMatch(semAcento(alvo.toLowerCase())) ? alvo : '';
}

/// Soma [n] dados ao primeiro grupo "XdY" da expressão (Golpe Pesado: +1
/// dado do mesmo tipo).
String comDadosExtras(String expr, int n) {
  if (n == 0) return expr;
  return expr.replaceFirstMapped(
      RegExp(r'(\d*)d(\d+)'), (m) => '${(int.tryParse(m[1]!) ?? 1) + n}d${m[2]}');
}

/// Dialogo de modificadores (segurar o botao de rolar).
Future<({int dados, int bonus})?> pedirModificadores(BuildContext context) {
  var dados = 0, bonus = 0;
  return showDialog<({int dados, int bonus})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Rolar com modificadores'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _linha('Dados (+/- d20)', dados, (v) => set(() => dados = v)),
          _linha('Bônus no resultado', bonus, (v) => set(() => bonus = v)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, (dados: dados, bonus: bonus)),
              child: const Text('Rolar')),
        ],
      ),
    ),
  );
}

Widget _linha(String r, int v, ValueChanged<int> mudar) => Row(children: [
      Expanded(child: Text(r)),
      IconButton(onPressed: () => mudar(v - 1), icon: const Icon(Icons.remove)),
      SizedBox(
          width: 32,
          child: Text('${v >= 0 ? '+' : ''}$v', textAlign: TextAlign.center)),
      IconButton(onPressed: () => mudar(v + 1), icon: const Icon(Icons.add)),
    ]);
