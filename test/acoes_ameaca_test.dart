import 'dart:io';

import 'package:cris_ficha/core/acoes_ameaca.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:cris_ficha/screens/master/ameacas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Catalogo.instance.carregar());

  test('cada ataque e cada habilidade das ameaças dos livros vira uma ação', () {
    final ameacas = Catalogo.instance.ameacas;
    expect(ameacas.length, greaterThan(150));
    final saida = StringBuffer();
    for (final a in ameacas) {
      final acoes = acoesDaAmeaca(ameacaDoLivro(a));
      final ataques = asMapList(a['ataques']);
      final habilidades = asMapList(a['habilidades']);
      final nome = asStr(a['nome']);
      expect(acoes.where((x) => x.ataque).length, ataques.length, reason: nome);
      expect(acoes.where((x) => !x.ataque && x.tipo != 'Enigma').length, habilidades.length, reason: nome);
      for (final (i, at) in ataques.indexed) {
        final x = acoes.where((x) => x.ataque).elementAt(i);
        final t = testeDoLivro(at['teste']);
        expect((x.nome, x.dados, x.bonus), (asStr(at['nome']), t.$1, t.$2), reason: nome);
        if (asStr(at['dano']).contains(RegExp(r'\dd\d'))) {
          expect(x.rolagens, isNotEmpty, reason: '$nome: ${at['nome']}');
        }
      }
      for (final h in habilidades) {
        final x = acoes.firstWhere((x) => x.nome == asStr(h['nome']) && x.tipo == asStr(h['acao']));
        final texto = asStr(h['resumo']);
        if (RegExp(r'(Fortitude|Reflexos|Vontade)\s*\(?DT\s*\d+').hasMatch(texto)) {
          expect(x.resistencias, isNotEmpty, reason: '$nome: ${x.nome}');
        }
        if (RegExp(r'\d+d(4|6|8|10|12)\b').hasMatch(texto)) {
          expect(x.rolagens, isNotEmpty, reason: '$nome: ${x.nome}');
        }
        saida.writeln('[${x.tipo}] $nome / ${x.nome}\n    ${x.mecanica}'
            '${x.condicoes.isEmpty ? '' : '\n    condições: ${x.condicoes.join(', ')}'}\n    $texto');
      }
    }
    final arquivo = Platform.environment['ACOES_AMEACA_SAIDA'];
    if (arquivo != null) File(arquivo).writeAsStringSync(saida.toString());
  });

  test('linhas escritas à mão também viram ações', () {
    final x = acaoDaLinha('Sopro gélido: 6d6 de frio em cone (Reflexos DT 18 metade), fica lento')!;
    expect((x.tipo, x.nome), ('Outra', 'Sopro gélido'));
    expect(x.rolagens.single.tipoDano, 'frio');
    expect(x.resistencias.single.metade, isTrue);
    expect(x.condicoes, contains('Lento'));
    final a = acaoDaLinha('Ataque: Garras (Corpo a corpo x2): 3d20+12, crítico 19/x3 • 2d8+6 corte')!;
    expect((a.ataque, a.golpes, a.dados, a.bonus, a.critico), (true, 2, 3, 12, '19/x3'));
    expect(a.tiposDano, ['corte']);
  });
}
