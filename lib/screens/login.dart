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
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LogoCris(tamanho: 64),
                const SizedBox(height: 8),
                const Text(
                  'Fichas de agentes da Ordo Realitas',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Cores.textoFraco),
                ),
                const SizedBox(height: 32),
                if (_criando) ...[
                  TextField(
                      controller: _nome,
                      decoration:
                          const InputDecoration(labelText: 'Seu nome / apelido')),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senha,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  onSubmitted: (_) => _enviar(),
                ),
                const SizedBox(height: 16),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_erro!,
                        style: TextStyle(color: Cores.destaque)),
                  ),
                FilledButton(
                  onPressed: _carregando ? null : _enviar,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _carregando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_criando ? 'CRIAR CONTA' : 'ENTRAR'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _criando = !_criando;
                    _erro = null;
                  }),
                  child: Text(_criando
                      ? 'Já tenho conta'
                      : 'Não tem conta? Criar agora'),
                ),
                if (!_criando)
                  TextButton(
                      onPressed: _esqueci,
                      child: const Text('Esqueci minha senha')),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await abrirImportarCris(context, logado: false);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Trazer agentes do site do CRIS'),
                ),
                const SizedBox(height: 6),
                Text(
                  CrisImport.pendentes.isEmpty
                      ? 'Já usa o crisordemparanormal.com? Traga seus agentes: eles entram no app assim que você entrar ou criar a conta.'
                      : '${CrisImport.pendentes.length == 1 ? '1 agente esperando' : '${CrisImport.pendentes.length} agentes esperando'} o login: ${CrisImport.pendentes.map((a) => a.nome).join(', ')}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: CrisImport.pendentes.isEmpty
                          ? Cores.textoFraco
                          : Cores.destaque),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => escolherTema(context),
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Tema de cores'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
