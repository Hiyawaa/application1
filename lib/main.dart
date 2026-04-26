import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  
  // Check if this is the first time the app is opened
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
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      // 🔴 TEMPORARILY FORCE THE ONBOARDING SCREEN FOR TESTING
      home: const OnboardingScreen(),
      // home: isFirstTime ? const OnboardingScreen() : const DashboardScreen(),
    );
  }
}
// ==========================================
// NEW: ONBOARDING FLOW (First Time Setup)
// ==========================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _passController = TextEditingController();

  List<String> _scannedSSIDs = []; 
  String? _selectedSSID;
  bool _isConnecting = false;
  bool _isScanningWiFi = false;

  // FUNCTION 1: Auto-Connect to the ESP32 (Still uses wifi_iot)
  Future<void> _connectToMachine() async {
    setState(() { _isConnecting = true; });

    try {
      bool isConnected = await WiFiForIoTPlugin.connect(
        "ESP32_VENDO", // Ensure this matches your ESP32's AP name
        password: "12345678", 
        security: NetworkSecurity.WPA, 
        joinOnce: true, 
        withInternet: false, 
      );

      if (isConnected) {
        // 🔴 NEW: Force Android to route traffic through the Wi-Fi chip!
        await WiFiForIoTPlugin.forceWifiUsage(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Connected! Scanning for nearby WiFi..."), backgroundColor: Colors.green),
          );
        }
        
        // AUTO-SCAN trigger immediately after connecting
        await _scanNearbyWiFi();

        if (mounted) {
          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not connect. Is the machine turned on?"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("WiFi Connection Error: $e");
    } finally {
      if (mounted) {
        setState(() { _isConnecting = false; });
      }
    }
  }

  // FUNCTION 2: Scan for nearby WiFi networks (Now uses wifi_scan & permissions)
  Future<void> _scanNearbyWiFi() async {
    setState(() { _isScanningWiFi = true; });
    
    try {
      // 1. Request Location Permission (Strictly required by Android for WiFi scanning)
      var status = await Permission.location.request();
      
      if (status.isGranted) {
        // 2. Check if the device allows us to start a scan
        final canScan = await WiFiScan.instance.canStartScan();
        
        if (canScan == CanStartScan.yes) {
          // 3. Command the hardware to scan
          await WiFiScan.instance.startScan();
          
          // Give the phone hardware 2 seconds to find networks
          await Future.delayed(const Duration(seconds: 2));
          
          // 4. Fetch the results
          final results = await WiFiScan.instance.getScannedResults();
          
          // Filter out empty names and duplicates
          List<String> uniqueSSIDs = results
              .map((net) => net.ssid)
              .where((ssid) => ssid.isNotEmpty)
              .toSet()
              .toList();

          if (mounted) {
            setState(() {
              _scannedSSIDs = uniqueSSIDs;
              if (uniqueSSIDs.isNotEmpty) {
                _selectedSSID = uniqueSSIDs.first; 
              }
            });
          }
        } else {
          debugPrint("Device prevented WiFi scan. Status: $canScan");
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission is required to scan for WiFi."), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint("Scan error: $e");
    } finally {
      if (mounted) {
        setState(() { _isScanningWiFi = false; });
      }
    }
  }

  void _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Machine Setup")),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), 
        children: [
          // PAGE 1: Connect to ESP32
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_tethering, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text("Step 1: Link to Machine", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                  "Keep your phone near the Vendo Machine. We will connect to it automatically.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                _isConnecting 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        textStyle: const TextStyle(fontSize: 18)
                      ),
                      onPressed: _connectToMachine,
                      child: const Text("Connect to Machine"),
                    )
              ],
            ),
          ),

          // PAGE 2: Send Home Credentials
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Step 2: Internet Setup", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Select your Home WiFi so the machine can connect to the cloud.", textAlign: TextAlign.center),
                const SizedBox(height: 30),

                // Show loader if scanning
                if (_isScanningWiFi)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text("Scanning for networks...")
                    ],
                  )
                // Show dropdown if networks were found
                else if (_scannedSSIDs.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedSSID,
                    items: _scannedSSIDs.map((ssidName) {
                      return DropdownMenuItem(
                        value: ssidName,
                        child: Text(ssidName),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedSSID = val),
                    decoration: const InputDecoration(
                      labelText: "Select Nearby WiFi", 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wifi),
                    ),
                  )
                // Show a RESCAN button if the list is empty
                else
                  Column(
                    children: [
                      const Text(
                        "No networks found. Please ensure Location is turned on.", 
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Rescan Networks"),
                        onPressed: _scanNearbyWiFi,
                      )
                    ],
                  ),

                const SizedBox(height: 20),

                // PASSWORD FIELD
                TextField(
                  controller: _passController,
                  decoration: const InputDecoration(labelText: "WiFi Password", border: OutlineInputBorder()),
                  obscureText: true,
                ),
                const SizedBox(height: 30),

// =====================================
                // SEND BUTTON (Replace your old one with this)
                // =====================================
                ElevatedButton(
                  onPressed: () async {
                    // 1. Check if fields are empty
                    if (_selectedSSID == null || _passController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select a WiFi and enter the password."), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    try {
                      // 2. Send the HTTP POST request WITH A 7-SECOND TIMEOUT
                      var response = await http.post(
                        Uri.parse('http://192.168.4.1/setup'), 
                        body: {
                          "ssid": _selectedSSID, 
                          "pass": _passController.text
                        }
                      ).timeout(const Duration(seconds: 7)); // <--- TIMEOUT ADDED HERE

                      if (!context.mounted) return; 

                      // 3. Success check
                      if (response.statusCode == 200) {
                        // 🔴 NEW: Turn off the force-route so their phone works normally again
                        await WiFiForIoTPlugin.forceWifiUsage(false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Credentials sent! Machine is rebooting."), backgroundColor: Colors.green),
                        );
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Machine rejected the data."), backgroundColor: Colors.red),
                        );
                      }
                    } catch (e) {
                      // 🔴 NEW: Turn off force-route on failure
                      await WiFiForIoTPlugin.forceWifiUsage(false);
                      if (!context.mounted) return; 
                      
                      debugPrint("HTTP POST FAILED: $e"); 
                      
                      // 🔴 CHANGED THIS LINE to show the true error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("TRUE ERROR: ${e.toString()}"), // <-- This is the magic line
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 10), // Stays on screen for 10 seconds
                        ),
                      );
                    }
                  },
                  child: const Text("Send to Machine"),
                )
              ],
            ),
          ),

          // PAGE 3: QR Scanner Placeholder
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                const Text("Step 3: Link Machine", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Scan the QR code on your Vendo Machine to link it to your account.", textAlign: TextAlign.center),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _finishSetup,
                  child: const Text("Simulate QR Scan & Finish"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// EXISTING DASHBOARD SCREEN (Unchanged)
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Map<String, dynamic> currentSettings = {
    "1": {"enabled": true, "time": 5},
    "5": {"enabled": true, "time": 15},
    "10": {"enabled": true, "time": 30},
    "20": {"enabled": true, "time": 60},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Station Dashboard"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _dbRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("Waiting for ESP32 data..."));
          }

          final rawData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          
          if (rawData['settings'] != null && rawData['settings']['coins'] != null) {
            currentSettings = Map<String, dynamic>.from(rawData['settings']['coins']);
          }

          final earnings = rawData['total_earnings'] as Map<dynamic, dynamic>? ?? {};
          final double chargingRevenue = double.tryParse(earnings['charging']?.toString() ?? '0') ?? 0.0;
          final double wifiRevenue = double.tryParse(earnings['wifi']?.toString() ?? '0') ?? 0.0;
          final double totalRevenue = chargingRevenue + wifiRevenue;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRevenueCard("Total Collected", totalRevenue, Colors.green),
                const SizedBox(height: 12),
                _buildRevenueCard("Charging Station", chargingRevenue, Colors.blue),
                const SizedBox(height: 12),
                _buildRevenueCard("WiFi Vending", wifiRevenue, Colors.orange),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LogsScreen()),
                    );
                  },
                  child: const Text("View Daily Logs"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueCard(String title, double amount, Color color) {
    return Card(
      elevation: 8,
      color: color.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: ListTile(
          title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          subtitle: Text("₱ ${amount.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    Map<String, dynamic> tempSettings = {
      "1": {"enabled": currentSettings["1"]?["enabled"] ?? true, "time": currentSettings["1"]?["time"] ?? 5},
      "5": {"enabled": currentSettings["5"]?["enabled"] ?? true, "time": currentSettings["5"]?["time"] ?? 15},
      "10": {"enabled": currentSettings["10"]?["enabled"] ?? true, "time": currentSettings["10"]?["time"] ?? 30},
      "20": {"enabled": currentSettings["20"]?["enabled"] ?? true, "time": currentSettings["20"]?["time"] ?? 60},
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Coin Time Settings"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: tempSettings.keys.map((coin) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        SizedBox(width: 50, child: Text("₱$coin", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Minutes per coin",
                              hintText: tempSettings[coin]["time"].toString(),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              tempSettings[coin]["time"] = int.tryParse(val) ?? tempSettings[coin]["time"];
                              tempSettings[coin]["enabled"] = true; 
                            },
                          ),
                        )
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  Map<String, Object> updates = {};
                  tempSettings.forEach((coin, data) {
                    updates["$coin/time"] = data["time"];
                    updates["$coin/enabled"] = data["enabled"];
                  });
                  _dbRef.child("settings/coins").update(updates).then((_) {
                    if (context.mounted) Navigator.pop(context);
                  });
                },
                child: const Text("Save to Station"),
              ),
            ],
          );
        }
      ),
    );
  }
}

// ==========================================
// EXISTING LOGS SCREEN (Unchanged)
// ==========================================
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference logRef = FirebaseDatabase.instance.ref("logs");

    return Scaffold(
      appBar: AppBar(title: const Text("Daily Earnings Logs")),
      body: StreamBuilder(
        stream: logRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("No logs available."));
          }

          final logs = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final sortedDates = logs.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView(
            children: <Widget>[
              ...sortedDates.map((date) {
                final entry = logs[date] as Map<dynamic, dynamic>;
                final charging = entry['charging'] ?? 0;
                final wifi = entry['wifi'] ?? 0;
                
                final double total = (double.tryParse(charging.toString()) ?? 0) + 
                                     (double.tryParse(wifi.toString()) ?? 0);
                                     
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(date.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Charging: ₱$charging | WiFi: ₱$wifi | Total: ₱$total"),
                  ),
                );
              }), 
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                  label: const Text("Clear All Logs", style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    _showClearLogsConfirmation(context, logRef);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearLogsConfirmation(BuildContext context, DatabaseReference logRef) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Clear All Logs?"),
          content: const Text("Are you sure you want to delete all daily logs? This cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                logRef.remove(); 
                Navigator.pop(dialogContext); 
              },
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}