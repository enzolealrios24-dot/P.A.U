import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/imagens.dart';
import '../data/models.dart';
import '../data/repo.dart';
import 'imagem.dart';

/// A foto de perfil de um jogador, redonda; sem foto, as iniciais do nome.
/// Com [aoTocar] (o próprio jogador), tocar troca a foto.
class FotoJogador extends StatefulWidget {
  final String uid;
  final String nome;
  final double tamanho;
  final VoidCallback? aoTocar;
  const FotoJogador({super.key, required this.uid, this.nome = '', this.tamanho = 32, this.aoTocar});

  @override
  State<FotoJogador> createState() => _FotoJogadorState();
}

class _FotoJogadorState extends State<FotoJogador> {
  late Stream<Map<String, dynamic>> _perfil = Repo.perfilDoJogador(widget.uid);

  @override
  void didUpdateWidget(covariant FotoJogador old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _perfil = Repo.perfilDoJogador(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamanho;
    final iniciais = widget.nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
    return StreamBuilder<Map<String, dynamic>>(
      stream: _perfil,
      builder: (context, s) {
        final id = asStr(s.data?['foto']);
        final circulo = id.isNotEmpty
            ? FotoRedonda(foto: id, ajuste: asMap(s.data?['fotoAjuste']), tamanho: t)
            : Container(
                width: t,
                height: t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Cores.painel2,
                  border: Border.all(color: Cores.destaque.withValues(alpha: 0.6), width: t >= 40 ? 1.6 : 1),
                ),
                child: Center(
                  child: iniciais.isEmpty
                      ? Icon(Icons.person_outline, size: t * 0.6, color: Cores.textoFraco)
                      : Text(iniciais.toUpperCase(),
                          style: estiloRotulo(t * 0.38, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 0.5)),
                ),
              );
        if (widget.aoTocar == null) return circulo;
        return Tooltip(
          message: 'Sua foto de jogador',
          child: InkWell(customBorder: const CircleBorder(), onTap: widget.aoTocar, child: circulo),
        );
      },
    );
  }
}

/// Pôr, ver, trocar ou tirar a foto de perfil de quem está usando o app.
/// Ela aparece nas fichas dos agentes dele e para o mestre.
Future<void> opcoesFotoJogador(BuildContext context) async {
  final perfil = await Repo.perfilDoJogador(Repo.uid).first;
  final atual = asStr(perfil['foto']);
  if (!context.mounted) return;
  final temFoto = atual.isNotEmpty;
  final escolha = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: Text('Foto de perfil', style: estiloTitulo(18, cor: Cores.texto)),
          subtitle: const Text('Aparece nas fichas dos seus agentes e para o mestre da mesa.'),
        ),
        if (temFoto)
          ListTile(
            leading: const Icon(Icons.zoom_in),
            title: const Text('Ver foto'),
            onTap: () => Navigator.pop(ctx, 'ver'),
          ),
        if (temFoto)
          ListTile(
            leading: const Icon(Icons.crop_free),
            title: const Text('Ajustar foto'),
            subtitle: const Text('Centralizar o rosto e dar zoom'),
            onTap: () => Navigator.pop(ctx, 'ajustar'),
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
    verImagem(context, atual, titulo: Repo.nomeUsuario);
  } else if (escolha == 'ajustar') {
    final a = await escolherEnquadramento(context,
        foto: atual, nome: Repo.nomeUsuario, ajuste: asMap(perfil['fotoAjuste']), redondo: true);
    if (a != null) Repo.enquadrarMinhaFoto(a);
  } else if (escolha == 'trocar') {
    final r = await escolherImagem(context, lado: 600);
    if (r == null) return;
    Repo.mudarMinhaFoto(r.id);
    Imagens.apagar(atual);
    // a foto nova já abre no ajuste
    if (!context.mounted) return;
    final a = await escolherEnquadramento(context, foto: r.id, nome: Repo.nomeUsuario, redondo: true);
    if (a != null) Repo.enquadrarMinhaFoto(a);
  } else if (escolha == 'tirar') {
    Repo.mudarMinhaFoto('');
    Imagens.apagar(atual);
  }
}
