import '../src/pam_log_request.dart';
import '../http/http_client.dart';
import '../response/pam_push_message.dart';
import '../pam.dart';
import 'package:http/http.dart' show Response;

class PamPushNotificationAPI {
  String baseURL;

  PamPushNotificationAPI(this.baseURL);

  Future<void> read(String? pixel) async {
    if (pixel != null) {
      var uri = Uri.parse(pixel);
      await HttpClient.get(uri);
    }
  }

  Future<List<PamPushMessage>?> loadPushNotificationsFromMobile(
    String mobileNumber,
  ) async {
    Response? response;
    var db = await Pam.shared.getDatabaseAlias();
    var contact = await Pam.shared.getContactID();
    final log = PamLogRequest(
      PamLogCategory.push,
      'GET /api/app-notifications',
      details: {
        'server': Uri.tryParse(baseURL)?.host,
        'database': db,
        'contact_id': contact,
        'match': 'sms',
      },
    );
    try {
      var uri = Uri.parse(
        "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&sms=$mobileNumber",
      );
      response = await HttpClient.get(uri);

      log.complete(response.statusCode, body: response.body);
    } catch (e, stackTrace) {
      log.fail(e, stackTrace);
    }

    if (response != null) {
      return PamPushMessage.parse(response.body);
    }

    return null;
  }

  Future<List<PamPushMessage>?> loadPushNotificationsFromEmail(
    String email,
  ) async {
    Response? response;
    var db = await Pam.shared.getDatabaseAlias();
    var contact = await Pam.shared.getContactID();

    final log = PamLogRequest(
      PamLogCategory.push,
      'GET /api/app-notifications',
      details: {
        'server': Uri.tryParse(baseURL)?.host,
        'database': db,
        'contact_id': contact,
        'match': 'email',
      },
    );
    try {
      var uri = Uri.parse(
        "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&email=$email",
      );
      response = await HttpClient.get(uri);
      log.complete(response.statusCode, body: response.body);
    } catch (e, stackTrace) {
      log.fail(e, stackTrace);
    }

    if (response != null) {
      return PamPushMessage.parse(response.body);
    }

    return null;
  }

  Future<List<PamPushMessage>?> loadPushNotificationsFromCustomerID(
    String customer,
  ) async {
    Response? response;
    var db = await Pam.shared.getDatabaseAlias();
    var contact = await Pam.shared.getContactID();
    final log = PamLogRequest(
      PamLogCategory.push,
      'GET /api/app-notifications',
      details: {
        'server': Uri.tryParse(baseURL)?.host,
        'database': db,
        'contact_id': contact,
        'match': 'customer',
      },
    );
    try {
      var uri = Uri.parse(
        "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&customer=$customer",
      );
      response = await HttpClient.get(uri);
      log.complete(response.statusCode, body: response.body);
    } catch (e, stackTrace) {
      log.fail(e, stackTrace);
    }

    if (response != null) {
      return PamPushMessage.parse(response.body);
    }

    return null;
  }

  Future<List<PamPushMessage>?> loadPushNotifications() async {
    Response? response;
    var db = await Pam.shared.getDatabaseAlias();
    var contact = await Pam.shared.getContactID();
    final log = PamLogRequest(
      PamLogCategory.push,
      'GET /api/app-notifications',
      details: {
        'server': Uri.tryParse(baseURL)?.host,
        'database': db,
        'contact_id': contact,
        'match': 'contact',
      },
    );
    try {
      var uri = Uri.parse(
        "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact",
      );
      response = await HttpClient.get(uri);
      log.complete(response.statusCode, body: response.body);
    } catch (e, stackTrace) {
      log.fail(e, stackTrace);
    }

    if (response != null) {
      return PamPushMessage.parse(response.body);
    }

    return null;
  }
}
