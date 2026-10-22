import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/imagens.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/imagem.dart';
import 'rolar.dart';
import 'sheet_screen.dart';

// Fotos dos personagens e transformações (fichas separadas ligadas a um
// agente, com atributos, perícias, poderes e foto próprios).

/// Ver, trocar ou tirar a foto da ficha.
Future<void> opcoesFoto(BuildContext context, Ficha f) async {
  final temFoto = f.foto.isNotEmpty;
  final escolha = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (temFoto)
          ListTile(
            leading: const Icon(Icons.zoom_in),
            title: const Text('Ver foto'),
            onTap: () => Navigator.pop(ctx, 'ver'),
          ),
        if (temFoto)
          ListTile(
            leading: const Icon(Icons.crop_portrait),
            title: const Text('Enquadrar foto'),
            onTap: () => Navigator.pop(ctx, 'enquadrar'),
          ),
        ListTile(
          leading: const Icon(Icons.add_a_photo_outlined),
          title: Text(temFoto ? 'Trocar foto' : 'Colocar foto'),
          onTap: () => Navigator.pop(ctx, 'trocar'),
        ),
        if (temFoto)
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(ctx, 'tirar'),
          ),
      ]),
    ),
  );
  if (!context.mounted || escolha == null) return;
  if (escolha == 'ver') {
    verImagem(context, f.foto, titulo: f.nome);
  } else if (escolha == 'enquadrar') {
    final a = await escolherEnquadramento(context,
        foto: f.foto, nome: f.nome, ajuste: f.fotoAjuste);
    if (a != null) Repo.set(f.id, 'fotoAjuste', a);
  } else if (escolha == 'trocar') {
    final r = await escolherImagem(context, lado: 900);
    if (r == null) return;
    // a foto nova entra já com o enquadramento escolhido logo em seguida
    Repo.setVarios(f.id, {'foto': r.id, 'fotoAjuste': null});
    Imagens.apagar(f.foto);
    if (!context.mounted) return;
    final a = await escolherEnquadramento(context, foto: r.id, nome: f.nome);
    if (a != null) Repo.set(f.id, 'fotoAjuste', a);
  } else if (escolha == 'tirar') {
    Repo.setVarios(f.id, {'foto': '', 'fotoAjuste': null});
    Imagens.apagar(f.foto);
  }
}

/// Faixa no topo da ficha: avisa que o agente está transformado, ou de quem
/// é esta transformação, com o botão de transformar e voltar.
class FaixaForma extends StatelessWidget {
  final Ficha ficha;
  const FaixaForma({super.key, required this.ficha});

  @override
  Widget build(BuildContext context) {
    final f = ficha;
    final de = f.transformacaoDe;
    if (de != null) {
      return StreamBuilder<Ficha?>(
        stream: Repo.ficha(de),
        builder: (context, s) {
          final a = s.data;
          if (a == null) return const SizedBox.shrink();
          final ativa = a.formaAtiva == f.id;
          return _faixa(
            context,
            icone: Icons.auto_awesome,
            rotulo: ativa ? 'FORMA EM USO POR' : 'TRANSFORMAÇÃO DE',
            texto: a.nome,
            foto: a.foto,
            ajuste: a.fotoAjuste,
            nome: a.nome,
            acoes: [
              TextButton(
                onPressed: () => Repo.transformar(a.id, ativa ? null : f.id),
                child: Text(ativa ? 'Destransformar' : 'Transformar'),
              ),
              TextButton(
                onPressed: () => abrirOutraFicha(context, a.id),
                child: const Text('Agente'),
              ),
            ],
          );
        },
      );
    }
    final forma = f.formaAtiva;
    if (forma == null) return const SizedBox.shrink();
    return StreamBuilder<Ficha?>(
      stream: Repo.ficha(forma),
      builder: (context, s) {
        final t = s.data;
        if (t == null) return const SizedBox.shrink();
        return _faixa(
          context,
          icone: Icons.auto_awesome,
          foto: t.foto,
          ajuste: t.fotoAjuste,
          nome: t.nome,
          rotulo: 'TRANSFORMADO EM',
          texto: t.nome,
          acoes: [
            TextButton(
              onPressed: () => abrirOutraFicha(context, t.id),
              child: const Text('Abrir'),
            ),
            TextButton(
              onPressed: () => Repo.transformar(f.id, null),
              child: const Text('Voltar'),
            ),
          ],
        );
      },
    );
  }

  Widget _faixa(BuildContext context,
      {required IconData icone,
      required String rotulo,
      required String texto,
      required List<Widget> acoes,
      String? foto,
      Map<String, dynamic> ajuste = const {},
      String nome = ''}) {
    final botoes = TextButtonTheme(
      data: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Cores.roxoClaro,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: estiloRotulo(14.5, peso: FontWeight.w700, espaco: 0.6),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: acoes),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Cores.roxo.withValues(alpha: 0.38),
          Cores.roxo.withValues(alpha: 0.12),
        ]),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cores.roxoClaro.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        if (foto != null)
          AvatarFicha(foto: foto, nome: nome, ajuste: ajuste, tamanho: 34, transformacao: true)
        else
          Icon(icone, size: 20, color: Cores.roxoClaro),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(rotulo, style: estiloRotulo(11, cor: Cores.roxoClaro, peso: FontWeight.w700, espaco: 1.6)),
            const SizedBox(height: 2),
            Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
          ]),
        ),
        botoes,
      ]),
    );
  }
}

/// Troca a ficha aberta por outra (agente <-> transformação).
void abrirOutraFicha(BuildContext context, String id) =>
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => TelaFicha(fichaId: id)));

/// Seção da aba AGENTE: as transformações do agente, ou, numa
/// transformação, o que ela divide com o agente.
class SecaoTransformacoes extends StatelessWidget {
  final CtxFicha ctx;
  const SecaoTransformacoes({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    if (f.eTransformacao) return _SecaoLigacao(ctx: ctx);
    final dono = f.ownerUid == Repo.uid;
    return Secao(
      titulo: 'Transformações',
      acoes: [
        if (dono)
          TextButton.icon(
            onPressed: () => novaTransformacao(context, f),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nova'),
          ),
      ],
      child: StreamBuilder<List<Ficha>>(
        stream: Repo.transformacoesDe(f.id),
        builder: (context, s) {
          final l = s.data ?? const <Ficha>[];
          if (l.isEmpty) {
            return Text(
                dono
                    ? 'Crie fichas separadas para as outras formas do agente (uma criatura, um avatar do Outro Lado...). Cada uma tem atributos, perícias, poderes e foto próprios; PE/PD e SAN podem ser divididos com o agente.'
                    : 'Nenhuma transformação.',
                style: const TextStyle(fontSize: 13, color: Cores.textoFraco));
          }
          return Column(children: [
            for (final t in l) _LinhaTransformacao(agente: f, t: t, regras: ctx.camp?.regras),
          ]);
        },
      ),
    );
  }
}

class _LinhaTransformacao extends StatelessWidget {
  final Ficha agente, t;
  final Map<String, dynamic>? regras;
  const _LinhaTransformacao(
      {required this.agente, required this.t, required this.regras});

  @override
  Widget build(BuildContext context) {
    final ativa = agente.formaAtiva == t.id;
    final c = Calc(t, regras);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ativa ? Cores.roxo.withValues(alpha: 0.30) : Cores.painel2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ativa ? Cores.roxoClaro : Cores.borda),
      ),
      child: Row(children: [
        RetratoFicha(
          foto: t.foto,
          nome: t.nome,
          ajuste: t.fotoAjuste,
          largura: 50,
          transformacao: true,
          aoTocar: () => abrirOutraFicha(context, t.id),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => abrirOutraFicha(context, t.id),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${t.classe} • ${c.resumoProgressao} • PV ${t.pvAtual}/${c.pvMax}',
                  style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
              if (ativa)
                Text('EM USO',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                        color: Cores.roxoClaro)),
            ]),
          ),
        ),
        ativa
            ? OutlinedButton(
                onPressed: () => Repo.transformar(agente.id, null),
                child: const Text('Voltar'))
            : FilledButton(
                onPressed: () => Repo.transformar(agente.id, t.id),
                child: const Text('Transformar')),
      ]),
    );
  }
}

class _SecaoLigacao extends StatelessWidget {
  final CtxFicha ctx;
  const _SecaoLigacao({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final t = ctx.f;
    final pd = ctx.calc.determinacao;
    final divide = {...Repo.compartilhaPadrao, ...t.compartilha};
    Widget chave(String k, String titulo, String sub) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(titulo),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
          value: divide[k] == true,
          onChanged: (v) => Repo.mudarCompartilha(t, {...divide, k: v}),
        );
    return Secao(
      titulo: 'Ligação com o agente',
      child: StreamBuilder<Ficha?>(
        stream: Repo.ficha(t.transformacaoDe!),
        builder: (context, s) {
          final a = s.data;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (a != null)
              Row(children: [
                AvatarFicha(
                  foto: a.foto,
                  nome: a.nome,
                  ajuste: a.fotoAjuste,
                  tamanho: 44,
                  aoTocar: () => abrirOutraFicha(context, a.id),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Transformação de ${a.nome}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => abrirOutraFicha(context, a.id),
                  child: const Text('Abrir agente'),
                ),
              ]),
            const SizedBox(height: 4),
            const Text('O que esta forma divide com o agente (o que muda numa ficha muda na outra):',
                style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
            chave('pv', 'Pontos de vida', 'Desligado: a forma tem PV próprios.'),
            chave('pe', pd ? 'Pontos de determinação' : 'Pontos de esforço',
                'Inclui os temporários.'),
            if (!pd) chave('san', 'Sanidade', 'A mente continua a mesma.'),
          ]);
        },
      ),
    );
  }
}

/// Pergunta o nome e como começar, cria a transformação e abre a ficha dela.
Future<void> novaTransformacao(BuildContext context, Ficha agente) async {
  final nome = TextEditingController();
  var copiar = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Nova transformação'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nome,
            autofocus: true,
            decoration: InputDecoration(
                labelText: 'Nome da forma',
                hintText: '${agente.nome} (transformado)'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Copiar o agente')),
              ButtonSegment(value: false, label: Text('Ficha em branco')),
            ],
            selected: {copiar},
            onSelectionChanged: (s) => set(() => copiar = s.first),
          ),
          const SizedBox(height: 8),
          Text(
              copiar
                  ? 'Começa com atributos, perícias, itens, rituais e poderes do agente. Depois é só mudar o que a forma tem de diferente.'
                  : 'Começa vazia, só com a classe e a progressão do agente.',
              style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Criar')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final id = Repo.criarTransformacao(agente,
      copiar: copiar, nome: nome.text.trim());
  Navigator.push(
      context, MaterialPageRoute(builder: (_) => TelaFicha(fichaId: id)));
}
