import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/foto_jogador.dart';
import '../sheet/tab_listas.dart' show itemPadrao, poderPadrao, ritualPadrao;

// Notas dos jogadores para o mestre e pedidos de homebrew. Ficam na ficha de
// cada agente: só o jogador dono dela e o mestre da mesa leem a ficha.

/// Uma nota ou um pedido, com o agente que mandou e o id.
typedef EntradaJogador = ({Ficha f, String id, Map<String, dynamic> d});

List<EntradaJogador> _juntar(List<Ficha> fichas, Map<String, dynamic> Function(Ficha) campo) => [
      for (final f in fichas)
        for (final e in campo(f).entries) (f: f, id: e.key, d: asMap(e.value)),
    ]..sort((a, b) => asInt(b.d['at']).compareTo(asInt(a.d['at'])));

List<EntradaJogador> notasDosJogadores(List<Ficha> fichas) => _juntar(fichas, (f) => f.notasAoMestre);
List<EntradaJogador> pedidosDosJogadores(List<Ficha> fichas) => _juntar(fichas, (f) => f.pedidosHomebrew);

/// Quantas notas o mestre ainda não leu e quantos pedidos esperam resposta.
int pendentesDoMestre(List<Ficha> fichas) =>
    notasDosJogadores(fichas).where((e) => !asBool(e.d['lida'])).length +
    pedidosDosJogadores(fichas).where((e) => asStr(e.d['estado'], 'pendente') == 'pendente').length;

const _tiposPedido = {'item': 'Item', 'ritual': 'Ritual', 'poder': 'Poder', 'outro': 'Outro'};

const _estados = {'pendente': 'Esperando o mestre', 'aceito': 'Aceito', 'recusado': 'Recusado'};

Widget _rotulo(String t) =>
    Text(t, style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 1.6));

ShapeBorder _borda(bool forte) => CorteCantos(corte: 12, cor: Cores.destaque.withValues(alpha: forte ? 0.85 : 0.35));

// ---------------- lado do jogador ----------------

/// Os agentes do jogador nesta mesa (as notas e os pedidos vão por eles).
class _ComMeusAgentes extends StatelessWidget {
  final Campanha camp;
  final Widget Function(BuildContext context, List<Ficha> aqui) builder;
  const _ComMeusAgentes({required this.camp, required this.builder});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Ficha>>(
        stream: Repo.minhasFichas(),
        builder: (context, snap) {
          final aqui = (snap.data ?? const <Ficha>[]).where((f) => f.campaignId == camp.id).toList();
          if (snap.hasData && aqui.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Vincule um agente a esta mesa (aba Mesa) para mandar notas e pedidos ao mestre.',
                  textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
            );
          }
          return builder(context, aqui);
        },
      );
}

/// Escolhe por qual agente vai a nota ou o pedido (só quando há mais de um).
class _EscolhaAgente extends StatelessWidget {
  final List<Ficha> agentes;
  final Ficha atual;
  final ValueChanged<Ficha> aoEscolher;
  const _EscolhaAgente({required this.agentes, required this.atual, required this.aoEscolher});

  @override
  Widget build(BuildContext context) => agentes.length < 2
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in agentes)
              ChoiceChip(label: Text(f.nome), selected: f.id == atual.id, onSelected: (_) => aoEscolher(f)),
          ]),
        );
}

/// A aba Notas do jogador: escreve para o mestre, que vê o nome dele e o do
/// agente, e acompanha se ele já leu.
class AbaNotasJogador extends StatelessWidget {
  final Campanha camp;
  const AbaNotasJogador({super.key, required this.camp});

  @override
  Widget build(BuildContext context) => _ComMeusAgentes(
        camp: camp,
        builder: (context, aqui) => aqui.isEmpty ? const SizedBox.shrink() : _NotasJogador(agentes: aqui),
      );
}

class _NotasJogador extends StatefulWidget {
  final List<Ficha> agentes;
  const _NotasJogador({required this.agentes});

  @override
  State<_NotasJogador> createState() => _NotasJogadorState();
}

class _NotasJogadorState extends State<_NotasJogador> {
  final _texto = TextEditingController();
  String? _agente;

  Ficha get _por => widget.agentes.firstWhere((f) => f.id == _agente, orElse: () => widget.agentes.first);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _enviar() {
    final t = _texto.text.trim();
    if (t.isEmpty) return;
    Repo.enviarNotaAoMestre(_por, t);
    _texto.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota enviada ao mestre.')));
  }

  @override
  Widget build(BuildContext context) {
    final notas = notasDosJogadores(widget.agentes);
    final por = _por;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 28), children: [
      Row(children: [
        FotoJogador(uid: Repo.uid, nome: Repo.nomeUsuario, tamanho: 40, aoTocar: () => opcoesFotoJogador(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NOTAS PARA O MESTRE', style: estiloTitulo(19, cor: Cores.destaque)),
            Text('Só o mestre lê. Ele vê seu nome (${Repo.nomeUsuario}) e o agente (${por.nome}).',
                style: const TextStyle(fontSize: 13, color: Cores.textoFraco)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      _EscolhaAgente(agentes: widget.agentes, atual: por, aoEscolher: (f) => setState(() => _agente = f.id)),
      TextField(
        controller: _texto,
        minLines: 3,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          labelText: 'Sua nota',
          hintText: 'Ex.: Quero que meu agente investigue o diário escondido…',
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _enviar,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Enviar ao mestre'),
        ),
      ),
      if (notas.isNotEmpty) ...[
        const SizedBox(height: 18),
        _rotulo('ENVIADAS'),
        for (final n in notas) ...[
          const SizedBox(height: 8),
          Material(
            color: Cores.painel,
            shape: _borda(false),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                        '${dataHora(asInt(n.d['at']))}${widget.agentes.length > 1 ? ' · ${n.f.nome}' : ''}',
                        style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
                  ),
                  Icon(asBool(n.d['lida']) ? Icons.done_all : Icons.schedule,
                      size: 16, color: asBool(n.d['lida']) ? Cores.destaque : Cores.textoFraco),
                  const SizedBox(width: 4),
                  Text(asBool(n.d['lida']) ? 'Lida pelo mestre' : 'Ainda não lida',
                      style: TextStyle(
                          fontSize: 12.5, color: asBool(n.d['lida']) ? Cores.destaque : Cores.textoFraco)),
                  IconButton(
                    tooltip: 'Apagar',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 18, color: Cores.textoFraco),
                    onPressed: () async {
                      if (await confirmar(context, 'Apagar esta nota?')) {
                        Repo.set(n.f.id, 'recadosMestre.${n.id}', FieldValue.delete());
                      }
                    },
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(asStr(n.d['texto']), style: const TextStyle(fontSize: 15, height: 1.4)),
                ),
              ]),
            ),
          ),
        ],
      ],
    ]);
  }
}

/// A aba Pedidos do jogador: pede ao mestre um item, ritual ou poder
/// homebrew e acompanha a resposta.
class AbaPedidosJogador extends StatelessWidget {
  final Campanha camp;
  const AbaPedidosJogador({super.key, required this.camp});

  @override
  Widget build(BuildContext context) => _ComMeusAgentes(
        camp: camp,
        builder: (context, aqui) => aqui.isEmpty ? const SizedBox.shrink() : _PedidosJogador(agentes: aqui),
      );
}

class _PedidosJogador extends StatefulWidget {
  final List<Ficha> agentes;
  const _PedidosJogador({required this.agentes});

  @override
  State<_PedidosJogador> createState() => _PedidosJogadorState();
}

class _PedidosJogadorState extends State<_PedidosJogador> {
  final _nome = TextEditingController();
  final _descricao = TextEditingController();
  String _tipo = 'item';
  String? _agente;

  Ficha get _por => widget.agentes.firstWhere((f) => f.id == _agente, orElse: () => widget.agentes.first);

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    super.dispose();
  }

  void _enviar() {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao pedido.')));
      return;
    }
    Repo.pedirHomebrew(_por, tipo: _tipo, nome: nome, descricao: _descricao.text.trim());
    _nome.clear();
    _descricao.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido enviado ao mestre.')));
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = pedidosDosJogadores(widget.agentes);
    final por = _por;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 28), children: [
      Text('PEDIDOS DE HOMEBREW', style: estiloTitulo(19, cor: Cores.destaque)),
      const Text(
          'Peça ao mestre um item, ritual ou poder feito para a mesa. Aceito, ele entra na biblioteca da mesa e você o põe na ficha.',
          style: TextStyle(fontSize: 13, color: Cores.textoFraco)),
      const SizedBox(height: 12),
      _EscolhaAgente(agentes: widget.agentes, atual: por, aoEscolher: (f) => setState(() => _agente = f.id)),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in _tiposPedido.entries)
          ChoiceChip(label: Text(t.value), selected: _tipo == t.key, onSelected: (_) => setState(() => _tipo = t.key)),
      ]),
      const SizedBox(height: 8),
      TextField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Faca de prata do avô')),
      const SizedBox(height: 8),
      TextField(
        controller: _descricao,
        minLines: 3,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          labelText: 'O que faz',
          hintText: 'Ex.: Arma simples, 1d6 de corte; conta como item amaldiçoado de Morte…',
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _enviar,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Enviar pedido'),
        ),
      ),
      if (pedidos.isNotEmpty) ...[
        const SizedBox(height: 18),
        _rotulo('SEUS PEDIDOS'),
        for (final p in pedidos) ...[
          const SizedBox(height: 8),
          _CartaoPedido(entrada: p, mostrarAgente: widget.agentes.length > 1),
        ],
      ],
    ]);
  }
}

// ---------------- lado do mestre ----------------

/// A aba Jogadores do mestre: as notas que os jogadores mandaram (com o
/// nome e a foto de cada um) e os pedidos de homebrew.
class AbaJogadoresMestre extends StatelessWidget {
  final Campanha camp;
  const AbaJogadoresMestre({super.key, required this.camp});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Ficha>>(
        stream: Repo.todasDaCampanha(camp.id),
        builder: (context, snap) {
          final fichas = snap.data ?? const <Ficha>[];
          final notas = notasDosJogadores(fichas);
          final pedidos = pedidosDosJogadores(fichas);
          final naoLidas = notas.where((n) => !asBool(n.d['lida'])).length;
          final pendentes = pedidos.where((p) => asStr(p.d['estado'], 'pendente') == 'pendente').length;
          Tab aba(String t, int n) => Tab(text: n == 0 ? t : '$t ($n)');
          return DefaultTabController(
            length: 2,
            child: Column(children: [
              TabBar(tabs: [aba('NOTAS DOS JOGADORES', naoLidas), aba('PEDIDOS DE HOMEBREW', pendentes)]),
              Expanded(
                child: TabBarView(children: [
                  _NotasMestre(notas: notas),
                  _PedidosMestre(camp: camp, pedidos: pedidos),
                ]),
              ),
            ]),
          );
        },
      );
}

class _NotasMestre extends StatelessWidget {
  final List<EntradaJogador> notas;
  const _NotasMestre({required this.notas});

  @override
  Widget build(BuildContext context) {
    if (notas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nenhuma nota ainda. Os jogadores escrevem para você na aba Notas da mesa.',
            textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 28), children: [
      for (final n in notas) ...[
        _CartaoNotaMestre(nota: n),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

class _CartaoNotaMestre extends StatelessWidget {
  final EntradaJogador nota;
  const _CartaoNotaMestre({required this.nota});

  @override
  Widget build(BuildContext context) {
    final d = nota.d;
    final lida = asBool(d['lida']);
    final autor = asStr(d['autor'], nota.f.jogador);
    return Material(
      color: lida ? Cores.painel : Cores.destaque.withValues(alpha: 0.08),
      shape: _borda(!lida),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            FotoJogador(uid: asStr(d['uid'], nota.f.ownerUid), nome: autor, tamanho: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: autor, style: estiloTitulo(17, cor: Cores.texto)),
                  TextSpan(text: '  ${nota.f.nome}', style: TextStyle(fontSize: 13.5, color: Cores.destaque)),
                ])),
                Text(dataHora(asInt(d['at'])), style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
              ]),
            ),
            TextButton.icon(
              onPressed: () => Repo.set(nota.f.id, 'recadosMestre.${nota.id}.lida', !lida),
              icon: Icon(lida ? Icons.done_all : Icons.mark_email_read_outlined, size: 18),
              label: Text(lida ? 'Lida' : 'Marcar como lida'),
            ),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(asStr(d['texto']), style: const TextStyle(fontSize: 15, height: 1.45)),
          ),
        ]),
      ),
    );
  }
}

class _PedidosMestre extends StatelessWidget {
  final Campanha camp;
  final List<EntradaJogador> pedidos;
  const _PedidosMestre({required this.camp, required this.pedidos});

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nenhum pedido ainda. Os jogadores pedem itens, rituais e poderes na aba Pedidos da mesa.',
            textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 28), children: [
      for (final p in pedidos) ...[
        _CartaoPedido(entrada: p, camp: camp, mostrarAgente: true),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

/// Um pedido de homebrew. Com [camp] (o mestre), dá para aceitar (o pedido
/// entra na biblioteca da mesa), recusar e responder; sem ele (o jogador),
/// mostra a resposta.
class _CartaoPedido extends StatelessWidget {
  final EntradaJogador entrada;
  final Campanha? camp;
  final bool mostrarAgente;
  const _CartaoPedido({required this.entrada, this.camp, this.mostrarAgente = false});

  void _aceitar(Campanha camp) {
    final d = entrada.d;
    final tipo = asStr(d['tipo'], 'outro');
    final padrao = switch (tipo) {
      'item' => itemPadrao,
      'ritual' => ritualPadrao,
      'poder' => poderPadrao,
      _ => null,
    };
    if (padrao != null) {
      Repo.salvarDoc(Repo.homebrew(camp.id), null, {
        ...padrao,
        'nome': asStr(d['nome']),
        'descricao': asStr(d['descricao']),
        'tipoBiblio': tipo,
      });
    }
    Repo.setVarios(entrada.f.id, {
      'pedidosHomebrew.${entrada.id}.estado': 'aceito',
      'pedidosHomebrew.${entrada.id}.naBiblioteca': padrao != null,
    });
  }

  Future<void> _recusar(BuildContext context) async {
    final motivo = await pedirTexto(context, 'Recusar o pedido', dica: 'Motivo (opcional)');
    if (motivo == null) return;
    Repo.setVarios(entrada.f.id, {
      'pedidosHomebrew.${entrada.id}.estado': 'recusado',
      if (motivo.isNotEmpty) 'pedidosHomebrew.${entrada.id}.resposta': motivo,
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = entrada.d;
    final estado = asStr(d['estado'], 'pendente');
    final mestre = camp;
    final autor = asStr(d['autor'], entrada.f.jogador);
    final resposta = asStr(d['resposta']);
    final corEstado = estado == 'aceito'
        ? Cores.destaque
        : estado == 'recusado'
            ? Cores.textoFraco
            : Cores.texto;
    return Material(
      color: estado == 'pendente' && mestre != null ? Cores.destaque.withValues(alpha: 0.08) : Cores.painel,
      shape: _borda(estado == 'pendente' && mestre != null),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (mestre != null) ...[
              FotoJogador(uid: asStr(d['uid'], entrada.f.ownerUid), nome: autor, tamanho: 40),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${(_tiposPedido[asStr(d['tipo'])] ?? 'Outro').toUpperCase()} · ${asStr(d['nome'])}',
                    style: estiloTitulo(17, cor: Cores.texto)),
                Text(
                    [
                      if (mestre != null) autor,
                      if (mostrarAgente) entrada.f.nome,
                      dataHora(asInt(d['at'])),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(
                estado == 'aceito' && asBool(d['naBiblioteca'])
                    ? 'Aceito · na biblioteca'
                    : estado == 'pendente' && mestre != null
                        ? 'Pendente'
                        : (_estados[estado] ?? estado),
                style: estiloRotulo(13, cor: corEstado, peso: FontWeight.w700, espaco: 0.4)),
          ]),
          if (asStr(d['descricao']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(asStr(d['descricao']), style: const TextStyle(fontSize: 14.5, height: 1.4)),
          ],
          if (mestre != null) ...[
            const SizedBox(height: 10),
            CampoSync(
              valor: resposta,
              rotulo: 'Resposta ao jogador',
              maxLinhas: 4,
              aoSalvar: (v) => Repo.set(entrada.f.id, 'pedidosHomebrew.${entrada.id}.resposta', v),
            ),
            if (estado == 'pendente') ...[
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                TextButton(onPressed: () => _recusar(context), child: const Text('Recusar')),
                FilledButton.icon(
                  onPressed: () => _aceitar(mestre),
                  icon: const Icon(Icons.check),
                  label: Text(asStr(d['tipo']) == 'outro' ? 'Aceitar' : 'Aceitar e pôr na biblioteca'),
                ),
              ]),
            ],
          ] else if (resposta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Mestre: ', style: TextStyle(fontWeight: FontWeight.w700, color: Cores.destaque)),
              TextSpan(text: resposta),
            ]), style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}
