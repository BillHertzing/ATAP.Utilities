public class AnsiblePlayBlockUserWindows : IAnsiblePlayBlockUserWindows
{
  public string Name { get; set; }
  public string Fullname { get; set; }
  public string Description { get; set; }
  public string Groups { get; set; }
  public string Password { get; set; }
  public AnsiblePlayBlockUserWindows(string name, string fullname, string description, string groups, string password)
  {
    Name = name;
    Fullname = fullname;
    Description = description;
    Groups = groups;
    Password = password;
  }
}
