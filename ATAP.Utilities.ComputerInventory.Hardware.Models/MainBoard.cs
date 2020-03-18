
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Models.Hardware
{

  [Serializable]
  public class MainBoard : IMainBoard
  {
    public MainBoard()
    {
    }

    public MainBoard(IMainBoardSignil mainBoardSignil, ICPU[] cPUs, Id<IMainBoard>? iD, ITimeBlock timeBlock)
    {
      MainBoardSignil = mainBoardSignil ?? throw new ArgumentNullException(nameof(mainBoardSignil));
      CPUs = cPUs ?? throw new ArgumentNullException(nameof(cPUs));
      ID = iD;
      TimeBlock = timeBlock ?? throw new ArgumentNullException(nameof(timeBlock));
    }

    public IMainBoardSignil MainBoardSignil { get; private set; }
    public ICPU[] CPUs { get; private set; }
    public Id<IMainBoard>? ID { get; private set; }
    public ITimeBlock? TimeBlock { get; private set; }
  }

}
