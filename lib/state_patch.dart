part of inky;

class StatePatch {
  Map<String?, InkObject?> get globals => _globals;
  HashSet<String?> get changedVariables => _changedVariables;
  Map<Container, int> get visitCounts => _visitCounts;
  Map<Container, int> get turnIndices => _turnIndices;

  StatePatch(StatePatch? toCopy) {
    if (toCopy != null) {
      _globals = {...toCopy._globals};
      _changedVariables = toCopy._changedVariables.toSet() as HashSet<String>;
      _visitCounts = {...toCopy._visitCounts};
      _turnIndices = {...toCopy._turnIndices};
    } else {
      _globals = <String, InkObject>{};
      _changedVariables = HashSet<String>();
      _visitCounts = <Container, int>{};
      _turnIndices = <Container, int>{};
    }
  }

  ValueHolder tryGetGlobal(String? name, /*out*/ InkObject? value) {
    var newVal = _globals[name];
    return ValueHolder(newVal ?? value, _globals.containsKey(name));
  }

  void setGlobal(String? name, InkObject? value) {
    _globals[name] = value;
  }

  void addChangedVariable(String? name) {
    _changedVariables.add(name);
  }

  ValueHolder tryGetVisitCount(Container container, /*out*/ int count) {
    var newVal = _visitCounts[container];
    return ValueHolder(newVal ?? count, _visitCounts.containsKey(container));
  }

  void setVisitCount(Container container, int count) {
    _visitCounts[container] = count;
  }

  void setTurnIndex(Container container, int index) {
    _turnIndices[container] = index;
  }

  ValueHolder tryGetTurnIndex(Container container, /*out*/ int index) {
    var newVal = _turnIndices[container];
    return ValueHolder(newVal ?? index, _turnIndices.containsKey(container));
  }

  Map<String?, InkObject?> _globals = <String, InkObject>{};
  HashSet<String?> _changedVariables = HashSet<String>();
  Map<Container, int> _visitCounts = <Container, int>{};
  Map<Container, int> _turnIndices = <Container, int>{};
}
