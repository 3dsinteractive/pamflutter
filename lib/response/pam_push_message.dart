import 'dart:convert';
import 'package:http/http.dart' as http;
import "../pam.dart";
import 'dart:async';

class PamPushMessage {
  String? deliverID = "";
  String? pixel = "";
  String? title = "";
  String? description = "";
  String? thumbnailUrl = "";
  String? flex = "";
  String? url;
  String? popupType;
  bool isOpen;
  DateTime date;
  Map<String, dynamic> data;

  String? clickTrackingUrl = "";
  String? redirectId = "";

  PamPushMessage(
      {required this.deliverID,
      required this.pixel,
      required this.title,
      required this.description,
      required this.thumbnailUrl,
      required this.flex,
      required this.url,
      required this.popupType,
      required this.date,
      required this.isOpen,
      required this.data,
      required this.clickTrackingUrl,
      required this.redirectId});

  Future<void> fireAndForget(String? url) async {
    if (url == null) {
      return;
    }
    try {
      final uri = Uri.parse(url);
      await http.get(uri).timeout(const Duration(seconds: 3));
      Pam.log(['Track sent successfully: $url']);
    } catch (e) {
      Pam.log(['Track failed: $e']);
    }
  }

  void trackRead() {
    unawaited(fireAndForget(pixel));
  }

  void trackPushUrlClick() {
    unawaited(fireAndForget(clickTrackingUrl));
  }

  static List<PamPushMessage> parse(String jsonStr) {
    Map<String, dynamic> map;

    try {
      map = jsonDecode(jsonStr);
    } catch (e, stackTrace) {
      Pam.log(["Push Message Parse Error", stackTrace, e]);
      return [];
    }

    List<PamPushMessage> result = [];

    var items = map["items"] as List<dynamic>;

    for (var element in items) {
      Map<String, dynamic> json = element;

      String? deliverID = json["deliver_id"];
      String? pixel = json["pixel"];
      String? title = json["title"];
      String? description = json["description"];
      String? thumbnailUrl = json["thumbnail_url"];
      String? flex = json["flex"];
      String? url = json["url"];

      var payloadJson = json["json_data"]["pam"] as Map<String, dynamic>;
      String? popupType = payloadJson["popupType"];

      var dateString = json["created_date"];
      DateTime utcDateTime = DateTime.parse(dateString + "Z");
      DateTime localDateTime = utcDateTime.toLocal();

      bool isOpen = json["is_open"];

      String? clickTrackingUrl = json["click_tracking_url"];
      String? redirectId = json["redirect_id"];

      var item = PamPushMessage(
          deliverID: deliverID,
          pixel: pixel,
          title: title,
          description: description,
          thumbnailUrl: thumbnailUrl,
          flex: flex,
          url: url,
          popupType: popupType,
          date: localDateTime,
          isOpen: isOpen,
          data: payloadJson,
          clickTrackingUrl: clickTrackingUrl,
          redirectId: redirectId);

      result.add(item);
    }

    return result;
  }
}
