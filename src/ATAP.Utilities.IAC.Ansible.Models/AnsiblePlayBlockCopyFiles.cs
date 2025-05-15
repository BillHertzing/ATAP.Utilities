namespace ATAP.Utilities.IAC.Ansible
{
  public class AnsiblePlayBlockCopyFiles : IAnsiblePlayBlockCopyFiles
  {
    public string Name { get; set; }
    public string Source { get; set; }
    public string Destination { get; set; }

    public AnsiblePlayBlockCopyFiles(string name, string source, string destination)
    {
      Name = name;
      Source = source;
      Destination = destination;
    }
  }
}
