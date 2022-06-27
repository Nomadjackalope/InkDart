part of inky;

class Container extends InkObject implements INamedContent {
  String? _name;

  @override
  String? get name => _name;
  set name(String? value) => _name = value;

  List<InkObject> _content = <InkObject>[];

  List<InkObject> get content => _content;
  set content(List<InkObject> value) => addContent(inkObjects: value);

  Map<String, INamedContent> namedContent = {};

  Map<String, InkObject>? get namedOnlyContent {
    Map<String, InkObject>? namedOnlyContentDict = <String, InkObject>{};
    namedContent.forEach((k, v) {
      namedOnlyContentDict?[k] = v as InkObject;
    });

    for (var c in content) {
      var named = ConvertTo.iNamedContent(c);
      if (named != null && named.hasValidName) {
        namedOnlyContentDict.remove(named.name);
      }
    }

    if (namedOnlyContentDict.isEmpty) {
      namedOnlyContentDict = null;
    }

    return namedOnlyContentDict;
  }

  set namedOnlyContent(Map<String, InkObject>? value) {
    var existingNamedOnly = namedOnlyContent;
    if (existingNamedOnly != null) {
      existingNamedOnly.forEach((k, v) {
        namedContent.remove(k);
      });
    }

    if (value == null) {
      return;
    }

    value.forEach((k, v) {
      var named = ConvertTo.iNamedContent(v);
      if (named != null) {
        addToNamedContentOnly(named);
      }
    });
  }

  var visitsShouldBeCounted = false;
  var turnIndexShouldBeCounted = false;
  var countingAtStartOnly = false;

  int get countFlags {
    int flags = 0;
    if (visitsShouldBeCounted) flags |= CountFlags.visits;
    if (turnIndexShouldBeCounted) flags |= CountFlags.turns;
    if (countingAtStartOnly) flags |= CountFlags.countStartOnly;

    // If we're only storing CountStartOnly, it serves no purpose,
    // since it's dependent on the other two to be used at all.
    // (e.g. for setting the fact that *if* a gather or choice's
    // content is counted, then is should only be counter at the start)
    // So this is just an optimisation for storage.
    if (flags == CountFlags.countStartOnly) {
      flags = 0;
    }

    return flags;
  }

  set countFlags(int value) {
    var flag = value;
    if ((flag & CountFlags.visits) > 0) visitsShouldBeCounted = true;
    if ((flag & CountFlags.turns) > 0) turnIndexShouldBeCounted = true;
    if ((flag & CountFlags.countStartOnly) > 0) countingAtStartOnly = true;
  }

  @override
  bool get hasValidName => name != null && name!.isNotEmpty;

  Path? _pathToFirstLeafContent;

  Path get pathToFirstLeafContent {
    _pathToFirstLeafContent ??=
        path!.pathByAppendingPath(internalPathToFirstLeafContent);

    return _pathToFirstLeafContent!;
  }

  Path get internalPathToFirstLeafContent {
    var components = <Component>[];
    var container = this;
    while (container.content != null) {
      // TODO: make sure content can be null
      if (container.content.isNotEmpty) {
        components.add(Component(0));
        container = container.content[0] as Container;
      }
    }
    return Path.fromList(components);
  }

  addContent({List<InkObject>? inkObjects, InkObject? inkObject}) {
    if (inkObjects != null) addAllContent(inkObjects);
    if (inkObject != null) addSingleContent(inkObject);
  }

  addSingleContent(InkObject contentObj) {
    content.add(contentObj);

    if (contentObj.parent != null) {
      throw FormatException('content is already in ${contentObj.parent}');
    }

    contentObj.parent = this;

    tryAddNamedContent(contentObj);
  }

  addAllContent(List<InkObject> contentList) {
    for (var c in contentList) {
      addSingleContent(c);
    }
  }

  void insertContent(contentObj, index) {
    content.insert(index, contentObj);

    if (contentObj.parent) {
      throw FormatException('content is already in ${contentObj.parent}');
    }

    contentObj.parent = this;

    tryAddNamedContent(contentObj);
  }

  tryAddNamedContent(InkObject contentObj) {
    var namedContentObj = ConvertTo.iNamedContent(contentObj);

    if (namedContentObj != null && namedContentObj.hasValidName) {
      addToNamedContentOnly(namedContentObj);
    }
  }

  addToNamedContentOnly(INamedContent namedContentObj) {
    assert(namedContentObj is InkObject,
        "Can only add Runtime.Objects to a Runtime.Container");

    var runtimeObj = namedContentObj as InkObject;
    runtimeObj.parent = this;

    namedContent[namedContentObj.name!] = namedContentObj;
  }

  addContentsOfContainer(Container otherContainer) {
    content.addAll(otherContainer.content);
    for (var obj in otherContainer.content) {
      obj.parent = this;
      tryAddNamedContent(obj);
    }
  }

  InkObject? contentWithPathComponent(Component component) {
    if (component.isIndex) {
      if (component.index >= 0 && component.index < content.length) {
        return content[component.index];
      }

      // When path is out of range, quietly return nil
      // (useful as we step/increment forwards through content)
      else {
        return null;
      }
    } else if (component.isParent) {
      return parent;
    } else {
      return namedContent[component.name] as InkObject;
    }
  }

  SearchResult contentAtPath(Path path,
      {int partialPathStart = 0, int partialPathLength = -1}) {
    if (partialPathLength == -1) {
      partialPathLength = path.length;
    }

    var result = SearchResult();
    result.approximate = false;

    Container? currentContainer = this;
    InkObject currentObj = this;

    for (int i = partialPathStart; i < partialPathLength; ++i) {
      var comp = path.getComponent(i);

      // Path component was wrong type
      if (currentContainer == null) {
        result.approximate = true;
        break;
      }

      var foundObj = currentContainer.contentWithPathComponent(comp);

      // Couldn't resolve entire path?
      if (foundObj == null) {
        result.approximate = true;
        break;
      }

      currentObj = foundObj;
      currentContainer = foundObj as Container;
    }

    result.obj = currentObj;

    return result;
  }

  void buildStringOfHierarchy(
      StringBuffer sb, int indentation, InkObject? pointedObj) {
    appendIndentation() {
      int spacesPerIndent = 4;
      for (int i = 0; i < spacesPerIndent * indentation; ++i) {
        sb.write(" ");
      }
    }

    appendIndentation();
    sb.write("[");

    if (hasValidName) {
      sb.write(" ($name)"); // TODO: double check this
    }

    if (this == pointedObj) {
      sb.write("  <---");
    }

    sb.writeln();

    indentation++;

    for (int i = 0; i < content.length; ++i) {
      var obj = content[i];

      if (obj is Container) {
        var container = obj;

        container.buildStringOfHierarchy(sb, indentation, pointedObj);
      } else {
        appendIndentation();

        if (obj is StringValue) {
          sb.write("\"");
          sb.write(obj.toString().replaceAll("\n", "\\n"));
          sb.write("\"");
        } else {
          sb.write(obj.toString());
        }
      }

      if (i != content.length - 1) {
        sb.write(",");
      }

      if (obj is! Container && obj == pointedObj) {
        sb.write("  <---");
      }

      sb.writeln();
    }

    var onlyNamed = <String, INamedContent>{};

    for (var objKV in namedContent.entries) {
      if (content.contains(objKV.value as InkObject)) {
        continue;
      } else {
        onlyNamed.putIfAbsent(objKV.key, () => objKV.value);
      }
    }

    if (onlyNamed.isNotEmpty) {
      appendIndentation();
      sb.writeln("-- named: --");

      for (var objKV in onlyNamed.entries) {
        assert(objKV.value is Container, "Can only print out named Containers");
        var container = objKV.value as Container;
        container.buildStringOfHierarchy(sb, indentation, pointedObj);

        sb.writeln();
      }
    }

    indentation--;

    appendIndentation();
    sb.write("]");
  }
}

class CountFlags {
  static const int visits = 1;
  static const int turns = 2;
  static const int countStartOnly = 4;
}
