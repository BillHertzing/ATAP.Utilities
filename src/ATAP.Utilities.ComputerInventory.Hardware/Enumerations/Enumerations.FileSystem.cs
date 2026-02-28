using System.ComponentModel;
namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public enum HashAlgorithm
  {
    //ToDo: Add [LocalizedDescription("CRC32", typeof(Resource))]
    [Description("CRC32")]
    CRC32 = 0,
    [Description("MD5")]
    MD5 = 1
  }

  public enum FSEntity
  {
    //ToDo: Add [LocalizedDescription("CRC32", typeof(Resource))]
    [Description("Directory")]
    Directory = 0,
    [Description("File")]
    File = 1,
    [Description("ArchiveFile")]
    ArchiveFile = 2,
    [Description("SoftLink")]
    SoftLink = 3,
    [Description("HardLink")]
    HardLink = 4,
  }
}

