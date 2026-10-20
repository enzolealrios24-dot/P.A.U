import 'package:flutter/material.dart';

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

  void _publicar(BuildContext context, Rolagem r) {
    mostrarRolagem(context, r);
    final c = camp;
    if (c != null) Repo.registrarRolagem(c.id, r, personagem: f.nome);
  }

  void rolarPericia(BuildContext context, String pericia,
      {int dadosExtra = 0, int bonusExtra = 0}) {
    final r = Dados.rolarTeste(
      titulo: '${f.nome}: $pericia',
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
    final crit = Dados.critico(asStr(arma['critico'], '20/x2'));
    final attrAtaque = agil
        ? (calc.agi > calc.forca ? calc.agi : calc.forca)
        : calc.attr(periciaPorNome(pericia)?.attr ?? 'for');
    final teste = Dados.rolarTeste(
      titulo: '${f.nome}: ataque com ${asStr(arma['nome'], 'arma')}',
      nDados: attrAtaque +
          calc.modDados(pericia: pericia, ataque: true, corpo: ataque == 'corpo') +
          dadosExtra,
      bonus: calc.bonusPericia(pericia) + asInt(arma['bonusAtaque']) + bonusExtra,
      margemCritico: crit.margem,
    );
    final danoExpr = asStr(arma['dano'], '1d4');
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
      danoTotal: dano.total + extra,
      danoDetalhe:
          '${dano.detalhe}${extra != 0 ? ' ${extra > 0 ? '+' : '-'} ${extra.abs()}' : ''}${teste.critico ? '  (crítico x${crit.mult})' : ''}',
    );
    _publicar(context, r);
  }

  void conjurar(BuildContext context, Map<String, dynamic> ritual,
      {required String forma}) {
    final circulo = asInt(ritual['circulo'], 1);
    var custo = asInt(ritual['custo']);
    if (custo <= 0) custo = calc.custoRitual(circulo);
    if (forma == 'Discente') custo += asInt(ritual['custoDiscente']);
    if (forma == 'Verdadeiro') custo += asInt(ritual['custoVerdadeiro']);
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
      titulo: '${f.nome} conjura ${asStr(ritual['nome'], 'ritual')}',
      detalhe:
          '$forma • ${circulo}º círculo • ${asStr(ritual['elemento'])} • gastou $custo ${calc.determinacao ? 'PD' : 'PE'} • DT ${calc.dtRitual}',
      total: custo,
      danoTotal: d == null ? null : d.total + extraRitual,
      danoDetalhe: d == null
          ? null
          : '${d.detalhe}${extraRitual != 0 ? ' + $extraRitual' : ''}',
    );
    _publicar(context, r);
  }
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
