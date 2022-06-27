part of inky;

class Divert extends InkObject {
  Path? _targetPath;
  Path? get targetPath {
    // Resolve any relative paths to global ones as we come across them
    if (_targetPath != null && _targetPath!.isRelative) {
      var targetObj = targetPointer.resolve();
      if (targetObj != null) {
        _targetPath = targetObj.path;
      }
    }
    return _targetPath;
  }

  set targetPath(Path? value) {
    _targetPath = value;
    _targetPointer = Pointer.nullPointer;
  }

  Pointer _targetPointer = Pointer();
  Pointer get targetPointer {
    if (_targetPointer.isNull) {
      var targetObj = resolvePath(_targetPath!).obj;

      if (_targetPath!.lastComponent!.isIndex) {
        _targetPointer.container = targetObj!.parent as Container;
        _targetPointer.index = _targetPath!.lastComponent!.index;
      } else {
        _targetPointer = Pointer.startOf(targetObj as Container);
      }
    }
    return _targetPointer;
  }

  String? get targetPathString {
    if (targetPath == null) {
      return null;
    }

    return compactPathString(targetPath!);
  }

  set targetPathString(String? value) {
    if (value == null) {
      targetPath = null;
    } else {
      targetPath = Path.fromString(value);
    }
  }

  String? variableDivertName;
  bool get hasVariableTarget => variableDivertName != null;

  bool pushesToStack = false;
  PushPopType? stackPushType;

  bool isExternal = false;
  int externalArgs = 0;

  bool isConditional = false;

  Divert([PushPopType? stackPushType]) {
    if (stackPushType != null) {
      pushesToStack = true;
      this.stackPushType = stackPushType;
    }
  }

  @override
  bool operator ==(Object? obj) {
    var otherDivert = ConvertTo.divert(obj);
    if (otherDivert != null) {
      if (hasVariableTarget == otherDivert.hasVariableTarget) {
        if (hasVariableTarget) {
          return variableDivertName == otherDivert.variableDivertName;
        } else {
          return targetPath == otherDivert.targetPath;
        }
      }
    }
    return false;
  }

  @override
  int get hashCode {
    if (hasVariableTarget) {
      const int variableTargetSalt = 12345;
      return variableDivertName!.hashCode + variableTargetSalt;
    } else {
      const int pathTargetSalt = 54321;
      return targetPath.hashCode + pathTargetSalt;
    }
  }

  @override
  String toString() {
    if (hasVariableTarget) {
      return "Divert(variable: $variableDivertName)";
    } else if (targetPath == null) {
      return "Divert(null)";
    } else {
      var sb = StringBuffer();

      String targetStr = targetPath.toString();
      int? targetLineNum = debugLineNumberOfPath(targetPath!);
      if (targetLineNum != null) {
        targetStr = "line $targetLineNum";
      }

      sb.write("Divert");

      if (isConditional) {
        sb.write("?");
      }

      if (pushesToStack) {
        if (stackPushType == PushPopType.Function) {
          sb.write(" function");
        } else {
          sb.write(" tunnel");
        }
      }

      sb.write(" -> ");
      sb.write(targetPathString);

      sb.write(" (");
      sb.write(targetStr);
      sb.write(")");

      return sb.toString();
    }
  }
}
