Readme
Changelog
Example
Installing
Versions
Scores

README:

A flutter plugin for execute dart code in background.

Support me to maintain this plugin continously with a cup of coffee.
"Buy Me A Coffee"

Android
To change notification icon, just add drawable icon with name ic_bg_service_small.
WARNING:

Please make sure your project already use the version of gradle tools below:

in android/build.gradle classpath 'com.android.tools.build:gradle:7.4.2'
in android/build.gradle ext.kotlin_version = '1.8.10'
in android/gradle/wrapper/gradle-wrapper.properties distributionUrl=https\://services.gradle.org/distributions/gradle-7.5-all.zip
Configuration required for Foreground Services on Android 14 (SDK 34)
Applications that target SDK 34 and use foreground services need to include some additional configuration to declare the type of foreground service they use:

Determine the type of foreground service your app requires by consulting the documentation

Add the corresponding permission to your android/app/src/main/AndroidManifest.xml file:

<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools" package="com.example">
  ...
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
  <!--
    Permission to use here depends on the value you picked for foregroundServiceType - see the Android documentation.
    Eg, if you picked 'location', use 'android.permission.FOREGROUND_SERVICE_LOCATION'
  -->
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_..." />
  <application
        android:label="example"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        ...>

        <activity
            android:name=".MainActivity"
            android:exported="true"
            ...>

        <!--Add this-->
        <service
            android:name="id.flutter.flutter_background_service.BackgroundService"
            android:foregroundServiceType="WhatForegroundServiceTypeDoYouWant"
        />
        <!--end-->

        ...

...
</application>
</manifest>
WARNING:

YOU MUST MAKE SURE ANY REQUIRED PERMISSIONS TO BE GRANTED BEFORE YOU START THE SERVICE
Using custom notification for Foreground Service
You can make your own custom notification for foreground service. It can give you more power to make notifications more attractive to users, for example adding progressbars, buttons, actions, etc. The example below is using flutter_local_notifications plugin, but you can use any other notification plugin. You can follow how to make it below:

Notification Channel

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();
await initializeService();

    runApp(MyApp());

}

// this will be used as notification channel id
const notificationChannelId = 'my_foreground';

// this will be used for notification id, So you can update your custom notification with this id.
const notificationId = 888;

Future<void> initializeService() async {
final service = FlutterBackgroundService();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
notificationChannelId, // id
'MY FOREGROUND SERVICE', // title
description:
'This channel is used for important notifications.', // description
importance: Importance.low, // importance must be at low or higher level
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

await flutterLocalNotificationsPlugin
.resolvePlatformSpecificImplementation<
AndroidFlutterLocalNotificationsPlugin>()
?.createNotificationChannel(channel);

await service.configure(
androidConfiguration: AndroidConfiguration(
// this will be executed when app is in foreground or background in separated isolate
onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId: notificationChannelId, // this must match with notification channel you created above.
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: notificationId,
    ),
    ...

Update notification info

Future<void> onStart(ServiceInstance service) async {
// Only available for flutter 3.0.0 and later
DartPluginRegistrant.ensureInitialized();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// bring to foreground
Timer.periodic(const Duration(seconds: 1), (timer) async {
if (service is AndroidServiceInstance) {
if (await service.isForegroundService()) {
flutterLocalNotificationsPlugin.show(
notificationId,
'COOL SERVICE',
'Awesome ${DateTime.now()}',
const NotificationDetails(
android: AndroidNotificationDetails(
notificationChannelId,
'MY FOREGROUND SERVICE',
icon: 'ic_bg_service_small',
ongoing: true,
),
),
);
}
}
});
}
Using Background Service Even when The Application Is Closed
You can use this feature in order to execute code in background. Very useful to fetch realtime data from a server and push notifications.

Must Know:

isForegroundMode: false : The background mode requires running in release mode and requires disabling battery optimization so that the service stays up when the user closes the application.
isForegroundMode: true : Displays a silent notification when used according to Android's Policy
Simple implementation using Socket.io
import 'dart:async';
import 'dart:ui';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();
await initializeService();

    runApp(MyApp());

}

void startBackgroundService() {
final service = FlutterBackgroundService();
service.startService();
}

void stopBackgroundService() {
final service = FlutterBackgroundService();
service.invoke("stop");
}

Future<void> initializeService() async {
final service = FlutterBackgroundService();

await service.configure(
iosConfiguration: IosConfiguration(
autoStart: true,
onForeground: onStart,
onBackground: onIosBackground,
),
androidConfiguration: AndroidConfiguration(
autoStart: true,
onStart: onStart,
isForegroundMode: false,
autoStartOnBoot: true,
),
);
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
WidgetsFlutterBinding.ensureInitialized();
DartPluginRegistrant.ensureInitialized();

return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
final socket = io.io("your-server-url", <String, dynamic>{
'transports': ['websocket'],
'autoConnect': true,
});
socket.onConnect((\_) {
print('Connected. Socket ID: ${socket.id}');
// Implement your socket logic here
// For example, you can listen for events or send data
});

socket.onDisconnect((\_) {
print('Disconnected');
});
socket.on("event-name", (data) {
//do something here like pushing a notification
});
service.on("stop").listen((event) {
service.stopSelf();
print("background process is now stopped");
});

service.on("start").listen((event) {});

Timer.periodic(const Duration(seconds: 1), (timer) {
socket.emit("event-name", "your-message");
print("service is successfully running ${DateTime.now().second}");
});
}

INSTALL:
Use this package as a library
Depend on it
Run this command:

With Flutter:

$ flutter pub add flutter_background_service
This will add a line like this to your package's pubspec.yaml (and run an implicit flutter pub get):

dependencies:
flutter_background_service: ^5.1.0
Alternatively, your editor might support flutter pub get. Check the docs for your editor to learn more.

Import it
Now in your Dart code, you can use:

import 'package:flutter_background_service/flutter_background_service.dart';

EXAMPLES:

example/lib/main.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();
await initializeService();
runApp(const MyApp());
}

Future<void> initializeService() async {
final service = FlutterBackgroundService();

/// OPTIONAL, using custom notification channel id
const AndroidNotificationChannel channel = AndroidNotificationChannel(
'my_foreground', // id
'MY FOREGROUND SERVICE', // title
description:
'This channel is used for important notifications.', // description
importance: Importance.low, // importance must be at low or higher level
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

if (Platform.isIOS || Platform.isAndroid) {
await flutterLocalNotificationsPlugin.initialize(
const InitializationSettings(
iOS: DarwinInitializationSettings(),
android: AndroidInitializationSettings('ic_bg_service_small'),
),
);
}

await flutterLocalNotificationsPlugin
.resolvePlatformSpecificImplementation<
AndroidFlutterLocalNotificationsPlugin>()
?.createNotificationChannel(channel);

await service.configure(
androidConfiguration: AndroidConfiguration(
// this will be executed when app is in foreground or background in separated isolate
onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),

);
}

// to ensure this is executed
// run app from xcode, then from xcode menu, select Simulate Background Fetch

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
WidgetsFlutterBinding.ensureInitialized();
DartPluginRegistrant.ensureInitialized();

SharedPreferences preferences = await SharedPreferences.getInstance();
await preferences.reload();
final log = preferences.getStringList('log') ?? <String>[];
log.add(DateTime.now().toIso8601String());
await preferences.setStringList('log', log);

return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
// Only available for flutter 3.0.0 and later
DartPluginRegistrant.ensureInitialized();

// For flutter prior to version 3.0.0
// We have to register the plugin manually

SharedPreferences preferences = await SharedPreferences.getInstance();
await preferences.setString("hello", "world");

/// OPTIONAL when use custom notification
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

if (service is AndroidServiceInstance) {
service.on('setAsForeground').listen((event) {
service.setAsForegroundService();
});

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

}

service.on('stopService').listen((event) {
service.stopSelf();
});

// bring to foreground
Timer.periodic(const Duration(seconds: 1), (timer) async {
if (service is AndroidServiceInstance) {
if (await service.isForegroundService()) {
/// OPTIONAL for use custom notification
/// the notification id must be equals with AndroidConfiguration when you call configure() method.
flutterLocalNotificationsPlugin.show(
888,
'COOL SERVICE',
'Awesome ${DateTime.now()}',
const NotificationDetails(
android: AndroidNotificationDetails(
'my_foreground',
'MY FOREGROUND SERVICE',
icon: 'ic_bg_service_small',
ongoing: true,
),
),
);

        // if you don't using custom notification, uncomment this
        service.setForegroundNotificationInfo(
          title: "My App Service",
          content: "Updated at ${DateTime.now()}",
        );
      }
    }

    /// you can see this log in logcat
    debugPrint('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    // test using external plugin
    final deviceInfo = DeviceInfoPlugin();
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device,
      },
    );

});
}

class MyApp extends StatefulWidget {
const MyApp({Key? key}) : super(key: key);

@override
State<MyApp> createState() => \_MyAppState();
}

class \_MyAppState extends State<MyApp> {
String text = "Stop Service";
@override
Widget build(BuildContext context) {
return MaterialApp(
home: Scaffold(
appBar: AppBar(
title: const Text('Service App'),
),
body: Column(
children: [
StreamBuilder<Map<String, dynamic>?>(
stream: FlutterBackgroundService().on('update'),
builder: (context, snapshot) {
if (!snapshot.hasData) {
return const Center(
child: CircularProgressIndicator(),
);
}

                final data = snapshot.data!;
                String? device = data["device"];
                DateTime? date = DateTime.tryParse(data["current_date"]);
                return Column(
                  children: [
                    Text(device ?? 'Unknown'),
                    Text(date.toString()),
                  ],
                );
              },
            ),
            ElevatedButton(
              child: const Text("Foreground Mode"),
              onPressed: () =>
                  FlutterBackgroundService().invoke("setAsForeground"),
            ),
            ElevatedButton(
              child: const Text("Background Mode"),
              onPressed: () =>
                  FlutterBackgroundService().invoke("setAsBackground"),
            ),
            ElevatedButton(
              child: Text(text),
              onPressed: () async {
                final service = FlutterBackgroundService();
                var isRunning = await service.isRunning();
                isRunning
                    ? service.invoke("stopService")
                    : service.startService();

                setState(() {
                  text = isRunning ? 'Start Service' : 'Stop Service';
                });
              },
            ),
            const Expanded(
              child: LogView(),
            ),
          ],
        ),
      ),
    );

}
}

class LogView extends StatefulWidget {
const LogView({Key? key}) : super(key: key);

@override
State<LogView> createState() => \_LogViewState();
}

class \_LogViewState extends State<LogView> {
late final Timer timer;
List<String> logs = [];

@override
void initState() {
super.initState();
timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
final SharedPreferences sp = await SharedPreferences.getInstance();
await sp.reload();
logs = sp.getStringList('log') ?? [];
if (mounted) {
setState(() {});
}
});
}

@override
void dispose() {
timer.cancel();
super.dispose();
}

@override
Widget build(BuildContext context) {
return ListView.builder(
itemCount: logs.length,
itemBuilder: (context, index) {
final log = logs.elementAt(index);
return Text(log);
},
);
}
}
