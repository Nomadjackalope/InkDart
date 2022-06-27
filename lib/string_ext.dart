part of inky;

class StringExt {
  static String join<T>(String separator, List<T> objects) {
    return objects.join(separator);
  }
}
