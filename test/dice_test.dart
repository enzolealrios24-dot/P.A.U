import 'package:cris_ficha/core/dice.dart';
import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teste com atributo 0 rola 2d20 e pega o menor', () {
    for (var i = 0; i < 50; i++) {
      final t = Dados.teste(0);
      expect(t.dados.length, 2);
      expect(t.escolhido, t.dados.reduce((a, b) => a < b ? a : b));
    }
  });

  test('teste com atributo 3 rola 3d20 e pega o maior', () {
    final t = Dados.teste(3);
    expect(t.dados.length, 3);
    expect(t.escolhido, t.dados.reduce((a, b) => a > b ? a : b));
  });

  test('expressao de dano', () {
    for (var i = 0; i < 50; i++) {
      final e = Dados.expressao('2d6+3');
      expect(e.total, inInclusiveRange(5, 15));
    }
    expect(Dados.expressao('4').total, 4);
    expect(Dados.critico('19/x3').margem, 19);
    expect(Dados.critico('19/x3').mult, 3);
  });

  test('calculo de combatente NEX 5% e 50%', () {
    final m = novaFicha('u', 'Eu');
    m['atributos'] = {'agi': 2, 'for': 3, 'int': 1, 'pre': 1, 'vig': 2};
    var c = Calc(Ficha('x', m));
    expect(c.pvMax, 22); // 20 + VIG
    expect(c.peMax, 3); // 2 + PRE
    expect(c.sanMax, 12);
    expect(c.defesa, 12); // 10 + AGI
    expect(c.limitePE, 1);
    expect(c.cargaMax, 15);
    m['nex'] = 50;
    c = Calc(Ficha('x', m));
    expect(c.nivel, 10);
    expect(c.pvMax, 22 + 9 * 6);
    expect(c.limitePE, 10);
    m['nex'] = 99;
    expect(Calc(Ficha('x', m)).nivel, 20);
  });
}
