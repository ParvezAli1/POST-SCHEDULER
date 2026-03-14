import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

class PostSchedulerApp extends StatelessWidget {
  const PostSchedulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POST SCHEDULER',
      theme: buildAppTheme(),
      routes: appRoutes,
      initialRoute: launchRoute,
    );
  }
}
