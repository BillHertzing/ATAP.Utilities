using System;
using System.Text;

namespace GenerateProgram
{
    public class GAssemblySingle
    {
        public GAssemblySingle(GAssemblySingleSignil gAssemblySingleSignil = default)
        {
            GAssemblySingleSignil = gAssemblySingleSignil == default ? new GAssemblySingleSignil() : gAssemblySingleSignil;
        }

        public GAssemblySingleSignil GAssemblySingleSignil { get; }
       
    }
}
