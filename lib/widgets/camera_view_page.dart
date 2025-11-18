import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'dart:typed_data';

class CameraViewPage extends StatefulWidget {
  final String imagePath;

  const CameraViewPage({super.key, required this.imagePath});

  @override
  State<CameraViewPage> createState() => _CameraViewPageState();
}

class _CameraViewPageState extends State<CameraViewPage> {
  final GlobalKey _imageKey = GlobalKey();

  late String _currentImagePath;
  Rect _selectionRect = Rect.zero;
  int? _activeCornerIndex;
  Size? _imageSize;

  Offset? _dragStartPoint;
  Rect? _initialRect;
  bool _isCropping = false;
  int _imageVersion = 0;
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String?> _extractTextFromSelection() async {
    if (_isCropping ||
        _imageSize == null ||
        _selectionRect == Rect.zero ||
        _selectionRect.width <= 1 ||
        _selectionRect.height <= 1) {
      return null;
    }

    setState(() {
      _isCropping = true;
    });

    try {
      final file = File(_currentImagePath);
      final bytes = await file.readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지를 읽을 수 없습니다.')),
          );
        }
        return null;
      }

      // 화면에 표시된 이미지 크기와 실제 이미지 크기의 비율 계산
      final double widthRatio = decoded.width / _imageSize!.width;
      final double heightRatio = decoded.height / _imageSize!.height;

      // 선택 영역을 실제 이미지 좌표로 변환
      int left = (_selectionRect.left * widthRatio).round();
      int top = (_selectionRect.top * heightRatio).round();
      int cropWidth = (_selectionRect.width * widthRatio).round();
      int cropHeight = (_selectionRect.height * heightRatio).round();

      // 경계 체크
      left = left.clamp(0, decoded.width - 1);
      top = top.clamp(0, decoded.height - 1);
      cropWidth = cropWidth.clamp(1, decoded.width - left);
      cropHeight = cropHeight.clamp(1, decoded.height - top);

      // 이미지 크롭
      final img.Image cropped = img.copyCrop(
        decoded,
        x: left,
        y: top,
        width: cropWidth,
        height: cropHeight,
      );

      // JPEG로 인코딩
      final Uint8List croppedBytes = Uint8List.fromList(img.encodeJpg(cropped));

      // 새 파일 경로로 저장
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String croppedFilePath = path.join(
        appDocDir.path,
        'crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final File croppedFile = File(croppedFilePath);
      await croppedFile.writeAsBytes(croppedBytes, flush: true);
      _currentImagePath = croppedFilePath;

      final inputImage = InputImage.fromFilePath(_currentImagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      final extracted = recognizedText.text.trim();

      if (!mounted) return null;
      if (extracted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('텍스트를 찾지 못했습니다. 영역을 다시 선택해 주세요.'),
          ),
        );
        return null;
      }

      setState(() {
        _imageVersion++;
        _selectionRect = Rect.zero;
        _imageSize = null;
        _dragStartPoint = null;
        _initialRect = null;
      });

      return extracted;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('크롭 중 오류가 발생했습니다: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isCropping = false;
        });
      }
    }
  }

  Future<void> _onDoubleTap() async {
    if (_imageSize == null || _selectionRect == Rect.zero) return;

    final extractedText = await _extractTextFromSelection();
    if (!mounted) return;

    if (extractedText != null && extractedText.isNotEmpty) {
      Navigator.pop(context, {
        'text': extractedText,
        'imagePath': _currentImagePath,
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateImageSize();
    });
  }

  void _updateImageSize() {
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      final size = renderBox.size;
      
      // 이미지 크기가 유효한 경우에만 업데이트
      if (size.width > 0 && size.height > 0) {
        setState(() {
          _imageSize = size;
          // 처음에는 이미지 전체를 덮는 사각형
          if (_selectionRect == Rect.zero) {
            _selectionRect = Rect.fromLTWH(0, 0, size.width, size.height);
          }
        });
      }
    }
  }

  int? _findNearestCorner(Offset localPoint) {
    if (_imageSize == null || _selectionRect == Rect.zero) return null;

    // 4개 모서리 좌표 (이미지 내부 좌표계)
    final corners = [
      Offset(_selectionRect.left, _selectionRect.top), // 좌상단
      Offset(_selectionRect.right, _selectionRect.top), // 우상단
      Offset(_selectionRect.right, _selectionRect.bottom), // 우하단
      Offset(_selectionRect.left, _selectionRect.bottom), // 좌하단
    ];

    double minDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < corners.length; i++) {
      final distance = (localPoint - corners[i]).distance;
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  void _onPanStart(DragStartDetails details) {
    final RenderBox? box =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPoint = box.globalToLocal(details.globalPosition);
    final nearestCorner = _findNearestCorner(localPoint);

    if (nearestCorner == null) return;

    setState(() {
      _activeCornerIndex = nearestCorner;
      _dragStartPoint = localPoint;
      _initialRect = _selectionRect;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_activeCornerIndex == null ||
        _imageSize == null ||
        _dragStartPoint == null ||
        _initialRect == null) {
      return;
    }

    final RenderBox? box =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPoint = box.globalToLocal(details.globalPosition);
    final delta = localPoint - _dragStartPoint!;

    final initialRect = _initialRect!;
    Rect updatedRect = initialRect;

    switch (_activeCornerIndex!) {
      case 0: // 좌상단
        updatedRect = Rect.fromLTRB(
          (initialRect.left + delta.dx).clamp(0.0, _imageSize!.width),
          (initialRect.top + delta.dy).clamp(0.0, _imageSize!.height),
          initialRect.right,
          initialRect.bottom,
        );
        break;
      case 1: // 우상단
        updatedRect = Rect.fromLTRB(
          initialRect.left,
          (initialRect.top + delta.dy).clamp(0.0, _imageSize!.height),
          (initialRect.right + delta.dx).clamp(0.0, _imageSize!.width),
          initialRect.bottom,
        );
        break;
      case 2: // 우하단
        updatedRect = Rect.fromLTRB(
          initialRect.left,
          initialRect.top,
          (initialRect.right + delta.dx).clamp(0.0, _imageSize!.width),
          (initialRect.bottom + delta.dy).clamp(0.0, _imageSize!.height),
        );
        break;
      case 3: // 좌하단
        updatedRect = Rect.fromLTRB(
          (initialRect.left + delta.dx).clamp(0.0, _imageSize!.width),
          initialRect.top,
          initialRect.right,
          (initialRect.bottom + delta.dy).clamp(0.0, _imageSize!.height),
        );
        break;
    }

    setState(() {
      _selectionRect = _normalizeRect(updatedRect);
    });
  }

  Rect _normalizeRect(Rect rect) {
    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;

    final normalized = Rect.fromLTRB(
      left < right ? left : right,
      top < bottom ? top : bottom,
      left > right ? left : right,
      top > bottom ? top : bottom,
    );

    return normalized;
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _activeCornerIndex = null;
    });
    _dragStartPoint = null;
    _initialRect = _selectionRect;
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 촬영 모드'),
      ),
      body: SafeArea(
        child: Center(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onDoubleTap: _onDoubleTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                KeyedSubtree(
                  key: ValueKey('${_currentImagePath}_$_imageVersion'),
                  child: Image.file(
                    File(_currentImagePath),
                    key: _imageKey,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                      if (frame != null) {
                        // 이미지가 로드되면 크기 업데이트
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _updateImageSize();
                        });
                      }
                      return child;
                    },
                  ),
                ),
                if (_imageSize != null && _selectionRect != Rect.zero)
                  SizedBox(
                    width: _imageSize!.width,
                    height: _imageSize!.height,
                    child: CustomPaint(
                      painter: RectanglePainter(
                        rect: _selectionRect,
                        activeCornerIndex: _activeCornerIndex,
                      ),
                    ),
                  ),
                if (_isCropping)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RectanglePainter extends CustomPainter {
  final Rect rect;
  final int? activeCornerIndex;

  const RectanglePainter({
    required this.rect,
    this.activeCornerIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // 사각형 테두리
    canvas.drawRect(rect, paint);

    // 모서리 포인트(동그라미)
    final corners = [
      Offset(rect.left, rect.top), // 좌상단
      Offset(rect.right, rect.top), // 우상단
      Offset(rect.right, rect.bottom), // 우하단
      Offset(rect.left, rect.bottom), // 좌하단
    ];

    final cornerPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < corners.length; i++) {
      if (i == activeCornerIndex) {
        // 활성화된 모서리: 노란색 강조
        cornerPaint.color = Colors.yellow;
        canvas.drawCircle(corners[i], 13, cornerPaint);
        cornerPaint.color = Colors.white;
        canvas.drawCircle(corners[i], 7, cornerPaint);
      } else {
        // 일반 모서리
        cornerPaint.color = Colors.red;
        canvas.drawCircle(corners[i], 9, cornerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RectanglePainter oldDelegate) {
    return rect != oldDelegate.rect ||
        activeCornerIndex != oldDelegate.activeCornerIndex;
  }
}

