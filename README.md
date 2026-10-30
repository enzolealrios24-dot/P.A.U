# P.A.U — fichas de Ordem Paranormal com mesa sincronizada

Projeto pessoal para usar com os amigos. App nativo para **Android** e **Windows** (Flutter + Firebase).

**Baixar:** a versão mais nova fica em [Releases](https://github.com/enzolealrios24-dot/P.A.U/releases/latest). Veja como instalar em [Instalar](#instalar).

Este arquivo é o log do aplicativo: [tudo o que ele tem](#tudo-o-que-o-pau-tem) e o [histórico de versões](#histórico-de-versões).

## Tudo o que o P.A.U tem

### Conta e início
- Entrar com e-mail e senha, com "Esqueci a senha".
- Seu nome na mesa e sua **foto de perfil**, com ajuste do enquadramento (centralizar o rosto e dar zoom).
- Tema de cores do app: Medo (branco, o padrão), Floresta, Oceano, Lago, Terra e Pôr do sol.
- **Agentes** como dossiês: retrato com o NEX num hexágono, classe, recursos e a mesa em que cada um está; organizados em pastas.
- **Mesas**: criar uma como mestre ou entrar com o código; cada mesa aparece como a pasta de uma operação, com quem mestra, a missão, quem está nela e a sessão ao vivo.
- Importar agentes do site do CRIS pelo link de compartilhar.
- Para Android e Windows (com instalador ou portátil).
- Funciona offline e sincroniza quando a internet volta.

### Segurança da conta
- **Senha forte**: ao criar a conta ou trocar a senha, o P.A.U recusa senhas curtas, sequências, as mais usadas, as feitas com o seu nome ou e-mail e as que já vazaram em outros sites, com um medidor de força enquanto você digita.
- Senha que vazou é conferida sem sair do aparelho: só os 5 primeiros caracteres de um código tirado dela vão para o Have I Been Pwned.
- Ao entrar com uma senha fraca ou que já vazou, o app pede para trocar.
- **Aparelhos com acesso**: a lista de todo aparelho que entrou na conta, com quando entrou e o último uso.
- **Aviso de acesso novo**: quando outro aparelho entra na conta, os seus perguntam "Foi você?"; "Não fui eu" leva direto para trocar a senha.
- **Desconectar os outros aparelhos** e **trocar a senha** (as duas pedem a senha atual) tiram da conta na hora todos os outros aparelhos: as regras do servidor recusam qualquer sessão mais antiga, que não lê nem grava mais nada.
- Confirmar o e-mail de recuperação.

### Ficha do agente
- **Ficha automática**: atributos, NEX, PV, PE e SAN (ou PD), Defesa, limite de PE, carga, DT dos rituais, patente e limites por categoria.
- **Agente**: dossiê com a foto do personagem (com enquadramento), número do arquivo, NEX, patente, classe, trilha e origem, e a foto do jogador. Afinidade com sigilo animado: cores, fonte, runas e dado do elemento. Modos de jogo (só NEX, nível + NEX ou patentes; com Sanidade ou Determinação). Atributos, estatísticas, condições, aparência e história, alterações de NEX.
- **PV, PE (ou PD) e SAN** sempre no topo, com barras, valores temporários e ajuste rápido.
- **Chegada a NEX 50%**: quem ainda não tem afinidade vê a tela escurecer, um cometa cruzar o céu e os quatro símbolos surgirem do impacto, cada um com seu efeito (o sangue escorre, a morte gira, a energia pisca e os sigilos do conhecimento rodam em volta), para escolher a afinidade ali mesmo ou decidir depois.
- **Transformações**: fichas ligadas ao agente, com transformar e voltar.
- **Perícias**: caderno de campo com as 28 perícias, graus de treino (+0, +5, +10, +15), outros bônus, penalidade de carga e a profissão escrita na Profissão. Tocar rola (Xd20, fica o maior; com atributo 0, 2d20 e fica o menor); segurar rola com modificadores.
- **Combate**: Defesa, deslocamento e iniciativa; dado do destino; testes rápidos; bloqueio e esquiva, com a reação que o agente escolhe usar; resistência a dano por tipo e "sofrer dano"; ataques com as armas (margem e multiplicador de crítico); rituais rápidos; o alvo no combate da mesa, com o relógio do combate; rolagem livre.
- **Rituais**: catálogo de todos os livros, runas por elemento e círculo, custo calculado, formas Padrão, Discente e Verdadeiro, DT e Vantagem Elemental.
- **Inventário**: itens como etiquetas de evidência, equipados, carga e os itens e armas dos livros.
- **Poderes e notas**: poderes de origem, classe e trilha como cartas, com os efeitos já contados na ficha; poderes dos livros; habilidades próprias; anotações.
- **Quadro**: mural de notas e o quadro completo (notas, títulos, tarefas, links, imagens, cores, colunas, quadros dentro de quadros, desenhos, fichas, setas e comentários).
- **Sessões**: o registro das sessões da mesa, com o tempo de cada uma, e os nomes e as notas do agente.
- Dado d20 em 3D animado, com crítico e falha crítica.

### Na mesa (jogadores)
- Entrar na mesa pelo código e vincular o agente.
- Abas de fichário: na lateral no computador e embaixo no celular.
- **Mesa**: a sessão ao vivo com o tempo, a missão atual, a iniciativa do combate com o relógio, o seu agente e quem está na mesa, com as fotos.
- **Rolagens**: as rolagens da mesa em tempo real.
- **Notas**: notas para o mestre, que vê o seu nome e o agente; aviso quando ele lê.
- **Pedidos**: pedidos de homebrew (item, ritual, poder ou outro) com a resposta do mestre.
- Ataques e rituais contra um alvo do combate vão ao mestre para conferir e aplicar o dano.

### Escudo do mestre
- Abas de fichário na lateral (no celular, embaixo, com as que não cabem em "Mais") e o código da mesa no topo, para copiar.
- **Painel**: iniciar e encerrar a sessão (com o tempo), os agentes ao vivo (PV, PE, SAN, Defesa, deslocamento, carga, prestígio e condições), pedir teste a todos, dano ou cura em grupo e recuperar todos.
- **Combate**: iniciativa (os agentes entram sozinhos), rodadas e turnos, ameaças com o nome escondido dos jogadores, relógio do combate e o espaço do alvo com agentes e ameaças.
  - **Ação**: os ataques e habilidades de cada ameaça em botões, com resumo ao passar o mouse; acerto contra a Defesa, dano com a RD do agente, testes de resistência, condições, esquiva e bloqueio (a reação que o agente escolheu, uma por rodada).
  - **Dano**: os golpes dos agentes, com o acerto, a RD, a imunidade e a vulnerabilidade da ameaça; rituais em área com a resistência de cada alvo; condições que o mestre escolhe aplicar.
- **Ameaças**: as ameaças dos livros e as da mesa, para criar e editar; rolagens secretas.
- **Rolagens**: o registro da mesa e o registro secreto do mestre.
- **Sessões**: todas as sessões com o tempo, e os nomes e as notas do mestre.
- **Jogadores**: as notas dos jogadores e os pedidos de homebrew (aceitar e pôr na biblioteca, recusar e responder).
- **Nomes**: gerador de nomes brasileiros para NPCs; copiar e guardar.
- **Regras**: regras da mesa (Determinação, progressão, carga, custos de ritual e valores das classes), biblioteca homebrew, consulta dos livros e resumo das regras de combate.
- **Mesa**: código da mesa, membros, prestígio da missão (eventos que dão ou tiram pontos de todos), quadro do mestre e notas privadas.

### Livros
- Livro de Regras, Sobrevivendo ao Horror e Arquivos Secretos 1 a 7 e 9: origens, classes, trilhas, poderes, rituais, itens, condições, ameaças e regras, sempre com a página.

## Histórico de versões

As novidades de cada versão, da mais nova para a mais antiga. O texto de cada release no GitHub sai daqui.

### v1.0.45 · 30/10/2026
- Cena nova ao chegar a NEX 50%: a tela escurece, um cometa cruza o céu e, do impacto, surgem os símbolos de Conhecimento, Energia, Morte e Sangue, cada um com a própria animação. Tocar em um deles escolhe a afinidade do agente; dá para pular a animação e decidir depois.

### v1.0.44 · 30/10/2026
- Correção: o fundo das telas agora acompanha o tema de cores escolhido e a afinidade da ficha, em vez de ficar com as cores do primeiro tema mostrado depois de abrir o app.

### v1.0.43 · 30/10/2026
- Nova tela **Segurança da conta** (no menu da sua foto): trocar a senha, confirmar o e-mail e ver os aparelhos que entraram na conta.
- Desconectar os outros aparelhos e trocar a senha agora tiram da conta na hora quem estiver nela em outro aparelho: o servidor deixa de aceitar as sessões antigas.
- Aviso "Foi você?" quando outro aparelho entra na sua conta.
- Senhas novas precisam ter pelo menos 8 caracteres e não podem ser fáceis de adivinhar nem ter vazado em outros sites; medidor de força ao digitar e o olho para mostrar a senha.
- Quem entra com uma senha fraca ou que já vazou recebe o pedido de trocar (e um ponto na foto, no menu da conta).

### v1.0.42 · 30/10/2026
- Visual novo nas telas de Agentes e de Mesas, com cara de arquivo da Ordem: cada agente é um dossiê com o NEX num hexágono e a mesa em que está; cada mesa é a pasta de uma operação, com quem mestra, a missão, quem está nela e a sessão ao vivo.
- A área da Mesa virou um fichário, para o mestre e para os jogadores: abas na lateral no computador e embaixo no celular. O código da mesa fica no topo; tocar copia.
- Todas as abas da Mesa foram redesenhadas. Painel com o relógio da sessão em destaque, as ações em grupo e os agentes com Defesa, deslocamento, carga e prestígio. Rolagens com carimbo de crítico e de falha. Sessões com o número de cada uma na margem. Jogadores, Nomes, Regras, Ameaças e Mesa com o mesmo visual.
- A aba Mesa do jogador mostra a sessão ao vivo, a missão, o combate, o agente dele e quem está na mesa.
- Barras de PV, PE e SAN do mestre com o nome dentro e o número legível em qualquer tema.

### v1.0.41 · 30/10/2026
- Foto de perfil do jogador com "Ajustar foto": centralizar o rosto e dar zoom, com a prévia redonda de como fica na ficha e nas notas ao mestre. A foto nova já abre no ajuste.
- Este README virou o log do aplicativo: tudo o que ele tem e o histórico de versões. Cada release no GitHub traz as novidades da versão e a lista completa.

### v1.0.40 · 29/10/2026
- Gerador de nomes, foto do jogador, notas e pedidos de homebrew para o mestre

### v1.0.39 · 29/10/2026
- Condições dos rituais só valem se o mestre escolher aplicar
- Sessão de jogo iniciada pelo mestre e relógio do combate
- Aba Sessões: registro de todas as sessões com o tempo, nomes e notas

### v1.0.38 · 29/10/2026
- Profissão nas perícias, regras de combate na consulta e Dano com área, efeitos e esquiva
- RD das ameaças com exceção: "RD 10/Morte" vale para tudo menos Morte
- Agente escolhe bloquear ou esquivar; o mestre conta a reação uma vez por rodada

### v1.0.37 · 29/10/2026
- Parte Dano no combate do mestre: golpes dos agentes com acerto e aplicar dano

### v1.0.36 · 28/10/2026
- Temas do app com cores da natureza e o branco do Medo como padrão

### v1.0.35 · 28/10/2026
- Vez passa para os agentes, ameaças do tamanho dos agentes e alvo na ficha

### v1.0.34 · 28/10/2026
- Ações das ameaças em botões, alvo no combate do mestre e sem tema de cores

### v1.0.33 · 27/10/2026
- Abertura da ficha lisa no PC: fundo pintado uma vez e abas sem tranco

### v1.0.32 · 27/10/2026
- Temas do app em tons de uma cor só, com amostras sólidas na escolha do tema

### v1.0.31 · 27/10/2026
- Temas de afinidade em tons de uma cor só e runas e dado de Morte como antes

### v1.0.30 · 27/10/2026
- Sigilo animado da afinidade na Vantagem Elemental e nos atributos, opção Sem afinidade e temas de uma cor só

### v1.0.29 · 26/10/2026
- Seleção de rituais sem ids repetidos e abertura da ficha lisa no PC

### v1.0.28 · 25/10/2026
- Seletor dos rituais rápidos com os rituais dos livros

### v1.0.27 · 24/10/2026
- Rituais de todos os livros e rituais rápidos no combate

### v1.0.26 · 24/10/2026
- Trilhas e origens no seletor de poderes do livro

### v1.0.25 · 24/10/2026
- Poderes: origem, classe e trilha como cartas e efeitos automáticos
- Poderes do Sobrevivendo ao Horror e dos Arquivos Secretos automatizados

### v1.0.24 · 24/10/2026
- Abertura da ficha mais fluida e pastas de agentes

### v1.0.23 · 24/10/2026
- Bloqueio, esquiva e itens equipados

### v1.0.22 · 24/10/2026
- Aviso do Esqueci a senha explica o que fazer se o e-mail não chegar
- Resistência a dano (RD) na aba Combate
- RD em fichas compactas, no formato dos testes rápidos

### v1.0.21 · 23/10/2026
- Dado 3D mais leve e rolagem mais rápida

### v1.0.20 · 23/10/2026
- Aba Agente: afinidade do dossiê, runas geradas e paleta por elemento
- Aba Perícias como caderno de campo
- Aba Combate em alerta e dado d20 em 3D
- Aba Rituais como catálogo
- Aba Inventário como etiquetas de evidência
- Aba Poderes e notas como cartas arcanas
- Aba Quadro como mural

### v1.0.19 · 22/10/2026
- Rolagem com d20 animado e filtros que rolam com o mouse

### v1.0.18 · 22/10/2026
- Configuração do Firebase CLI para publicar as regras do Firestore
- Visual de arquivo da Ordem, animações e habilidades editáveis

### v1.0.17 · 21/10/2026
- Visual novo: Cinzel e Barlow, retrato do agente e ficha mais compacta

### v1.0.16 · 21/10/2026
- Transformações, fotos dos personagens, quadro sem limitações e nome P.A.U
- CI: menos memoria para o Gradle e APK so para ARM

### v1.0.14 · 21/10/2026
- Quadro de anotações estilo Milanote na ficha e no escudo

### v1.0.13 · 21/10/2026
- Temas de cores: amarelo, roxo, preto e vermelho

### v1.0.12 · 20/10/2026
- Visual novo: degradê amarelo e roxo com sigilos de Conhecimento

### v1.0.11 · 20/10/2026
- Barras de PV e PE/PD temporários na ficha

### v1.0.10 · 20/10/2026
- Importa agentes do site do CRIS pelo link de compartilhar

### v1.0.9 · 20/10/2026
- Ameaças dos livros no escudo e consulta das regras
- Corrige quebra de linha na consulta das regras

### v1.0.7 · 20/10/2026
- Dados dos Arquivos Secretos 3 a 7 e 9, remédios e drones

### v1.0.6 · 20/10/2026
- Dados do Sobrevivendo ao Horror e dos Arquivos Secretos 1 e 2

### v1.0.5 · 20/10/2026
- Catálogo dos livros, modos de sanidade/progressão e "Do livro"

### v1.0.4 · 19/10/2026
- CI: actions em Node 24 e sem build para README/regras

### v1.0.3 · 19/10/2026
- Regras: permite ler ficha que ainda nao existe no servidor

### v1.0.2 · 19/10/2026
- Configura o Firebase (projeto ferramenta-op)

### v1.0.1 · 19/10/2026
- C.R.I.S: ficha de Ordem Paranormal com mesa sincronizada
- CI: localizar o ISCC.exe de qualquer versao do Inno Setup


## Instalar
- **Android**: baixe o `.apk` no celular e permita "instalar apps desconhecidos". Atualizações instalam por cima.
- **Windows**: rode o instalador. Se o SmartScreen avisar, clique em "Mais informações → Executar assim mesmo". O aviso aparece porque o app não é assinado. Sem instalar: descompacte o `PAU-Windows-portatil.zip` e abra `cris_ficha.exe`.

## Configuração (uma vez)
1. **Firebase**: crie um projeto em console.firebase.google.com.
   - Ative **Firestore** e **Authentication → E-mail/senha**.
   - Crie um app **Web** e copie o `firebaseConfig` para `lib/firebase_options.dart`.
2. **Regras de segurança**: em Firestore → Regras, cole o conteúdo de `firestore.rules` e publique.
3. **Build**: cada push na branch `main` roda o GitHub Actions. Ele gera:
   - `PAU-Android.apk`
   - `PAU-Instalador-Windows.exe`
   - `PAU-Windows-portatil.zip`

   Os três ficam na aba **Releases** do repositório, com as novidades da versão (deste README) e a lista de tudo o que o app tem.

## Regras
Os números estão em `lib/core/rules.dart` e podem ser ajustados por mesa na aba **Regras** do mestre. Confira-os no seu livro. Os valores padrão de PD (Determinação) são uma estimativa: ajuste-os pelo *Sobrevivendo ao Horror*.
