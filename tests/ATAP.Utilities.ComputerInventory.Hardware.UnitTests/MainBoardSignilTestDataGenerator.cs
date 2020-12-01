using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using System.Text;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class MainBoardSignilTestData : TestData<MainBoardSignil>
  {
    public MainBoardSignilTestData(MainBoardSignil objTestData, string serializedTestData) : base(objTestData, serializedTestData) { }
  }



  public class MainBoardSignilTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      StringBuilder str = new StringBuilder();
      foreach (MainBoardMakerTestData[] maker in MainBoardMakerTestDataGenerator.TestData())
      {
        foreach (CPUSocketTestData[] socket in CPUSocketTestDataGenerator.TestData())
        {
          str.Clear();
          str.Append($"{{\"MainBoardMaker\":{maker[0].SerializedMainBoardMaker},\"CPUSocket\":{socket[0].SerializedTestData},\"NumberOfX1SlotsMax\":6}}");
          yield return new MainBoardSignilTestData[] {
            new MainBoardSignilTestData(
              new MainBoardSignil(
                maker[0].MainBoardMaker,
                socket[0].ObjTestData,
                6
              ),
              str.ToString())};
        }
      }
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
