using System.ComponentModel;
namespace ATAP.Utilities.ComputerInventory.Enumerations
{
    public enum HashAlgorithm {
        //ToDo: Add [LocalizedDescription("CRC32", typeof(Resource))]
        [Description("CRC32")]
        CRC32,
        [Description("MD5")]
        MD5
    }

  public enum PartitionFileSystem
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic,
    [Description("NTFS")]
    NTFS,
    [Description("FAT32")]
    FAT32
  }

}

