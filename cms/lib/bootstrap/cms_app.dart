import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/routing/cms_router.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';

class CmsApp extends ConsumerWidget {
  const CmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Nadha Edu CMS',
    debugShowCheckedModeBanner: false,
    theme: CmsTheme.darkTheme,
    routerConfig: ref.watch(cmsRouterProvider),
  );
}
