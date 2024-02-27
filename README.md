# Add pam_flutter to Your Project

To integrate `pam_flutter` into your Flutter project, follow these steps:

## Step 1: Add pam_flutter to Your Project

Open a terminal and run the following command to add `pam_flutter` to your Flutter project:

```sh
dart pub add pam_flutter
```

## Step 2: Configure the Library

- 2.1 Create `lib/pam_config.dart` in Your Project.
- 2.2 Add the Following Code to `lib/pam_config.dart`

```dart
import 'package:pam_flutter/pam.dart';

class PamConfigProvider {
  static PamConfig getConfig() {
    // Replace the following values with your configuration
    const endpoint = "https://[YOUR-DOMAIN]pams.ai";
    const publicDBAlias = "[PAM-PUBLIC-DB-FROM-PAM-CMS]";
    const loginDBAlias = "[PAM-LOGIN-DB-FROM-PAM-CMS]";
    const trackingConsentMessageID = "[CONSENT-MESSAGE-ID-FROM-PAM-CMS]";

    const debugMode = true; // Enabled log

    return PamConfig(endpoint, publicDBAlias, loginDBAlias,
        trackingConsentMessageID, debugMode);
  }
}
```

## Step 3: Initialize the pam_flutter Library

In your main.dart file, add the following code to the main() function to initialize the PAM library:

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

## Step 4: Submit User Consent for PDPA/GDPR Compliance

To handle user consent in compliance with PDPA or GDPR laws, you can use the following example code in your application:

### 4.1 Tracking Consent

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

### 4.2 Contacting Consent

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

## Step 5: Save Push Notification Token to PAM

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

## Step 6: Signal User Login to PAM

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

## Step 7: Signal User Logout to PAM

When a user logs out of your application, it's important to signal this event to PAM. This helps in managing user sessions and ensures accurate analytics. Follow these steps to signal user logout:

```dart
import 'package:pam_flutter/pam.dart';

// Signal user logout to PAM
Pam.userLogout();
```

By signaling user logout to PAM, you contribute to the accurate tracking of user activities and ensure that the analytics reflect the user's session status.

## Step 8: Load Notification History and Track Read Status

To load the notification history sent from the PAM system, follow these steps. Please note that the inbox data retrieved is only the raw data, and you'll need to implement the UI to display it.

### 8.1 Load Inbox Data by Email

```dart
import 'package:pam_flutter/pam.dart';

// Load inbox data using the user's email
var userInbox = await Pam.loadPushNotificationsFromEmail("[USER-EMAIL]");
```

### 8.2 Load Inbox Data by Mobile Number

```dart
import 'package:pam_flutter/pam.dart';

// Load inbox data using the user's mobile number
var userInbox = await Pam.loadPushNotificationsFromMobile("[USER-MOBILE]");
```

> Reminder: Replace [USER-EMAIL] or [USER-MOBILE] with the actual user's email or mobile number to retrieve their respective inbox.

The userInbox variable will contain an array of messages sent from the PAM system.

### 8.3 Track Read Status

```dart
import 'package:pam_flutter/pam.dart';

// Track read status for the first message in the inbox
userInbox?[0].trackRead();
```

> By calling trackRead(), you can keep track of whether the user has opened or read the specific message.

> Note: Implement the UI to display the inbox messages as needed.

## Step 9: Track User Events

To track user events and activities, follow these steps:

### 9.1 Send Event with Payload

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
