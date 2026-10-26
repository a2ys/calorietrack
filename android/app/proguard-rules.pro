# ML Kit text recognition (nutrition label scanning) only bundles the Latin
# model. The plugin also references the Chinese, Devanagari, Japanese and
# Korean recognizers, which aren't included; R8 must not fail on them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
