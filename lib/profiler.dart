part of inky;

/// <summary>
/// Simple ink profiler that logs every instruction in the story and counts frequency and timing.
/// To use:
///
///   var profiler = story.StartProfiling(),
///
///   (play your story for a bit)
///
///   var reportStr = profiler.Report();
///
///   story.EndProfiling();
///
/// </summary>
class Profiler {
  /// <summary>
  /// The root node in the hierarchical tree of recorded ink timings.
  /// </summary>
  ProfileNode get rootNode => _rootNode;

  Profiler() {
    _rootNode = ProfileNode();
  }

  /// <summary>
  /// Generate a printable report based on the data recording during profiling.
  /// </summary>
  String report() {
    var sb = StringBuffer();
    sb.write("$_numContinues CONTINUES / LINES:\n");
    sb.write("TOTAL TIME: ${formatMillisecs(_continueTotal)}\n");
    sb.write("SNAPSHOTTING: ${formatMillisecs(_snapTotal)}\n");
    sb.write(
        "OTHER: ${formatMillisecs(_continueTotal - (_stepTotal + _snapTotal))}\n");
    sb.write(_rootNode.toString());
    return sb.toString();
  }

  void preContinue() {
    _continueWatch.reset();
    _continueWatch.start();
  }

  void postContinue() {
    _continueWatch.stop();
    _continueTotal += millisecs(_continueWatch);
    _numContinues++;
  }

  void preStep() {
    _currStepStack = null;
    _stepWatch.reset();
    _stepWatch.start();
  }

  void step(CallStack callstack) {
    _stepWatch.stop();

    var stack = List<String?>.filled(callstack.elements.length, null);
    for (int i = 0; i < stack.length; i++) {
      String? stackElementName = "";
      if (!callstack.elements[i].currentPointer.isNull) {
        var objPath = callstack.elements[i].currentPointer.path;

        for (int c = 0; c < objPath!.length; c++) {
          var comp = objPath.getComponent(c);
          if (!comp.isIndex) {
            stackElementName = comp.name;
            break;
          }
        }
      }
      stack[i] = stackElementName;
    }

    _currStepStack = stack;

    var currObj = callstack.currentElement.currentPointer.resolve();

    String? stepType;
    var controlCommandStep = currObj as ControlCommand?;
    if (controlCommandStep != null) {
      stepType = controlCommandStep.commandType.toString() + " CC";
    } else {
      stepType = currObj.runtimeType.toString();
    }

    _currStepDetails = StepDetails(stepType, currObj, 0);

    _stepWatch.start();
  }

  void postStep() {
    _stepWatch.stop();

    var duration = millisecs(_stepWatch);
    _stepTotal += duration;

    _rootNode.addSample(_currStepStack, duration);

    _currStepDetails.time = duration;
    _stepDetails.add(_currStepDetails);
  }

  /// <summary>
  /// Generate a printable report specifying the average and maximum times spent
  /// stepping over different internal ink instruction types.
  /// This report type is primarily used to profile the ink engine itself rather
  /// than your own specific ink.
  /// </summary>
  String stepLengthReport() {
    // var sb = StringBuffer();

    // sb.writeln("TOTAL: ${_rootNode.totalMillisecs} ms");

    // var averageStepTimes = _stepDetails
    // 	.groupBy((s) => s.type)
    // 	.Select(typeToDetails => KeyValuePair<String, double>(typeToDetails.Key, typeToDetails.average(d => d.time)))
    // 	.OrderByDescending(stepTypeToAverage => stepTypeToAverage.Value)
    // 	.Select(stepTypeToAverage => {
    // 		var typeName = stepTypeToAverage.Key;
    // 		var time = stepTypeToAverage.Value;
    // 		return typeName + ": " + time + "ms";
    // 	})
    // 	.ToArray();

    // sb.writeln("AVERAGE STEP TIMES: "+String.Join(", ", averageStepTimes));

    // var accumStepTimes = _stepDetails
    // 	.GroupBy(s => s.type)
    // 	.Select(typeToDetails => KeyValuePair<String, double>(typeToDetails.Key + " (x"+typeToDetails.Count()+")", typeToDetails.sum(d => d.time)))
    // 	.OrderByDescending(stepTypeToAccum => stepTypeToAccum.Value)
    // 	.Select(stepTypeToAccum => {
    // 		var typeName = stepTypeToAccum.Key;
    // 		var time = stepTypeToAccum.Value;
    // 		return typeName + ": " + time;
    // 	})
    // 	.ToArray();

    // sb.writeln("ACCUMULATED STEP TIMES: ${String.Join(", ", accumStepTimes)}");

    // return sb.toString();
    return "String stepLengthReport not implemented";
  }

  /// <summary>
  /// Create a large log of all the internal instructions that were evaluated while profiling was active.
  /// Log is in a tab-separated format, for easy loading into a spreadsheet application.
  /// </summary>
  String megalog() {
    var sb = StringBuffer();

    sb.writeln("Step type\tDescription\tPath\tTime");

    for (var step in _stepDetails) {
      sb.write(step.type);
      sb.write("\t");
      sb.write(step.obj.toString());
      sb.write("\t");
      sb.write(step.obj?.path);
      sb.write("\t");
      sb.writeln(step.time.toString()); // numberFormat to 8 decimal places
    }

    return sb.toString();
  }

  void preSnapshot() {
    _snapWatch.reset();
    _snapWatch.start();
  }

  void postSnapshot() {
    _snapWatch.stop();
    _snapTotal += millisecs(_snapWatch);
  }

  double millisecs(Stopwatch watch) {
    var ticks = watch.elapsedTicks;
    return ticks * _millisecsPerTick;
  }

  static String formatMillisecs(double num) {
    if (num > 5000) {
      return "${num / 1000} secs"; // TODO numberformat ######.0
    }
    if (num > 1000) {
      return "${num / 1000} secs"; // numberformat ######.00
    } else if (num > 100) {
      return "$num ms"; // numberformat ######.
    } else if (num > 1) {
      return "$num ms"; // numberformat ######.0
    } else if (num > 0.01) {
      return "$num ms"; // numberformat ######.000
    } else {
      return "$num ms"; // numberformat default
    }
  }

  final Stopwatch _continueWatch = Stopwatch();
  final Stopwatch _stepWatch = Stopwatch();
  final Stopwatch _snapWatch = Stopwatch();

  double _continueTotal = 0;
  double _snapTotal = 0;
  double _stepTotal = 0;

  List<String?>? _currStepStack;
  StepDetails _currStepDetails = StepDetails();
  late ProfileNode _rootNode;
  int _numContinues = 0;

  final List<StepDetails> _stepDetails = <StepDetails>[];

  static final double _millisecsPerTick = 1000.0 / Stopwatch().frequency;
}

/// In original code this was a struct so we make a default
class StepDetails {
  String? type;
  InkObject? obj;
  double time;

  StepDetails([this.type, this.obj, this.time = 0]);
}

/// <summary>
/// Node used in the hierarchical tree of timings used by the Profiler.
/// Each node corresponds to a single line viewable in a UI-based representation.
/// </summary>
class ProfileNode {
  /// <summary>
  /// The key for the node corresponds to the printable name of the callstack element.
  /// </summary>
  final String? key;

  // #pragma warning disable 0649
  /// <summary>
  /// Horribly hacky field only used by ink unity integration,
  /// but saves constructing an entire data structure that mirrors
  /// the one in here purely to store the state of whether each
  /// node in the UI has been opened or not  /// </summary>
  bool openInUI = false;
  // #pragma warning restore 0649

  /// <summary>
  /// Whether this node contains any sub-nodes - i.e. does it call anything else
  /// that has been recorded?
  /// </summary>
  /// <value><c>true</c> if has children; otherwise, <c>false</c>.</value>
  bool get hasChildren => _nodes != null && _nodes.isNotEmpty;

  /// <summary>
  /// Total number of milliseconds this node has been active for.
  /// </summary>
  int get totalMillisecs => _totalMillisecs as int;

  ProfileNode([this.key]);

  void addSample(List<String?>? stack, double duration) {
    addSampleWithId(stack!, -1, duration);
  }

  void addSampleWithId(List<String?> stack, int stackIdx, double duration) {
    _totalSampleCount++;
    _totalMillisecs += duration;

    if (stackIdx == stack.length - 1) {
      _selfSampleCount++;
      _selfMillisecs += duration;
    }

    if (stackIdx + 1 < stack.length) {
      addSampleToNode(stack, stackIdx + 1, duration);
    }
  }

  void addSampleToNode(List<String?> stack, int stackIdx, double duration) {
    var nodeKey = stack[stackIdx];
    if (_nodes == null) _nodes = Map<String, ProfileNode>();

    ProfileNode? node = _nodes[nodeKey];
    if (!_nodes.containsKey(nodeKey)) {
      node = ProfileNode(nodeKey);
      _nodes[nodeKey!] = node;
    }

    node!.addSampleWithId(stack, stackIdx, duration);
  }

  /// <summary>
  /// Returns a sorted enumerable of the nodes in descending order of
  /// how long they took to run.
  /// </summary>
  List<KeyValuePair<String, ProfileNode>>? get descendingOrderedNodes {
    if (_nodes == null) return null;
    var sortedMapEntries = _nodes.entries.toList()
      ..sort((a, b) {
        return a.value.totalMillisecs.compareTo(b.value.totalMillisecs);
      });

    var returnable = <KeyValuePair<String, ProfileNode>>[];
    for (var entry in sortedMapEntries) {
      returnable.add(KeyValuePair(entry.key, entry.value));
    }

    return returnable.reversed.toList();
  }

  void printHierarchy(StringBuffer sb, int indent) {
    pad(sb, indent);

    sb.write(key);
    sb.write(": ");
    sb.writeln(ownReport);

    if (_nodes == null) return;

    for (var keyNode in descendingOrderedNodes!) {
      keyNode.value.printHierarchy(sb, indent + 1);
    }
  }

  /// <summary>
  /// Generates a String giving timing information for this single node, including
  /// total milliseconds spent on the piece of ink, the time spent within itself
  /// (v.s. spent in children), as well as the number of samples (instruction steps)
  /// recorded for both too.
  /// </summary>
  /// <value>The own report.</value>
  String get ownReport {
    var sb = StringBuffer();
    sb.write("total ");
    sb.write(Profiler.formatMillisecs(_totalMillisecs));
    sb.write(", self ");
    sb.write(Profiler.formatMillisecs(_selfMillisecs));
    sb.write(" (");
    sb.write(_selfSampleCount);
    sb.write(" self samples, ");
    sb.write(_totalSampleCount);
    sb.write(" total)");
    return sb.toString();
  }

  void pad(StringBuffer sb, int spaces) {
    for (int i = 0; i < spaces; i++) {
      sb.write("   ");
    }
  }

  /// <summary>
  /// String is a report of the sub-tree from this node, but without any of the header information
  /// that's prepended by the Profiler in its Report() method.
  /// </summary>
  @override
  String toString() {
    var sb = StringBuffer();
    printHierarchy(sb, 0);
    return sb.toString();
  }

  late Map<String, ProfileNode> _nodes;
  double _selfMillisecs = 0;
  double _totalMillisecs = 0;
  int _selfSampleCount = 0;
  int _totalSampleCount = 0;
}
