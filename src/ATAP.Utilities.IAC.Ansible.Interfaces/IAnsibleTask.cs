namespace ATAP.Utilities.IAC.Ansible
{
  public interface IAnsibleTask
  {
    string Name { get; set; }
    List<IAnsiblePlay> Items { get; set; }
  }
}
