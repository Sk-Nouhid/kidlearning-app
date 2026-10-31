import 'package:sembast_web/sembast_web.dart';

Future<Database> openTinyTrailDatabase() =>
    databaseFactoryWeb.openDatabase('tinytrail.db');
