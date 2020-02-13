using System.ComponentModel;
using ATAP.Utilities.Enumeration;
namespace ATAP.Utilities.ComputerInventory.Enumerations
{
    public enum CrudType {
        //ToDo: Add [LocalizedDescription("Create", typeof(Resource))]
        [Description("Create")]
        Create,
        [Description("Replace")]
        Replace,
        [Description("Update")]
        Update,
        [Description("Delete")]
        Delete
    }
}
