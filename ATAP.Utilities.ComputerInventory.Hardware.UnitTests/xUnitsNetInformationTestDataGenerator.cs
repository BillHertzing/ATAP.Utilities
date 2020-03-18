using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{


  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class UnitsNetInformationTestData : TestData<UnitsNet.Information>
  {
    public UnitsNetInformationTestData(UnitsNet.Information objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class UnitsNetInformationTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new UnitsNetInformationTestData[] { new UnitsNetInformationTestData(new UnitsNet.Information(1, UnitsNet.Units.InformationUnit.Megabyte), "\"1 MB\"") };
      yield return new UnitsNetInformationTestData[] { new UnitsNetInformationTestData(new UnitsNet.Information(100, UnitsNet.Units.InformationUnit.Megabyte), "\"100 MB\"") };
      yield return new UnitsNetInformationTestData[] { new UnitsNetInformationTestData(new UnitsNet.Information(2, UnitsNet.Units.InformationUnit.Gigabyte), "\"2 GB\"") };
      yield return new UnitsNetInformationTestData[] { new UnitsNetInformationTestData(new UnitsNet.Information(200, UnitsNet.Units.InformationUnit.Gigabyte), "\"200 GB\"") };
      yield return new UnitsNetInformationTestData[] { new UnitsNetInformationTestData(new UnitsNet.Information(1, UnitsNet.Units.InformationUnit.Terabyte), "\"1 TB\"") };
      yield return new UnitsNetInformationTestData[] { new UnitsNetInformationTestData(new UnitsNet.Information(4, UnitsNet.Units.InformationUnit.Terabyte), "\"4 TB\"") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
