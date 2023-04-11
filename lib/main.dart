import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mlkit/mlkit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Get a list of available cameras.
  final cameras = await availableCameras();
  // Get the first camera from the list.
  final firstCamera = cameras.first;
  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatefulWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final FaceDetector _faceDetector;
  late final LiveFeedDetector _liveFeedDetector;
  late final CameraController _cameraController;
  late final StreamController<CameraImage> _imageStreamController;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    // Initialize face detector and live feed detector
    _faceDetector = FirebaseVision.instance.faceDetector();
    _liveFeedDetector = FirebaseVisionLiveFeed.instance.liveFeedDetector();
    // Initialize camera controller and image stream controller
    _cameraController =
        CameraController(widget.camera, ResolutionPreset.medium);
    _imageStreamController = StreamController<CameraImage>();
    _cameraController.startImageStream((image) {
      _imageStreamController.add(image);
    });
  }

  @override
  void dispose() {
    // Dispose of all resources
    _cameraController.dispose();
    _faceDetector.close();
    _liveFeedDetector.close();
    _imageStreamController.close();
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      // Increment the counter when button is pressed
      _isLive = !_isLive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Demo Home Page'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Liveliness: $_isLive',
                style: TextStyle(fontSize: 24.0),
              ),
              StreamBuilder<CameraImage>(
                stream: _imageStreamController.stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return CircularProgressIndicator();
                  }
                  FirebaseVisionImage visionImage =
                      FirebaseVisionImage.fromBytes(
                    snapshot.data!.planes[0].bytes,
                    FirebaseVisionImageMetadata(
                      rawFormat: snapshot.data!.format.raw,
                      size: Size(snapshot.data!.width.toDouble(),
                          snapshot.data!.height.toDouble()),
                      planeData: snapshot.data!.planes.map((plane) {
                        return FirebaseVisionImagePlaneMetadata(
                          bytesPerRow: plane.bytesPerRow,
                          height: plane.height,
                          width: plane.width,
                        );
                      }).toList(),
                    ),
                  );
                  // Perform face detection
                  _faceDetector.detectInImage(visionImage).then((faces) async {
                    if (faces.isNotEmpty) {
                      Face face = faces.first;
                      // Perform liveness detection
                      bool isLive = await _liveFeedDetector.detectLiveness(
                        visionImage,
                        Rect.fromLTRB(
                          face.boundingBox.left.toDouble(),
                          face.boundingBox.top.toDouble(),
                          face.boundingBox.right.toDouble(),
                          face.boundingBox.bottom.toDouble(),
                        ),
                      );
                      setState(() {
                        _isLive = isLive;
                      });
                    }
                  });
                  return AspectRatio(
                    aspectRatio: _cameraController.value.aspectRatio,
                    child: CameraPreview(_cameraController),
                  );
                },
              ),
              ElevatedButton(
                onPressed: _incrementCounter,
                child: Text('Check liveliness'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
