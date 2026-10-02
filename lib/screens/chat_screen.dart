import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';
import 'chat_detail_screen.dart';

// Lab Activity 6, Enhancement 1 & 2: lists every registered Firebase user
// (minus the signed-in one) with a search bar to filter by name or email.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  String? _currentUserUid;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _loadCurrentUser() async {
    final userData = await _userService.getUserData();
    setState(() => _currentUserUid = userData['uid'] as String?);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.cancel),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: CustomText(
                      text: 'Error loading users',
                      fontSize: 16.sp,
                    ),
                  );
                }

                var users = snapshot.data ?? [];

                // Enhancement 1: exclude the current logged-in user.
                if (_currentUserUid != null) {
                  users = users
                      .where((u) => u['uid'] != _currentUserUid)
                      .toList();
                }

                // Enhancement 2: filter by name or email.
                if (_searchText.isNotEmpty) {
                  users = users.where((u) {
                    final name =
                        '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                            .toLowerCase();
                    final email = (u['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchText) ||
                        email.contains(_searchText);
                  }).toList();
                }

                if (users.isEmpty) {
                  return Center(
                    child: CustomText(
                      text: 'No users found',
                      fontSize: 16.sp,
                    ),
                  );
                }

                final currentUserUid = _currentUserUid;

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final firstName = (user['firstName'] ?? '').toString();
                    final lastName = (user['lastName'] ?? '').toString();
                    final displayName = '$firstName $lastName'.trim();
                    final email = (user['email'] ?? 'No email').toString();
                    final otherUid = (user['uid'] ?? '').toString();
                    final initial = firstName.isNotEmpty
                        ? firstName[0].toUpperCase()
                        : '?';

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: currentUserUid == null
                          ? null
                          : _chatService.getChatRoomInfo(
                              currentUserUid,
                              otherUid,
                            ),
                      builder: (context, roomSnapshot) {
                        final room = roomSnapshot.data?.data();
                        final lastMessage = room?['lastMessage'] as String?;
                        final lastSenderId = room?['lastSenderId'] as String?;
                        final readBy = List<String>.from(
                          room?['readBy'] ?? [],
                        );
                        final isUnread =
                            currentUserUid != null &&
                            lastSenderId != null &&
                            lastSenderId != currentUserUid &&
                            !readBy.contains(currentUserUid);

                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4.h),
                          child: ListTile(
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF1A237E),
                                  child: CustomText(
                                    text: initial,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0,
                                  ),
                                ),
                                if (isUnread)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      width: 14.w,
                                      height: 14.w,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: CustomText(
                              text: displayName.isNotEmpty
                                  ? displayName
                                  : 'Unknown',
                              fontSize: 16.sp,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                            subtitle: CustomText(
                              text: lastMessage?.isNotEmpty == true
                                  ? lastMessage!
                                  : email,
                              fontSize: 12.sp,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatDetailScreen(
                                    currentUserUid: currentUserUid ?? '',
                                    tappedUser: user,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
