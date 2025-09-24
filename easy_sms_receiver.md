easy_sms_receiver: ^0.0.2

Use this package as a library
Depend on it
Run this command:

With Flutter:

$ flutter pub add easy_sms_receiver
This will add a line like this to your package's pubspec.yaml (and run an implicit flutter pub get):

dependencies:
easy_sms_receiver: ^0.0.2
Alternatively, your editor might support flutter pub get. Check the docs for your editor to learn more.

Import it
Now in your Dart code, you can use:

import 'package:easy_sms_receiver/easy_sms_receiver.dart';

easy_sms_receiver #
Note: ❗This plugin currently only works on Android Platform
pub package

Flutter plugin to listen and read incoming SMS on Android

Usage
To use this plugin add easy_sms_receiver as a dependency in your pubspec.yaml file.

Add permission_handler as a dependency in your project to request SMS permission.

Add flutter_background_service as a dependency in your project to listen for incoming SMS in the background.

Setup
Import the easy_sms_receiver package

import 'package:easy_sms_receiver/easy_sms_receiver.dart';
Retrieve the singleton instance of easy_sms_receiver by calling

final EasySmsReceiver easySmsReceiver = EasySmsReceiver.instance;
Permissions
This plugin requires SMS permission to be able to read incoming SMS.

So use permission_handler to request SMS permission:

final permissionStatus = await Permission.sms.request();
Note: The plugin will only request those permission that are listed in the AndroidManifest.xml so you must add this permission to your android/app/src/main/AndroidManifest.xml file:

<manifest>
	<uses-permission android:name="android.permission.RECEIVE_SMS"/>

    <application>
    	...
    	...
    </application>

</manifest>
Start the sms receiver to Listen to incoming SMS 
After add RECEIVE_SMS permission to your AndroidManifest.xml and request sms permission by permission_handler.

You can use the listenIncomingSms function to start listening for incoming SMS:

final easySmsReceiver = EasySmsReceiver.instance;
easySmsReceiver.listenIncomingSms(
onNewMessage: (message) {
// do something
},
);
Listen to incoming SMS in background
\*\*You can use the flutter_background_service plugin to listen for incoming SMS in the background as follow:

import 'package:flutter/material.dart';
import 'package:easy_sms_receiver/easy_sms_receiver.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// function to initialize the background service
Future<void> initializeService() async {
final service = FlutterBackgroundService();

await service.configure(
iosConfiguration: IosConfiguration(),
androidConfiguration: AndroidConfiguration(
onStart: onStart,
isForegroundMode: true,
autoStart: true,
),
);
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
DartPluginRegistrant.ensureInitialized();

final plugin = EasySmsReceiver.instance;
plugin.listenIncomingSms(
onNewMessage: (message) {
print("You have new message:");
print("::::::Message Address: ${message.address}");
print("::::::Message body: ${message.body}");

      // do something

      // for example: show notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: message.address ?? "address",
          content: message.body ?? "body",
        );
      }
    },

);
}

void main() async {
WidgetsFlutterBinding.ensureInitialized();

// request the SMS permission, then initialize the background service
Permission.sms.request().then((status) {
if (status.isGranted) initializeService();
});
runApp(const MyApp());
}
Stop the sms receiver
You can stop the listening to incoming SMS by calling the stopListenIncomingSms function as follow:

easySmsReceiver.stopListenIncomingSms();
Look at the example

EXAMPLES:

Readme
Changelog
Example
Installing
Versions
Scores
example/lib/main.dart

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:easy_sms_receiver/easy_sms_receiver.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
WidgetsFlutterBinding.ensureInitialized();
runApp(const MyApp());
}

class MyApp extends StatefulWidget {
const MyApp({super.key});

@override
State<MyApp> createState() => \_MyAppState();
}

class \_MyAppState extends State<MyApp> {
final EasySmsReceiver easySmsReceiver = EasySmsReceiver.instance;
String \_easySmsReceiverStatus = "Undefined";
String \_message = "";

@override
void initState() {
super.initState();
}

Future<bool> requestSmsPermission() async {
return await Permission.sms.request().then(
(PermissionStatus pStatus) {
if (pStatus.isPermanentlyDenied) {
// "You must allow sms permission"
openAppSettings();
}
return pStatus.isGranted;
},
);
}

Future<void> startSmsReceiver() async {
// Platform messages may fail, so we use a try/catch PlatformException.
if (await requestSmsPermission()) {
easySmsReceiver.listenIncomingSms(
onNewMessage: (message) {
print("You have new message:");
print("::::::Message Address: ${message.address}");
print("::::::Message body: ${message.body}");

          if (!mounted) return;

          setState(() {
            _message = message.body ?? "Error reading message body.";
          });
        },
      );

      // If the widget was removed from the tree while the asynchronous platform
      // message was in flight, we want to discard the reply rather than calling
      // setState to update our non-existent appearance.
      if (!mounted) return;

      setState(() {
        _easySmsReceiverStatus = "Running";
      });
    }

}

void stopSmsReceiver() {
easySmsReceiver.stopListenIncomingSms();
if (!mounted) return;

    setState(() {
      _easySmsReceiverStatus = "Stopped";
    });

}

final plugin = EasySmsReceiver.instance;
@override
Widget build(BuildContext context) {
return MaterialApp(
home: Scaffold(
appBar: AppBar(title: const Text('Plugin example app')),
body: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text("Latest Received SMS: $_message"),
Text('EasySmsReceiver Status: $_easySmsReceiverStatus\n'),
TextButton(
onPressed: startSmsReceiver, child: Text("Start Receiver")),
TextButton(
onPressed: stopSmsReceiver, child: Text("Stop Receiver")),
],
),
),
),
);
}
}
