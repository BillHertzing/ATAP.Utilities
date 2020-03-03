using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;
using ATAP.Utilities.ComputerInventory.Models.Hardware;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class MainBoardTestData
  {
    public MainBoard MainBoard;
    public string SerializedMainBoard;

    public MainBoardTestData()
    {
    }

    public MainBoardTestData(MainBoard mainBoard, string serializedMainBoard)
    {
      MainBoard = mainBoard ?? throw new ArgumentNullException(nameof(mainBoard));
      SerializedMainBoard = serializedMainBoard ?? throw new ArgumentNullException(nameof(serializedMainBoard));
    }
  }

  public class MainBoardTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> MainBoardTestData()
    {
      yield return new MainBoardTestData[] { new MainBoardTestData { MainBoard = new MainBoard
        (MainBoardMaker.ASUS,
        CPUSocket.LGA1155
        ), SerializedMainBoard = "{\"Maker\":0}" } };
      yield return new MainBoardTestData[] { new MainBoardTestData { MainBoard = new MainBoard(
        MainBoardMaker.MSI,
        CPUSocket.LGA1156
        ), SerializedMainBoard = "{\"Maker\":1}" } };
      yield return new MainBoardTestData[] { new MainBoardTestData { MainBoard = new MainBoard(
        MainBoardMaker.Generic, CPUSocket.Generic
        ), SerializedMainBoard = "{\"Maker\":2}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return MainBoardTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
