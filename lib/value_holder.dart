part of inky;

class ValueHolder<T> {
  T value;
  bool exists;

  ValueHolder(this.value, this.exists);
}
