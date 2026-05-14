import 'package:supabase_flutter/supabase_flutter.dart';
import 'current_session.dart';

class MessageService {
  final _supabase = Supabase.instance.client;

  Stream<int> getUnreadCountStream() {
    final myId = CurrentSession().user?.id;
    if (myId == null) return Stream.value(0);

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .map((events) {
          // Filter client-side because multiple .eq() or .or() might not be supported in all versions
          return events.where((m) => 
            m['receiver_id'] == myId && m['is_read'] == false
          ).length;
        });
  }

  // A stream that emits a signal whenever conversations might have changed
  Stream<void> getConversationsChangedStream() {
    final myId = CurrentSession().user?.id;
    if (myId == null) return const Stream.empty();

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .map((events) {
          // Filter for messages involving me
          final hasInvolvement = events.any((m) => 
            m['sender_id'] == myId || m['receiver_id'] == myId
          );
          return hasInvolvement ? null : null;
        });
  }
}
