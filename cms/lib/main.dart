import 'package:nadha_cms/bootstrap/cms_bootstrap.dart';
import 'package:nadha_cms/config/app_environment.dart';

Future<void> main() =>
    bootstrapCms(environment: AppEnvironment.fromBuildMode());
