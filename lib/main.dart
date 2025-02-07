import 'dart:async';
import 'package:flutter/material.dart';
import 'services/sms_service.dart';
import 'utils/permission_handler.dart';
import 'models/sms_model.dart';
import 'package:flutter/services.dart';
import 'services/settings_service.dart';
import 'pages/settings_page.dart';
import 'services/background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/permission_guide_page.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '短信读取器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(),
        '/home': (context) => const MyHomePage(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SmsService _smsService = SmsService();
  final ApiService _apiService = ApiService();
  final SettingsService _settingsService = SettingsService();
  final ScrollController _scrollController = ScrollController();
  List<SmsMessage> _messages = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _pageSize = 20;
  StreamSubscription? _smsSubscription;

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('is_first_run') ?? true;

    if (isFirstRun) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PermissionGuidePage()),
      );
    } else {
      _initializeApp();
      initializeBackgroundService();
      _scrollController.addListener(_onScroll);
      _apiService.addErrorListener((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '设置',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    bool hasPermission = await PermissionUtil.requestSmsPermission();
    if (hasPermission) {
      final settings = await _settingsService.getSettings();
      await _loadMessages();
      if (mounted) {
        _startSmsListener(settings.smsRefreshInterval);
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final messages = await _smsService.getMessages(
        offset: (_currentPage - 1) * _pageSize,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (messages.isEmpty) {
            _hasMore = false;
          } else {
            _messages.addAll(messages);
            _currentPage++;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startSmsListener(int intervalSeconds) {
    _smsSubscription?.cancel();
    _smsSubscription = _smsService
        .streamMessages(intervalSeconds: intervalSeconds)
        .listen((messages) {
      if (mounted) {
        setState(() => _messages = messages);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadMessages();
    }
  }

  Future<void> _refreshMessages() async {
    setState(() {
      _messages.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    await _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _smsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('短信列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final settingsChanged = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
              if (settingsChanged == true) {
                final settings = await _settingsService.getSettings();
                _startSmsListener(settings.smsRefreshInterval);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMessages,
        child: ListView.separated(
          controller: _scrollController,
          itemCount: _messages.length + (_hasMore ? 1 : 0),
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index >= _messages.length) {
              return _buildLoadingIndicator();
            }

            final message = _messages[index];
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.sender,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.content,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        message.timestamp.toString().substring(0, 16),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                            text: '发信人: ${message.sender}\n'
                                '内容: ${message.content}\n'
                                '时间: ${message.timestamp.toString().substring(0, 16)}',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
