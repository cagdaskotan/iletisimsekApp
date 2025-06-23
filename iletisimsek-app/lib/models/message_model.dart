class MessageModel {
  final String? id;
  final String from;
  final String to;
  final String content;
  final String type;
  final DateTime createdAt; // ✅ DÜZELTİLDİ

  MessageModel({
    this.id,
    required this.from,
    required this.to,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'],
      from: json['from'],
      to: json['to'],
      content: json['content'],
      type: json['type'],
      createdAt: DateTime.parse(json['createdAt']), // ✅ JSON string → DateTime
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'from': from,
      'to': to,
      'content': content,
      'type': type,
      'createdAt': createdAt
          .toIso8601String(), // ✅ DateTime → JSON uyumlu string
    };
  }
}
