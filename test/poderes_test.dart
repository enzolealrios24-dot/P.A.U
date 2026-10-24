import 'package:cris_ficha/core/rules.dart';
import 'package:cris_ficha/data/catalogo.dart';
import 'package:cris_ficha/data/models.dart';
import 'package:cris_ficha/screens/sheet/rolar.dart';
import 'package:flutter_test/flutter_test.dart';

// O que os poderes fazem sozinhos na ficha: ativáveis, condições, escolhas,
// dados de dano, custo de ritual e custo pelo NEX.

Ficha ficha(Map<String, dynamic> extra) => Ficha('f1', {...novaFicha('u1', 'Teste'), ...extra});

Map<String, dynamic> poder(String id, String ref) => {'id': id, 'nome': id, 'ref': ref};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Catalogo.instance.carregar());

  test('Sentido Tático só soma o Intelecto na Defesa enquanto está ativo', () {
    final base = {
      'classe': 'Combatente',
      'atributos': {'agi': 1, 'for': 1, 'int': 3, 'pre': 1, 'vig': 1},
      'poderes': [poder('st', 'oprpg/c.sentido_tatico')],
    };
    final desligado = Calc(ficha(base));
    final ligado = Calc(ficha({...base, 'ativos': ['poder:st']}));
    expect(ligado.defesa - desligado.defesa, 3);
    expect(ligado.bonusPericia('Reflexos') - desligado.bonusPericia('Reflexos'), 3);
    expect(desligado.custoPoder(Catalogo.instance.porRef('oprpg/c.sentido_tatico')!), 2);
  });

  test('Sangue Fervente: +1 no atributo escolhido só machucado', () {
    final base = {
      'classe': 'Combatente',
      'poderes': [poder('sf', 'oprpg/p.sangue_fervente')],
      'escolhasPoder': {'poder:sf': ['agi']},
    };
    final inteiro = Calc(ficha({...base, 'pvAtual': 999}));
    final ferido = Calc(ficha({...base, 'pvAtual': 1}));
    expect(ferido.agi - inteiro.agi, 1);
    expect(ferido.forca, inteiro.forca);
  });

  test('Golpe Pesado: +1 dado de dano corpo a corpo', () {
    final c = Calc(ficha({'classe': 'Combatente', 'poderes': [poder('gp', 'oprpg/c.golpe_pesado')]}));
    expect(comDadosExtras('1d8', c.dadosDanoArma(corpo: true)), '2d8');
    expect(comDadosExtras('1d12', c.dadosDanoArma(corpo: false)), '1d12');
  });

  test('Mestre em Elemento baixa o custo só dos rituais do elemento escolhido', () {
    final c = Calc(ficha({
      'classe': 'Ocultista',
      'poderes': [poder('me', 'oprpg/o.mestre_elemento')],
      'escolhasPoder': {'poder:me': ['Sangue']},
    }));
    expect(c.custoRitualFinal({'nome': 'Hemofagia', 'elemento': 'Sangue'}, 3), 2);
    expect(c.custoRitualFinal({'nome': 'Eletrocussão', 'elemento': 'Energia'}, 3), 3);
    expect(c.custoRitualFinal({'nome': 'Hemofagia', 'elemento': 'Sangue'}, 1), 1);
  });

  test('Tanque de Guerra: +2 na Defesa só com proteção pesada equipada', () {
    final base = {
      'classe': 'Combatente',
      'poderes': [poder('tg', 'oprpg/c.tanque_guerra')],
    };
    final pesada = {'id': 'i1', 'nome': 'Proteção pesada', 'tipo': 'protecao', 'ref': 'oprpg/protecao_pesada', 'defesa': 10, 'equipado': true};
    final sem = Calc(ficha(base));
    final com = Calc(ficha({...base, 'inventario': [pesada]}));
    expect(com.defesa - sem.defesa, 12);
  });

  test('Ataque Especial custa mais conforme o NEX', () {
    final meta = Catalogo.instance.classePorNome('Combatente')!;
    final ataque = asMapList(meta['habilidades']).firstWhere((h) => h['nome'] == 'Ataque Especial');
    expect(Calc(ficha({'classe': 'Combatente', 'nex': 5})).custoPoder(ataque), 2);
    expect(Calc(ficha({'classe': 'Combatente', 'nex': 30})).custoPoder(ataque), 3);
    expect(Calc(ficha({'classe': 'Combatente', 'nex': 90})).custoPoder(ataque), 5);
  });

  test('Habilidade oculta não conta na ficha', () {
    final base = {'classe': 'Combatente', 'origem': 'Policial'};
    final normal = Calc(ficha(base));
    final o = normal.origemDados!;
    final oculta = Calc(ficha({...base, 'habilidadesOcultas': [Calc.chaveOrigem(o)]}));
    expect(normal.defesa - oculta.defesa, 2);
  });
}
