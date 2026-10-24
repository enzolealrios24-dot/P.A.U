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

  test('Treino em perícia: quem não era treinado passa a ser; quem era ganha +2', () {
    final base = {'classe': 'Combatente', 'poderes': [poder('ac', 'sah/g.acrobatico')]};
    final semTreino = Calc(ficha(base));
    expect(semTreino.grau('Acrobacia'), 5);
    final treinado = Calc(ficha({...base, 'pericias': {'Acrobacia': {'grau': 5}}}));
    expect(treinado.grau('Acrobacia'), 5);
    expect(treinado.bonusPericia('Acrobacia') - semTreino.bonusPericia('Acrobacia'), 2);
  });

  test('Instinto de Fuga ativo dá +2 em todas as perícias', () {
    final base = {'classe': 'Combatente', 'poderes': [poder('if', 'sah/c.instinto_fuga')]};
    final parado = Calc(ficha(base));
    final fugindo = Calc(ficha({...base, 'ativos': ['poder:if']}));
    for (final p in ['Atletismo', 'Furtividade', 'Vontade']) {
      expect(fugindo.bonusPericia(p) - parado.bonusPericia(p), 2);
    }
  });

  test('Valentão usa Força em Intimidação e Racionalidade usa Intelecto nos PE', () {
    final c = Calc(ficha({
      'classe': 'Especialista',
      'atributos': {'agi': 1, 'for': 3, 'int': 3, 'pre': 1, 'vig': 1},
      'poderes': [poder('va', 'sah/c.valentao'), poder('ri', 'sah/g.racionalidade_inflexivel')],
    }));
    expect(c.atributoDaPericia('Intimidação'), 'for');
    expect(c.dadosPericia('Intimidação'), 3);
    expect(c.atributoPE, 'int');
  });

  test('Monstruoso (Conhecimento): Int na Defesa e RD que cresce no Ser Macabro', () {
    final base = {
      'classe': 'Combatente',
      'trilha': 'Monstruoso',
      'atributos': {'agi': 1, 'for': 1, 'int': 3, 'pre': 1, 'vig': 1},
      'escolhasPoder': {'trilha:Monstruoso:Ser Amaldiçoado': ['Conhecimento']},
    };
    final nex10 = Calc(ficha({...base, 'nex': 10}));
    final semEscolha = Calc(ficha({'classe': 'Combatente', 'trilha': 'Monstruoso', 'nex': 10,
        'atributos': {'agi': 1, 'for': 1, 'int': 3, 'pre': 1, 'vig': 1}}));
    expect(nex10.defesa - semEscolha.defesa, 3);
    expect(nex10.rdContra('balistico'), 5);
    expect(nex10.rdContra('corte'), 0);
    final nex40 = Calc(ficha({...base, 'nex': 40}));
    expect(nex40.rdContra('balistico'), 10);
    expect(nex40.rdContra('conhecimento'), 10);
  });

  test('CQB: treina Pontaria; com Pontaria, treina Luta; com as duas, +2 nelas', () {
    Calc c(Map<String, dynamic> pericias) =>
        Calc(ficha({'classe': 'Combatente', 'trilha': 'Incursor', 'nex': 10, 'pericias': pericias}));
    expect(c({}).grau('Pontaria'), 5);
    expect(c({}).grau('Luta'), 0);
    expect(c({'Pontaria': {'grau': 5}}).grau('Luta'), 5);
    final ambas = c({'Pontaria': {'grau': 5}, 'Luta': {'grau': 5}});
    final nada = Calc(ficha({'classe': 'Combatente', 'pericias': {'Pontaria': {'grau': 5}, 'Luta': {'grau': 5}}}));
    expect(ambas.bonusPericia('Luta') - nada.bonusPericia('Luta'), 2);
  });

  test('Exorcizado: RD 5 contra o elemento escolhido', () {
    final c = Calc(ficha({
      'classe': 'Ocultista',
      'origem': 'Exorcizado',
      'escolhasPoder': {'origem:Exorcizado': ['Sangue']},
    }));
    expect(c.rdContra('sangue'), 5);
    expect(c.rdContra('morte'), 0);
  });

  test('Treinado pela Hell Hunters: PV só com Luta e Fortitude treinadas', () {
    final base = {'classe': 'Combatente', 'origem': 'Treinado pela Hell Hunters', 'nex': 20};
    final sem = Calc(ficha(base));
    final com = Calc(ficha({...base, 'pericias': {'Luta': {'grau': 5}, 'Fortitude': {'grau': 5}}}));
    expect(com.pvMax - sem.pvMax, 2 + 2);
  });

  test('Ensaio: +1 na margem e cada habilidade seguinte da trilha soma +1 enquanto vale', () {
    final base = {'classe': 'Combatente', 'trilha': 'Performático', 'nex': 65};
    expect(Calc(ficha(base)).margemAtaque(corpo: true), 0);
    final ensaiado = Calc(ficha({...base, 'ativos': ['trilha:Performático:Ensaio']}));
    expect(ensaiado.margemAtaque(corpo: true), 3);
  });

  test('Habilidade oculta não conta na ficha', () {
    final base = {'classe': 'Combatente', 'origem': 'Policial'};
    final normal = Calc(ficha(base));
    final o = normal.origemDados!;
    final oculta = Calc(ficha({...base, 'habilidadesOcultas': [Calc.chaveOrigem(o)]}));
    expect(normal.defesa - oculta.defesa, 2);
  });
}
