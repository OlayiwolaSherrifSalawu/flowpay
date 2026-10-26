import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/auth/secure_storage_service.dart';
import 'core/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SecureStorageService.isTestEnv = false;


  runApp(
    ProviderScope(
      child: FlowPayApp(
        appState: AppState(providerMode: ProviderMode.bmoniSandbox),
      ),
    ),
  );
}
