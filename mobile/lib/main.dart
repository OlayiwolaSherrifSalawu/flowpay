import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/bmoni_sdk/bmoni_sdk_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize BMONI Embedded SDK on-device with 6-digit PIN policy
  BmoniEmbeddedSdk.initialize(
    pinLength: 6,
    requirePin: true,
  );
  await BmoniSdkService.initialize(
    pinLength: 6,
    requirePin: true,
  );

  runApp(
    const ProviderScope(
      child: FlowPayApp(),
    ),
  );
}
