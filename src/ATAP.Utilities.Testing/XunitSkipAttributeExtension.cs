using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Xunit;

namespace ATAP.Utilities.Testing.XunitSkipAttributeExtension
{
  //Attribution: [Skipping XUnit tests based on runtime conditions](https://josephwoodward.co.uk/2019/01/skipping-xunit-tests-based-on-runtime-conditions)
  public sealed class Fact : TheoryAttribute
  {
    public Fact()
    {
        Skip = "Skipped because test is not working";
    }
  }
  public sealed class SkipOnAppVeyorTheory : TheoryAttribute
  {
    public SkipOnAppVeyorTheory()
    {
      if (IsAppVeyor())
      {
        Skip = "Skip this test when run via AppVeyor";
      }
    }

    private static bool IsAppVeyor()
        => Environment.GetEnvironmentVariable("APPVEYOR") != null;
  }
}
