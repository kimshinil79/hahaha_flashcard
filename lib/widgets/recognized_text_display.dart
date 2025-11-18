import 'package:flutter/material.dart';

class RecognizedTextDisplay extends StatelessWidget {
  final String recognizedText;
  final Function(BuildContext, TapDownDetails, String) onWordDoubleTap;

  const RecognizedTextDisplay({
    super.key,
    required this.recognizedText,
    required this.onWordDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
          Builder(
            builder: (context) {
              return GestureDetector(
                onDoubleTapDown: (details) async {
                  await onWordDoubleTap(context, details, recognizedText);
                },
                child: SelectableText(
                  recognizedText,
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        fontSize: 15,
                        color: Colors.grey.shade800,
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

