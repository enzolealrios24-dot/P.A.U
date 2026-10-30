import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/arquivo.dart';
import '../../widgets/common.dart';
import '../../widgets/efeitos.dart';

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
    final textos = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Sessão ${ativa ? numero : numero + 1}', style: estiloTitulo(22, cor: Cores.texto)),
        if (ativa) ...[
          const SizedBox(width: 12),
          const Carimbo('AO VIVO', tamanho: 11.5),
        ],
      ]),
      const SizedBox(height: 4),
      if (ativa)
        Text('Começou às ${formatarHora(asInt(s['inicio']))}', style: estiloMaquina(13, cor: Cores.textoFraco))
      else
        Text(
          numero == 0 || durou <= 0
              ? 'Quando todos estiverem prontos, inicie a sessão: os jogadores veem que ela começou.'
              : 'A sessão $numero durou ${duracaoTexto(Duration(milliseconds: durou))}.',
          style: const TextStyle(fontSize: 14, height: 1.4, color: Cores.textoFraco),
        ),
    ]);
    final botao = ativa
        ? OutlinedButton.icon(
            onPressed: () => _encerrar(context, s),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Encerrar sessão'),
          )
        : FilledButton.icon(
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
          );
    final relogio = ativa ? Cronometro(inicio: asInt(s['inicio']), estilo: estiloNumero(40, cor: Cores.texto)) : null;
    return Material(
      color: ativa ? Color.alphaBlend(Cores.destaque.withValues(alpha: 0.09), Cores.painel) : Cores.painel,
      shape: CorteCantos(corte: 16, cor: Cores.destaque.withValues(alpha: ativa ? 0.9 : 0.45), largura: ativa ? 1.6 : 1),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: LayoutBuilder(
          builder: (context, c) => c.maxWidth < 560
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  textos,
                  if (relogio != null) ...[const SizedBox(height: 8), relogio],
                  const SizedBox(height: 12),
                  botao,
                ])
              : Row(children: [
                  Expanded(child: textos),
                  if (relogio != null) ...[relogio, const SizedBox(width: 20)],
                  botao,
                ]),
        ),
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
        padding: EdgeInsets.fromLTRB(2, 2, 2, 8),
        child: Row(children: [
          Icon(Icons.schedule, size: 18, color: Cores.textoFraco),
          SizedBox(width: 8),
          Expanded(
            child: Text('A sessão ainda não começou: o mestre inicia pelo Painel da mesa.',
                style: TextStyle(fontSize: 14, color: Cores.textoFraco)),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Color.alphaBlend(Cores.destaque.withValues(alpha: 0.09), Cores.painel),
        shape: CorteCantos(corte: 12, cor: Cores.destaque.withValues(alpha: 0.8), largura: 1.4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            const Carimbo('AO VIVO', tamanho: 11),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Sessão ${asInt(s['numero'])} em andamento',
                  style: estiloTitulo(16, cor: Cores.texto)),
            ),
            Cronometro(inicio: asInt(s['inicio']), estilo: estiloNumero(24, cor: Cores.texto)),
          ]),
        ),
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
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
      if (comControle) ...[
        CartaoSessao(camp: camp),
        const SizedBox(height: 22),
      ],
      CabecalhoAba(
        titulo: 'Sessões',
        texto: 'O registro de todas as sessões da mesa, com o tempo de cada uma. Nomes e notas $deQuem.',
      ),
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
        _RegistroSessao(
          key: ValueKey(asInt(s['numero'])),
          sessao: s,
          ativa: asBool(atual['ativa']) && asInt(atual['numero']) == asInt(s['numero']),
          nota: asMap(notas['${asInt(s['numero'])}']),
          aoSalvar: (campo, v) => aoSalvar(asInt(s['numero']), campo, v),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

/// Uma sessão do registro: o número grande na margem, como capítulo, e ao
/// lado o nome, a data, o tempo e as notas.
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
    final tempo = estiloNumero(22, cor: Cores.texto);
    return Material(
      color: ativa ? Color.alphaBlend(Cores.destaque.withValues(alpha: 0.07), Cores.painel) : Cores.painel,
      shape: CorteCantos(corte: 12, cor: ativa ? Cores.destaque.withValues(alpha: 0.85) : Cores.borda),
      clipBehavior: Clip.antiAlias,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(children: [
              Text('sessão', style: estiloMaquina(11, cor: Cores.textoFraco)),
              Gasto(
                escala: 0.6,
                child: Text('$numero',
                    style: estiloTitulo(34, cor: ativa ? Cores.destaque : Cores.texto, peso: FontWeight.w800, altura: 1.1)),
              ),
            ]),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: Cores.linha))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(nome.isEmpty ? 'Sessão $numero' : nome,
                      style: estiloTitulo(18, cor: nome.isEmpty ? Cores.textoFraco : Cores.texto)),
                ),
                const SizedBox(width: 10),
                if (ativa)
                  Cronometro(inicio: inicio, estilo: tempo)
                else
                  Text(fim > inicio && inicio > 0 ? duracaoTexto(Duration(milliseconds: fim - inicio)) : '—', style: tempo),
              ]),
              if (inicio > 0) ...[
                const SizedBox(height: 2),
                Text('${dataHora(inicio)}${ativa ? ', em andamento' : ''}',
                    style: estiloMaquina(12.5, cor: ativa ? Cores.destaque : Cores.textoFraco)),
              ],
              const SizedBox(height: 8),
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
        ),
      ]),
    );
  }
}
// A aba Sessões do mestre: os nomes e as notas dele ficam guardados à
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
