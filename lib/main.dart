import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'widgets/camera_screen.dart';
import 'widgets/camera_view_page.dart';
import 'widgets/searching_words.dart';
import 'widgets/login_screen.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hahaha Flashcard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.grey.shade600,
          surface: Colors.white,
          background: Colors.white,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
          onBackground: Colors.black,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      home: AuthWrapper(cameras: cameras),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final List<CameraDescription> cameras;

  const AuthWrapper({super.key, required this.cameras});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        // 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 로그인 상태 확인
        if (snapshot.hasData && snapshot.data != null) {
          // 로그인 되어 있으면 메인 화면
          return MyHomePage(title: 'Hahaha Flashcard', cameras: widget.cameras);
        } else {
          // 로그인 안 되어 있으면 로그인 화면
          return const LoginScreen();
        }
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.cameras});

  final String title;
  final List<CameraDescription> cameras;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  String? _recognizedText;
  int _imageVersion = 0;
  Offset? _fabOffset; // Stored relative to SafeArea coordinates
  bool _isDragging = false;
  static const double _fabSize = 56.0;

  Future<void> _takePicture() async {
    if (widget.cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라를 사용할 수 없습니다.')),
      );
      return;
    }

    // 카메라 화면으로 이동
    if (!mounted) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(camera: widget.cameras.first),
      ),
    );

    // await 후 mounted 체크
    if (!mounted) return;

    if (result != null && result is String) {
      setState(() {
        _image = null;
        _recognizedText = null;
      });
      
      // 사진 촬영 모드로 이동
      final cropResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraViewPage(imagePath: result),
        ),
      );

      // await 후 mounted 체크
      if (!mounted) return;

      if (cropResult is Map<String, dynamic>) {
        final extractedText = cropResult['text'] as String?;
        final updatedImagePath = cropResult['imagePath'] as String?;

        setState(() {
          if (updatedImagePath != null && updatedImagePath.isNotEmpty) {
            _image = File(updatedImagePath);
            _imageVersion++;
          }

          if (extractedText != null && extractedText.trim().isNotEmpty) {
            _recognizedText = extractedText.trim();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: '로그아웃',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      extendBody: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safeWidth = constraints.maxWidth;
            final safeHeight = constraints.maxHeight;
            final defaultOffset = Offset(
              safeWidth - _fabSize - 24,
              safeHeight - _fabSize - 24,
            );
            final fabOffset = _fabOffset ?? defaultOffset;

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SearchingWords(),
                        const SizedBox(height: 32),
                        if (_recognizedText != null &&
                            _recognizedText!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '인식된 텍스트',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                SelectableText(
                                  _recognizedText!,
                                  textAlign: TextAlign.justify,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        height: 1.6,
                                        fontSize: 15,
                                        color: Colors.grey.shade800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_image != null) ...[
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _image!,
                                key: ValueKey(_imageVersion),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                        if (_recognizedText == null && _image == null) ...[
                          const SizedBox(height: 120),
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '카메라 버튼을 눌러\n사진을 찍고 텍스트를 추출해보세요',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey.shade600,
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: fabOffset.dx,
                  top: fabOffset.dy,
                  child: GestureDetector(
                    onPanStart: (_) {
                      setState(() => _isDragging = true);
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _isDragging = true;
                        final minX = 16.0;
                        final maxX = safeWidth - _fabSize - 16.0;
                        final minY = 16.0;
                        final maxY = safeHeight - _fabSize - 16.0;

                        final current = _fabOffset ?? fabOffset;
                        final newDx =
                            (current.dx + details.delta.dx).clamp(minX, maxX);
                        final newDy =
                            (current.dy + details.delta.dy).clamp(minY, maxY);
                        _fabOffset = Offset(newDx, newDy);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() => _isDragging = false);
                    },
                    child: Container(
                      width: _fabSize,
                      height: _fabSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isDragging ? null : _takePicture,
                          borderRadius: BorderRadius.circular(_fabSize / 2),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

