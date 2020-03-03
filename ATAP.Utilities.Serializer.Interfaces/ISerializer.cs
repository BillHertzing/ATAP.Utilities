

namespace ATAP.Utilities.Serializer.Interfaces
{
  public interface ISerializer
  {
    public string Serialize(object obj);
    public T Deserialize<T>(string str);
    public void Configure();
  }
}
