import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/theme/app_theme.dart';
import 'src/ui/home_screen.dart';
import 'src/vpn/vpn_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const IbrahimVpnApp());
}

class IbrahimVpnApp extends StatefulWidget {
  const IbrahimVpnApp({super.key});

  @override
  State<IbrahimVpnApp> createState() => _IbrahimVpnAppState();
}

class _IbrahimVpnAppState extends State<IbrahimVpnApp> {
  late final VpnController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VpnController();
    _controller.boot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ابراهيم VPN',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(controller: _controller),
    );
  }
}
