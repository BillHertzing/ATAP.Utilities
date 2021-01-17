using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using System.Linq;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.StronglyTypedIDs;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class MainBoardTestData : TestData<MainBoard>
  {
    public MainBoardTestData(MainBoard objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class MainBoardTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      StringBuilder str = new StringBuilder();
      foreach (MainBoardSignilTestData[] signil in MainBoardSignilTestDataGenerator.TestData())
      {
        foreach (CPUEnumerableTestData[] cPUEnumerable in CPUEnumerableTestDataGenerator.TestData())
        {
          if (cPUEnumerable[0].E.FirstOrDefault() == null) { continue; }
          foreach (DiskDriveEnumerableTestData[] diskDriveEnumerable in DiskDriveEnumerableTestDataGenerator.TestData())
          {
            if (diskDriveEnumerable[0].E.FirstOrDefault() == null) { continue; }
            foreach (PhiloteTestData<IMainBoard>[] philote in PhiloteTestDataGenerator<IMainBoard>.TestData())
            {

              str.Clear();
              str.Append($"{{\"MainBoardSignil\":{signil[0].SerializedTestData},\"CPUEnumerable\":{{{cPUEnumerable[0].E.FirstOrDefault().SerializedTestData}}},\"DiskDriveEnumerable\":{{{diskDriveEnumerable[0].E.FirstOrDefault().SerializedTestData}}},\"Philote\":{philote[0].SerializedTestData}}}");
              yield return new MainBoardTestData[] { new MainBoardTestData(new MainBoard(signil[0].ObjTestData, cPUEnumerable[0].E.Select(x => x.ObjTestData), diskDriveEnumerable[0].E.Select(x => x.ObjTestData), philote[0].ObjTestData), str.ToString()) };
            }
          }
        }
      }
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
