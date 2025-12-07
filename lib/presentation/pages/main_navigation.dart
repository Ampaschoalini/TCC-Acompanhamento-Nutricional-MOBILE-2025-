import 'package:flutter/material.dart';
import 'plano_alimentar.dart';
import 'relatorios.dart';
import 'perfil.dart';
import 'registro.dart';// <- NOVO

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int paginaAtual = 0;

  final List<Widget> paginas = const [
    PlanoAlimentarPage(),
    RegistroPage(),
    RelatoriosPage(),
    PerfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: paginas[paginaAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: paginaAtual,
        onTap: (index) => setState(() => paginaAtual = index),
        selectedItemColor: const Color(0xFFEC8800),
        unselectedItemColor: const Color(0xFF999999),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Plano',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note),
            label: 'Registro',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_outlined_rounded),
            label: 'Relatórios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
