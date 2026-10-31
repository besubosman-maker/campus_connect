import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/report_dialog.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userModel != null) {
        _chatService.markMessagesAsRead(
          chatId: widget.chatId,
          currentUserId: auth.userModel!.uid,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;
    if (currentUser == null) return;

    _textController.clear();
    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: currentUser.uid,
        text: text,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;
    if (currentUser == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 65,
      );

      if (picked == null) return;

      setState(() => _isSending = true);

      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      await _chatService.sendMediaMessage(
        chatId: widget.chatId,
        senderId: currentUser.uid,
        type: 'image',
        mediaUrl: dataUri,
        text: _textController.text.trim(),
      );

      _textController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share Photo with Peer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Take a Photo (ካሜራ)'),
                subtitle: const Text('Capture item condition directly'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Choose from Gallery (ጋለሪ)'),
                subtitle: const Text('Select a saved screenshot or photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoiceNoteSheet() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        int recordedSeconds = 0;
        bool isRecording = true;
        Timer? recordingTimer;
        String selectedPreset = '';

        final presets = [
          'ዋጋው ይቀነሳል? (Can you lower the price?)',
          'የት እንገናኝ? (Where can we meet on campus?)',
          'አሁን ይገኛል? (Is it available right now?)',
          'በቴሌብር ልላክ? (Can I pay via Telebirr?)',
          'እቃውን አይቼ እወስዳለሁ (I will inspect it first)',
        ];

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            recordingTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (sheetContext.mounted && isRecording) {
                setSheetState(() {
                  recordedSeconds++;
                });
              }
            });

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 8),
                        const Text(
                          'Voice Note (የድምጽ መልእክት)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            recordingTimer?.cancel();
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Recording indicator & pulsating circle
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Recording Voice Note...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '0:${recordedSeconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Quick Amharic topic tag selector
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Optional Quick Topic / ማስታወሻ:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presets.map((preset) {
                        final isSel = selectedPreset == preset;
                        return ChoiceChip(
                          label: Text(
                            preset,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: AppConstants.primaryColor,
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (val) {
                            setSheetState(() {
                              selectedPreset = val ? preset : '';
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: Text(
                          'Send Voice Note (0:${recordedSeconds.clamp(1, 99).toString().padLeft(2, '0')})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () async {
                          recordingTimer?.cancel();
                          Navigator.pop(ctx);

                          final duration = recordedSeconds < 1 ? 3 : recordedSeconds;
                          await _chatService.sendMediaMessage(
                            chatId: widget.chatId,
                            senderId: currentUser.uid,
                            type: 'voice',
                            mediaUrl: 'simulated_audio_note',
                            text: selectedPreset,
                            durationSeconds: duration,
                          );

                          _scrollToBottom();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.userModel?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
              backgroundImage: widget.otherUser.photoUrl != null
                  ? CachedNetworkImageProvider(widget.otherUser.photoUrl!)
                  : null,
              child: widget.otherUser.photoUrl == null
                  ? const Icon(Icons.person, color: AppConstants.primaryColor, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Campus Peer',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.outlined_flag_rounded, color: Colors.black54),
            tooltip: 'Report User',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => ReportDialog(
                  targetType: 'user',
                  targetId: widget.otherUser.uid,
                  targetTitle: widget.otherUser.name,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Safety Tip Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                Icon(Icons.security_outlined, size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Safety tip: Meet in public campus locations (Library, Student Center) for item exchanges.',
                    style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),

          // Real-time messages stream
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getChatMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Connecting to chat...');
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (snapshot.hasData && messages.isNotEmpty) {
                  final hasUnread = messages.any((m) => !m.read && m.senderId != currentUserId);
                  if (hasUnread) {
                    _markRead();
                  }
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined, size: 54, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'No Messages Yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Send a greeting to ${widget.otherUser.name} to discuss the item or agree on an exchange spot!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Trigger read receipt check
                _markRead();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return ChatBubble(
                      message: msg,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),

          // Message input bar with Camera, Mic, and Send
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Photo Attachment Button
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: AppConstants.primaryColor),
                    tooltip: 'Send Photo',
                    onPressed: _isSending ? null : _showAttachSheet,
                  ),

                  // Voice Note Button
                  IconButton(
                    icon: const Icon(Icons.mic_outlined, color: Colors.redAccent),
                    tooltip: 'Send Voice Note',
                    onPressed: _isSending ? null : _showVoiceNoteSheet,
                  ),

                  // Text input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Type message...',
                          hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Send button
                  Container(
                    decoration: const BoxDecoration(
                      color: AppConstants.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
