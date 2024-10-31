import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await determinePosition();
  await GetStorage.init();
  await initializeService();
  runApp(const MyApp());
}

Future<Position> determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('Location permissions are permanently denied, we cannot request permissions.');
  }
  return await Geolocator.getCurrentPosition();
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String text = "Boshlash";
  bool isPaused = false;


  @override
  Widget build(BuildContext context) {
    // textFunction();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Service App'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: double.infinity),
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
                // DateTime? date = DateTime.tryParse(data["current_date"]);
                return Column(
                  children: [
                    Text(
                      device ?? 'Unknown',
                      style: TextStyle(color: Colors.black, fontSize: 40),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 50),
            TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: () async {
                  SharedPreferences preferences = await SharedPreferences.getInstance();
                  final service = FlutterBackgroundService();
                  bool isStart = preferences.getBool('Start') ?? false;
                  var isRunning = await service.isRunning();
                  if (isRunning) {
                    if (isStart) {
                      isPaused = false;
                      preferences.setBool("Start", false);
                    } else {
                      preferences.setBool("Start", true);
                      isPaused = true;
                    }
                  }
                  setState(() {});
                },
                child: Icon(
                  isPaused ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                )),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              child: Text(
                text,
                style: const TextStyle(color: Colors.black, fontSize: 40),
              ),
              onPressed: () async {
                SharedPreferences preferences = await SharedPreferences.getInstance();
                final service = FlutterBackgroundService();
                var isRunning = await service.isRunning();
                isRunning ? service.invoke("stopService") : service.startService();
                if (!isRunning) {
                  preferences.setBool("Start", true);
                  isPaused = true;
                }
                print('_MyAppState.build isRunning $isRunning');
                setState(() {
                  text = isRunning ? 'Boshlash' : 'Tugatish';
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
