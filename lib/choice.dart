part of inky;

/// <summary>
/// A generated Choice from the story.
/// A single ChoicePoint in the Story could potentially generate
/// different Choices dynamically dependent on state, so they're
/// separated.
/// </summary>
class Choice extends InkObject {
  /// <summary>
  /// The main text to presented to the player for this Choice.
  /// </summary>
  String? text;

  /// <summary>
  /// The target path that the Story should be diverted to if
  /// this Choice is chosen.
  /// </summary>
  String? get pathStringOnChoice => targetPath.toString();
  set pathStringOnChoice(String? value) {
    targetPath = Path.fromString(value);
  }

  /// <summary>
  /// Get the path to the original choice point - where was this choice defined in the story?
  /// </summary>
  /// <value>A dot separated path into the story data.</value>
  String? sourcePath;

  /// <summary>
  /// The original index into currentChoices list on the Story when
  /// this Choice was generated, for convenience.
  /// </summary>
  int index = 0;

  Path? targetPath;

  Thread? threadAtGeneration;
  int originalThreadIndex = 0;

  bool isInvisibleDefault = false;

  Choice();
}
