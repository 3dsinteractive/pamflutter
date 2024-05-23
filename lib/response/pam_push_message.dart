import 'dart:convert';
import 'package:http/http.dart' as http;
import "../pam.dart";

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
      required this.data});

  Future<void> trackRead() async {
    if (pixel != null) {
      final uri = Uri.parse(pixel ?? "");
      await http.get(uri);
    }
  }

  static List<PamPushMessage> parse(String jsonStr) {
    Map<String, dynamic> map;

    try {
      map = jsonDecode(jsonStr);
    } catch (e) {
      Pam.log(["Push Message Parse Error", e.toString()]);
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
      DateTime date = DateTime.parse(dateString);

      bool isOpen = json["is_open"];

      var item = PamPushMessage(
          deliverID: deliverID,
          pixel: pixel,
          title: title,
          description: description,
          thumbnailUrl: thumbnailUrl,
          flex: flex,
          url: url,
          popupType: popupType,
          date: date,
          isOpen: isOpen,
          data: payloadJson);

      result.add(item);
    }

    return result;
  }
}
