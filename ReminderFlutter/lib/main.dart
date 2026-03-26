import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

// ── 全局通知插件实例 ──────────────────────────────────────
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ── WorkManager 后台任务名 ────────────────────────────────
const String kTaskName = 'randomReminder';
const String kTaskTag  = 'com.reminder.flutter.randomReminder';

// ── WorkManager 回调（必须是顶层函数）────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('enabled') ?? false;
    if (!enabled) return Future.value(true);

    final line1 = prefs.getString('line1') ?? '';
    final line2 = prefs.getString('line2') ?? '';
    final line3 = prefs.getString('line3') ?? '';

    // 初始化通知
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // 发送全屏/锁屏通知
    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      '随机提醒',
      channelDescription: '锁屏随机提醒',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      '🔔 随机提醒',
      '$line1\n$line2\n$line3',
      details,
    );

    // 重新调度下一次（随机 1~4 分钟后）
    final random = Random();
    final delayMinutes = 1 + random.nextInt(4); // 1, 2, 3, 或 4 分钟
    await Workmanager().registerOneOffTask(
      kTaskTag,
      kTaskName,
      initialDelay: Duration(minutes: delayMinutes),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.not_required),
    );

    return Future.value(true);
  });
}

// ── 入口 ─────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 WorkManager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // 初始化本地通知
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const ReminderApp());
}

// ── App Widget ───────────────────────────────────────────
class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '随机提醒',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const HomePage(),
    );
  }
}

// ── 主界面 ───────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _line3Controller = TextEditingController();
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _line1Controller.text = prefs.getString('line1') ?? '第一行提醒内容';
      _line2Controller.text = prefs.getString('line2') ?? '第二行提醒内容';
      _line3Controller.text = prefs.getString('line3') ?? '第三行提醒内容';
      _enabled = prefs.getBool('enabled') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('line1', _line1Controller.text);
    await prefs.setString('line2', _line2Controller.text);
    await prefs.setString('line3', _line3Controller.text);
  }

  Future<void> _requestPermissions() async {
    // 通知权限
    await Permission.notification.request();
    // Android 13+ 精确闹钟权限
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    // iOS 通知权限
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _toggle() async {
    await _saveSettings();
    final newEnabled = !_enabled;

    if (newEnabled) {
      await _requestPermissions();
      // 随机延迟 1~4 分钟后第一次触发
      final delay = 1 + Random().nextInt(4);
      await Workmanager().registerOneOffTask(
        kTaskTag,
        kTaskName,
        initialDelay: Duration(minutes: delay),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.not_required),
      );
    } else {
      await Workmanager().cancelByUniqueName(kTaskTag);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enabled', newEnabled);
    setState(() => _enabled = newEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newEnabled ? '随机提醒已开启 🔔' : '随机提醒已关闭 🔕'),
          backgroundColor: newEnabled ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('随机提醒', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 说明卡片
            Card(
              color: const Color(0xFFE3F2FD),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('🔔', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '每隔 1~4 分钟随机在锁屏显示提醒',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 三行输入框
            _buildLabel('第一行内容'),
            _buildInput(_line1Controller, '输入第一行提醒文字'),
            const SizedBox(height: 16),

            _buildLabel('第二行内容'),
            _buildInput(_line2Controller, '输入第二行提醒文字'),
            const SizedBox(height: 16),

            _buildLabel('第三行内容'),
            _buildInput(_line3Controller, '输入第三行提醒文字'),
            const SizedBox(height: 32),

            // 保存按钮
            ElevatedButton(
              onPressed: () async {
                await _saveSettings();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('提醒内容已保存 ✓'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('保存内容'),
            ),
            const SizedBox(height: 16),

            // 开关按钮
            ElevatedButton(
              onPressed: _toggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: _enabled
                    ? const Color(0xFFE53935)
                    : const Color(0xFF43A047),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(_enabled ? '关闭提醒 🔕' : '开启提醒 🔔'),
            ),
            const SizedBox(height: 20),

            // 状态文字
            Center(
              child: Text(
                _enabled
                    ? '✅ 状态：提醒已开启（每隔 1~4 分钟随机触发）'
                    : '⭕ 状态：提醒已关闭',
                style: TextStyle(
                  fontSize: 14,
                  color: _enabled ? Colors.green.shade700 : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // 提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                '💡 iOS 用户：请在系统设置中允许「随机提醒」发送通知，并开启「时效性通知」权限，以确保锁屏时能正常显示。\n\n'
                '💡 Android 用户：请授予「精确闹钟」和「通知」权限，并在电池设置中允许后台运行。',
                style: TextStyle(fontSize: 12, color: Colors.deepOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFBBDEFB), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFBBDEFB), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      style: const TextStyle(fontSize: 18),
      maxLines: 2,
    );
  }

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    _line3Controller.dispose();
    super.dispose();
  }
}
