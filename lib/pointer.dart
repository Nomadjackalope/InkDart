part of inky;

/// <summary>
/// Internal structure used to point to a particular / current point in the story.
/// Where Path is a set of components that make content fully addressable, this is
/// a reference to the current container, and the index of the current piece of
/// content within that container. This scheme makes it as fast and efficient as
/// possible to increment the pointer (move the story forwards) in a way that's as
/// native to the internal engine as possible.
/// </summary>
/// In original code this was a struct so we make a default
class Pointer {
  Container? container;
  int index = 0;

  Pointer();

  Pointer.from(this.container, this.index);

  InkObject? resolve() {
    if (index < 0) return container;
    if (container == null) return null;
    if (container!.content.isEmpty) return container;
    if (index >= container!.content.length) return null;
    return container!.content[index];
  }

  bool get isNull => container == null;

  Path? get path {
    if (isNull) return null;

    if (index >= 0) {
      return container!.path!.pathByAppendingComponent(Component(index));
    } else {
      return container!.path;
    }
  }

  @override
  String toString() {
    if (container == null) {
      return "Ink Pointer (null)";
    }

    return "Ink Pointer -> ${container!.path!.toString()} -- index $index";
  }

  static Pointer startOf(Container? container) => Pointer.from(container, 0);

  static Pointer nullPointer = Pointer.from(null, -1);
}
