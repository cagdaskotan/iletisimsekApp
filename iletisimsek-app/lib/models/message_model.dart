class MessageModel {
  final String? id;
  final String from;
  final String to;
  final String content;
  final String type;
  final DateTime createdAt;
  bool isRead;
  DateTime? readAt;

  MessageModel({
    this.id,
    required this.from,
    required this.to,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'] ?? json['id'], // ikisinden biri olabilir
      from: json['from'],
      to: json['to'],
      content: json['content'],
      type: json['type'],
      createdAt: DateTime.tryParse(json['createdAt']) ?? DateTime.now(),
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'from': from,
      'to': to,
      'content': content,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      if (readAt != null) 'readAt': readAt!.toIso8601String(),
    };
  }
}
