part of inky;

class CommandType {
  static const int notSet = -1;
  static const int evalStart = 0;
  static const int evalOutput = 1;
  static const int evalEnd = 2;
  static const int duplicate = 3;
  static const int popEvaluatedValue = 4;
  static const int popFunction = 5;
  static const int popTunnel = 6;
  static const int beginString = 7;
  static const int endString = 8;
  static const int noOp = 9;
  static const int choiceCount = 10;
  static const int turns = 11;
  static const int turnsSince = 12;
  static const int readCount = 13;
  static const int random = 14;
  static const int seedRandom = 15;
  static const int visitIndex = 16;
  static const int sequenceShuffleIndex = 17;
  static const int startThread = 18;
  static const int done = 19;
  static const int end = 20;
  static const int listFromInt = 21;
  static const int listRange = 22;
  static const int listRandom = 23;
  //----
  static const int TOTAL_VALUES = 24;

  static int fromString(String name) {
    switch (name) {
      case "notSet":
        return -1;
      case "evalStart":
        return 0;
      case "evalOutput":
        return 1;
      case "evalEnd":
        return 2;
      case "duplicate":
        return 3;
      case "popEvaluatedValue":
        return 4;
      case "popFunction":
        return 5;
      case "popTunnel":
        return 6;
      case "beginString":
        return 7;
      case "endString":
        return 8;
      case "noOp":
        return 9;
      case "choiceCount":
        return 10;
      case "turns":
        return 11;
      case "turnsSince":
        return 12;
      case "readCount":
        return 13;
      case "random":
        return 14;
      case "seedRandom":
        return 15;
      case "visitIndex":
        return 16;
      case "sequenceShuffleIndex":
        return 17;
      case "startThread":
        return 18;
      case "done":
        return 19;
      case "end":
        return 20;
      case "listFromInt":
        return 21;
      case "listRange":
        return 22;
      case "listRandom":
        return 23;
    }

    throw FormatException("No string found for $name");
  }

  static String fromInt(int i) {
    switch (i) {
      case -1:
        return "notSet";
      case 0:
        return "evalStart";
      case 1:
        return "evalOutput";
      case 2:
        return "evalEnd";
      case 3:
        return "duplicate";
      case 4:
        return "popEvaluatedValue";
      case 5:
        return "popFunction";
      case 6:
        return "popTunnel";
      case 7:
        return "beginString";
      case 8:
        return "endString";
      case 9:
        return "noOp";
      case 10:
        return "choiceCount";
      case 11:
        return "turns";
      case 12:
        return "turnsSince";
      case 13:
        return "readCount";
      case 14:
        return "random";
      case 15:
        return "seedRandom";
      case 16:
        return "visitIndex";
      case 17:
        return "sequenceShuffleIndex";
      case 18:
        return "startThread";
      case 19:
        return "done";
      case 20:
        return "end";
      case 21:
        return "listFromInt";
      case 22:
        return "listRange";
      case 23:
        return "listRandom";
    }

    throw FormatException("No string found for $i");
  }
}

class ControlCommand extends InkObject {
  final int _commandType;
  int get commandType => _commandType;

  ControlCommand({int commandType = CommandType.notSet})
      : _commandType = commandType;
  // {
  // this.commandType = commandType;
  // }

  // Require default constructor for serialisation
  // ControlCommand() : this(CommandType.NotSet) {}

  @override
  InkObject copy() {
    return ControlCommand(commandType: _commandType);
  }

  // The following static factory methods are to make generating these objects
  // slightly more succinct. Without these, the code gets pretty massive! e.g.
  //
  //     var c = Runtime.ControlCommand(Runtime.ControlCommand.CommandType.EvalStart)
  //
  // as opposed to
  //
  //     var c = Runtime.ControlCommand.EvalStart()

  static ControlCommand evalStart() {
    return ControlCommand(commandType: CommandType.evalStart);
  }

  static ControlCommand evalOutput() {
    return ControlCommand(commandType: CommandType.evalOutput);
  }

  static ControlCommand evalEnd() {
    return ControlCommand(commandType: CommandType.evalEnd);
  }

  static ControlCommand duplicate() {
    return ControlCommand(commandType: CommandType.duplicate);
  }

  static ControlCommand popEvaluatedValue() {
    return ControlCommand(commandType: CommandType.popEvaluatedValue);
  }

  static ControlCommand popFunction() {
    return ControlCommand(commandType: CommandType.popFunction);
  }

  static ControlCommand popTunnel() {
    return ControlCommand(commandType: CommandType.popTunnel);
  }

  static ControlCommand beginString() {
    return ControlCommand(commandType: CommandType.beginString);
  }

  static ControlCommand endString() {
    return ControlCommand(commandType: CommandType.endString);
  }

  static ControlCommand noOp() {
    return ControlCommand(commandType: CommandType.noOp);
  }

  static ControlCommand choiceCount() {
    return ControlCommand(commandType: CommandType.choiceCount);
  }

  static ControlCommand turns() {
    return ControlCommand(commandType: CommandType.turns);
  }

  static ControlCommand turnsSince() {
    return ControlCommand(commandType: CommandType.turnsSince);
  }

  static ControlCommand readCount() {
    return ControlCommand(commandType: CommandType.readCount);
  }

  static ControlCommand random() {
    return ControlCommand(commandType: CommandType.random);
  }

  static ControlCommand seedRandom() {
    return ControlCommand(commandType: CommandType.seedRandom);
  }

  static ControlCommand visitIndex() {
    return ControlCommand(commandType: CommandType.visitIndex);
  }

  static ControlCommand sequenceShuffleIndex() {
    return ControlCommand(commandType: CommandType.sequenceShuffleIndex);
  }

  static ControlCommand startThread() {
    return ControlCommand(commandType: CommandType.startThread);
  }

  static ControlCommand done() {
    return ControlCommand(commandType: CommandType.done);
  }

  static ControlCommand end() {
    return ControlCommand(commandType: CommandType.end);
  }

  static ControlCommand listFromInt() {
    return ControlCommand(commandType: CommandType.listFromInt);
  }

  static ControlCommand listRange() {
    return ControlCommand(commandType: CommandType.listRange);
  }

  static ControlCommand listRandom() {
    return ControlCommand(commandType: CommandType.listRandom);
  }

  @override
  String toString() {
    return commandType.toString();
  }
}
