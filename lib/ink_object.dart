part of inky;

// Base class for all ink runtime content.

class InkObject {
  Container? parent;

  DebugMetadata? get debugMetadata {
    if (_debugMetadata == null) {
      if (parent != null) {
        return parent!.debugMetadata;
      }
    }

    return _debugMetadata;
  }

  set debugMetadata(DebugMetadata? value) {
    _debugMetadata = value;
  }

  DebugMetadata? get ownDebugMetadata => _debugMetadata;

  // TODO: Come up with some clever solution for not having
  // to have debug metadata on the object itself, perhaps
  // for serialisation purposes at least.
  late DebugMetadata? _debugMetadata;

  int? debugLineNumberOfPath(Path path) {
    if (path == null) {
      return null;
    }

    // Try to get a line number from debug metadata
    var root = rootContentContainer;
    if (root != null) {
      InkObject? targetContent = root.contentAtPath(path).obj;
      if (targetContent != null) {
        var dm = targetContent.debugMetadata;
        if (dm != null) {
          return dm.startLineNumber;
        }
      }
    }

    return null;
  }

  Path? get path {
    if (_path == null) {
      if (parent == null) {
        _path = Path();
      } else {
        // Maintain a Stack so that the order of the components
        // is reversed when they're added to the Path.
        // We're iterating up the hierarchy from the leaves/children to the root.
        var comps = Stack<Component>();

        var child = this;
        Container? container = ConvertTo.container(child.parent);

        while (container != null) {
          var namedChild = ConvertTo.iNamedContent(child);
          if (namedChild != null && namedChild.hasValidName) {
            comps.push(Component.withName(namedChild.name));
          } else {
            comps.push(Component(container.content.indexOf(child)));
          }

          child = container;
          container = ConvertTo.container(container.parent);
        }

        _path = Path.fromStack(comps);
      }
    }

    return _path;
  }

  Path? _path;

  SearchResult resolvePath(Path path) {
    if (path.isRelative) {
      Container? nearestContainer = ConvertTo.container(this);
      if (nearestContainer == null) {
        assert(parent != null,
            "Can't resolve relative path because we don't have a parent");
        nearestContainer = ConvertTo.container(parent);
        assert(nearestContainer != null, "Expected parent to be a container");
        assert(path.getComponent(0).isParent);
        path = path.tail;
      }

      return nearestContainer!.contentAtPath(path);
    } else {
      return rootContentContainer!.contentAtPath(path);
    }
  }

  Path convertPathToRelative(Path globalPath) {
    // 1. Find last shared ancestor
    // 2. Drill up using ".." style (actually represented as "^")
    // 3. Re-build downward chain from common ancestor

    var ownPath = path;

    int minPathLength = min(globalPath.length, ownPath!.length);
    int lastSharedPathCompIndex = -1;

    for (int i = 0; i < minPathLength; ++i) {
      var ownComp = ownPath.getComponent(i);
      var otherComp = globalPath.getComponent(i);

      if (ownComp == otherComp) {
        lastSharedPathCompIndex = i;
      } else {
        break;
      }
    }

    // No shared path components, so just use global path
    if (lastSharedPathCompIndex == -1) {
      return globalPath;
    }

    int numUpwardsMoves = (ownPath.length - 1) - lastSharedPathCompIndex;

    var newPathComps = <Component>[];

    for (int up = 0; up < numUpwardsMoves; ++up) {
      newPathComps.add(Component.toParent());
    }

    for (int down = lastSharedPathCompIndex + 1;
        down < globalPath.length;
        ++down) {
      newPathComps.add(globalPath.getComponent(down));
    }

    var relativePath = Path.fromList(newPathComps, true);
    return relativePath;
  }

  // Find most compact representation for a path, whether relative or global
  String compactPathString(Path otherPath) {
    String globalPathStr;
    String relativePathStr;
    if (otherPath.isRelative) {
      relativePathStr = otherPath.componentsString;
      globalPathStr = path!.pathByAppendingPath(otherPath).componentsString;
    } else {
      var relativePath = convertPathToRelative(otherPath);
      relativePathStr = relativePath.componentsString;
      globalPathStr = otherPath.componentsString;
    }

    if (relativePathStr.length < globalPathStr.length) {
      return relativePathStr;
    } else {
      return globalPathStr;
    }
  }

  Container? get rootContentContainer {
    InkObject ancestor = this;
    while (ancestor.parent != null) {
      ancestor = ancestor.parent!;
    }

    return ConvertTo.container(ancestor);
  }

  InkObject();

  /*virtual*/ InkObject? copy() {
    throw UnimplementedError("$runtimeType doesn't support copying");
  }

  void setChild<T extends InkObject>(/*ref*/ T? refObj, T? value) {
    if (refObj != null) {
      refObj.parent = null;
    }

    refObj = value;

    if (refObj != null) {
      refObj.parent = this as Container?;
    }
  }

  /// Allow implicit conversion to bool so you don't have to do:
  /// if( myObj != null ) ...
  // static /*implicit operator*/bool get exists // (Object obj)
  // {
  //     var isNull = object.ReferenceEquals (obj, null);
  //     return !isNull;
  // }

  /// Required for implicit bool comparison
  // TODO ben gordon test this
  // bool operator ==(Object a, Object b)
  // {
  //     return object.ReferenceEquals (a, b);
  // }

  /// Required for implicit bool comparison
  // TODO ben gordon test this
  // static bool operator !=(Object a, Object b)
  // {
  //     return !(a == b);
  // }

  /// Required for implicit bool comparison
  @override
  bool operator ==(Object? obj) {
    return super == obj; //Object.ReferenceEquals (obj, this);
  }

  /// Required for implicit bool comparison
  @override
  int get hashCode => super.hashCode;
  // {
  // throw UnimplementedError(); //hash(); //base.GetHashCode ();
  // }
}
