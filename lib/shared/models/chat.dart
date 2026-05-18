import 'package:cap/shared/models/message.dart';

class Chat {
  final String id;
  final List<String> participants;
  final List<String> participantNames;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final List<Message> messages;

  Chat({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.messages,
  });

  Chat copyWith({
    String? id,
    List<String>? participants,
    List<String>? participantNames,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    List<Message>? messages,
  }) {
    return Chat(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantNames: participantNames ?? this.participantNames,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'participantNames': participantNames,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      participants: List<String>.from(json['participants']),
      participantNames: List<String>.from(json['participantNames']),
      lastMessage: json['lastMessage'],
      lastMessageTime: DateTime.parse(json['lastMessageTime']),
      unreadCount: json['unreadCount'],
      messages: (json['messages'] as List)
          .map((messageJson) => Message.fromJson(messageJson))
          .toList(),
    );
  }
}
