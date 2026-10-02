import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'chat_screen.dart';
import 'product_screen.dart';
import 'profile_screen.dart';

import '../services/chat_service.dart';
import '../widgets/custom_text.dart';

// Enhancement 3: userData is the signed-in user's saved data (from
// UserService.getUserData/loginUser), passed in as this route's arguments by
// splash_screen.dart or signin_screen.dart. userId is threaded down to
// ProductScreen so products are rendered for the signed-in user.
// Lab Activity 6: the second tab (previously Cart) is now the Chat list.
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const HomeScreen({super.key, this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  static const int _chatTabIndex = 1;
  final ChatService _chatService = ChatService();

  int get _userId => widget.userData?['id'] ?? 0;

  String? get _currentUserUid => widget.userData?['uid'] as String?;

  String get _firstName {
    final firstName = widget.userData?['firstName'] as String?;
    if (firstName != null && firstName.isNotEmpty) return firstName;
    return (widget.userData?['username'] as String?) ?? 'Profile';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 2,
          title: _selectedIndex == 0
              ? Image.asset('assets/images/nubdexchange_logo.png', scale: 11.sp)
              : CustomText(
                  text: _selectedIndex == _chatTabIndex ? 'Chat' : _firstName,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 24.sp),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          children: <Widget>[
            ProductScreen(userId: _userId),
            const ChatScreen(),
            const ProfileScreen(),
          ],
          onPageChanged: (page) {
            setState(() {
              _selectedIndex = page;
            });
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: _onTappedBar,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.shop_2),
              label: 'Shop',
            ),
            BottomNavigationBarItem(
              icon: _ChatTabIcon(
                chatService: _chatService,
                currentUserUid: _currentUserUid,
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
        ),
      ),
    );
  }

  void _onTappedBar(int value) {
    setState(() {
      _selectedIndex = value;
    });
    _pageController.jumpToPage(value);
  }
}

// Chat tab icon with a small red dot badge while any chat has an unread
// message, so it's visible without having to open the Chat tab first.
class _ChatTabIcon extends StatelessWidget {
  final ChatService chatService;
  final String? currentUserUid;

  const _ChatTabIcon({required this.chatService, required this.currentUserUid});

  @override
  Widget build(BuildContext context) {
    if (currentUserUid == null) {
      return const Icon(Icons.chat_bubble);
    }

    return StreamBuilder<bool>(
      stream: chatService.hasUnreadMessages(currentUserUid!),
      builder: (context, snapshot) {
        final hasUnread = snapshot.data ?? false;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat_bubble),
            if (hasUnread)
              Positioned(
                top: -2,
                right: -4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
