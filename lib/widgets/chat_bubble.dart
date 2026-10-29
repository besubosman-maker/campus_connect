import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import 'app_image_helper.dart';

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isPlayingVoice = false;
  int _playedSeconds = 0;
  Timer? _playbackTimer;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayVoice() {
    if (_isPlayingVoice) {
      _playbackTimer?.cancel();
      setState(() {
        _isPlayingVoice = false;
      });
    } else {
      final total = widget.message.durationSeconds ?? 5;
      setState(() {
        _isPlayingVoice = true;
        _playedSeconds = 0;
      });

      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_playedSeconds >= total) {
          timer.cancel();
          setState(() {
            _isPlayingVoice = false;
            _playedSeconds = 0;
          });
        } else {
          setState(() {
            _playedSeconds++;
          });
        }
      });
    }
  }

  void _openImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Center(
                child: AppImageHelper.buildImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormatted = DateFormat('hh:mm a').format(widget.message.sentAt);
    final isMe = widget.isMe;
    final message = widget.message;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? theme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // IMAGE MESSAGE
            if (message.isImage && message.mediaUrl != null) ...[
              GestureDetector(
                onTap: () => _openImageViewer(context, message.mediaUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppImageHelper.buildImage(
                    imageUrl: message.mediaUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (message.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ]
            // VOICE NOTE MESSAGE
            else if (message.isVoice) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _togglePlayVoice,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.2)
                            : theme.primaryColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlayingVoice
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: isMe ? Colors.white : theme.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Animated waveform visualizer
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '🎙️ Voice Note',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              _isPlayingVoice
                                  ? '0:${_playedSeconds.toString().padLeft(2, '0')}'
                                  : '0:${(message.durationSeconds ?? 5).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Waveform bars
                        Row(
                          children: List.generate(14, (idx) {
                            final heights = [8.0, 14.0, 20.0, 12.0, 24.0, 18.0, 10.0, 22.0, 16.0, 20.0, 14.0, 8.0, 16.0, 10.0];
                            final h = heights[idx % heights.length];
                            final isActive = _isPlayingVoice &&
                                idx <= ((_playedSeconds / (message.durationSeconds ?? 5)) * 14);

                            return Expanded(
                              child: Container(
                                height: h,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (isMe ? Colors.amberAccent : theme.primaryColor)
                                      : (isMe ? Colors.white54 : Colors.grey[400]),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (message.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: isMe ? Colors.white.withOpacity(0.9) : Colors.black87,
                  ),
                ),
              ],
            ]
            // REGULAR TEXT MESSAGE
            else ...[
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  color: isMe ? Colors.white : Colors.black87,
                  height: 1.3,
                ),
              ),
            ],

            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeFormatted,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.black45,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.message.read ? Icons.done_all_rounded : Icons.check_rounded,
                    size: 14,
                    color: widget.message.read ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
