using ATAP.Utilities.Philote;
using System;
using System.Collections.Generic;
using System.IO;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IFSEntityAbstract
  {
    Exception Exception { get; set; }
    string Path { get; set; }
    IPhilote<IFSEntityAbstract> Philote { get; set; }
  }
  public interface IFSEntityDirectory : IFSEntityAbstract
  {
    DirectoryInfo? DirectoryInfo { get; set; }
  }
  public interface IFSEntityFile : IFSEntityAbstract
  {
    FileInfo FileInfo { get; set; }
    string Hash { get; set; }

  }

}
