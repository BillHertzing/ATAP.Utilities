namespace ATAP.Utilities.Secrets;

public class SecretsOptions : ISecretsOptionsAbstract
{
  public SecretsOptions(object shimSpecificOptions)
  {
    ShimSpecificOptions = shimSpecificOptions;
  }

  public object ShimSpecificOptions { get; }
}
