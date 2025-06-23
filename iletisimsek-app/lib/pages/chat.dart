import 'dart:io';
import 'package:chat/services/banned_words_service.dart';
import '../widgets/fullscreen_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../widgets/message_list_view.dart';
import '../services/socket_service.dart';

class ChatPage extends StatefulWidget {
  final UserModel currentUser;
  final UserModel chatWith;

  const ChatPage({
    super.key,
    required this.currentUser,
    required this.chatWith,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  List<MessageModel> messages = [];
  bool isLoading = true;

  File? selectedImage;
  File? selectedFile;

  String? topWarningMessage;
  bool showTopWarning = false;

  @override
  void initState() {
    super.initState();
    fetchMessages();

    // 🔌 Gelen mesajları dinle
    SocketService().onMessageReceived((data) async {
      final incoming = MessageModel.fromJson(data);

      final isIncoming =
          incoming.from == widget.chatWith.id &&
          incoming.to == widget.currentUser.id;

      final isRelevant =
          isIncoming ||
          (incoming.to == widget.chatWith.id &&
              incoming.from == widget.currentUser.id);

      if (isRelevant) {
        // 🔔 Gelen mesaj sana aitse, anında okundu yap
        if (isIncoming) {
          try {
            await MessageService.markAsRead(incoming.from, incoming.to);
            incoming.isRead = true;
            incoming.readAt = DateTime.now(); // UI’da da gösterilmesi için
          } catch (e) {
            print('⛔️ Okundu işaretleme hatası: $e');
          }
        }

        setState(() {
          messages.add(incoming);
        });

        print('✅ [${widget.currentUser.name}] Mesaj listeye eklendi');
      }
    });
  }

  Future<void> fetchMessages() async {
    try {
      messages = await MessageService.getMessages(
        widget.currentUser.id,
        widget.chatWith.id,
      );

      print('✅ [fetchMessages] Gelen mesaj sayısı: ${messages.length}');
      for (var m in messages) {
        print(m.toJson()); // 🧪 gelen veri formatı doğru mu kontrol et
      }

      for (final msg in messages) {
        if (msg.to == widget.currentUser.id && !msg.isRead) {
          await MessageService.markAsRead(msg.from, msg.to); // ✅
          msg.isRead = true;
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      print('⛔️ fetchMessages hata: $e');
    }
  }

  Future<void> openFileUrl(String fileUrl) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final fileName = fileUrl.split('/').last;
        final filePath = '${tempDir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(bytes);

        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          throw 'Açılamadı: ${result.message}';
        }
      } else {
        throw 'Dosya indirilemedi';
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Dosya açılırken hata: $e")));
    }
  }

  Future<void> sendTextMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final bannedWords = await BannedWordService.fetchBannedWords();
    final lowerMessage = content.toLowerCase();

    for (final banned in bannedWords) {
      if (lowerMessage.contains(banned)) {
        setState(() {
          topWarningMessage = 'Bu mesaj yasaklı bir kelime içeriyor: "$banned"';
          showTopWarning = true;
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            showTopWarning = false;
          });
        });

        return;
      }
    }

    // API'ye gönder
    await MessageService.sendMessage(
      widget.currentUser.id,
      widget.chatWith.id,
      content,
    );

    final newMessage = MessageModel(
      from: widget.currentUser.id,
      to: widget.chatWith.id,
      content: content,
      type: 'text',
      createdAt: DateTime.now(),
      isRead: false,
      readAt: null,
    );

    // 👉 Anında kendi ekranına ekle
    setState(() {
      messages.add(newMessage);
    });

    // 👉 Socket ile karşıya gönder
    SocketService().sendMessage(newMessage.toJson());

    // 🎯 Input temizle
    _messageController.clear();
  }

  Future<void> sendImageMessage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    setState(() {
      selectedImage = File(pickedImage.path);
      selectedFile = null;
    });
  }

  Future<void> sendFileMessage() async {
    final XFile? file = await openFile();
    if (file == null) return;

    setState(() {
      selectedFile = File(file.path);
      selectedImage = null;
    });
  }

  Future<void> sendSelectedMedia() async {
    try {
      MessageModel? newMessage;

      if (selectedImage != null) {
        final json = await MessageService.sendMedia(
          from: widget.currentUser.id,
          to: widget.chatWith.id,
          file: selectedImage!,
          type: 'image',
        );

        newMessage = MessageModel.fromJson(json);
      } else if (selectedFile != null) {
        final json = await MessageService.sendMedia(
          from: widget.currentUser.id,
          to: widget.chatWith.id,
          file: selectedFile!,
          type: 'file',
        );

        newMessage = MessageModel.fromJson(json);
      }

      if (newMessage != null) {
        setState(() {
          messages.add(newMessage!);
          selectedImage = null;
          selectedFile = null;
        });

        SocketService().sendMessage(newMessage.toJson());
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Medya gönderilemedi: $e")));
    }
  }

  Widget _buildPreviewWidget() {
    if (selectedImage != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Image.file(selectedImage!, height: 120),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => selectedImage = null),
                child: const Icon(Icons.close, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    } else if (selectedFile != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedFile!.path.split('/').last,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => selectedFile = null),
                child: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color.fromARGB(255, 210, 223, 248);
    final Color appBarColor = const Color(0xFF1976D2);
    final Color sendButtonColor = const Color(0xFF1976D2);

    return WillPopScope(
      onWillPop: () async => true,

      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          iconTheme: const IconThemeData(color: Colors.white),
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 0),
              const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 6),
              Text(
                widget.chatWith.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : MessageListView(
                          messages: messages,
                          currentUserId: widget.currentUser.id,
                          chatWith: widget.chatWith,
                          onTapImage: (url, senderName) {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    FullscreenImageViewer(
                                      imageUrl: url,
                                      senderName: senderName,
                                      heroTag: url,
                                    ),
                                transitionsBuilder: (_, animation, __, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                          onTapFile: openFileUrl,
                        ),
                ),

                if (selectedImage != null || selectedFile != null)
                  _buildPreviewWidget(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  color: Colors.white,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image, color: Color(0xFF1976D2)),
                        onPressed: sendImageMessage,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.attach_file,
                          color: Color(0xFF1976D2),
                        ),
                        onPressed: sendFileMessage,
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: "Mesaj yaz...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      CircleAvatar(
                        backgroundColor: sendButtonColor,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed:
                              selectedImage != null || selectedFile != null
                              ? sendSelectedMedia
                              : sendTextMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final offsetAnimation =
                    Tween<Offset>(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: showTopWarning
                  ? Padding(
                      key: const ValueKey("warning"),
                      padding: const EdgeInsets.only(
                        top: 16,
                        left: 16,
                        right: 16,
                      ),
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  topWarningMessage ?? '',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // SocketService().disconnect(); // 🔌 Bağlantıyı kes
    SocketService().clearListeners(); // 🔥 dinleyiciyi sıfırla
    _messageController.dispose(); // 🎯 Controller'ı temizle
    super.dispose();
  }
}
