import 'package:flutter/material.dart';
import 'app/flow_app.dart';

export 'app/flow_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlowApp());
}
