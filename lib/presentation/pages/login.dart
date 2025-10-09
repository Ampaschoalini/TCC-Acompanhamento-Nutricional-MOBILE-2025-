import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation.dart';
import '../../data/services/auth_service.dart';

class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin> {
  bool _senhaVisivel = false;
  bool _carregando = false;

  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ListView(
            shrinkWrap: true,
            children: [
              // LOGO
              Image.asset('assets/images/logo.png',
                  height: 150, fit: BoxFit.contain),
              const SizedBox(height: 24),

              // TÍTULO
              const Text(
                "Acesse sua conta",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEC8800),
                ),
              ),
              const SizedBox(height: 32),

              // FORMULÁRIO
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("E-mail",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF444444))),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Informe seu e-mail'
                          : null,
                      decoration: _inputDecoration(),
                    ),
                    const SizedBox(height: 16),

                    const Text("Senha",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF444444))),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: !_senhaVisivel,
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Informe sua senha'
                          : null,
                      decoration: _inputDecoration(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _senhaVisivel
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey[700],
                          ),
                          onPressed: () => setState(
                                  () => _senhaVisivel = !_senhaVisivel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC8800),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _realizarLogin,
                child: const Text(
                  "Entrar",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
        const BorderSide(color: Color(0xFFEC8800), width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Future<void> _realizarLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    print('🔐 Enviando login $email / $senha');

    setState(() => _carregando = true);

    try {
      final sucesso = await AuthService().login(email, senha);

      if (sucesso) {
        final prefs = await SharedPreferences.getInstance();
        final pacienteId = prefs.getInt('paciente_id') ?? 0;
        final nome = prefs.getString('nome') ?? '';

        print("✅ Login bem-sucedido: paciente_id=$pacienteId, nome=$nome");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        );
      } else {
        _mostrarErro("E-mail ou senha incorretos ou servidor indisponível");
      }
    } catch (e) {
      print("❌ Erro inesperado $e");
      _mostrarErro("Erro inesperado ao tentar fazer login");
    }

    setState(() => _carregando = false);
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
