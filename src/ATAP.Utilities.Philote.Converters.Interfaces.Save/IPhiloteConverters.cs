using System;
using ATAP.Utilities.StronglyTypedIDs;
using ATAP.Utilities.Serializer;
using Itenso.TimePeriod;
using System.Collections.Generic;

namespace ATAP.Utilities.Philote
{

  public interface IPhiloteConverterFactory<T> : ISerializerConverterFactory<T>
  {
     bool CanConvert(Type typeToConvert);
      ISerializerConverter<T> CreateConverter(
            Type T,
            ISerializerOptions options);
  }
}
