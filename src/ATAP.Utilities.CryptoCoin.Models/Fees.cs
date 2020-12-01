using ATAP.Utilities.CryptoCoin.Interfaces;

namespace ATAP.Utilities.CryptoCoin.Models
{
  public class Fees : IFees
  {
    public Fees(double feeAsAPercent)
    {
      FeeAsAPercent = feeAsAPercent;
    }

    public Fees()
    {
    }

    public override string ToString()
    {
      return $"{FeeAsAPercent}";
    }

    public double FeeAsAPercent { get; set; }
  }

}
