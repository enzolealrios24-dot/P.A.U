# Como fazer um mod do P.A.U

Um mod é um arquivo `.json` com conteúdo novo para o P.A.U: origens, classes, trilhas, poderes, rituais, itens, condições e ameaças. O conteúdo aparece nas mesmas listas dos livros, com o nome do mod no lugar do livro.

Um mod é só texto: ele não roda nenhum código no aparelho de quem instala.

## Instalar

No app, toque na sua foto, no canto de cima, e escolha **Mods**. Dá para instalar de dois jeitos:

- **Abrir arquivo**: escolha o `.json` do mod no aparelho.
- **Instalar por link**: cole o link direto do arquivo. No GitHub, use o botão **Raw** do arquivo e copie o endereço que começa com `https://raw.githubusercontent.com/`.

O mod fica só no aparelho em que foi instalado. Instalar de novo um mod com o mesmo `id` atualiza o que já estava lá.

Na mesa, o que um jogador pegou de um mod continua aparecendo na ficha para todo mundo. Quem não tem o mod só não acha esse conteúdo nas listas.

## O arquivo

Comece pelo [exemplo](exemplo.json): copie, troque os dados e apague as listas que não for usar.

```json
{
  "formato": "pau-mod",
  "versaoFormato": 1,
  "id": "meu-mod",
  "nome": "Meu Mod",
  "sigla": "Meu Mod",
  "autor": "Seu nome",
  "versao": "1.0",
  "descricao": "O que o mod traz.",
  "poderes": [ ... ],
  "rituais": [ ... ]
}
```

| Campo | Obrigatório | O que é |
|---|---|---|
| `formato` | sim | Sempre `"pau-mod"`. |
| `versaoFormato` | sim | Sempre `1` por enquanto. |
| `id` | sim | De 2 a 40 letras minúsculas, números ou hífens. Não mude entre versões do mesmo mod: é por ele que o app sabe que é uma atualização. |
| `nome` | sim | Até 60 caracteres. |
| `sigla` | não | Até 24 caracteres. É o que aparece no lugar do nome do livro nas listas. Sem ela, vale o `nome`. |
| `autor`, `versao`, `descricao` | não | Aparecem na tela de Mods. |

Depois vêm as listas, cada uma com os nomes abaixo: `origens`, `classes`, `trilhas`, `poderes`, `rituais`, `itens`, `condicoes` e `ameacas`. O mod precisa ter pelo menos uma.

Toda entrada de uma lista precisa de:

- `id`: sem espaços (letras, números, `_`, `.` ou `-`), único dentro da lista. Não mude depois de publicar: as fichas guardam o conteúdo por esse `id`.
- `nome`: o nome que aparece no app.

E costuma ter `resumo`, o texto curto que aparece na ficha. Escreva com as suas palavras: não copie o texto dos livros de Ordem Paranormal.

## Campos de cada lista

Os campos que faltarem ficam em branco no app. Os principais:

**origens**: `pericias` (lista de nomes de perícias) e `poder`, com `nome` e `resumo`.

**poderes**: `tipo` (`geral`, `paranormal`, `combatente`, `especialista` ou `ocultista`), `resumo`, `prereq` (pré-requisito, em texto), `custo` (ex.: `"2 PE"`) e, nos paranormais, `elemento`.

**rituais**: `elemento` (`Conhecimento`, `Energia`, `Morte`, `Sangue` ou `Medo`), `circulo` (1 a 4), `execucao`, `alcance`, `alvo`, `duracao`, `resistencia`, `resumo` e, se houver, `discente` e `verdadeiro` (o que muda nessas formas) com `custoDiscente` e `custoVerdadeiro`.

**itens**: `tipo` (`arma`, `protecao`, `municao`, `explosivo`, `acessorio`, `operacional` ou `paranormal`), `categoria` (0 a 4), `espacos` e `resumo`. Nas armas: `proficiencia` (`simples`, `tatica` ou `pesada`), `empunhadura` (`leve`, `uma` ou `duas`), `ataque` (`corpo`, `disparo` ou `fogo`), `dano` (ex.: `"1d8"`), `critico` (ex.: `"19"`, `"x3"` ou `"19/x3"`) e `tipoDano` (ex.: `"Corte"`). Nas proteções: `defesa`.

**condicoes**: `categoria` (`mental`, `paralisia`, `sentidos`, `medo` ou `fadiga`) e `resumo`.

**ameacas**: `elemento`, `vd`, `tipo`, `pv`, `defesa`, `deslocamento`, os testes `percepcao`, `iniciativa`, `fortitude`, `reflexos` e `vontade` (ex.: `"2d20+5"`), `atributos` (`agi`, `for`, `int`, `pre`, `vig`), `ataques` (cada um com `nome`, `alcance`, `teste` e `dano`) e `habilidades` (cada uma com `nome` e `resumo`).

**classes** e **trilhas**: seguem o mesmo formato das dos livros e são as listas mais trabalhosas. Uma trilha tem `classe` e `habilidades`, cada habilidade com `nex`, `nome` e `resumo`.

### Efeitos na ficha

Poderes, itens e origens podem ter `efeitos`, que a ficha soma sozinha. Cada efeito tem `alvo` e `valor`, e alguns têm `tipo`:

```json
"efeitos": [
  { "alvo": "defesa", "valor": 2 },
  { "alvo": "rd", "tipo": "mental", "valor": 2 }
]
```

## Quando o app recusa o mod

O app diz o que está errado: um campo obrigatório que falta, um `id` repetido, uma lista que não está entre `[ ]`. Arquivos acima de 2 MB não entram.

## Compartilhar

Publique o `.json` onde quiser: um repositório no GitHub, um gist ou uma pasta compartilhada. Quem for instalar só precisa do arquivo ou do link direto para ele.
