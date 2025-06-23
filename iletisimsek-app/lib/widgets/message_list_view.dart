import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'fullscreen_image_viewer.dart';

class MessageListView extends StatelessWidget {
  final List<MessageModel> messages;
  final String currentUserId;
  final UserModel chatWith;
  final void Function(String url, String senderName)? onTapImage;
  final void Function(String fileUrl)? onTapFile;

  const MessageListView({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.chatWith,
    this.onTapImage,
    this.onTapFile,
  });

  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return "Bugün";
    if (msgDay == today.subtract(const Duration(days: 1))) return "Dün";
    return DateFormat('dd.MM.yyyy').format(date);
  }

  Widget buildTickIcon(bool isRead) {
    return Icon(
      isRead ? Icons.done_all : Icons.check,
      size: 16,
      color: isRead
          ? const Color.fromARGB(255, 253, 253, 253)
          : Colors.grey[600],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color meBubbleColor = const Color.fromARGB(255, 86, 173, 255);
    final Color otherBubbleColor = Colors.white;
    final Color dateLabelBackground = const Color.fromARGB(255, 245, 245, 245);
    final Color dateLabelTextColor = Colors.black87;

    final List<Widget> items = [];
    DateTime? lastDate;

    for (final msg in messages) {
      final msgDate = msg.createdAt.toLocal();

      if (lastDate == null || !isSameDay(lastDate, msgDate)) {
        items.add(
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: dateLabelBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                formatDateLabel(msgDate),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: dateLabelTextColor,
                ),
              ),
            ),
          ),
        );
        lastDate = msgDate;
      }

      final isMe = msg.from == currentUserId;
      final isImage = msg.type == 'image';
      final fileUrl = 'http://10.20.10.30:3002/uploads/${msg.content}';
      final senderName = isMe ? 'Siz' : chatWith.name;

      Widget contentWidget;

      if (msg.type == 'image') {
        contentWidget = GestureDetector(
          onTap: () {
            if (onTapImage != null) {
              onTapImage!(fileUrl, senderName);
            } else {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => FullscreenImageViewer(
                    imageUrl: fileUrl,
                    senderName: senderName,
                    heroTag: fileUrl,
                  ),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            }
          },
          child: Hero(
            tag: fileUrl,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: fileUrl,
                width: 200,
                placeholder: (context, url) => Container(
                  width: 200,
                  height: 120,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      } else if (msg.type == 'file') {
        contentWidget = GestureDetector(
          onTap: () {
            if (onTapFile != null) onTapFile!(fileUrl);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_file),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  msg.content,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        );
      } else {
        contentWidget = Text(msg.content);
      }

      items.add(
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: isImage
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isImage
                  ? Colors.transparent
                  : (isMe ? meBubbleColor : otherBubbleColor),
              borderRadius: BorderRadius.circular(isImage ? 8 : 12),
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                  child: contentWidget,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(msgDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      buildTickIcon(msg.isRead),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      reverse: true,
      children: items.reversed.toList(),
    );
  }
}
