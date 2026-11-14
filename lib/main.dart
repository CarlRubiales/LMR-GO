import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';

import 'core/theme/app_theme.dart';
import 'models/delivery_request.dart';
import 'models/rider_account.dart';
import 'models/chat_preview.dart';
import 'screens/conversation_screen.dart';
import 'screens/account_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/deliveries_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/mock_backend.dart';
import 'services/offline_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();
  runApp(const LmrGoApp(initialLogin: true));
}

class LmrGoApp extends StatefulWidget {
  const LmrGoApp({
    super.key,
    this.initialLogin = false,
    this.showSplash = true,
  });

  final bool initialLogin;
  final bool showSplash;

  @override
  State<LmrGoApp> createState() => _LmrGoAppState();
}

class _LmrGoAppState extends State<LmrGoApp> {
  late bool _showingSplash;

  @override
  void initState() {
    super.initState();
    _showingSplash = widget.showSplash;
  }

  void _onSplashFinished() {
    if (mounted) {
      setState(() {
        _showingSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LMR GO',
      theme: AppTheme.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _showingSplash
            ? SplashScreen(
                key: const ValueKey('splash_screen'),
                onFinish: _onSplashFinished,
              )
            : RiderShell(
                key: const ValueKey('rider_shell'),
                startAtLogin: widget.initialLogin,
              ),
      ),
    );
  }
}

typedef RiderGoApp = LmrGoApp;

class RiderShell extends StatefulWidget {
  const RiderShell({super.key, this.startAtLogin = false});

  final bool startAtLogin;

  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> with WidgetsBindingObserver {
  int tab = 0;
  bool available = true;
  bool registered = false;
  DeliveryRequest? activeTrip;
  DeliveryStage stage = DeliveryStage.accepted;
  late bool login;
  bool registration = false;
  late bool signedOut;
  RiderAccount account = RiderAccount();
  List<PreviewConversation> conversations = createPreviewConversations();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    login = widget.startAtLogin;
    signedOut = widget.startAtLogin;
    _syncAccount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ApiService.instance.isAuthenticated) {
      MockBackend().getTodayRunParcels();
      OfflineQueueService.instance.flushQueue();
    }
  }

  void _syncAccount() {
    account = RiderAccount();
    final user = ApiService.instance.currentUser;
    if (user != null) {
      final name = (user['name'] as String? ?? '').trim();
      final parts = name.split(' ');
      if (parts.isNotEmpty) {
        account.profile['First name'] = parts.first;
        account.profile['Last name'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
      account.profile['Email'] = user['email'] as String? ?? '';
      if (user['phone'] != null) {
        account.profile['Mobile number'] = user['phone'] as String;
      }
    }
  }

  void logout() {
    ApiService.instance.logout();
    MockBackend().stopAutoSync();
    MockBackend().reset();
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      account = RiderAccount();
      conversations = createPreviewConversations();
      activeTrip = null;
      registered = false;
      available = true;
      stage = DeliveryStage.accepted;
      tab = 0;
      registration = false;
      signedOut = true;
      login = true;
    });
  }

  Future<void> _syncHubChatPreview() async {
    if (!ApiService.instance.isAuthenticated) return;
    try {
      final list = await ApiService.instance.fetchMessages(markRead: false);
      if (!mounted) return;
      final hubConv = conversations.firstWhere(
        (c) => c.isHubStaff,
        orElse: () => conversations.first,
      );
      final hubInfo = ApiService.instance.hubChatInfo;
      setState(() {
        if (hubInfo != null) {
          final hubTitle = hubInfo['hub_title']?.toString() ?? '';
          final adminName = hubInfo['admin_name']?.toString() ?? '';
          final adminEmail = hubInfo['admin_email']?.toString() ?? '';
          if (hubTitle.isNotEmpty) hubConv.name = hubTitle;
          if (adminName.isNotEmpty) {
            hubConv.description = adminEmail.isNotEmpty
                ? '$adminName · $adminEmail'
                : adminName;
          }
        }
        hubConv.unread = ApiService.instance.unreadHubMessages;
        hubConv.messages
          ..clear()
          ..addAll(
            list.map((m) {
              final timeStr = m['created_at']?.toString();
              final time = timeStr != null
                  ? (DateTime.tryParse(timeStr)?.toLocal() ?? DateTime.now())
                  : DateTime.now();
              return PreviewMessage(
                id: m['id'] as int? ?? 0,
                text: (m['message'] ?? m['text'] ?? '').toString(),
                isMine: m['is_mine'] == true,
                isRead: m['is_read'] == true,
                time: time,
                parcelId: m['parcel_number']?.toString() ?? m['parcel_id']?.toString(),
                senderName: (m['sender_name'] ?? '').toString(),
              );
            }),
          );
      });
    } catch (_) {}
  }

  Future<void> support() async {
    await openHubChat();
  }

  Future<void> openHubChat([String? parcelId]) async {
    final hubConversation = conversations.firstWhere(
      (c) => c.isHubStaff,
      orElse: () => conversations.first,
    );
    hubConversation.unread = 0;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          conversation: hubConversation,
          attachedParcelId: parcelId,
        ),
      ),
    );
    if (mounted) {
      _syncHubChatPreview();
      setState(() {});
    }
  }

  void accept(DeliveryRequest request) {
    setState(() {
      activeTrip = request;
      stage = DeliveryStage.accepted;
      tab = 1;
    });
    MockBackend().acceptRequest(request.id);
  }

  void progress() {
    final nextStage = stage == DeliveryStage.accepted
        ? DeliveryStage.pickedUp
        : DeliveryStage.delivered;
    setState(() {
      stage = nextStage;
    });
    if (activeTrip != null) {
      MockBackend().updateDelivery(activeTrip!.id, nextStage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (registration) {
      return RegistrationScreen(
        onBack: () => setState(() {
          registration = false;
          login = true;
        }),
        onLogin: () {
          setState(() {
            registration = false;
            login = true;
          });
        },
        onSubmitted: () {
          setState(() {
            registration = false;
            registered = true;
            login = true;
            signedOut = true;
          });
        },
      );
    }

    if (login || signedOut) {
      return LoginScreen(
        onBack: signedOut ? null : () => setState(() => login = false),
        onLogin: () {
          MockBackend().reset();
          setState(() {
            _syncAccount();
            conversations = createPreviewConversations();
            login = false;
            signedOut = false;
            tab = 0;
          });
          MockBackend().getTodayRunParcels();
          MockBackend().startAutoSync();
          _syncHubChatPreview();
        },
        onRegister: () {
          setState(() {
            login = false;
            registration = true;
          });
        },
      );
    }

    final unreadChatCount = conversations.fold<int>(0, (sum, c) => sum + c.unread);

    final List<Widget> pages = [
      DashboardScreen(
        available: available,
        onAvailability: (value) {
          setState(() => available = value);
          ApiService.instance.setAvailability(value);
        },
        activeTrip: activeTrip,
        onAccept: accept,
        onTab: (value) => setState(() => tab = value),
        onAccount: () => setState(() => tab = 3),
        registered: registered,
        onMessageHub: openHubChat,
      ),
      DeliveriesScreen(
        activeTrip: activeTrip,
        stage: stage,
        onAccept: accept,
        onProgress: progress,
        onMessageHub: openHubChat,
      ),
      ChatScreen(conversations: conversations),
      AccountScreen(
        account: account,
        onSupport: support,
        onRegister: () => setState(() => registration = true),
        onLogin: logout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (registered) const _PendingBanner(),
            Expanded(
              child: IndexedStack(index: tab, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
          if (value == 0 || value == 1) {
            MockBackend().getTodayRunParcels();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: unreadChatCount > 0
                ? Badge.count(
                    count: unreadChatCount,
                    child: const Icon(Icons.chat_bubble_outline),
                  )
                : const Icon(Icons.chat_bubble_outline),
            selectedIcon: unreadChatCount > 0
                ? Badge.count(
                    count: unreadChatCount,
                    child: const Icon(Icons.chat_bubble),
                  )
                : const Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningSoft,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: const Row(
        children: [
          Icon(Icons.schedule, color: AppColors.warning, size: 17),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Registration preview completed · nothing submitted',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
