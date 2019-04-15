using System.ComponentModel;

namespace ATAP.Utilities.FileSystem.Enumerations
{
  public enum Operation
  {
    //ToDo: Add [LocalizedDescription("CRC32", typeof(Resource))]
    [Description("CRC32")]
    CRC32,
    [Description("MD5")]
    MD5
  }
}
