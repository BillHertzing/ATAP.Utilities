using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;
using Xunit;
using FluentAssertions;

namespace ATAP.Utilities.ZSandbox.UnitTests
{
  public enum CPUMaker
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic,
    [Description("Intel")]
    Intel,
    [Description("AMD")]
    AMD
  }
  public class DynamicEnumList_UnitTests
  {
    [Theory]
    [InlineData("10")]
    public void CreateList(string _testdatainput)
    {
      var str = "10";
      str.Should()
          .Be(_testdatainput);
    }
  }
}
