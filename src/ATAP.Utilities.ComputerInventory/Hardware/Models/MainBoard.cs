
using ATAP.Utilities.Philote;
using ATAP.Utilities.StronglyTypedId;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware
{


  [Serializable]
  public class MainBoard : IMainBoard
  {
    public MainBoard()
    {
    }


    public MainBoard(IMainBoardSignil mainBoardSignil, IEnumerable<ICPU>? cPUs, IEnumerable<IDiskDrive>? diskDrives, IGuidPhilote<GuidStronglyTypedId>? philote)
    {
      MainBoardSignil = mainBoardSignil ?? throw new ArgumentNullException(nameof(mainBoardSignil));
      CPUs = cPUs;
      DiskDrives = diskDrives;
      Philote = philote;
    }

    public IMainBoardSignil MainBoardSignil { get; private set; }
    public IEnumerable<ICPU>? CPUs { get; private set; }
    public IEnumerable<IDiskDrive>? DiskDrives { get; private set; }
    public IGuidPhilote<GuidStronglyTypedId>? Philote { get; private set; }
  }

}
