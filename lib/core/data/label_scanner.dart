import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'label_reader.dart';

sealed class LabelScan {
  const LabelScan();
}

class LabelRead extends LabelScan {
  const LabelRead(this.nutrition);
  final LabelNutrition nutrition;
}

/// A photo was taken but no nutrition table could be read from it.
class LabelUnreadable extends LabelScan {
  const LabelUnreadable();
}

class LabelCancelled extends LabelScan {
  const LabelCancelled();
}

/// Takes a photo of a nutrition label and reads it on the phone (ML Kit text
/// recognition: free, offline, nothing leaves the device).
Future<LabelScan> scanNutritionLabel() async {
  final XFile? file;
  try {
    // Sharp enough for small print, small enough to read quickly.
    file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, maxHeight: 2400, imageQuality: 92);
  } on Exception {
    return const LabelCancelled();
  }
  if (file == null) return const LabelCancelled();

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final text = await recognizer.processImage(InputImage.fromFilePath(file.path));
    final lines = [
      for (final block in text.blocks)
        for (final line in block.lines) LabelLine(line.text, line.boundingBox),
    ];
    final nutrition = readNutritionLabel(lines);
    return nutrition == null ? const LabelUnreadable() : LabelRead(nutrition);
  } on Exception {
    return const LabelUnreadable();
  } finally {
    await recognizer.close();
  }
}
