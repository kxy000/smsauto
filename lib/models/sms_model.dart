class SmsMessage {
  final String id;
  final String sender;
  final String content;
  final DateTime timestamp;
  final String receiverNumber;
  final int simSlot;
  final String simDisplayName;

  SmsMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.receiverNumber,
    required this.simSlot,
    required this.simDisplayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'receiverNumber': receiverNumber,
    };
  }
}
