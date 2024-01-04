import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:flutter_ffmpeg/media_information.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late StreamedResponse response;
  late Stream<List<int>> stream;
  late StreamSubscription<List<int>> subscription;
  int receivedBytes = 0;

  String path = '';
  final url =
      'https://cms-oss.sgmlink.com/60078b016c250/6589953fc1acded5cd1884e0/21.mp4';

  @override
  void initState() {
    init();
    super.initState();
  }

  Future<void> init() async {
    [
      Permission.storage,
    ].request();
    final List<Directory>? listDirectory =
    await getExternalStorageDirectories(type: StorageDirectory.downloads);
    path = "${listDirectory?[0].path}/11.mp4";
    print('$path');
  }

  Future<bool> isVideoFileValid(String filePath) async {
    final FlutterFFprobe _flutterFFprobe = FlutterFFprobe();

    final MediaInformation mediaInformation = await _flutterFFprobe
        .getMediaInformation(filePath);

    final Map<dynamic, dynamic>? format = mediaInformation.getMediaProperties();
    // print('$format');
    // final int? duration = format?['duration']?.toInt();


    // return duration != null && duration > 0;
    return format != null;
  }

  Future<int> _getTotalLength(String url) async {
    final response = await http.head(Uri.parse(url));
    return int.parse(response.headers['content-length'] ?? '0');
  }

  Future<void> startDownload(String url) async {
    final file = File(path);
    print('start download: path:$path');
    int totalLength = await _getTotalLength(url);
    print('totalLength:$totalLength');
    int downloadedBytes = 0;
    bool isFileValid = false;
    if (file.existsSync()) {
      isFileValid = await isVideoFileValid(path);
      if (!isFileValid) {
        downloadedBytes = 0;
      } else {
        downloadedBytes = await file.length();
      }
    }
    print('downloadedBytes:$downloadedBytes');
    receivedBytes = downloadedBytes;

    if (downloadedBytes > totalLength) {
      downloadedBytes = 0;
      receivedBytes = 0;
      isFileValid = false;
    }

    if (downloadedBytes < totalLength || !isFileValid) {
      await _resumeDownload(url, downloadedBytes);
      saveStreamToFile(
          totalLength, mode: isFileValid ? FileMode.append : FileMode.write);
    }
  }

  Future<dynamic> _resumeDownload(String url, int downloadedBytes) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Range'] = 'bytes=$downloadedBytes-';
    response = await http.Client().send(request);
    return response;
  }

  Future<void> saveStreamToFile(int totalLength,
      {FileMode mode = FileMode.write}) async {
    final file = File(path);
    final fileStream = file.openWrite(mode: mode);
    subscription = response.stream.listen(
          (List<int> chunk) {
        fileStream.add(chunk);
        receivedBytes += chunk.length;
        final progress = ((receivedBytes / totalLength) * 100).toStringAsFixed(
            2);
        print('Downloaded: $progress%');
      },
      onDone: () {
        fileStream.close();
        print('Download complete');
      },
      onError: (error) {
        fileStream.close();
        print('Error during download: $error');
      },
    );
  }

  void pauseDownload() {
    subscription.pause();
  }

  void resumeDownload() {
    subscription.resume();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Wrap(
          spacing: 20,
          children: [
            MaterialButton(
              onPressed: () {
                startDownload(url);
              },
              child: Text("下载"),
              color: Colors.grey,
            ),
            MaterialButton(
              onPressed: () {
                pauseDownload();
              },
              child: Text("暂停"),
              color: Colors.grey,
            ),
            MaterialButton(
              onPressed: () {
                resumeDownload();
              },
              child: Text("恢复"),
              color: Colors.grey,
            ),
          ],
        ),
      ),
// This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
