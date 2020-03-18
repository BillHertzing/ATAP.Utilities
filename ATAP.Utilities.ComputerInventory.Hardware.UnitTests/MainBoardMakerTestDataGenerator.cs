using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{


  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class MainBoardMakerTestData
  {
    public MainBoardMaker MainBoardMaker = MainBoardMaker.Generic;
    public string SerializedMainBoardMaker = "0";

    public MainBoardMakerTestData()
    {
    }

    public MainBoardMakerTestData(MainBoardMaker mainBoardMaker, string serializedMainBoardMaker)
    {
      MainBoardMaker = mainBoardMaker;
      SerializedMainBoardMaker = serializedMainBoardMaker ?? throw new ArgumentNullException(nameof(serializedMainBoardMaker));
    }
  }

  public class MainBoardMakerTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new MainBoardMakerTestData[] { new MainBoardMakerTestData { MainBoardMaker = MainBoardMaker.Generic, SerializedMainBoardMaker = "0" } };
      yield return new MainBoardMakerTestData[] { new MainBoardMakerTestData { MainBoardMaker = MainBoardMaker.ASUS, SerializedMainBoardMaker = "1" } };
      yield return new MainBoardMakerTestData[] { new MainBoardMakerTestData { MainBoardMaker = MainBoardMaker.MSI, SerializedMainBoardMaker = "2" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
