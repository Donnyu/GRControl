import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PC Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. ГЛАВНОЕ МЕНЮ
// -----------------------------------------------------------------------------
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final TextEditingController _ipController = TextEditingController(text: "192.168.0.16");

  Future<void> _ensurePortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PC Remote Control"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "IP-адрес ПК",
                      hintText: "192.168.X.X",
                      icon: Icon(Icons.computer),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 170,
                child: InkWell(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RemoteDesktopScreen(ip: _ipController.text.trim()),
                      ),
                    );
                    await _ensurePortrait();
                  },
                  child: const Card(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.screen_share, size: 54, color: Colors.blueAccent),
                          SizedBox(height: 10),
                          Text("Управление экраном", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Трансляция и мышь", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 170,
                child: InkWell(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuickActionsScreen(ip: _ipController.text.trim()),
                      ),
                    );
                  },
                  child: const Card(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.power_settings_new, size: 54, color: Colors.redAccent),
                          SizedBox(height: 10),
                          Text("Горячие действия", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Блокировка, Выключение ПК", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. ЭКРАН ГОРЯЧИХ ДЕЙСТВИЙ
// -----------------------------------------------------------------------------
class QuickActionsScreen extends StatefulWidget {
  final String ip;
  const QuickActionsScreen({super.key, required this.ip});

  @override
  State<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends State<QuickActionsScreen> {
  void _sendCommand(String action) {
    try {
      final channel = WebSocketChannel.connect(Uri.parse('ws://${widget.ip}:8765'));
      channel.sink.add(jsonEncode({"type": "command", "action": action}));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Команда '$action' отправлена!"), duration: const Duration(seconds: 1)),
      );

      Future.delayed(const Duration(milliseconds: 500), () => channel.sink.close());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ошибка подключения к ПК!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Быстрые действия (${widget.ip})")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _actionCard(
              title: "Заблокировать",
              icon: Icons.lock,
              color: Colors.orange,
              onTap: () => _sendCommand("lock"),
            ),
            _actionCard(
              title: "Выключить ПК",
              icon: Icons.power_off,
              color: Colors.red,
              onTap: () => _sendCommand("shutdown"),
            ),
            _actionCard(
              title: "Перезагрузка",
              icon: Icons.restart_alt,
              color: Colors.blue,
              onTap: () => _sendCommand("restart"),
            ),
            _actionCard(
              title: "Отмена выкл.",
              icon: Icons.cancel,
              color: Colors.green,
              onTap: () => _sendCommand("cancel_shutdown"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. ЭКРАН УДАЛЕННОГО РАБОЧЕГО СТОЛА
// -----------------------------------------------------------------------------
class RemoteDesktopScreen extends StatefulWidget {
  final String ip;
  const RemoteDesktopScreen({super.key, required this.ip});

  @override
  State<RemoteDesktopScreen> createState() => _RemoteDesktopScreenState();
}

class _RemoteDesktopScreenState extends State<RemoteDesktopScreen> {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Uint8List? _currentFrame;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _connect();
  }

  Future<void> _exitScreen() async {
    _disconnect();
    
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  void _connect() {
    _disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://${widget.ip}:8765'));
      _channel!.stream.listen(
        (message) {
          if (!mounted) return;

          if (message is Uint8List) {
            setState(() {
              _currentFrame = message;
              _isConnected = true;
            });
          } else if (message is List<int>) {
            setState(() {
              _currentFrame = Uint8List.fromList(message);
              _isConnected = true;
            });
          }
        },
        onDone: () => _setDisconnected(),
        onError: (_) => _setDisconnected(),
      );
    } catch (_) {
      _setDisconnected();
    }
  }

  void _setDisconnected() {
    if (mounted) {
      setState(() {
        _isConnected = false;
        _currentFrame = null;
      });
    }
  }

  void _disconnect() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _sendEvent(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _exitScreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 🎯 1. НИЗКОУРОВНЕВЫЙ Listener ДЛЯ МГНОВЕННОГО УПРАВЛЕНИЯ КУРСОРOM
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerMove: (event) {
                  // Передаем дельту движения пальца напрямую
                  _sendEvent({
                    "type": "move",
                    "dx": event.delta.dx * 2.5, // Множитель чувствительности
                    "dy": event.delta.dy * 2.5,
                  });
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _sendEvent({"type": "click", "button": "left"}),
                  onDoubleTap: () => _sendEvent({"type": "click", "button": "right"}),
                  child: _currentFrame != null
                      ? Image.memory(_currentFrame!, gaplessPlayback: true, fit: BoxFit.fill)
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Text("Подключение к ${widget.ip}...", style: const TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                ),
              ),
            ),

            // 2. 🔙 КНОПКА НАЗАД
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _exitScreen,
                  ),
                ),
              ),
            ),

            // 3. 📶 КНОПКА СТАТУСА
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(_isConnected ? Icons.wifi : Icons.wifi_off, color: _isConnected ? Colors.green : Colors.red),
                    onPressed: _connect,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}