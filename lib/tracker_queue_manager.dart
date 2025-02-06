library;

import './response/pam_response.dart';

typedef QueueCallback = Function(TrackQueue);
typedef TrackerCallBack = Function(PamResponse);

class TrackerQueueManger {
  List<TrackQueue> queue = [];
  QueueCallback? onQueueStart;
  bool processing = false;

  void enqueue(TrackQueue track) {
    queue.add(track);
    if (!processing) {
      next();
    }
  }

  void next() {
    if (queue.isNotEmpty) {
      processing = true;
      var track = queue.last;
      queue.removeLast();
      onQueueStart?.call(track);
    } else {
      processing = false;
    }
  }
}

class TrackQueue {
  String event;
  Map<String, dynamic>? payload;
  TrackerCallBack? trackerCallBack;

  TrackQueue(this.event, {this.payload, this.trackerCallBack});
}
