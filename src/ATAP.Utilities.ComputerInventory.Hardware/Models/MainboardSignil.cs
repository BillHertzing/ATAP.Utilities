
using System;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  [Serializable]
  public class MainBoardSignil : IMainBoardSignil
  {
    public MainBoardSignil()
    {
    }

    public MainBoardSignil(MainBoardMaker mainBoardMaker, CPUSocket cPUSocket, int numberOfX1SlotsMax)
    {
      MainBoardMaker = mainBoardMaker;
      CPUSocket = cPUSocket;
      NumberOfX1SlotsMax = numberOfX1SlotsMax;
    }

    public MainBoardMaker MainBoardMaker { get; private set; }
    public CPUSocket CPUSocket { get; private set; }

    public int NumberOfX1SlotsMax { get; private set; }

  }


}
