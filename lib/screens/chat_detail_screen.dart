import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/chat_service.dart';
import '../widgets/custom_text.dart';

// Lab Activity 6, Enhancement 3: redesigned chat detail screen with rounded
// bubbles for clear sender/receiver distinction, a "sending..." state that
// flips to a delivered check once Firestore confirms the write, and
// fade/slide transitions for incoming messages.
class ChatDetailScreen extends StatefulWidget {
  final String currentUserUid;
  final Map<String, dynamic> tappedUser;

  const ChatDetailScreen({
    super.key,
    required this.currentUserUid,
    required this.tappedUser,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  final ChatService _chatService = ChatService();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Clears the unread badge for this chat now that the user has opened it.
    final tappedUserId = (widget.tappedUser['uid'] ?? '').toString();
    _chatService.markAsRead(widget.currentUserUid, tappedUserId);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String receiverId) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(receiverId, text);
      _msgCtrl.clear();
      _msgFocus.requestFocus();

      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tappedUserId = (widget.tappedUser['uid'] ?? '').toString();
    final firstName = (widget.tappedUser['firstName'] ?? '').toString();
    final lastName = (widget.tappedUser['lastName'] ?? '').toString();
    final tappedUserName = '$firstName $lastName'.trim().isNotEmpty
        ? '$firstName $lastName'.trim()
        : (widget.tappedUser['email'] ?? 'Chat').toString();
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: const Color(0xFF1A237E),
              child: CustomText(
                text: initial,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 10.w),
            CustomText(
              text: tappedUserName,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(
                widget.currentUserUid,
                tappedUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: CustomText(text: 'No messages yet', fontSize: 14.sp),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final msgText = (data['message'] ?? '').toString();
                    final senderId = (data['senderId'] ?? '').toString();
                    final isMe = senderId == widget.currentUserUid;
                    final ts = data['timestamp'];
                    final timeLabel = ts is Timestamp
                        ? _formatTime(ts.toDate())
                        : '';
                    // Delivered check only makes sense on my own latest bubble.
                    final isLatestMine = isMe && index == 0;

                    return TweenAnimationBuilder<double>(
                      key: ValueKey(docs[index].id),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 12),
                            child: child,
                          ),
                        );
                      },
                      child: Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            vertical: 4.h,
                            horizontal: 8.w,
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: 10.h,
                            horizontal: 14.w,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFF1A237E)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16.r).copyWith(
                              bottomLeft: isMe
                                  ? Radius.circular(16.r)
                                  : Radius.zero,
                              bottomRight: isMe
                                  ? Radius.zero
                                  : Radius.circular(16.r),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msgText.isNotEmpty ? msgText : '[empty]',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15.sp,
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeLabel,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w300,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  if (isLatestMine) ...[
                                    SizedBox(width: 4.w),
                                    Icon(
                                      Icons.done_all,
                                      size: 14.sp,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Sending indicator (Enhancement 3: "sending..." state).
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isSending
                ? Padding(
                    key: const ValueKey('sending'),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 4.h,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CustomText(
                        text: 'Sending...',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      focusNode: _msgFocus,
                      enabled: !_isSending,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) =>
                          _isSending ? null : _send(tappedUserId),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _isSending
                      ? SizedBox(
                          height: 24.h,
                          width: 24.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          color: const Color(0xFF1A237E),
                          onPressed: () => _send(tappedUserId),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
