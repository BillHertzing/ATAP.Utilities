using System.ComponentModel;
namespace ATAP.Utilities.ComputerInventory.Enumerations
{
  public enum HashAlgorithm
  {
    //ToDo: Add [LocalizedDescription("CRC32", typeof(Resource))]
    [Description("CRC32")]
    CRC32 = 0,
    [Description("MD5")]
    MD5 = 1
  }

  public enum PartitionFileSystem
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("NTFS")]
    NTFS = 1,
    [Description("FAT32")]
    FAT32 = 2
  }

}

