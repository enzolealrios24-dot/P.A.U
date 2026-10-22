import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/cris_import.dart';
import '../widgets/importar_cris.dart';
import '../widgets/tema_picker.dart';
import '../widgets/logo.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});
  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _nome = TextEditingController();
  bool _criando = false;
  bool _carregando = false;
  String? _erro;

  String _traduzir(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já tem conta. Entre com ele.';
      case 'weak-password':
        return 'Senha fraca (mínimo 6 caracteres).';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'operation-not-allowed':
        return 'Ative o login por E-mail/senha no console do Firebase.';
      default:
        return e.message ?? e.code;
    }
  }

  Future<void> _enviar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final auth = FirebaseAuth.instance;
    try {
      if (_criando) {
        final nome = _nome.text.trim();
        if (nome.isEmpty) throw 'Digite seu nome.';
        final cred = await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _senha.text);
        await cred.user?.updateDisplayName(nome);
        await cred.user?.reload();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({'nome': nome});
      } else {
        await auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _senha.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _traduzir(e));
    } catch (e) {
      setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _esqueci() async {
    final e = _email.text.trim();
    if (e.isEmpty) {
      setState(() => _erro = 'Digite seu e-mail para recuperar a senha.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: e);
      setState(() => _erro = 'Enviamos um e-mail de recuperação para $e.');
    } on FirebaseAuthException catch (x) {
      setState(() => _erro = _traduzir(x));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LogoCris(tamanho: 58),
                const SizedBox(height: 14),
                Text(
                  'FICHAS DE AGENTES DA ORDO REALITAS',
                  textAlign: TextAlign.center,
                  style: estiloRotulo(13.5, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 2.6),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(_criando ? 'Criar conta' : 'Entrar',
                          style: estiloTitulo(20, cor: Cores.texto)),
                      const SizedBox(height: 4),
                      Text(
                          _criando
                              ? 'Seus agentes ficam salvos na nuvem e no aparelho.'
                              : 'Bem-vindo de volta, agente.',
                          style: const TextStyle(color: Cores.textoFraco, fontSize: 13.5)),
                      const SizedBox(height: 12),
                      if (_criando) ...[
                        TextField(
                            controller: _nome,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Seu nome / apelido',
                                prefixIcon: Icon(Icons.person_outline, size: 20))),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                            labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline, size: 20)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _senha,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Senha', prefixIcon: Icon(Icons.lock_outline, size: 20)),
                        onSubmitted: (_) => _enviar(),
                      ),
                      const SizedBox(height: 18),
                      if (_erro != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_erro!, style: TextStyle(color: Cores.destaque)),
                        ),
                      FilledButton(
                        onPressed: _carregando ? null : _enviar,
                        child: _carregando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_criando ? 'CRIAR CONTA' : 'ENTRAR'),
                      ),
                      const SizedBox(height: 6),
                      Wrap(alignment: WrapAlignment.spaceBetween, children: [
                        TextButton(
                          onPressed: () => setState(() {
                            _criando = !_criando;
                            _erro = null;
                          }),
                          child: Text(_criando ? 'Já tenho conta' : 'Criar conta'),
                        ),
                        if (!_criando)
                          TextButton(
                            onPressed: _esqueci,
                            style: TextButton.styleFrom(foregroundColor: Cores.textoFraco),
                            child: const Text('Esqueci a senha'),
                          ),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () async {
                      await abrirImportarCris(context, logado: false);
                      if (mounted) setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Cores.roxoClaro.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Cores.roxoClaro.withValues(alpha: 0.4)),
                          ),
                          child: Icon(Icons.download_outlined, color: Cores.roxoClaro),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Trazer agentes do site do CRIS',
                                style: estiloRotulo(16, cor: Cores.texto, peso: FontWeight.w700, espaco: 0.3)),
                            const SizedBox(height: 3),
                            Text(
                              CrisImport.pendentes.isEmpty
                                  ? 'Já usa o crisordemparanormal.com? Seus agentes entram assim que você entrar.'
                                  : '${CrisImport.pendentes.length == 1 ? '1 agente esperando' : '${CrisImport.pendentes.length} agentes esperando'} o login: ${CrisImport.pendentes.map((a) => a.nome).join(', ')}.',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: CrisImport.pendentes.isEmpty
                                      ? Cores.textoFraco
                                      : Cores.destaque),
                            ),
                          ]),
                        ),
                        const Icon(Icons.chevron_right, color: Cores.textoFraco),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const AmostrasTema(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
