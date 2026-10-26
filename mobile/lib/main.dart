import 'core/network/api_client.dart';
import 'core/navigation/invite_link.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/auth/secure_storage_service.dart';
import 'core/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SecureStorageService.isTestEnv = false;
  FlowPayApiClient.sessionToken = await SecureStorageService().getAuthToken();

  // Opened from an employee invite link (web): remember it for the auth gate.
  if (kIsWeb) InviteLink.pendingToken = InviteLink.parse(Uri.base.toString());


  runApp(
    ProviderScope(
      child: FlowPayApp(
        appState: AppState(providerMode: ProviderMode.live),
      ),
    ),
  );
}
