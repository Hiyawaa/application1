import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_scan/wifi_scan.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

// ─────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────
class AppColors {
  static const bg        = Color(0xFF0D1117);
  static const surface   = Color(0xFF161B22);
  static const card      = Color(0xFF1C2333);
  static const accent    = Color(0xFF58A6FF);
  static const accentAlt = Color(0xFF3FB950); // green
  static const warn      = Color(0xFFD29922);  // orange
  static const danger    = Color(0xFFF85149);
  static const textPrim  = Color(0xFFE6EDF3);
  static const textSub   = Color(0xFF8B949E);
  static const divider   = Color(0xFF30363D);
}

// Reusable gradient decoration
BoxDecoration get _bgDecor => const BoxDecoration(
  gradient: LinearGradient(
    colors: [AppColors.bg, Color(0xFF0A0E1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

// ─────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
  runApp(ChargingStationAdmin(isFirstTime: isFirstTime));
}

class ChargingStationAdmin extends StatelessWidget {
  final bool isFirstTime;
  const ChargingStationAdmin({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Station Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const OnboardingScreen(),
    );
  }
}

// ─────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────

/// Glowing icon container
Widget _glowIcon(IconData icon, Color color, {double size = 60}) => Container(
  width: size + 20,
  height: size + 20,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: color.withOpacity(0.08),
    border: Border.all(color: color.withOpacity(0.25), width: 1.5),
    boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 24, spreadRadius: 2)],
  ),
  child: Icon(icon, size: size, color: color),
);

/// Gradient primary button
Widget _primaryBtn({required String label, required VoidCallback? onTap, Color color = AppColors.accent, IconData? icon}) =>
  SizedBox(
    width: double.infinity,
    height: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withBlue((color.blue + 40).clamp(0, 255))]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ),
    ),
  );

/// Ghost / outlined button
Widget _ghostBtn({required String label, required VoidCallback? onTap, Color color = AppColors.textSub, IconData? icon}) =>
  SizedBox(
    width: double.infinity,
    height: 44,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    ),
  );

/// Step indicator dots
Widget _stepDots(int current, int total) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: List.generate(total, (i) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.symmetric(horizontal: 4),
    width: i == current ? 24 : 8,
    height: 8,
    decoration: BoxDecoration(
      color: i == current ? AppColors.accent : AppColors.divider,
      borderRadius: BorderRadius.circular(4),
    ),
  )),
);

/// Section label
Widget _label(String text) => Text(
  text.toUpperCase(),
  style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: AppColors.textSub, fontWeight: FontWeight.w600),
);

// ─────────────────────────────────────────
// ONBOARDING SCREEN
// ─────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl  = PageController();
  final _passCtrl  = TextEditingController();
  int   _pageIndex = 0;

  List<String> _scannedSSIDs  = [];
  String?      _selectedSSID;
  bool         _isConnecting  = false;
  bool         _isScanningWifi = false;
  String?      _qrResult;
  final _camCtrl = MobileScannerController();

  void _goNext() {
    setState(() => _pageIndex++);
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  Future<void> _connectToMachine() async {
    setState(() => _isConnecting = true);
    try {
      bool ok = await WiFiForIoTPlugin.connect(
        "ESP32_VENDO",
        password: "12345678",
        security: NetworkSecurity.WPA,
        joinOnce: true,
        withInternet: false,
      );
      if (ok) {
        await WiFiForIoTPlugin.forceWifiUsage(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Connected! Scanning for nearby WiFi…"),
            backgroundColor: AppColors.accentAlt,
          ));
          await _scanNearbyWiFi();
          _goNext();
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Could not connect. Is the machine turned on?"),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (e) {
      debugPrint("WiFi error: $e");
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _scanNearbyWiFi() async {
    setState(() => _isScanningWifi = true);
    try {
      var status = await Permission.location.request();
      if (status.isGranted) {
        final canScan = await WiFiScan.instance.canStartScan();
        if (canScan == CanStartScan.yes) {
          await WiFiScan.instance.startScan();
          await Future.delayed(const Duration(seconds: 2));
          final results = await WiFiScan.instance.getScannedResults();
          final unique = results.map((n) => n.ssid).where((s) => s.isNotEmpty).toSet().toList();
          if (mounted) setState(() {
            _scannedSSIDs = unique;
            if (unique.isNotEmpty) _selectedSSID = unique.first;
          });
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Location permission required to scan WiFi."),
          backgroundColor: AppColors.warn,
        ));
      }
    } catch (e) {
      debugPrint("Scan error: $e");
    } finally {
      if (mounted) setState(() => _isScanningWifi = false);
    }
  }

  void _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _bgDecor,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bolt, color: AppColors.accent, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text("VendoSetup", style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 16)),
                    ]),
                    _stepDots(_pageIndex, 3),
                  ],
                ),
              ),
              const Divider(color: AppColors.divider, height: 24),

              // ── Pages ────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  children: [_page1(), _page2(), _page3()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PAGE 1: Connect to ESP32 ────────────────────
  Widget _page1() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      _glowIcon(Icons.wifi_tethering_rounded, AppColors.accent, size: 64),
      const SizedBox(height: 24),
      _label("Step 1 of 3"),
      const SizedBox(height: 8),
      const Text("Link to Machine",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrim)),
      const SizedBox(height: 12),
      const Text(
        "Keep your phone near the Vendo Machine.\nWe will connect to it automatically.",
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSub, height: 1.5),
      ),
      const SizedBox(height: 36),

      // Status card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.router_rounded, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("ESP32_VENDO", style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w600)),
            Text("WPA2 · Auto connect", style: TextStyle(color: AppColors.textSub, fontSize: 12)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: const Text("READY", style: TextStyle(color: AppColors.accentAlt, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      const SizedBox(height: 32),

      _isConnecting
          ? Column(children: [
              const CircularProgressIndicator(color: AppColors.accent),
              const SizedBox(height: 10),
              const Text("Connecting…", style: TextStyle(color: AppColors.textSub)),
            ])
          : _primaryBtn(label: "Connect to Machine", onTap: _connectToMachine, icon: Icons.wifi_rounded),

      const SizedBox(height: 12),
      _primaryBtn(
        label: "Add QR Code (Temp)",
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddQrPage())),
        color: AppColors.warn,
        icon: Icons.qr_code_2_rounded,
      ),
      const SizedBox(height: 12),
      _ghostBtn(
        label: "Skip to Next Page (Temp)",
        onTap: _goNext,
        icon: Icons.skip_next_rounded,
      ),
    ]),
  );

  // ── PAGE 2: Internet Setup ──────────────────────
  Widget _page2() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: _glowIcon(Icons.hub_rounded, AppColors.warn, size: 64)),
      const SizedBox(height: 24),
      Center(child: _label("Step 2 of 3")),
      const SizedBox(height: 8),
      const Center(
        child: Text("Internet Setup",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrim)),
      ),
      const SizedBox(height: 10),
      const Center(
        child: Text(
          "Select your home WiFi so the machine\ncan connect to the cloud.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, height: 1.5),
        ),
      ),
      const SizedBox(height: 28),

      _label("Available Networks"),
      const SizedBox(height: 8),

      if (_isScanningWifi)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            SizedBox(width: 12),
            Text("Scanning for networks…", style: TextStyle(color: AppColors.textSub)),
          ]),
        )
      else if (_scannedSSIDs.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSSID,
              isExpanded: true,
              dropdownColor: AppColors.card,
              icon: const Icon(Icons.expand_more, color: AppColors.textSub),
              items: _scannedSSIDs.map((s) => DropdownMenuItem(
                value: s,
                child: Row(children: [
                  const Icon(Icons.wifi_rounded, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(s, style: const TextStyle(color: AppColors.textPrim)),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _selectedSSID = v),
            ),
          ),
        )
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.danger.withOpacity(0.4))),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.signal_wifi_off, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text("No networks found. Enable Location and retry.", style: TextStyle(color: AppColors.textSub, fontSize: 13))),
            ]),
            const SizedBox(height: 12),
            _ghostBtn(label: "Rescan Networks", onTap: _scanNearbyWiFi, icon: Icons.refresh_rounded, color: AppColors.accent),
          ]),
        ),

      const SizedBox(height: 16),
      _label("WiFi Password"),
      const SizedBox(height: 8),
      TextField(
        controller: _passCtrl,
        obscureText: true,
        style: const TextStyle(color: AppColors.textPrim),
        decoration: InputDecoration(
          hintText: "Enter password",
          hintStyle: const TextStyle(color: AppColors.textSub),
          filled: true,
          fillColor: AppColors.card,
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSub),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
        ),
      ),
      const SizedBox(height: 28),

      _primaryBtn(
        label: "Send to Machine",
        icon: Icons.send_rounded,
        color: AppColors.warn,
        onTap: () async {
          if (_selectedSSID == null || _passCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Please select a WiFi and enter the password."),
              backgroundColor: AppColors.warn,
            ));
            return;
          }
          try {
            var res = await http.post(Uri.parse('http://192.168.4.1/setup'),
              body: {"ssid": _selectedSSID, "pass": _passCtrl.text},
            ).timeout(const Duration(seconds: 7));
            if (!context.mounted) return;
            if (res.statusCode == 200) {
              await WiFiForIoTPlugin.forceWifiUsage(false);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Credentials sent! Machine is rebooting."),
                backgroundColor: AppColors.accentAlt,
              ));
              _goNext();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Machine rejected the data."),
                backgroundColor: AppColors.danger,
              ));
            }
          } catch (e) {
            await WiFiForIoTPlugin.forceWifiUsage(false);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("TRUE ERROR: ${e.toString()}"),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 10),
            ));
          }
        },
      ),
      const SizedBox(height: 12),
      _ghostBtn(label: "Skip to Next Page (Temp)", onTap: _goNext, icon: Icons.skip_next_rounded),
    ]),
  );

  // ── PAGE 3: QR Scanner ──────────────────────────
  Widget _page3() => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(children: [
        _glowIcon(Icons.qr_code_scanner_rounded, AppColors.accentAlt, size: 56),
        const SizedBox(height: 16),
        _label("Step 3 of 3"),
        const SizedBox(height: 6),
        const Text("Link Machine",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrim)),
        const SizedBox(height: 8),
        const Text(
          "Scan the QR code on your Vendo Machine to link it to your account.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, height: 1.5),
        ),
        const SizedBox(height: 16),
      ]),
    ),

    // Camera viewport with overlay border
    Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            MobileScanner(
              controller: _camCtrl,
              onDetect: (capture) async {
                if (capture.barcodes.isNotEmpty) {
                  final code = capture.barcodes.first.rawValue;
                  if (code != null && code != _qrResult) {
                    setState(() => _qrResult = code);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Scanned: $code")));
                    try {
                      final ref = FirebaseDatabase.instance.ref('qr_codes');
                      final event = await ref.orderByChild('code').equalTo(code).once();
                      if (event.snapshot.value != null) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Unsuccessful login: QR not recognized"),
                          backgroundColor: AppColors.danger,
                        ));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Error checking QR: $e"),
                        backgroundColor: AppColors.danger,
                      ));
                    }
                  }
                }
              },
            ),
            // Corner brackets overlay
            Positioned.fill(child: CustomPaint(painter: _ScanOverlayPainter())),
          ]),
        ),
      ),
    ),

    Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(children: [
        _primaryBtn(label: "Simulate QR Scan & Finish", onTap: _finishSetup, icon: Icons.check_circle_outline_rounded, color: AppColors.accentAlt),
        const SizedBox(height: 10),
        _ghostBtn(label: "Skip to Dashboard (Temp)", icon: Icons.skip_next_rounded,
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen())),
        ),
      ]),
    ),
  ]);
}

// Corner-bracket scanner overlay painter
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.accentAlt..strokeWidth = 3..style = PaintingStyle.stroke;
    const r = 24.0;
    
    final corners = [
      [Offset(0, r), Offset(0, 0), Offset(r, 0)],
      [Offset(size.width - r, 0), Offset(size.width, 0), Offset(size.width, r)],
      [Offset(size.width, size.height - r), Offset(size.width, size.height), Offset(size.width - r, size.height)],
      [Offset(r, size.height), Offset(0, size.height), Offset(0, size.height - r)],
    ];
    for (final c in corners) {
      canvas.drawLine(c[0], c[1], p);
      canvas.drawLine(c[1], c[2], p);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────
// ADD QR PAGE
// ─────────────────────────────────────────
class AddQrPage extends StatefulWidget {
  const AddQrPage({super.key});
  @override
  State<AddQrPage> createState() => _AddQrPageState();
}

class _AddQrPageState extends State<AddQrPage> {
  final _ctrl  = MobileScannerController();
  final _qrRef = FirebaseDatabase.instance.ref('qr_codes');
  bool _isProcessing = false;

  void _handleScan(String raw) async {
    final key = encrypt.Key.fromBase64(raw.replaceAll('-', '+').replaceAll('_', '/'));
    final fernet = encrypt.Fernet(key);
    final encrypter = encrypt.Encrypter(fernet);
    try {
      final json = encrypter.decrypt64(raw);
      final data = jsonDecode(json) as Map<String, dynamic>;
      await _qrRef.push().set({'code': raw, 'decrypted': data, 'timestamp': ServerValue.timestamp});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("QR code decrypted and saved"),
        backgroundColor: AppColors.accentAlt,
      ));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Security Alert: Invalid or fake QR Code scanned!"),
        backgroundColor: AppColors.danger,
      ));
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text("Add QR Code", style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: _bgDecor,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warn.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warn.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warn, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text("Scan the encrypted QR code on the machine.", style: TextStyle(color: AppColors.warn, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(children: [
                  MobileScanner(
                    controller: _ctrl,
                    onDetect: (capture) {
                      if (_isProcessing) return;
                      if (capture.barcodes.isNotEmpty) {
                        final code = capture.barcodes.first.rawValue;
                        if (code != null) {
                          setState(() => _isProcessing = true);
                          _handleScan(code);
                        }
                      }
                    },
                  ),
                  Positioned.fill(child: CustomPaint(painter: _ScanOverlayPainter())),
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(child: CircularProgressIndicator(color: AppColors.accentAlt)),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// DASHBOARD SCREEN
// ─────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirebaseDatabase.instance.ref();

  Map<String, dynamic> currentSettings = {
    "1":  {"enabled": true, "time": 5},
    "5":  {"enabled": true, "time": 15},
    "10": {"enabled": true, "time": 30},
    "20": {"enabled": true, "time": 60},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.bolt, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 8),
          const Text("Station Dashboard", style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 17)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
                child: const Icon(Icons.tune_rounded, color: AppColors.textSub, size: 18),
              ),
              onPressed: _showSettingsDialog,
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _db.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (!snap.hasData || snap.data?.snapshot.value == null) {
            return _emptyState();
          }

          final raw = snap.data!.snapshot.value as Map<dynamic, dynamic>;
          if (raw['settings']?['coins'] != null) {
            currentSettings = Map<String, dynamic>.from(raw['settings']['coins']);
          }

          final earn = raw['total_earnings'] as Map<dynamic, dynamic>? ?? {};
          final charge = double.tryParse(earn['charging']?.toString() ?? '0') ?? 0.0;
          final wifi   = double.tryParse(earn['wifi']?.toString() ?? '0') ?? 0.0;
          final total  = charge + wifi;

          return Container(
            decoration: _bgDecor,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Total card (hero) ────────────────
                _heroCard(total),
                const SizedBox(height: 16),

                // ── Sub-revenue cards ────────────────
                Row(children: [
                  Expanded(child: _miniCard("Charging", charge, AppColors.accent, Icons.electrical_services_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _miniCard("WiFi Vending", wifi, AppColors.warn, Icons.wifi_rounded)),
                ]),
                const SizedBox(height: 24),

                // ── Quick stats ──────────────────────
                _label("Quick Stats"),
                const SizedBox(height: 10),
                _statsRow(charge, wifi, total),
                const SizedBox(height: 24),

                // ── View Logs button ─────────────────
                _primaryBtn(
                  label: "View Daily Logs",
                  icon: Icons.bar_chart_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogsScreen())),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _glowIcon(Icons.cloud_off_rounded, AppColors.textSub),
      const SizedBox(height: 16),
      const Text("Waiting for ESP32 data…", style: TextStyle(color: AppColors.textSub)),
    ]),
  );

  Widget _heroCard(double total) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.accentAlt.withOpacity(0.85), const Color(0xFF0D5E27)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: AppColors.accentAlt.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
        SizedBox(width: 6),
        Text("TOTAL COLLECTED", style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),
      Text("₱ ${total.toStringAsFixed(2)}",
        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
      const SizedBox(height: 4),
      const Text("All-time revenue", style: TextStyle(color: Colors.white60, fontSize: 13)),
    ]),
  );

  Widget _miniCard(String label, double val, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 10),
      Text("₱ ${val.toStringAsFixed(2)}",
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrim)),
    ]),
  );

  Widget _statsRow(double charge, double wifi, double total) {
    final pct = total == 0 ? 0.0 : charge / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Charging share", style: TextStyle(color: AppColors.textSub, fontSize: 13)),
          Text("${(pct * 100).toStringAsFixed(0)}%", style: const TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.divider,
            color: AppColors.accent,
          ),
        ),
      ]),
    );
  }

  void _showSettingsDialog() {
    // ── local state captured by StatefulBuilder ──────────────────
    Map<String, dynamic> tmp = {
      for (final k in ["1","5","10","20"])
        k: {"enabled": currentSettings[k]?["enabled"] ?? true, "time": currentSettings[k]?["time"] ?? 0}
    };
    final ssidCtrl  = TextEditingController();
    final passCtrl  = TextEditingController();
    bool  isSending = false;
    bool  passVisible = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) {

          // ── Save coin settings ─────────────────────────────────
          void saveCoinSettings() {
            Map<String, Object> updates = {};
            tmp.forEach((c, d) {
              updates["$c/time"]    = d["time"];
              updates["$c/enabled"] = d["enabled"];
            });
            _db.child("settings/coins").update(updates).then((_) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text("✓ Coin settings saved to station."),
                  backgroundColor: AppColors.accentAlt,
                ));
              }
            });
          }

          // ── Send WiFi change to Firebase ───────────────────────
          Future<void> sendWifiChange() async {
            if (ssidCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                content: Text("Enter both WiFi name and password."),
                backgroundColor: AppColors.warn,
              ));
              return;
            }
            setDlg(() => isSending = true);
            try {
              await _db.child("commands/wifi_change").set({
                "ssid":    ssidCtrl.text.trim(),
                "pass":    passCtrl.text,
                "pending": true,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("✓ WiFi change sent! Machine will reboot shortly."),
                  backgroundColor: AppColors.accentAlt,
                  duration: Duration(seconds: 4),
                ));
              }
            } catch (e) {
              setDlg(() => isSending = false);
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text("Failed to send: $e"),
                backgroundColor: AppColors.danger,
              ));
            }
          }

          // ── Dialog UI ──────────────────────────────────────────
          return Dialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ───────────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_rounded, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Machine Settings", style: TextStyle(color: AppColors.textPrim, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text("ESP32 Vendo Configuration", style: TextStyle(color: AppColors.textSub, fontSize: 11)),
                    ]),
                  ]),
                  const SizedBox(height: 22),

                  // ══════════════════════════════════════════════
                  // SECTION 1 — COIN TIME
                  // ══════════════════════════════════════════════
                  _sectionHeader(Icons.monetization_on_rounded, AppColors.warn, "Coin Time Settings"),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: tmp.keys.toList().asMap().entries.map((entry) {
                        final idx  = entry.key;
                        final coin = entry.value;
                        final isLast = idx == tmp.length - 1;
                        return Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              // Coin badge
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.warn.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.warn.withOpacity(0.35)),
                                ),
                                child: Center(child: Text("₱$coin",
                                  style: const TextStyle(color: AppColors.warn, fontWeight: FontWeight.w800, fontSize: 12))),
                              ),
                              const SizedBox(width: 12),
                              // Time input
                              Expanded(child: TextField(
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.textPrim, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: tmp[coin]["time"].toString(),
                                  hintStyle: const TextStyle(color: AppColors.textSub),
                                  suffixText: "min",
                                  suffixStyle: const TextStyle(color: AppColors.textSub, fontSize: 12),
                                  filled: true,
                                  fillColor: AppColors.card,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.warn)),
                                ),
                                onChanged: (v) {
                                  tmp[coin]["time"]    = int.tryParse(v) ?? tmp[coin]["time"];
                                  tmp[coin]["enabled"] = true;
                                },
                              )),
                            ]),
                          ),
                          if (!isLast) const Divider(color: AppColors.divider, height: 1, indent: 14, endIndent: 14),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Save coin settings button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warn.withOpacity(0.15),
                        foregroundColor: AppColors.warn,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.warn.withOpacity(0.4)),
                        ),
                      ),
                      onPressed: saveCoinSettings,
                      icon: const Icon(Icons.save_rounded, size: 17),
                      label: const Text("Save Coin Settings", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════════
                  // SECTION 2 — WIFI CHANGE
                  // ══════════════════════════════════════════════
                  _sectionHeader(Icons.wifi_rounded, AppColors.accent, "Machine WiFi Network"),
                  const SizedBox(height: 12),

                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                    ),
                    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 15),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        "The machine will save the new credentials and reboot. Both master and slave ESP32 will reconnect automatically.",
                        style: TextStyle(color: AppColors.textSub, fontSize: 11, height: 1.5),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // SSID field
                  TextField(
                    controller: ssidCtrl,
                    style: const TextStyle(color: AppColors.textPrim, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "New WiFi Name (SSID)",
                      labelStyle: const TextStyle(color: AppColors.textSub, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surface,
                      prefixIcon: const Icon(Icons.wifi_rounded, color: AppColors.textSub, size: 18),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Password field with show/hide toggle
                  TextField(
                    controller: passCtrl,
                    obscureText: !passVisible,
                    style: const TextStyle(color: AppColors.textPrim, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "New WiFi Password",
                      labelStyle: const TextStyle(color: AppColors.textSub, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surface,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSub, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(passVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: AppColors.textSub, size: 18),
                        onPressed: () => setDlg(() => passVisible = !passVisible),
                      ),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Send WiFi change button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent.withOpacity(0.15),
                        foregroundColor: AppColors.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.accent.withOpacity(0.4)),
                        ),
                      ),
                      onPressed: isSending ? null : sendWifiChange,
                      icon: isSending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                        : const Icon(Icons.send_rounded, size: 17),
                      label: Text(isSending ? "Sending…" : "Send WiFi to Machine",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Close ────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Close", style: TextStyle(color: AppColors.textSub, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Small section header row
  Widget _sectionHeader(IconData icon, Color color, String label) => Row(children: [
    Icon(icon, color: color, size: 16),
    const SizedBox(width: 6),
    Text(label.toUpperCase(),
      style: TextStyle(color: color, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
  ]);
}

// ─────────────────────────────────────────
// LOGS SCREEN
// ─────────────────────────────────────────
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logRef = FirebaseDatabase.instance.ref("logs");

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSub),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Daily Earnings", style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
      ),
      body: Container(
        decoration: _bgDecor,
        child: StreamBuilder(
          stream: logRef.onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> snap) {
            if (!snap.hasData || snap.data!.snapshot.value == null) {
              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _glowIcon(Icons.receipt_long_rounded, AppColors.textSub),
                  const SizedBox(height: 12),
                  const Text("No logs available.", style: TextStyle(color: AppColors.textSub)),
                ]),
              );
            }

            final logs  = snap.data!.snapshot.value as Map<dynamic, dynamic>;
            final dates = logs.keys.toList()..sort((a, b) => b.compareTo(a));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                ...dates.map((date) {
                  final entry   = logs[date] as Map<dynamic, dynamic>;
                  final charge  = double.tryParse(entry['charging']?.toString() ?? '0') ?? 0.0;
                  final wifi    = double.tryParse(entry['wifi']?.toString() ?? '0') ?? 0.0;
                  final total   = charge + wifi;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          const Icon(Icons.calendar_today_rounded, color: AppColors.textSub, size: 14),
                          const SizedBox(width: 6),
                          Text(date.toString(), style: const TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.accentAlt.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text("₱ ${total.toStringAsFixed(2)}",
                            style: const TextStyle(color: AppColors.accentAlt, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.divider, height: 1),
                      const SizedBox(height: 10),
                      Row(children: [
                        _logChip("Charging", charge, AppColors.accent),
                        const SizedBox(width: 8),
                        _logChip("WiFi", wifi, AppColors.warn),
                      ]),
                    ]),
                  );
                }),

                // Clear Logs button
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger.withOpacity(0.15),
                        foregroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.danger.withOpacity(0.4))),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 20),
                      label: const Text("Clear All Logs", style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () => _confirmClear(context, logRef),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _logChip(String label, double val, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text("₱ ${val.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.bold)),
      ]),
    ),
  );

  void _confirmClear(BuildContext ctx, DatabaseReference logRef) {
    showDialog(
      context: ctx,
      builder: (dlg) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
          SizedBox(width: 8),
          Text("Clear All Logs?", style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          "Are you sure you want to delete all daily logs? This cannot be undone.",
          style: TextStyle(color: AppColors.textSub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlg), child: const Text("Cancel", style: TextStyle(color: AppColors.textSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { logRef.remove(); Navigator.pop(dlg); },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}