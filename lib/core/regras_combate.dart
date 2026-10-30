// Resumo das principais regras de combate do livro básico (OPRPG, capítulo
// 4), escrito para consulta rápida na mesa. As páginas são as do livro.

class TopicoCombate {
  final String titulo;
  final String paginas;
  final List<(String, String)> itens;
  const TopicoCombate(this.titulo, this.paginas, this.itens);
}

const regrasCombate = <TopicoCombate>[
  TopicoCombate('Rodada, iniciativa e surpresa', 'p. 83–84', [
    ('Rodada', 'Cerca de seis segundos. Cada personagem age no seu turno, na ordem da Iniciativa, e a rodada acaba quando todos agiram.'),
    ('Iniciativa', 'Todos rolam no começo do combate; o mestre faz um teste só para os inimigos, com o menor bônus entre eles. Empatados rolam de novo entre si. A ordem vale até o fim do combate.'),
    ('Entrando depois', 'Quem chega no meio da luta rola Iniciativa e começa a agir na rodada seguinte.'),
    ('Surpresa', 'Quem não percebeu os inimigos começa surpreendido: fica desprevenido e não age na primeira rodada. Em geral, Percepção contra a Furtividade dos inimigos decide quem percebe.'),
  ]),
  TopicoCombate('Ações do turno', 'p. 84–87', [
    ('No seu turno', 'Uma ação padrão e uma de movimento, ou duas de movimento, ou uma ação completa. Além disso, quantas ações livres e reações quiser.'),
    ('Padrão', 'Agredir, conjurar a maioria dos rituais, usar habilidade ou item, fintar e preparar.'),
    ('Fintar', 'Enganação contra os Reflexos de alguém em alcance curto. Passando, ele fica desprevenido contra o seu próximo ataque, até o fim do seu próximo turno.'),
    ('Preparar', 'Você combina uma ação e o gatilho dela ("atiro no primeiro que passar pela porta") e a faz como reação antes do seu próximo turno. Daí em diante, sua Iniciativa fica logo acima de quando preparou.'),
    ('Movimento', 'Andar o deslocamento (normalmente 9 m), levantar-se, sacar ou guardar um item, abrir uma porta, pegar algo da mochila.'),
    ('Mirar', 'Ação de movimento, para quem é treinado em Pontaria: até o fim do próximo turno, tira a penalidade de atirar em um alvo que está em combate corpo a corpo.'),
    ('Investida', 'Ação completa: avança em linha reta até o dobro do deslocamento (mínimo 3 m) e ataca corpo a corpo com +1d20, mas fica com –5 na Defesa até o seu próximo turno. Não dá para fazer em terreno difícil.'),
    ('Golpe de misericórdia', 'Ação completa contra alguém adjacente e indefeso: é um crítico automático, e a vítima pode morrer na hora (1 em 1d4 para personagens e NPCs importantes, 1 a 3 em 1d4 para NPCs secundários).'),
    ('Corrida', 'Ação completa para correr além do deslocamento (veja Atletismo, p. 42).'),
    ('Livres', 'Falar frases curtas, jogar-se no chão, largar um item e atrasar o turno (agir mais tarde na ordem, até 0 menos o seu bônus de Iniciativa).'),
  ]),
  TopicoCombate('Atacar e causar dano', 'p. 82 e 85', [
    ('Teste de ataque', 'Luta para corpo a corpo, Pontaria para distância. Igual ou maior que a Defesa do alvo acerta.'),
    ('Alcance', 'Corpo a corpo alcança quem está a até 1,5 m. À distância, qualquer alvo visível no alcance da arma; até o dobro do alcance com –5.'),
    ('Atirar em quem está no corpo a corpo', 'Quem está a 1,5 m de algum inimigo está em combate corpo a corpo: atirar nele dá –1d20 no ataque (a menos que você tenha mirado).'),
    ('Dano', 'Rola o dano da arma. Corpo a corpo e arremesso somam a Força; armas de disparo e de fogo não.'),
    ('Crítico', 'Se o d20 cair na margem de ameaça da arma (20 se não disser outra) e o ataque acertar, os dados de dano são multiplicados (x2 se não disser outro). Bônus fixos e dados extras não multiplicam.'),
    ('Dano não letal', 'Com arma corpo a corpo, dá para bater sem matar sofrendo –5 no ataque. Ataques desarmados já são não letais; para serem letais, a mesma penalidade.'),
  ]),
  TopicoCombate('Defesa, esquiva e bloqueio', 'p. 36 e 88', [
    ('Defesa', '10 + Agilidade + proteção, habilidades e condições. É a DT para acertar você.'),
    ('Reações de defesa', 'Só uma por rodada, e esquiva ou bloqueio precisam ser declarados antes de o inimigo rolar o ataque.'),
    ('Esquiva', 'Treinado em Reflexos: contra um ataque, soma o seu bônus de Reflexos na Defesa.'),
    ('Bloqueio', 'Treinado em Fortitude, contra um ataque corpo a corpo: ganha RD igual ao seu bônus de Fortitude contra aquele ataque.'),
    ('Contra-ataque', 'Treinado em Luta: quando alguém erra um ataque corpo a corpo em você, você ataca essa pessoa.'),
  ]),
  TopicoCombate('Manobras de combate', 'p. 85–86', [
    ('Como fazer', 'Troque um ataque corpo a corpo por um teste de manobra (Luta) oposto ao Luta do alvo; empate, rolam de novo. Não existe manobra à distância.'),
    ('Agarrar', 'Só desarmado. O alvo fica desprevenido e imóvel, com –1d20 nos ataques e só pode usar armas leves; escapa com uma ação padrão vencendo outro teste. Quem agarra anda metade e tem uma mão ocupada. Atirar em quem está agarrado tem 50% de chance de acertar o outro.'),
    ('Derrubar', 'O alvo fica caído. Vencendo por 5 ou mais, ainda é empurrado 1,5 m.'),
    ('Desarmar', 'O item que ele segura cai. Vencendo por 5 ou mais, o item vai 1,5 m para onde você quiser.'),
    ('Empurrar', 'Afasta o alvo 1,5 m, e mais 1,5 m a cada 5 pontos de diferença.'),
    ('Quebrar', 'Ataca um item que o alvo está segurando.'),
    ('Atropelar', 'Durante o movimento, passa pelo espaço de alguém. Se ele resistir, teste oposto: vencendo, ele fica caído e você segue. É livre durante uma investida.'),
  ]),
  TopicoCombate('Situações especiais', 'p. 89–90', [
    ('Atacante caído', '–2d20 no ataque.'),
    ('Atacante em posição elevada', '+1d20 no ataque.'),
    ('Flanqueando', 'Você e um aliado em lados opostos do inimigo, os dois no corpo a corpo: +1d20 nos ataques corpo a corpo contra ele.'),
    ('Atacante invisível ou ofuscado', 'Invisível: +2d20 (não contra alvos cegos). Ofuscado: –1d20. Cego: 50% de chance de errar.'),
    ('Alvo caído', '–5 na Defesa contra corpo a corpo, +5 contra ataques à distância.'),
    ('Alvo cego ou desprevenido', '–5 na Defesa.'),
    ('Camuflagem', 'Leve: 20% de chance de falha (1 ou 2 num d10 rolado junto). Total: 50% (1 a 5 no d10).'),
    ('Cobertura', 'Leve: +5 na Defesa. Total: não pode ser alvo de ataques nem de habilidades.'),
  ]),
  TopicoCombate('Tipos de dano e resistências', 'p. 82 e 180', [
    ('Tipos', 'Balístico, corte, impacto, perfuração, eletricidade, fogo, frio, químico, mental e paranormal (Conhecimento, Energia, Medo, Morte ou Sangue).'),
    ('Mental', 'Contra personagens, tira Sanidade. Contra ameaças da Realidade, tira PV.'),
    ('Resistência a dano (RD)', 'Ignora parte do dano: RD 5 contra 8 de dano, perde 3. Pode valer só para alguns tipos. "RD 10/Morte" vale para tudo, menos Morte.'),
    ('Imunidade', 'Ignora todo o dano daquele tipo (ou a condição).'),
    ('Vulnerabilidade', 'Sofre o dobro do dano daquele tipo.'),
    ('Perda de vida', 'Tira PV sem passar pela RD.'),
  ]),
  TopicoCombate('Ferimentos e morte', 'p. 88', [
    ('Machucado', 'Com metade dos PV ou menos. Não dá penalidade, mas alguns efeitos pedem essa condição.'),
    ('Morrendo', 'Com 0 PV, fica inconsciente e morrendo. Quem começa três turnos morrendo na mesma cena (não precisam ser seguidos) morre. Curar 1 PV acorda; morrendo só acaba com Medicina DT 20 ou efeitos específicos.'),
    ('Dano massivo', 'Sofrer de uma vez metade dos PV totais ou mais, sem cair a 0: Fortitude DT 15 +2 a cada 10 de dano. Falhando, vai a 0 PV.'),
    ('Dano não letal', 'Conta para desmaiar, mas não para morrer. A cura tira primeiro o dano não letal.'),
  ]),
  TopicoCombate('Sanidade', 'p. 88', [
    ('Perturbado', 'Com menos da metade da Sanidade. Na primeira vez da cena, ganha um efeito de insanidade, só de interpretação (p. 111).'),
    ('Enlouquecendo', 'Com Sanidade 0. Quem começa três turnos enlouquecendo na mesma cena fica insano e vira um NPC do mestre. Acaba com Diplomacia DT 20 ou com qualquer cura de Sanidade.'),
  ]),
  TopicoCombate('Movimentação', 'p. 89', [
    ('Deslocamento', 'Normalmente 9 m (6 quadrados) por ação de movimento. Sobrecarregado, 3 m a menos.'),
    ('Terreno difícil e diagonais', 'Os dois custam o dobro: no terreno difícil você anda metade; no mapa, cada quadrado na diagonal conta como dois.'),
    ('Espaços ocupados', 'Dá para passar por aliados. Por inimigos, só se ele estiver indefeso, for três categorias de tamanho maior ou menor, com Acrobacia ou atropelando.'),
  ]),
];
