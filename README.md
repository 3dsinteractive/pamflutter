# PAM Flutter SDK

A Flutter plugin for integrating PAM (Personalized Advertising Management) into your mobile applications.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Initialization](#initialization)
- [Core Features](#core-features)
  - [Consent Management](#consent-management)
  - [Push Notifications](#push-notifications)
  - [User Tracking](#user-tracking)
  - [App Attention](#app-attention)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Installation

### Prerequisites

- Flutter SDK version 3.3.0 or later
- Dart SDK version 3.6.0 or later

### Adding pam_flutter to Your Project

Open a terminal and run the following command to add `pam_flutter` to your Flutter project:

```sh
dart pub add pam_flutter
```

## Configuration

Create `lib/pam_config.dart` in your project and add the following code:

```dart
import 'package:pam_flutter/pam.dart';

class PamConfigProvider {
  static PamConfig getConfig() {
    // Replace the following values with your configuration
    const endpoint = "https://[YOUR-DOMAIN]pams.ai";
    const publicDBAlias = "[PAM-PUBLIC-DB-FROM-PAM-CMS]";
    const loginDBAlias = "[PAM-LOGIN-DB-FROM-PAM-CMS]";
    const trackingConsentMessageID = "[CONSENT-MESSAGE-ID-FROM-PAM-CMS]";

    const debugMode = true; // Enable logs

    return PamConfig(endpoint, publicDBAlias, loginDBAlias,
        trackingConsentMessageID, debugMode);
  }
}
```

## Initialization

In your `main.dart` file, add the following code to the `main()` function to initialize the PAM library:

```dart
import 'package:flutter/material.dart';
import 'package:pam_flutter/pam.dart';
import 'pam_config.dart';

void main() async {
  // Initialize PAM
  var pamConfig = PamConfigProvider.getConfig();
  await Pam.initialize(pamConfig);

  runApp(const MyApp());
}
```

## Core Features

### Consent Management

To handle user consent in compliance with PDPA or GDPR laws, you can use the following example code in your application:

#### Tracking Consent

Tracking Consent allows users to grant permission for tracking events or user behavior. Use the following example code to implement tracking consent in your application:

```dart
import 'package:pam_flutter/pam.dart';

Future<SubmitConsentResult?> allowTrackingConsent() async {
  var trackingConsentMessageID = "[YOUR-TRACKING-CONSENT-MSG-ID]";
  var trackingConsent = await Pam.loadConsentMessage(trackingConsentMessageID);
  trackingConsent?.allowAll();

  if (trackingConsent != null) {
    var result = await Pam.submitConsent(trackingConsent);
    return result;
  }
  return null;
}
```

> Reminder: Replace [YOUR-TRACKING-CONSENT-MSG-ID] with your actual tracking consent message ID from your PAM CMS.

#### Contacting Consent

Contacting Consent allows users to grant permission for communication for marketing purposes. Use the following example code to implement contacting consent in your application:

```dart
import 'package:pam_flutter/pam.dart';

Future<SubmitConsentResult?> allowContactingConsent() async {
  var contactingConsentMessageID = "[YOUR-CONTACTING-CONSENT-MSG-ID]";
  var contactingConsent =
      await Pam.loadConsentMessage(contactingConsentMessageID);
  contactingConsent?.allowAll();

  if (contactingConsent != null) {
    var result = await Pam.submitConsent(contactingConsent);
    return result;
  }
  return null;
}
```

> Reminder: Replace [YOUR-CONTACTING-CONSENT-MSG-ID] with your actual contacting consent message ID from your PAM CMS.

### Push Notifications

#### Saving Push Notification Token

If your application uses push notifications, it's essential to save the device's push notification token to PAM. Follow these steps to ensure proper integration:

```dart
import 'package:pam_flutter/pam.dart';

// Obtain the push notification token from your messaging service
var deviceToken = "[PUSH-NOTIFICATION-TOKEN]";

// Save the push notification token to PAM
Pam.setPushNotificationToken(deviceToken);
```

> Note: Replace [PUSH-NOTIFICATION-TOKEN] with the actual push notification token obtained from your messaging service.

By saving the push notification token to PAM, you enable the system to deliver personalized notifications to users.

#### Handling Push Notifications

Since Flutter focuses on working with push notifications through Firebase, you can integrate PAM push notifications as follows:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pam_flutter/pam.dart';

// In your Firebase messaging handler
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Check if the push notification is from PAM
  if (Pam.isPushNotiFromPam(message.data)) {
    // Convert to PAM push message
    var pamMessage = Pam.convertToPamPushMessage(message.data);
    if (pamMessage != null) {
      // Handle the PAM push message
      // For example, show a custom notification or perform actions
      print('Received PAM push: ${pamMessage.title}');

      // Optionally track that the message was read
      pamMessage.trackRead();
    }
  } else {
    // Handle non-PAM notifications
  }
});
```

This allows you to check if an incoming push notification is from PAM and convert it to a `PamPushMessage` for further processing.

#### Loading Notification History and Tracking Read Status

To load the notification history sent from the PAM system, follow these steps. Please note that the inbox data retrieved is only the raw data, and you'll need to implement the UI to display it.

##### Load Inbox Data by Email

```dart
import 'package:pam_flutter/pam.dart';

// Load inbox data using the user's email
var userInbox = await Pam.loadPushNotificationsFromEmail("[USER-EMAIL]");
```

##### Load Inbox Data by Mobile Number

```dart
import 'package:pam_flutter/pam.dart';

// Load inbox data using the user's mobile number
var userInbox = await Pam.loadPushNotificationsFromMobile("[USER-MOBILE]");
```

> Reminder: Replace [USER-EMAIL] or [USER-MOBILE] with the actual user's email or mobile number to retrieve their respective inbox.

The userInbox variable will contain an array of messages sent from the PAM system.

##### Track Read Status

```dart
import 'package:pam_flutter/pam.dart';

// Track read status for the first message in the inbox
userInbox?[0].trackRead();
```

> By calling trackRead(), you can keep track of whether the user has opened or read the specific message.

> Note: Implement the UI to display the inbox messages as needed.

### User Tracking

#### Signaling User Login

When a user logs into your application, it's important to signal this event to PAM. This helps in associating user activities with their identity for better analytics. Follow these steps to signal user login:

```dart
import 'package:pam_flutter/pam.dart';

// Login key, for example, if your PAM's database uses email to identify users, you can use the user's email
var userIdentity = "[YOUR-LOGIN-IDENTITY]";

// Signal user login to PAM
Pam.userLogin(userIdentity);
```

> Note: Replace [YOUR-LOGIN-IDENTITY] with the actual login identity of the user, such as their email or any unique identifier.

By signaling user login to PAM, you ensure that user activities are tracked and associated with their identity for comprehensive analytics.

#### Signaling User Logout

When a user logs out of your application, it's important to signal this event to PAM. This helps in managing user sessions and ensures accurate analytics. Follow these steps to signal user logout:

```dart
import 'package:pam_flutter/pam.dart';

// Signal user logout to PAM
Pam.userLogout();
```

By signaling user logout to PAM, you contribute to the accurate tracking of user activities and ensure that the analytics reflect the user's session status.

#### Tracking User Events

To track user events and activities, follow these steps:

##### Send Event with Payload

Use the following example code to send an event with a payload:

```dart
import 'package:pam_flutter/pam.dart';

void trackEvent() {
  var eventName = "purchase";
  var payload = {
    "product_name": "pizza",
    "size": "big",
    "price": 300
  };
  Pam.track(eventName, payload: payload);
}
```

In this example, the eventName is set to "purchase," and the payload contains additional data related to the purchase event. You can customize the event name and payload based on the specific user activity you want to track.

By calling Pam.track(), you send the event data to PAM for analytics.

### App Attention

App Attention is a comprehensive solution for integrating custom promotional popups into your mobile applications. This feature allows you to display banners, videos, and promotional messages directly within your app, helping to increase user engagement, highlight special offers, and drive traffic to specific URLs.

Designed for flexibility, App Attention provides developers with the ability to customize popup behavior, such as displaying full-screen media or small promotional messages. It supports handling user interactions, such as opening external links or triggering custom app events, ensuring seamless integration into your app's user experience.

#### How to Use

To integrate App Attention into your Flutter application, follow the steps below:

##### Display App Attention

Call the `Pam.appAttention` method to display the App Attention popup. This function can be used to fetch and show banners, videos, or promotional messages based on the pageName you specify.

Here’s an example of how to implement it in your app:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Display App Attention if it exists
    Pam.appAttention(
      context,
      pageName: "home", // Specify the page name for dynamic banners
      onBannerClick: (bannerData) {
        // Handle banner click
        print("CLICK LEARN MORE.");
        print(bannerData.toString());

        // Return true if you want to stop the default behavior (e.g., opening the URL)
        // Return false to allow the default behavior (open URL in browser)
        return false;
      },
    );

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
```

##### Explanation

- `context`: The BuildContext of the current widget tree.
- `pageName`: A string that specifies the current page name, allowing dynamic banners tailored to specific app pages.
- `onBannerClick`: A callback function triggered when the user interacts with the banner. It receives `bannerData` as a parameter, which contains details about the clicked banner. The callback can:
  - Return `true` to stop the default behavior (e.g., open a custom page in your app).
  - Return `false` to proceed with the default behavior (e.g., open the provided URL in the browser).

## API Reference

For detailed API documentation, please refer to the source code and inline comments in the `lib/` directory.

## Examples

Check the `example/` directory for a complete sample application demonstrating the usage of pam_flutter.

## Troubleshooting

- **Configuration Issues**: Ensure all values in `pam_config.dart` are correct, including endpoint, database aliases, and consent message IDs.
- **Debugging**: Set `debugMode = true` to enable logs in the console for debugging.
- **Network and Permissions**: Check internet connection and required permissions (e.g., for push notifications on iOS/Android).
- **PAM CMS Verification**: Verify that keys, IDs, and settings in PAM CMS match your config.
- **Error Checking**: Look for error messages in the console or logs for more details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
