import 'package:flutter/material.dart';
import 'app.dart';
import 'core/bmoni_sdk/bmoni_sdk_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize BMONI Embedded SDK on-device
  await BmoniSdkService.initialize(
    pinLength: 6,
    requirePin: true,
  );

  runApp(const FlowPayApp());
}
