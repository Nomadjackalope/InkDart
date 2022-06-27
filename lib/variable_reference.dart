part of inky;

class VariableReference extends InkObject
    {
        // Normal named variable
        String? name;

        // Variable reference is actually a path for a visit (read) count
       Path? pathForCount;

        Container get containerForCount => resolvePath (pathForCount!).container;
            
            
        String? get pathStringForCount  
             {
                if( pathForCount == null ) {
                  return null;
                }

                return compactPathString(pathForCount!);
            }
            set pathStringForCount(String? value) {
                if (value == null) {
                  pathForCount = null;
                } else {
                  pathForCount = Path.fromString(value);
                }
            }
        

        VariableReference ([this.name]);

        // Require default constructor for serialisation
        // VariableReference() {}

        @override
        String toString ()
        {
            if (name != null) {
                return "var($name)";
            } else {
                var pathStr = pathStringForCount;
                return "read_count($pathStr)";
            }
        }
    }