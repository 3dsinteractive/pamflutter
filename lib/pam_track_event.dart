/// A tracking event belonging to the current SDK user.
class PamTrackEvent {
  final String event;
  final Map<String, dynamic>? payload;

  const PamTrackEvent({required this.event, this.payload});
}
