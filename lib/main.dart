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
// THEME SYSTEM
// ─────────────────────────────────────────
final _themeNotifier = ValueNotifier<int>(0);

const _tNames   = ['Ocean',           'Violet',          'Teal',             'Rose',             'Amber'           ];
const _tAccents = [Color(0xFF58A6FF), Color(0xFFBC8CFF), Color(0xFF39D5C5),  Color(0xFFFF6B8A),  Color(0xFFE5A836) ];
const _tAlts    = [Color(0xFF3FB950), Color(0xFF5CC8FF), Color(0xFF7BC67E),  Color(0xFFFF9F7F),  Color(0xFF52C97F) ];

Color get _ac  => _tAccents[_themeNotifier.value];
Color get _alt => _tAlts[_themeNotifier.value];

// ─────────────────────────────────────────
// FIXED COLORS
// ─────────────────────────────────────────
class AppColors {
  static const bg       = Color(0xFF0D1117);
  static const surface  = Color(0xFF161B22);
  static const card     = Color(0xFF1C2333);
  static const warn     = Color(0xFFD29922);
  static const danger   = Color(0xFFF85149);
  static const textPrim = Color(0xFFE6EDF3);
  static const textSub  = Color(0xFF8B949E);
  static const divider  = Color(0xFF30363D);
}

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
  _themeNotifier.value = prefs.getInt('themeIndex') ?? 0;
  runApp(const ChargingStationAdmin());
}

class ChargingStationAdmin extends StatelessWidget {
  const ChargingStationAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _themeNotifier,
      builder: (_, __, ___) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Station Admin',
        theme: ThemeData(
          colorScheme: ColorScheme.dark(primary: _ac, surface: AppColors.surface),
          scaffoldBackgroundColor: AppColors.bg,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const OnboardingScreen(),
      ),
    );
  }
}

// ─────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────
Widget _glowIcon(IconData icon, Color color, {double size = 60}) => Container(
  width: size + 20, height: size + 20,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: color.withValues(alpha: 0.08),
    border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2)],
  ),
  child: Icon(icon, size: size, color: color),
);

Widget _primaryBtn({
  required String label,
  required VoidCallback? onTap,
  Color? color,
  IconData? icon,
}) {
  final c = color ?? _ac;
  final int boostedBlue = (c.b * 255.0).round().clamp(0, 255);
  final Color lighter = c.withBlue(boostedBlue < 215 ? boostedBlue + 40 : 255);
  return SizedBox(
    width: double.infinity, height: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, lighter]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ),
    ),
  );
}

Widget _ghostBtn({
  required String label,
  required VoidCallback? onTap,
  Color? color,
  IconData? icon,
}) {
  final c = color ?? AppColors.textSub;
  return SizedBox(
    width: double.infinity, height: 44,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    ),
  );
}

Widget _stepDots(int current, int total) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: List.generate(total, (i) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.symmetric(horizontal: 4),
    width: i == current ? 24 : 8, height: 8,
    decoration: BoxDecoration(
      color: i == current ? _ac : AppColors.divider,
      borderRadius: BorderRadius.circular(4),
    ),
  )),
);

Widget _label(String text) => Text(
  text.toUpperCase(),
  style: const TextStyle(
    fontSize: 11, letterSpacing: 1.5,
    color: AppColors.textSub, fontWeight: FontWeight.w600,
  ),
);

Widget _sectionHeader(IconData icon, Color color, String label) => Row(children: [
  Icon(icon, color: color, size: 16),
  const SizedBox(width: 6),
  Text(label.toUpperCase(),
      style: TextStyle(color: color, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
]);

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
  List<String> _scannedSSIDs = [];
  String?      _selectedSSID;
  bool         _isConnecting   = false;
  bool         _isScanningWifi = false;
  String?      _qrResult;
  final _camCtrl = MobileScannerController();

  void _goNext() {
    setState(() => _pageIndex++);
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _connectToMachine() async {
    setState(() => _isConnecting = true);
    try {
      final ok = await WiFiForIoTPlugin.connect(
        'ESP32_VENDO',
        password: '12345678',
        security: NetworkSecurity.WPA,
        joinOnce: true,
        withInternet: false,
      );
      if (!mounted) return;
      if (ok) {
        await WiFiForIoTPlugin.forceWifiUsage(true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Connected! Scanning for nearby WiFi…'),
          backgroundColor: _alt,
        ));
        await _scanNearbyWiFi();
        _goNext();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not connect. Is the machine turned on?'),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (e) {
      debugPrint('WiFi error: $e');
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _scanNearbyWiFi() async {
    setState(() => _isScanningWifi = true);
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        final canScan = await WiFiScan.instance.canStartScan();
        if (canScan == CanStartScan.yes) {
          await WiFiScan.instance.startScan();
          await Future.delayed(const Duration(seconds: 2));
          final results = await WiFiScan.instance.getScannedResults();
          final unique = results
              .map((n) => n.ssid)
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          if (mounted) {
            setState(() {
              _scannedSSIDs = unique;
              if (unique.isNotEmpty) _selectedSSID = unique.first;
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission required to scan WiFi.'),
            backgroundColor: AppColors.warn,
          ));
        }
      }
    } catch (e) {
      debugPrint('Scan error: $e');
    } finally {
      if (mounted) {
        setState(() => _isScanningWifi = false);
      }
    }
  }

  Future<void> _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _bgDecor,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _ac.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.bolt, color: _ac, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text('VendoSetup',
                      style: TextStyle(
                        color: AppColors.textPrim,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      )),
                ]),
                _stepDots(_pageIndex, 3),
              ]),
            ),
            const Divider(color: AppColors.divider, height: 24),
            Expanded(child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: [_page1(), _page2(), _page3()],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _page1() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      _glowIcon(Icons.wifi_tethering_rounded, _ac, size: 64),
      const SizedBox(height: 24),
      _label('Step 1 of 3'),
      const SizedBox(height: 8),
      const Text('Link to Machine',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrim)),
      const SizedBox(height: 12),
      const Text('Keep your phone near the Vendo Machine.\nWe will connect to it automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, height: 1.5)),
      const SizedBox(height: 36),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _ac.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.router_rounded, color: _ac, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ESP32_VENDO',
                style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w600)),
            Text('WPA2 · Auto connect',
                style: TextStyle(color: AppColors.textSub, fontSize: 12)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _alt.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('READY',
                style: TextStyle(color: _alt, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      const SizedBox(height: 32),
      _isConnecting
          ? Column(children: [
              CircularProgressIndicator(color: _ac),
              const SizedBox(height: 10),
              const Text('Connecting…', style: TextStyle(color: AppColors.textSub)),
            ])
          : _primaryBtn(
              label: 'Connect to Machine',
              onTap: _connectToMachine,
              icon: Icons.wifi_rounded,
            ),
      const SizedBox(height: 12),
      _primaryBtn(
        label: 'Add QR Code (Temp)',
        color: AppColors.warn,
        icon: Icons.qr_code_2_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddQrPage()),
        ),
      ),
      const SizedBox(height: 12),
      _ghostBtn(
        label: 'Skip to Next Page (Temp)',
        onTap: _goNext,
        icon: Icons.skip_next_rounded,
      ),
    ]),
  );

  Widget _page2() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: _glowIcon(Icons.hub_rounded, AppColors.warn, size: 64)),
      const SizedBox(height: 24),
      Center(child: _label('Step 2 of 3')),
      const SizedBox(height: 8),
      const Center(child: Text('Internet Setup',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrim))),
      const SizedBox(height: 10),
      const Center(child: Text(
          'Select your home WiFi so the machine\ncan connect to the cloud.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, height: 1.5))),
      const SizedBox(height: 28),
      _label('Available Networks'),
      const SizedBox(height: 8),
      if (_isScanningWifi)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _ac),
            ),
            const SizedBox(width: 12),
            const Text('Scanning for networks…', style: TextStyle(color: AppColors.textSub)),
          ]))
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
              value: _selectedSSID, isExpanded: true, dropdownColor: AppColors.card,
              icon: const Icon(Icons.expand_more, color: AppColors.textSub),
              items: _scannedSSIDs.map((s) => DropdownMenuItem(
                value: s,
                child: Row(children: [
                  Icon(Icons.wifi_rounded, color: _ac, size: 18),
                  const SizedBox(width: 8),
                  Text(s, style: const TextStyle(color: AppColors.textPrim)),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _selectedSSID = v),
            ),
          ))
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          child: Column(children: [
            const Row(children: [
              Icon(Icons.signal_wifi_off, color: AppColors.danger, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('No networks found. Enable Location and retry.',
                  style: TextStyle(color: AppColors.textSub, fontSize: 13))),
            ]),
            const SizedBox(height: 12),
            _ghostBtn(
              label: 'Rescan Networks',
              onTap: _scanNearbyWiFi,
              icon: Icons.refresh_rounded,
              color: _ac,
            ),
          ]),
        ),
      const SizedBox(height: 16),
      _label('WiFi Password'),
      const SizedBox(height: 8),
      TextField(
        controller: _passCtrl, obscureText: true,
        style: const TextStyle(color: AppColors.textPrim),
        decoration: InputDecoration(
          hintText: 'Enter password',
          hintStyle: const TextStyle(color: AppColors.textSub),
          filled: true, fillColor: AppColors.card,
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSub),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _ac),
          ),
        ),
      ),
      const SizedBox(height: 28),
      _primaryBtn(
        label: 'Send to Machine',
        icon: Icons.send_rounded,
        color: AppColors.warn,
        onTap: () async {
          if (_selectedSSID == null || _passCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please select a WiFi and enter the password.'),
              backgroundColor: AppColors.warn,
            ));
            return;
          }
          try {
            final res = await http.post(
              Uri.parse('http://192.168.4.1/setup'),
              body: {'ssid': _selectedSSID, 'pass': _passCtrl.text},
            ).timeout(const Duration(seconds: 7));
            if (!mounted) return;
            if (res.statusCode == 200) {
              await WiFiForIoTPlugin.forceWifiUsage(false);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Credentials sent! Machine is rebooting.'),
                backgroundColor: _alt,
              ));
              _goNext();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Machine rejected the data.'),
                backgroundColor: AppColors.danger,
              ));
            }
          } catch (e) {
            await WiFiForIoTPlugin.forceWifiUsage(false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 10),
            ));
          }
        },
      ),
      const SizedBox(height: 12),
      _ghostBtn(
        label: 'Skip to Next Page (Temp)',
        onTap: _goNext,
        icon: Icons.skip_next_rounded,
      ),
    ]),
  );

  Widget _page3() => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(children: [
        _glowIcon(Icons.qr_code_scanner_rounded, _alt, size: 56),
        const SizedBox(height: 16),
        _label('Step 3 of 3'),
        const SizedBox(height: 6),
        const Text('Link Machine',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrim)),
        const SizedBox(height: 8),
        const Text('Scan the QR code on your Vendo Machine to link it to your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSub, height: 1.5)),
        const SizedBox(height: 16),
      ]),
    ),
    Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          MobileScanner(controller: _camCtrl, onDetect: (capture) async {
            if (capture.barcodes.isNotEmpty) {
              final code = capture.barcodes.first.rawValue;
              if (code != null && code != _qrResult) {
                setState(() => _qrResult = code);
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Scanned: $code')));
                try {
                  final ref   = FirebaseDatabase.instance.ref('qr_codes');
                  final event = await ref.orderByChild('code').equalTo(code).once();
                  if (!mounted) return;
                  if (event.snapshot.value != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Unsuccessful login: QR not recognized'),
                      backgroundColor: AppColors.danger,
                    ));
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error checking QR: $e'),
                    backgroundColor: AppColors.danger,
                  ));
                }
              }
            }
          }),
          Positioned.fill(child: ScanOverlay(_alt)),
        ]),
      ),
    )),
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(children: [
        _primaryBtn(
          label: 'Simulate QR Scan & Finish',
          color: _alt,
          icon: Icons.check_circle_outline_rounded,
          onTap: _finishSetup,
        ),
        const SizedBox(height: 10),
        _ghostBtn(
          label: 'Skip to Dashboard (Temp)',
          icon: Icons.skip_next_rounded,
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          ),
        ),
      ]),
    ),
  ]);
}

// ─────────────────────────────────────────
// SCAN OVERLAY
// ─────────────────────────────────────────
class ScanOverlay extends StatefulWidget {
  final Color color;
  const ScanOverlay(this.color, {super.key});
  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _line;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _line = Tween<double>(begin: 0.05, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _line,
    builder: (_, __) => CustomPaint(
      painter: _ScanOverlayPainter(widget.color, _line.value),
    ),
  );
}

class _ScanOverlayPainter extends CustomPainter {
  final Color  color;
  final double scanProgress;
  const _ScanOverlayPainter(this.color, this.scanProgress);

  @override
  void paint(Canvas canvas, Size size) {
    const margin    = 40.0;
    const cornerLen = 28.0;
    const cornerR   = 6.0;
    const strokeW   = 3.0;

    final winRect = Rect.fromLTRB(
      margin, margin, size.width - margin, size.height - margin,
    );

    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(winRect, const Radius.circular(12)));
    canvas.drawPath(
      overlayPath..fillType = PathFillType.evenOdd,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(winRect, const Radius.circular(12)),
      Paint()
        ..color       = color.withValues(alpha: 0.25)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final cp = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap   = StrokeCap.round;

    final tl = winRect.topLeft;
    final tr = winRect.topRight;
    final bl = winRect.bottomLeft;
    final br = winRect.bottomRight;

    void drawCorner(Offset pivot, Offset dx, Offset dy) {
      canvas.drawLine(pivot + dy, pivot, cp);
      canvas.drawLine(pivot, pivot + dx, cp);
    }

    drawCorner(tl, const Offset(cornerLen, 0),  const Offset(0, cornerLen));
    drawCorner(tr, const Offset(-cornerLen, 0), const Offset(0, cornerLen));
    drawCorner(bl, const Offset(cornerLen, 0),  const Offset(0, -cornerLen));
    drawCorner(br, const Offset(-cornerLen, 0), const Offset(0, -cornerLen));

    for (final pt in [tl, tr, bl, br]) {
      canvas.drawCircle(pt, cornerR,
          Paint()..color = color.withValues(alpha: 0.9)..style = PaintingStyle.fill);
      canvas.drawCircle(pt, cornerR + 3,
          Paint()..color = color.withValues(alpha: 0.25)..style = PaintingStyle.fill);
    }

    final lineY     = winRect.top + winRect.height * scanProgress;
    final lineShader = LinearGradient(colors: [
      color.withValues(alpha: 0.0),
      color.withValues(alpha: 0.9),
      color.withValues(alpha: 0.0),
    ]).createShader(Rect.fromLTRB(winRect.left, lineY, winRect.right, lineY));

    canvas.drawLine(
      Offset(winRect.left + 8, lineY),
      Offset(winRect.right - 8, lineY),
      Paint()
        ..shader      = lineShader
        ..strokeWidth = 2.0
        ..style       = PaintingStyle.stroke,
    );

    final glowShader = LinearGradient(colors: [
      color.withValues(alpha: 0.0),
      color.withValues(alpha: 0.18),
      color.withValues(alpha: 0.0),
    ]).createShader(Rect.fromLTRB(winRect.left, lineY, winRect.right, lineY));

    canvas.drawLine(
      Offset(winRect.left + 8, lineY + 3),
      Offset(winRect.right - 8, lineY + 3),
      Paint()
        ..shader      = glowShader
        ..strokeWidth = 6.0
        ..style       = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => old.scanProgress != scanProgress;
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

  Future<void> _handleScan(String raw) async {
    final key       = encrypt.Key.fromBase64(raw.replaceAll('-', '+').replaceAll('_', '/'));
    final encrypter = encrypt.Encrypter(encrypt.Fernet(key));
    try {
      final data = jsonDecode(encrypter.decrypt64(raw)) as Map<String, dynamic>;
      await _qrRef.push().set({
        'code': raw, 'decrypted': data, 'timestamp': ServerValue.timestamp,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('QR code decrypted and saved'),
        backgroundColor: _alt,
      ));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Security Alert: Invalid or fake QR Code scanned!'),
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
        backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent,
        title: const Text('Add QR Code',
            style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
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
                color: AppColors.warn.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warn.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warn, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Scan the encrypted QR code on the machine.',
                    style: TextStyle(color: AppColors.warn, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(children: [
                MobileScanner(controller: _ctrl, onDetect: (capture) {
                  if (_isProcessing) return;
                  if (capture.barcodes.isNotEmpty) {
                    final code = capture.barcodes.first.rawValue;
                    if (code != null) {
                      setState(() => _isProcessing = true);
                      _handleScan(code);
                    }
                  }
                }),
                Positioned.fill(child: ScanOverlay(_alt)),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: Center(child: CircularProgressIndicator(color: _alt)),
                  ),
              ]),
            )),
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
    '1':  {'enabled': true, 'time': 5},
    '5':  {'enabled': true, 'time': 15},
    '10': {'enabled': true, 'time': 30},
    '20': {'enabled': true, 'time': 60},
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
            decoration: BoxDecoration(
              color: _ac.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.bolt, color: _ac, size: 18),
          ),
          const SizedBox(width: 8),
          const Text('Station Dashboard',
              style: TextStyle(
                color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 17,
              )),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
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
            return Center(child: CircularProgressIndicator(color: _ac));
          }
          if (!snap.hasData || snap.data?.snapshot.value == null) {
            return _emptyState();
          }

          final raw = snap.data!.snapshot.value as Map<dynamic, dynamic>;
          if (raw['settings']?['coins'] != null) {
            currentSettings = Map<String, dynamic>.from(raw['settings']['coins']);
          }

          final earn   = raw['total_earnings'] as Map<dynamic, dynamic>? ?? {};
          final charge = double.tryParse(earn['charging']?.toString() ?? '0') ?? 0.0;
          final wifi   = double.tryParse(earn['wifi']?.toString() ?? '0') ?? 0.0;
          final total  = charge + wifi;

          final wifiUsers   = (raw['status']?['wifi_users']   as num?)?.toInt() ?? 0;
          final activePorts = (raw['status']?['active_ports'] as num?)?.toInt() ?? 0;

          return Container(
            decoration: _bgDecor,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              _heroCard(total),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _miniCard('Charging', charge, _ac, Icons.electrical_services_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _miniCard('WiFi Vending', wifi, AppColors.warn, Icons.wifi_rounded)),
              ]),
              const SizedBox(height: 24),
              _label('Live Station Status'),
              const SizedBox(height: 10),
              _liveStatsRow(wifiUsers, activePorts),
              const SizedBox(height: 24),
              _primaryBtn(
                label: 'View Daily Logs',
                icon: Icons.bar_chart_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogsScreen()),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    _glowIcon(Icons.cloud_off_rounded, AppColors.textSub),
    const SizedBox(height: 16),
    const Text('Waiting for ESP32 data…', style: TextStyle(color: AppColors.textSub)),
  ]));

  Widget _heroCard(double total) => Container(
    width: double.infinity, padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_alt.withValues(alpha: 0.85), _alt.withValues(alpha: 0.3)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: _alt.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
        SizedBox(width: 6),
        Text('TOTAL COLLECTED',
            style: TextStyle(
              color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600,
            )),
      ]),
      const SizedBox(height: 12),
      Text('₱ ${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5,
          )),
      const SizedBox(height: 4),
      const Text('All-time revenue', style: TextStyle(color: Colors.white60, fontSize: 13)),
    ]),
  );

  Widget _miniCard(String label, double val, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 10),
      Text('₱ ${val.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrim,
          )),
    ]),
  );

  Widget _liveStatsRow(int wifiUsers, int activePorts) => Row(children: [
    Expanded(child: _statBox(
      icon: Icons.people_alt_rounded, color: _ac,
      label: 'WiFi Users', value: '$wifiUsers', sub: 'Connected',
    )),
    const SizedBox(width: 12),
    Expanded(child: _statBox(
      icon: Icons.bolt_rounded, color: _alt,
      label: 'Active Ports', value: '$activePorts / 4', sub: 'Charging',
    )),
  ]);

  Widget _statBox({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String sub,
  }) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          colors: [AppColors.card, color.withValues(alpha: 0.06)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text(value,
            style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrim, height: 1,
            )),
        const SizedBox(height: 4),
        Text(sub,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
      ]),
    );

  // ─────────────────────────────────────────
  // RECONNECT FLOW
  // ─────────────────────────────────────────

  Future<void> _initiateReconnectFlow() async {
    try {
      await _db.child('commands/ap_mode').set({
        'pending': true,
        'duration_seconds': 180,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not reach Firebase: $e'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _ac),
            const SizedBox(height: 20),
            const Text(
              'Activating machine hotspot…',
              style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w600, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Connecting your phone to ESP32_VENDO. Please wait.',
              style: TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));

    bool connected = false;
    try {
      connected = await WiFiForIoTPlugin.connect(
        'ESP32_VENDO',
        password: '12345678',
        security: NetworkSecurity.WPA,
        joinOnce: true,
        withInternet: false,
      );
      if (connected) await WiFiForIoTPlugin.forceWifiUsage(true);
    } catch (e) {
      debugPrint('WiFi connect error: $e');
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not connect to ESP32_VENDO. Is the machine powered on?'),
        backgroundColor: AppColors.danger,
        duration: Duration(seconds: 5),
      ));
      return;
    }

    final ssids = await _scanNetworksForReconnect();
    if (!mounted) return;
    _showReconnectWifiDialog(ssids);
  }

  Future<List<String>> _scanNetworksForReconnect() async {
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) return [];
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) return [];
      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 2));
      final results = await WiFiScan.instance.getScannedResults();
      return results
          .map((n) => n.ssid)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      debugPrint('Scan error: $e');
      return [];
    }
  }

  void _showReconnectWifiDialog(List<String> initialSsids) {
    String? selectedSsid = initialSsids.isNotEmpty ? initialSsids.first : null;
    List<String> ssids   = List.from(initialSsids);
    final passCtrl       = TextEditingController();
    bool passVisible     = false;
    bool isScanning      = false;
    bool sending         = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warn.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hub_rounded, color: AppColors.warn, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Update Machine WiFi',
                      style: TextStyle(
                        color: AppColors.textPrim, fontSize: 16, fontWeight: FontWeight.w800,
                      )),
                  Text('Send new credentials to ESP32',
                      style: TextStyle(color: AppColors.textSub, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 10),

              // 3-min timer notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warn.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.timer_outlined, color: AppColors.warn, size: 14),
                  SizedBox(width: 6),
                  Expanded(child: Text(
                    'Machine hotspot active for 3 minutes. Complete setup quickly.',
                    style: TextStyle(color: AppColors.warn, fontSize: 11, height: 1.4),
                  )),
                ]),
              ),
              const SizedBox(height: 18),

              // Network picker
              _label('Select Home WiFi'),
              const SizedBox(height: 8),
              if (isScanning)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _ac),
                    ),
                    const SizedBox(width: 10),
                    const Text('Scanning…', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
                  ]))
              else if (ssids.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ac.withValues(alpha: 0.4)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSsid, isExpanded: true, dropdownColor: AppColors.card,
                      icon: const Icon(Icons.expand_more, color: AppColors.textSub),
                      items: ssids.map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(children: [
                          Icon(Icons.wifi_rounded, color: _ac, size: 16),
                          const SizedBox(width: 8),
                          Text(s, style: const TextStyle(color: AppColors.textPrim, fontSize: 13)),
                        ]),
                      )).toList(),
                      onChanged: (v) => setDlg(() => selectedSsid = v),
                    ),
                  ))
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.signal_wifi_off, color: AppColors.danger, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('No networks found. Try rescanning.',
                        style: TextStyle(color: AppColors.textSub, fontSize: 12))),
                  ]),
                ),

              if (!isScanning) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      setDlg(() => isScanning = true);
                      final fresh = await _scanNetworksForReconnect();
                      setDlg(() {
                        ssids = fresh;
                        if (fresh.isNotEmpty) selectedSsid = fresh.first;
                        isScanning = false;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Rescan', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSub, padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Password field
              _label('WiFi Password'),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl, obscureText: !passVisible,
                style: const TextStyle(color: AppColors.textPrim, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  hintStyle: const TextStyle(color: AppColors.textSub),
                  filled: true, fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSub, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      passVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppColors.textSub, size: 18,
                    ),
                    onPressed: () => setDlg(() => passVisible = !passVisible),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _ac),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Send button
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warn.withValues(alpha: 0.15),
                    foregroundColor: AppColors.warn, elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.warn.withValues(alpha: 0.4)),
                    ),
                  ),
                  onPressed: sending ? null : () async {
                    if (selectedSsid == null || passCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Please select a network and enter the password.'),
                        backgroundColor: AppColors.warn,
                      ));
                      return;
                    }
                    setDlg(() => sending = true);
                    try {
                      final res = await http.post(
                        Uri.parse('http://192.168.4.1/setup'),
                        body: {'ssid': selectedSsid, 'pass': passCtrl.text},
                      ).timeout(const Duration(seconds: 7));

                      await WiFiForIoTPlugin.forceWifiUsage(false);
                      await WiFiForIoTPlugin.disconnect();

                      if (!ctx.mounted) return;
                      if (res.statusCode == 200) {
                        Navigator.pop(ctx);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('✓ New WiFi sent! Machine is rebooting.'),
                          backgroundColor: _alt,
                          duration: const Duration(seconds: 4),
                        ));
                      } else {
                        setDlg(() => sending = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Machine rejected the request.'),
                          backgroundColor: AppColors.danger,
                        ));
                      }
                    } catch (e) {
                      await WiFiForIoTPlugin.forceWifiUsage(false);
                      await WiFiForIoTPlugin.disconnect();
                      if (!ctx.mounted) return;
                      setDlg(() => sending = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: AppColors.danger,
                        duration: const Duration(seconds: 8),
                      ));
                    }
                  },
                  icon: sending
                      ? SizedBox(
                          width: 15, height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warn),
                        )
                      : const Icon(Icons.send_rounded, size: 17),
                  label: Text(
                    sending ? 'Sending…' : 'Send to Machine',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Cancel
              SizedBox(
                width: double.infinity, height: 40,
                child: TextButton(
                  onPressed: () async {
                    await WiFiForIoTPlugin.forceWifiUsage(false);
                    await WiFiForIoTPlugin.disconnect();
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textSub, fontSize: 13)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // SETTINGS DIALOG
  // ─────────────────────────────────────────
  void _showSettingsDialog() {
    final tmp = <String, Map<String, Object>>{
      for (final k in ['1', '5', '10', '20'])
        k: {
          'enabled': (currentSettings[k]?['enabled'] as bool?)  ?? true,
          'time':    (currentSettings[k]?['time']    as int?)    ?? 0,
        }
    };

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _ac.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.settings_rounded, color: _ac, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Machine Settings',
                      style: TextStyle(
                        color: AppColors.textPrim, fontSize: 16, fontWeight: FontWeight.w800,
                      )),
                  Text('ESP32 Vendo Configuration',
                      style: TextStyle(color: AppColors.textSub, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 22),

              // ── SECTION 1: COIN TIME ──────────────
              _sectionHeader(Icons.monetization_on_rounded, AppColors.warn, 'Coin Time Settings'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(children: tmp.keys.toList().asMap().entries.map((e) {
                  final coin   = e.value;
                  final isLast = e.key == tmp.length - 1;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.warn.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.warn.withValues(alpha: 0.35)),
                          ),
                          child: Center(child: Text('₱$coin',
                              style: const TextStyle(
                                color: AppColors.warn, fontWeight: FontWeight.w800, fontSize: 12,
                              ))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrim, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: tmp[coin]!['time'].toString(),
                            hintStyle: const TextStyle(color: AppColors.textSub),
                            suffixText: 'min',
                            suffixStyle: const TextStyle(color: AppColors.textSub, fontSize: 12),
                            filled: true, fillColor: AppColors.card, isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.warn),
                            ),
                          ),
                          onChanged: (v) {
                            tmp[coin]!['time']    = int.tryParse(v) ?? tmp[coin]!['time']!;
                            tmp[coin]!['enabled'] = true;
                          },
                        )),
                      ]),
                    ),
                    if (!isLast)
                      const Divider(color: AppColors.divider, height: 1, indent: 14, endIndent: 14),
                  ]);
                }).toList()),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warn.withValues(alpha: 0.15),
                    foregroundColor: AppColors.warn, elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.warn.withValues(alpha: 0.4)),
                    ),
                  ),
                  onPressed: () {
                    final updates = <String, Object>{};
                    tmp.forEach((c, d) {
                      updates['$c/time']    = d['time']!;
                      updates['$c/enabled'] = d['enabled']!;
                    });
                    _db.child('settings/coins').update(updates).then((_) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: const Text('✓ Coin settings saved.'),
                        backgroundColor: _alt,
                      ));
                    });
                  },
                  icon: const Icon(Icons.save_rounded, size: 17),
                  label: const Text('Save Coin Settings',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 22),

              // ── SECTION 2: MACHINE WIFI ───────────
              _sectionHeader(Icons.wifi_rounded, _ac, 'Machine WiFi Network'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _ac.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _ac.withValues(alpha: 0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, color: _ac, size: 15),
                  const SizedBox(width: 8),
                  const Expanded(child: Text(
                    'This will briefly activate the machine\'s hotspot so you can send new WiFi credentials remotely.',
                    style: TextStyle(color: AppColors.textSub, fontSize: 11, height: 1.5),
                  )),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ac.withValues(alpha: 0.15),
                    foregroundColor: _ac, elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _ac.withValues(alpha: 0.4)),
                    ),
                  ),
                  icon: const Icon(Icons.wifi_tethering_rounded, size: 17),
                  label: const Text('Reconnect to Machine',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _initiateReconnectFlow();
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textSub.withValues(alpha: 0.08),
                    foregroundColor: AppColors.textSub, elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.textSub.withValues(alpha: 0.25)),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_rounded, size: 17),
                  label: const Text('Show Current WiFi on Machine',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: () async {
                    try {
                      await _db.child('commands/wifi_show').set({'pending': true});
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: const Text(
                            '✓ Credentials will appear on the machine screen shortly.'),
                        backgroundColor: _alt,
                        duration: const Duration(seconds: 3),
                      ));
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: AppColors.danger,
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(height: 22),

              // ── SECTION 3: APP THEME ──────────────
              _sectionHeader(Icons.palette_rounded, AppColors.warn, 'App Theme'),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_tNames.length, (i) {
                  final selected = _themeNotifier.value == i;
                  return GestureDetector(
                    onTap: () async {
                      _themeNotifier.value = i;
                      setDlg(() {});
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('themeIndex', i);
                    },
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: selected ? 46 : 36, height: selected ? 46 : 36,
                        decoration: BoxDecoration(
                          color: _tAccents[i], shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: selected
                              ? [BoxShadow(
                                  color: _tAccents[i].withValues(alpha: 0.55),
                                  blurRadius: 14,
                                )]
                              : [],
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(_tNames[i], style: TextStyle(
                        color: selected ? _tAccents[i] : AppColors.textSub,
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      )),
                    ]),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close',
                      style: TextStyle(color: AppColors.textSub, fontSize: 13)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// LOGS SCREEN
// ─────────────────────────────────────────
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logRef = FirebaseDatabase.instance.ref('logs');
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSub),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Daily Earnings',
            style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
      ),
      body: Container(
        decoration: _bgDecor,
        child: StreamBuilder(
          stream: logRef.onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> snap) {
            if (!snap.hasData || snap.data!.snapshot.value == null) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _glowIcon(Icons.receipt_long_rounded, AppColors.textSub),
                const SizedBox(height: 12),
                const Text('No logs available.', style: TextStyle(color: AppColors.textSub)),
              ]));
            }

            final logs  = snap.data!.snapshot.value as Map<dynamic, dynamic>;
            final dates = logs.keys.toList()..sort((a, b) => b.compareTo(a));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                ...dates.map((date) {
                  final entry  = logs[date] as Map<dynamic, dynamic>;
                  final charge = double.tryParse(entry['charging']?.toString() ?? '0') ?? 0.0;
                  final wifi   = double.tryParse(entry['wifi']?.toString() ?? '0') ?? 0.0;
                  final total  = charge + wifi;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          const Icon(Icons.calendar_today_rounded, color: AppColors.textSub, size: 14),
                          const SizedBox(width: 6),
                          Text(date.toString(),
                              style: const TextStyle(
                                color: AppColors.textPrim, fontWeight: FontWeight.w700,
                              )),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _alt.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('₱ ${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: _alt, fontWeight: FontWeight.bold, fontSize: 13,
                              )),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.divider, height: 1),
                      const SizedBox(height: 10),
                      Row(children: [
                        _logChip('Charging', charge, _ac),
                        const SizedBox(width: 8),
                        _logChip('WiFi', wifi, AppColors.warn),
                      ]),
                    ]),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                        foregroundColor: AppColors.danger, elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                        ),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 20),
                      label: const Text('Clear All Logs',
                          style: TextStyle(fontWeight: FontWeight.w600)),
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
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('₱ ${val.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.bold)),
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
          Text('Clear All Logs?',
              style: TextStyle(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Are you sure you want to delete all daily logs? This cannot be undone.',
          style: TextStyle(color: AppColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              logRef.remove();
              Navigator.pop(dlg);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}