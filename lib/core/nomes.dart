import 'dart:math';

// Nomes e sobrenomes comuns no Brasil, para o gerador de nomes do mestre
// (NPCs, testemunhas, cultistas...).

const nomesFemininos = [
  'Adriana', 'Aline', 'Ana', 'Beatriz', 'Bruna', 'Camila', 'Carolina', 'Cecília', 'Clara', 'Cristina',
  'Dalva', 'Daniela', 'Débora', 'Eduarda', 'Elaine', 'Eliane', 'Fernanda', 'Francisca', 'Gabriela', 'Glória',
  'Helena', 'Irene', 'Isabela', 'Jéssica', 'Joana', 'Juliana', 'Larissa', 'Laura', 'Letícia', 'Lívia',
  'Luana', 'Lúcia', 'Luíza', 'Marcela', 'Mariana', 'Marina', 'Marta', 'Natália', 'Neusa', 'Patrícia',
  'Paula', 'Priscila', 'Rafaela', 'Raquel', 'Renata', 'Rosa', 'Sabrina', 'Sandra', 'Simone', 'Sofia',
  'Sônia', 'Tatiana', 'Teresa', 'Thaís', 'Valéria', 'Vanessa', 'Vera', 'Vitória', 'Yasmin', 'Zilda',
];

const nomesMasculinos = [
  'Álvaro', 'André', 'Antônio', 'Arthur', 'Augusto', 'Benedito', 'Bernardo', 'Bruno', 'Caio', 'Carlos',
  'César', 'Cláudio', 'Daniel', 'Davi', 'Diego', 'Edson', 'Eduardo', 'Emanuel', 'Fábio', 'Felipe',
  'Fernando', 'Francisco', 'Gabriel', 'Geraldo', 'Guilherme', 'Gustavo', 'Heitor', 'Hélio', 'Henrique', 'Igor',
  'João', 'Jorge', 'José', 'Júlio', 'Leonardo', 'Lucas', 'Luiz', 'Marcelo', 'Marcos', 'Mateus',
  'Miguel', 'Murilo', 'Nícolas', 'Otávio', 'Paulo', 'Pedro', 'Rafael', 'Raimundo', 'Renato', 'Ricardo',
  'Roberto', 'Rodrigo', 'Samuel', 'Sérgio', 'Thiago', 'Tomás', 'Vinícius', 'Vítor', 'Wagner', 'Wellington',
];

const sobrenomes = [
  'Aguiar', 'Albuquerque', 'Almeida', 'Alves', 'Andrade', 'Araújo', 'Barbosa', 'Barros', 'Batista', 'Bezerra',
  'Bittencourt', 'Brandão', 'Campos', 'Cardoso', 'Carvalho', 'Cavalcanti', 'Coelho', 'Correia', 'Costa', 'Dias',
  'Duarte', 'Fagundes', 'Farias', 'Fernandes', 'Ferreira', 'Fonseca', 'Freitas', 'Gomes', 'Gonçalves', 'Guimarães',
  'Leite', 'Lima', 'Lopes', 'Machado', 'Magalhães', 'Marques', 'Martins', 'Medeiros', 'Mendes', 'Moreira',
  'Moura', 'Nascimento', 'Novaes', 'Nunes', 'Oliveira', 'Pacheco', 'Peixoto', 'Pereira', 'Pinto', 'Prado',
  'Queiroz', 'Ramos', 'Rezende', 'Ribeiro', 'Rocha', 'Rodrigues', 'Sampaio', 'Santana', 'Santos', 'Silva',
  'Siqueira', 'Soares', 'Souza', 'Tavares', 'Teixeira', 'Toledo', 'Vasconcelos', 'Vieira', 'Xavier',
];

/// Um nome inventado: 'f' (feminino), 'm' (masculino) ou qualquer outro
/// valor para sortear o gênero. O nome do meio é de outro nome do mesmo
/// gênero; os sobrenomes não se repetem.
String gerarNome(Random r, {String genero = '', bool nomeDoMeio = false, bool doisSobrenomes = false}) {
  final g = genero == 'f' || genero == 'm' ? genero : (r.nextBool() ? 'f' : 'm');
  final lista = g == 'f' ? nomesFemininos : nomesMasculinos;
  T sortear<T>(List<T> l) => l[r.nextInt(l.length)];
  final nome = sortear(lista);
  var meio = sortear(lista);
  while (meio == nome) {
    meio = sortear(lista);
  }
  final s1 = sortear(sobrenomes);
  var s2 = sortear(sobrenomes);
  while (s2 == s1) {
    s2 = sortear(sobrenomes);
  }
  return [nome, if (nomeDoMeio) meio, if (doisSobrenomes) s2, s1].join(' ');
}
