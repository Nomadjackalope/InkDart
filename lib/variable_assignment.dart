part of inky;

// The value to be assigned is popped off the evaluation stack, so no need to keep it here
class VariableAssignment extends InkObject {
  String? _variableName;
  String? get variableName => _variableName;

  bool _isNewDeclaration = false;
  bool get isNewDeclaration => _isNewDeclaration;

  bool isGlobal = false;

  VariableAssignment(this._variableName, this._isNewDeclaration);

  // Require default constructor for serialisation
  // VariableAssignment() : this(null, false);

  @override
  String toString() {
    return "VarAssign to $variableName";
  }
}
