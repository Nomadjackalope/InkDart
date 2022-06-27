part of inky;

class KeyValuePair<T, U> {
  final T key;
  final U value;

  KeyValuePair(this.key, this.value);

  KeyValuePair.from(MapEntry<T, U> mapEntry)
      : key = mapEntry.key,
        value = mapEntry.value;

  MapEntry to() {
    return MapEntry(key, value);
  }
}
