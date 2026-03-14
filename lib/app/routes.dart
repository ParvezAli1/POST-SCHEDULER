import 'package:flutter/widgets.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/connect_accounts_screen.dart';
import '../features/auth/presentation/launch_screen.dart';
import 'root_shell.dart';

const String launchRoute = '/launch';
const String authRoute = '/auth';
const String homeRoute = '/home';
const String connectAccountsRoute = '/connect-accounts';

final Map<String, WidgetBuilder> appRoutes = {
  launchRoute: (_) => const LaunchScreen(),
  authRoute: (_) => const AuthScreen(),
  homeRoute: (_) => const RootShell(),
  connectAccountsRoute: (_) => const ConnectAccountsScreen(),
};
