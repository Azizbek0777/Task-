import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}


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
  double totalDistance = 0;
  DartPluginRegistrant.ensureInitialized();

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
  Position lastLocation = await Geolocator.getCurrentPosition();
  DateTime lastTimestamp = DateTime.now();

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final isStart = preferences.getBool('Start') ?? false;
    DateTime currentTimestamp = DateTime.now();
    Position currentLocation = await Geolocator.getCurrentPosition();
    if (isStart) {
      totalDistance += calculateDistance(lastLocation.latitude, lastLocation.longitude, currentLocation.latitude, currentLocation.longitude);
      lastTimestamp = currentTimestamp;
      lastLocation = currentLocation;
      service.invoke(
        'update',
        {
          "device": totalDistance.toStringAsFixed(2),
        },
      );
    } else {
      double stopDistance = calculateDistance(lastLocation.latitude, lastLocation.longitude, currentLocation.latitude, currentLocation.longitude);
      num timeDiff = currentTimestamp.difference(lastTimestamp).inSeconds;
      double speed = ((stopDistance) / timeDiff) * 3600;
      if (speed >= 30) {
        preferences.setBool("Start", true);
        totalDistance += calculateDistance(lastLocation.latitude, lastLocation.longitude, currentLocation.latitude, currentLocation.longitude);
        lastTimestamp = currentTimestamp;
        lastLocation = currentLocation;
        service.invoke(
          'update',
          {
            "device": totalDistance.toStringAsFixed(2),
          },
        );
      }
    }
  });
}

double calculateDistance(lat1, lon1, lat2, lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}