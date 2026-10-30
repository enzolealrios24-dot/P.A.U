import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';

int _agora() => DateTime.now().millisecondsSinceEpoch;

/// A sessão de jogo da mesa, no Painel do mestre: só ele inicia e encerra.
/// Os jogadores veem a sessão em andamento e há quanto tempo começou.
class CartaoSessao extends StatelessWidget {
  final Campanha camp;
  const CartaoSessao({super.key, required this.camp});

  Future<void> _encerrar(BuildContext context, Map<String, dynamic> s) async {
    if (!await confirmar(context, 'Encerrar a sessão ${asInt(s['numero'])}?')) return;
    final fim = _agora();
    Repo.setCamp(camp.id, {
      'sessao': {...s, 'ativa': false, 'fim': fim},
      'sessoes': [
        for (final h in camp.historicoSessoes)
          asInt(h['numero']) == asInt(s['numero']) ? {...h, 'fim': fim} : h,
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = camp.sessao;
    final ativa = asBool(s['ativa']);
    final numero = asInt(s['numero']);
    final durou = asInt(s['fim']) - asInt(s['inicio']);
    return Material(
      color: ativa ? Cores.destaque.withValues(alpha: 0.1) : Cores.painel,
      shape: CorteCantos(corte: 14, cor: Cores.destaque.withValues(alpha: ativa ? 0.9 : 0.45), largura: ativa ? 1.6 : 1),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(children: [
          Icon(ativa ? Icons.radio_button_checked : Icons.play_circle_outline, size: 30, color: Cores.destaque),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ativa ? 'SESSÃO $numero · EM ANDAMENTO' : 'SESSÃO ${numero + 1}',
                  style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.6)),
              const SizedBox(height: 2),
              if (ativa)
                Cronometro(inicio: asInt(s['inicio']), estilo: estiloNumero(28, cor: Cores.texto))
              else
                Text(
                  numero == 0 || durou <= 0
                      ? 'Quando todos estiverem prontos, inicie a sessão: os jogadores veem que ela começou.'
                      : 'A sessão $numero durou ${duracaoTexto(Duration(milliseconds: durou))}.',
                  style: const TextStyle(fontSize: 13, color: Cores.textoFraco),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          if (ativa)
            OutlinedButton.icon(
              onPressed: () => _encerrar(context, s),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Encerrar sessão'),
            )
          else
            FilledButton.icon(
              onPressed: () {
                final inicio = _agora();
                Repo.setCamp(camp.id, {
                  'sessao': {'ativa': true, 'numero': numero + 1, 'inicio': inicio},
                  'sessoes': [
                    ...camp.historicoSessoes,
                    {'numero': numero + 1, 'inicio': inicio},
                  ],
                });
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar sessão'),
            ),
        ]),
      ),
    );
  }
}

/// Para os jogadores: a sessão em andamento e há quanto tempo começou.
class AvisoSessao extends StatelessWidget {
  final Campanha camp;
  const AvisoSessao({super.key, required this.camp});

  @override
  Widget build(BuildContext context) {
    final s = camp.sessao;
    if (!asBool(s['ativa'])) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Text('A sessão ainda não começou: o mestre inicia pelo Painel da mesa.',
            style: TextStyle(fontSize: 13, color: Cores.textoFraco)),
      );
    }
    return Material(
      color: Cores.destaque.withValues(alpha: 0.1),
      shape: CorteCantos(corte: 12, cor: Cores.destaque.withValues(alpha: 0.8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          Icon(Icons.radio_button_checked, size: 20, color: Cores.destaque),
          const SizedBox(width: 10),
          Expanded(
            child: Text('SESSÃO ${asInt(s['numero'])} EM ANDAMENTO',
                style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.4)),
          ),
          Cronometro(inicio: asInt(s['inicio']), estilo: estiloNumero(20, cor: Cores.texto)),
        ]),
      ),
    );
  }
}

/// A aba Sessões: o registro de todas as sessões da mesa, com o tempo de
/// cada uma, e os nomes e as notas de quem a abre. O mestre e cada agente
/// têm os seus.
class AbaSessoes extends StatelessWidget {
  final Campanha camp;
  /// Nomes e notas, pelo número da sessão.
  final Map<String, dynamic> notas;
  final void Function(int numero, String campo, String valor) aoSalvar;
  /// De quem são os nomes e as notas ("só você vê", "de Bianca").
  final String deQuem;
  /// O cartão de iniciar e encerrar a sessão (só o mestre).
  final bool comControle;
  const AbaSessoes({
    super.key,
    required this.camp,
    required this.notas,
    required this.aoSalvar,
    required this.deQuem,
    this.comControle = false,
  });

  @override
  Widget build(BuildContext context) {
    final lista = camp.historicoSessoes.reversed.toList();
    final atual = camp.sessao;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 28), children: [
      if (comControle) ...[
        CartaoSessao(camp: camp),
        const SizedBox(height: 16),
      ],
      Text('SESSÕES', style: estiloTitulo(20, cor: Cores.destaque)),
      const SizedBox(height: 2),
      Text('O registro de todas as sessões da mesa, com o tempo de cada uma. Nomes e notas $deQuem.',
          style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco)),
      if (lista.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Nenhuma sessão ainda. ${comControle ? 'Inicie a primeira no cartão acima.' : 'O mestre inicia a sessão pelo Painel da mesa.'}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Cores.textoFraco),
          ),
        ),
      for (final s in lista) ...[
        const SizedBox(height: 12),
        _RegistroSessao(
          key: ValueKey(asInt(s['numero'])),
          sessao: s,
          ativa: asBool(atual['ativa']) && asInt(atual['numero']) == asInt(s['numero']),
          nota: asMap(notas['${asInt(s['numero'])}']),
          aoSalvar: (campo, v) => aoSalvar(asInt(s['numero']), campo, v),
        ),
      ],
    ]);
  }
}

class _RegistroSessao extends StatelessWidget {
  final Map<String, dynamic> sessao;
  final bool ativa;
  final Map<String, dynamic> nota;
  final void Function(String campo, String valor) aoSalvar;
  const _RegistroSessao({super.key, required this.sessao, required this.ativa, required this.nota, required this.aoSalvar});

  @override
  Widget build(BuildContext context) {
    final numero = asInt(sessao['numero']);
    final inicio = asInt(sessao['inicio']);
    final fim = asInt(sessao['fim']);
    final nome = asStr(nota['nome']);
    final tempo = estiloNumero(20, cor: Cores.texto);
    return Material(
      color: ativa ? Cores.destaque.withValues(alpha: 0.08) : Cores.painel,
      shape: CorteCantos(corte: 12, cor: Cores.destaque.withValues(alpha: ativa ? 0.9 : 0.4)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Sessão $numero', style: estiloTitulo(18, cor: Cores.texto)),
                if (nome.isNotEmpty) TextSpan(text: ' · $nome', style: estiloTitulo(18, cor: Cores.destaque)),
              ])),
            ),
            const SizedBox(width: 10),
            if (ativa)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.radio_button_checked, size: 16, color: Cores.destaque),
                const SizedBox(width: 6),
                Cronometro(inicio: inicio, estilo: tempo),
              ])
            else
              Text(fim > inicio && inicio > 0 ? duracaoTexto(Duration(milliseconds: fim - inicio)) : '—', style: tempo),
          ]),
          if (inicio > 0)
            Text('${dataHora(inicio)}${ativa ? ' · em andamento' : ''}',
                style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
          const SizedBox(height: 10),
          CampoSync(
            valor: nome,
            rotulo: 'Nome da sessão',
            dica: 'Ex.: O porão da fazenda',
            aoSalvar: (v) => aoSalvar('nome', v),
          ),
          const SizedBox(height: 8),
          CampoSync(
            valor: asStr(nota['nota']),
            rotulo: 'Notas',
            dica: 'Ex.: Fulano morreu; a chave ficou com a Bianca…',
            maxLinhas: 8,
            aoSalvar: (v) => aoSalvar('nota', v),
          ),
        ]),
      ),
    );
  }
}

/// A aba Sessões do mestre: os nomes e as notas dele ficam guardados à
/// parte, só para ele.
class AbaSessoesMestre extends StatelessWidget {
  final Campanha camp;
  const AbaSessoesMestre({super.key, required this.camp});

  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: Repo.sessoesMestre(camp.id).snapshots(),
        builder: (context, snap) => AbaSessoes(
          camp: camp,
          notas: snap.data?.data() ?? const {},
          deQuem: 'do mestre: só você vê',
          comControle: true,
          aoSalvar: (n, campo, v) => Repo.notaSessaoMestre(camp.id, n, campo, v),
        ),
      );
}
