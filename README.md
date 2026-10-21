# P.A.U — fichas de Ordem Paranormal com mesa sincronizada

Projeto pessoal para usar com os amigos. App nativo para **Android** e **Windows** (Flutter + Firebase).

## O que tem
- Ficha automática: atributos, NEX, PV/PE/SAN (ou PD), Defesa, limite de PE, carga, DT de rituais, patente e limites por categoria.
- 28 perícias com treino (+0/+5/+10/+15), rolagem com 1 toque (Xd20 fica o maior; atributo 0 = 2d20 fica o menor). Segure para rolar com modificadores.
- Ataques com crítico (margem/multiplicador), rituais com custo debitado e versões discente/verdadeiro, inventário, poderes, condições e notas.
- Mesas com código de convite. Rolagens aparecem para todos em tempo real.
- **Escudo do mestre**
  - Painel ao vivo com PV/PE/SAN de todos (editável), testes em grupo com DT, dano/cura em grupo.
  - Iniciativa e turnos com rodadas, condições e ameaças com nome oculto.
  - Ameaças/NPCs com ataques secretos.
  - Rolagens secretas e limpar o log.
  - Regras caseiras: Determinação, carga, custos de ritual e valores de classe editáveis.
  - Biblioteca homebrew da mesa (itens, rituais, poderes).
  - Prestígio da missão (+10/+2/−2/−5 para todos) e notas privadas.
- Funciona offline e sincroniza quando a internet volta.

## Configuração (uma vez)
1. **Firebase**: crie um projeto em console.firebase.google.com.
   - Ative **Firestore** e **Authentication → E-mail/senha**.
   - Crie um app **Web** e copie o `firebaseConfig` para `lib/firebase_options.dart`.
2. **Regras de segurança**: em Firestore → Regras, cole o conteúdo de `firestore.rules` e publique.
3. **Build**: cada push na branch `main` roda o GitHub Actions. Ele gera:
   - `PAU-Android.apk`
   - `PAU-Instalador-Windows.exe`
   - `PAU-Windows-portatil.zip`

   Os três ficam na aba **Releases** do repositório.

## Instalar
- **Android**: baixe o `.apk` no celular e permita "instalar apps desconhecidos". Atualizações instalam por cima.
- **Windows**: rode o instalador. Se o SmartScreen avisar, clique em "Mais informações → Executar assim mesmo". O aviso aparece porque o app não é assinado.

## Regras
Os números estão em `lib/core/rules.dart` e podem ser ajustados por mesa na aba **Regras** do mestre. Confira-os no seu livro. Os valores padrão de PD (Determinação) são uma estimativa: ajuste-os pelo *Sobrevivendo ao Horror*.
