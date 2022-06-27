part of inky;

class INamedContent {
  String? get name {}
  // return ""; // Should this be String? or not nullable with default return

  bool get hasValidName => false;
}
