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
    Repo.setCamp(camp.id, {
      'sessao': {...s, 'ativa': false, 'fim': _agora()},
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
              onPressed: () => Repo.setCamp(camp.id, {
                'sessao': {'ativa': true, 'numero': numero + 1, 'inicio': _agora()},
              }),
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
