using System;

namespace ATAP.Utilities.Philote;

public interface IPhiloteConverterFactory
{
  bool CanConvert(Type typeToConvert);
}
