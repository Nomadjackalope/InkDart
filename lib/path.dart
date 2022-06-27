part of inky;

class Path {
  static String parentId = "^";

  List<Component> _components = <Component>[];

  List<Component> get components => _components;

  Component getComponent(index) {
    return _components[index];
  }

  bool _isRelative = false;

  bool get isRelative => _isRelative;
  set isRelative(relative) => _isRelative = relative;

  String? _componentsString;

  Component? get head {
    if (_components.isNotEmpty) {
      return _components.first;
    } else {
      return null;
    }
  }

  Path get tail {
    if (_components.length >= 2) {
      Iterable<Component> tailComps =
          _components.getRange(1, _components.length);
      return Path.fromList(tailComps);
    } else {
      return Path.self;
    }
  }

  int get length => _components.length;

  Component? get lastComponent {
    var lastComponentIndex = _components.length - 1;
    if (lastComponentIndex >= 0) {
      return _components[lastComponentIndex];
    } else {
      return null;
    }
  }

  bool get containsNamedComponent {
    for (var comp in _components) {
      if (!comp.isIndex) {
        return true;
      }
    }
    return false;
  }

  initComponents() {
    _components = <Component>[];
  }

  Path() {
    initComponents();
  }

  Path.fromHeadTail(head, tail) {
    initComponents();
    _components.add(head);
    _components.addAll(tail.components);
  }

  Path.fromList(Iterable<Component> components, [relative = false]) {
    initComponents();
    _components.addAll(components);
    isRelative = relative;
  }

  Path.fromStack(Stack<Component> components, [relative = false]) {
    initComponents();
    _components.addAll(stackToList(components));
  }

  Path.fromString(componentsString) {
    initComponents();
    this.componentsString = componentsString;
  }

  List<Component> stackToList(Stack<Component> stack) {
    List<Component> returnable = [];
    while (stack.isNotEmpty) {
      returnable.add(stack.pop());
    }
    return returnable;
  }

  static Path get self {
    var path = Path();
    path.isRelative = true;
    return path;
  }

  Path pathByAppendingPath(pathToAppend) {
    Path p = Path();

    int upwardMoves = 0;
    for (int i = 0; i < pathToAppend._components.Count; ++i) {
      if (pathToAppend._components[i].isParent) {
        upwardMoves++;
      } else {
        break;
      }
    }

    for (int i = 0; i < _components.length - upwardMoves; ++i) {
      p._components.add(_components[i]);
    }

    for (int i = upwardMoves; i < pathToAppend._components.Count; ++i) {
      p._components.add(pathToAppend._components[i]);
    }

    return p;
  }

  Path pathByAppendingComponent(Component c) {
    Path p = Path();
    p._components.addAll(_components);
    p._components.add(c);
    return p;
  }

  String get componentsString {
    if (_componentsString == null) {
      _componentsString = StringExt.join(".", _components);
      if (isRelative) _componentsString = ".$_componentsString";
    }
    return _componentsString!;
  }

  set componentsString(String value) {
    _components.clear();

    _componentsString = value;

    // Empty path, empty components
    // (path is to root, like "/" in file system)
    if (_componentsString == null || _componentsString!.isEmpty) {
      //  String.isNullOrEmpty(_componentsString))
      return;
    }
    // When components start with ".", it indicates a relative path, e.g.
    //   .^.^.hello.5
    // is equivalent to file system style path:
    //  ../../hello/5
    if (_componentsString![0] == '.') {
      isRelative = true;
      _componentsString = _componentsString!.substring(1);
    } else {
      isRelative = false;
    }

    var componentStrings = _componentsString?.split('.');
    for (var str in componentStrings!) {
      int? index = int.tryParse(str);
      if (index != null) {
        _components.add(Component(index));
      } else {
        _components.add(Component.withName(str));
      }
    }
  }

  @override
  String toString() {
    return componentsString;
  }

  @override
  bool operator ==(Object? obj) {
    Path? otherPath = obj as Path?;

    if (otherPath == null) return false;

    if (otherPath._components.length != this._components.length) return false;

    if (otherPath.isRelative != this.isRelative) return false;

    // the original code uses SequenceEqual here, so we need to iterate over the components manually.
    for (int i = 0; i < otherPath._components.length; i++) {
      if (otherPath._components[i] != _components[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    // TODO: Better way to make a hash code!
    return toString().hashCode;
  }
}

class Component {
  final int _index;

  int get index => _index;

  final String? _name;

  String? get name => _name;

  bool get isIndex => _index >= 0;

  bool get isParent => name == Path.parentId;

  Component(this._index) : _name = null {
    assert(index >= 0);
  }

  Component.withName(this._name) : _index = -1 {
    assert(name != null && _name!.isNotEmpty);
  }

  static Component toParent() {
    return Component.withName(Path.parentId);
  }

  @override
  String toString() {
    if (isIndex) {
      return index.toString();
    } else {
      return _name!; // == null ? "" : _name!;
    }
  }

  @override
  bool operator ==(Object? other) {
    Component? otherComp = ConvertTo.component(other);

    if (otherComp != null && otherComp.isIndex == isIndex) {
      if (isIndex) {
        return index == otherComp.index;
      } else {
        return name == otherComp.name;
      }
    }

    return false;
  }

  @override
  int get hashCode {
    if (isIndex) {
      return index;
    } else {
      return name.hashCode;
    }
  }
}
