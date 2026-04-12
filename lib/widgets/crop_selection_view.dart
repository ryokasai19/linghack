import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;

class CropSelectionView extends StatefulWidget {
  final Uint8List imageBytes;
  final Function(Uint8List) onCropConfirmed;
  final VoidCallback onCancel;
  final VoidCallback onScanStarted;

  const CropSelectionView({
    super.key,
    required this.imageBytes,
    required this.onCropConfirmed,
    required this.onCancel,
    required this.onScanStarted
  });

  @override
  State<CropSelectionView> createState() => _CropSelectionViewState();
}

class _CropSelectionViewState extends State<CropSelectionView> {
  Offset? _startPoint;
  Offset? _currentPoint;
  final GlobalKey _imageKey = GlobalKey();

  Future<void> _confirmCrop() async {
    widget.onScanStarted();
    // 1. If no selection, return original
    if (_startPoint == null || _currentPoint == null) {
      widget.onCropConfirmed(widget.imageBytes);
      return;
    }

    try {
      // 2. Decode the image using the GPU (Fast!)
      final ui.Codec codec = await ui.instantiateImageCodec(widget.imageBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image originalImage = frame.image;

      // 3. Calculate Scale
      final RenderBox renderBox = _imageKey.currentContext!.findRenderObject() as RenderBox;
      final Size displayedSize = renderBox.size;

      final double scaleX = originalImage.width / displayedSize.width;
      final double scaleY = originalImage.height / displayedSize.height;

      // 4. normalize the selection rect (handle dragging backwards)
      final Rect selectionRect = Rect.fromPoints(_startPoint!, _currentPoint!);

      final Rect cropRect = Rect.fromLTRB(
        selectionRect.left * scaleX,
        selectionRect.top * scaleY,
        selectionRect.right * scaleX,
        selectionRect.bottom * scaleY,
      );

      // 5. Draw the crop onto a new Canvas
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Draw only the selected part of the image into the new canvas
      canvas.drawImageRect(
        originalImage,
        cropRect, // Source: The area from the original image
        Rect.fromLTWH(0, 0, cropRect.width, cropRect.height), // Dest: The new canvas size
        Paint(),
      );

      // 6. Output the new image
      final ui.Image finalImage = await recorder.endRecording().toImage(
        cropRect.width.toInt(),
        cropRect.height.toInt(),
      );

      // 7. Convert to PNG bytes
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        widget.onCropConfirmed(byteData.buffer.asUint8List());
      }

    } catch (e) {
      print("Crop Error: $e");
      // Fallback: send original if crop fails
      widget.onCropConfirmed(widget.imageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildCropArea()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text("Select Text to Scan", style: TextStyle(color: Colors.white)),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: widget.onCancel,
      ),
      actions: [
        TextButton(
          onPressed: _confirmCrop,
          child: const Text("CONFIRM", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      ],
    );
  }

  Widget _buildCropArea() {
    return Center(
      child: Stack(
        children: [
          Image.memory(widget.imageBytes, key: _imageKey, fit: BoxFit.contain),
          Positioned.fill(
            child: GestureDetector(
              onPanStart: (d) => setState(() {
                _startPoint = d.localPosition;
                _currentPoint = d.localPosition;
              }),
              onPanUpdate: (d) => setState(() => _currentPoint = d.localPosition),
              child: CustomPaint(
                painter: SelectionPainter(startPoint: _startPoint, currentPoint: _currentPoint),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Padding(
      padding: EdgeInsets.all(20.0),
      child: Text("Click and drag to box the words you want to learn",
          style: TextStyle(color: Colors.white70)),
    );
  }
}

// Keep the painter in this file too
class SelectionPainter extends CustomPainter {
  final Offset? startPoint;
  final Offset? currentPoint;
  SelectionPainter({this.startPoint, this.currentPoint});

  @override
  void paint(Canvas canvas, Size size) {
    if (startPoint == null || currentPoint == null) return;
    final rect = Rect.fromPoints(startPoint!, currentPoint!);
    canvas.drawRect(rect, Paint()..color = Colors.blue.withOpacity(0.3));
    canvas.drawRect(rect, Paint()..color = Colors.blue..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(SelectionPainter old) => true;
}