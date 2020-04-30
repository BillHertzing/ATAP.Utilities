using System;
using System.Collections.Generic;
using System.Text;

namespace GenerateProgram {
  class GCompilationUnit {
    public GUsingGroup[] GUsingGroups { get; set; }
    public GNamespace GNamespace { get; set; }
    public GClass[] GClasses { get; set; }
  }
}

