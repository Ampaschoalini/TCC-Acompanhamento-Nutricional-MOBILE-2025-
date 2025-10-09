import 'package:flutter/material.dart';
import '../presentation/pages/login.dart';

class AppRoutes {
  static const login = '/login';

  static final Map<String, WidgetBuilder> routes = {
    login: (context) => const PaginaLogin(),
  };
}

