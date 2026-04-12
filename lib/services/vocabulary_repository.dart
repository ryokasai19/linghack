// 1. Common Imports (Safe for Web and Mobile)
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_pair.dart'; // Only import the UI model!

// 2. Conditional Export
// The compiler picks ONE file. It ignores the other.
export 'vocabulary_repository_mobile.dart'
    if (dart.library.html) 'vocabulary_repository_web.dart';