using System.ComponentModel;
namespace ATAP.Utilities.ComputerInventory.Software
{
  public enum CrudType
  {
    //ToDo: Add [LocalizedDescription("Create", typeof(Resource))]
    [Description("Create")]
    Create = 0,
    [Description("Replace")]
    Replace = 1,
    [Description("Update")]
    Update = 2,
    [Description("Delete")]
    Delete = 3
  }
}
