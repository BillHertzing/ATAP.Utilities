using System;
using ATAP.Utilities.StronglyTypedID;
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
            ISerializerOptionsAbstract options);
  }
}
