using System.IO;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IFSEntityArchiveFile
  {
    FileInfo FileInfo { get; set; }
    string Hash { get; set; }
  }
}