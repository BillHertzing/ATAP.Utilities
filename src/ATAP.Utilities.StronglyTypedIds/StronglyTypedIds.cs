using System;
// For Converter
using System.ComponentModel;
using System.Collections.Concurrent;
using System.Globalization;
using System.Linq.Expressions;
// For the NotNullWhenAttribute used in code
using System.Diagnostics.CodeAnalysis;

namespace ATAP.Utilities.StronglyTypedID {
  // Attribution (earlier): taken from answers provided to this question: https://stackoverflow.com/questions/53748675/strongly-typed-guid-as-generic-struct
  // Modifications:  CheckValue and all references removed, because our use case requires Guid.Empty to be a valid value
  // Attribution 1/8/2021:[Using C# 9 records as strongly-typed ids](https://thomaslevesque.com/2020/10/30/using-csharp-9-records-as-strongly-typed-ids/)

  public record GuidStronglyTypedID : StronglyTypedID<Guid> {
    public GuidStronglyTypedID(Guid value) : base(value) { }
  }
  public record IntStronglyTypedID : StronglyTypedID<int> {
      public IntStronglyTypedID(int value) : base(value) {      }
    }
    public abstract record StronglyTypedID<TValue> : IStronglyTypedID<TValue> where TValue : notnull {
      public TValue Value { get; init; }
      public override string ToString() => Value.ToString();
      public StronglyTypedID() { }
      // ToDo: figure out how to generate a random value for the StronglyTypedID in the parameterless constructor
      // public StronglyTypedID() {
      //   Value = (typeof(TValue)) switch {
      //     Type inttype when typeof(TValue) == typeof(int) =>  new Random().Next(),
      //     Type guidtype when typeof(TValue) == typeof(Guid) => Guid.NewGuid(),
      //     _ => throw new Exception(String.Format("Invalid TValue type {0}", typeof(TValue)))
      //   };
      // }
      public StronglyTypedID(TValue value) {
        Value = value;
      }
      /*
      public static bool AllowedTValue() {
        return (typeof(TValue)) switch {
          Type intType when intType == typeof(int) => true,
          Type GuidType when GuidType == typeof(Guid) => true,
          _ => false,
        };
      }
      private static TValue RandomTValue() {
        if (!AllowedTValue()) {
          throw new Exception(String.Format("Invalid TValue type {0}", typeof(TValue)));
        }
        return (typeof(TValue)) switch {
          Type intType when intType == typeof(int) => new Random().Next as TValue; // Compiletime error
              Type GuidType when GuidType == typeof(Guid) => (TValue)Guid.NewGuid(), // Compiletime error
        };
      }
      */
    }
    public class StronglyTypedIDConverter<TValue> : TypeConverter
      where TValue : notnull {
      private static readonly TypeConverter IdValueConverter = GetIdValueConverter();

      private static TypeConverter GetIdValueConverter() {
        var converter = TypeDescriptor.GetConverter(typeof(TValue));
        return !converter.CanConvertFrom(typeof(string))
          ? throw new InvalidOperationException(
              $"Type '{typeof(TValue)}' doesn't have a converter that can convert from string")
          : converter;
      }

      private readonly Type _type;
      public StronglyTypedIDConverter(Type type) {
        _type = type;
      }

      public override bool CanConvertFrom(ITypeDescriptorContext context, Type sourceType) {
        return sourceType == typeof(string)
            || sourceType == typeof(TValue)
            || base.CanConvertFrom(context, sourceType);
      }

      public override bool CanConvertTo(ITypeDescriptorContext context, Type destinationType) {
        return destinationType == typeof(string)
            || destinationType == typeof(TValue)
            || base.CanConvertTo(context, destinationType);
      }

      public override object ConvertFrom(ITypeDescriptorContext context, CultureInfo culture, object value) {
        if (value is string s) {
          value = IdValueConverter.ConvertFrom(s);
        }

        if (value is TValue idValue) {
          var factory = StronglyTypedIDHelper.GetFactory<TValue>(_type);
          return factory(idValue);
        }

        return base.ConvertFrom(context, culture, value);
      }

      public override object ConvertTo(ITypeDescriptorContext context, CultureInfo culture, object value, Type destinationType) {
        if (value is null) {
          throw new ArgumentNullException(nameof(value));
        }

        var StronglyTypedID = (StronglyTypedID<TValue>)value;
        TValue idValue = StronglyTypedID.Value;
        if (destinationType == typeof(string)) {
          return idValue.ToString()!;
        }

        if (destinationType == typeof(TValue)) {
          return idValue;
        }

        return base.ConvertTo(context, culture, value, destinationType);
      }
    }

    public class StronglyTypedIDConverter : TypeConverter {
      private static readonly ConcurrentDictionary<Type, TypeConverter> ActualConverters = new();

      private readonly TypeConverter _innerConverter;

      public StronglyTypedIDConverter(Type StronglyTypedIDType) {
        _innerConverter = ActualConverters.GetOrAdd(StronglyTypedIDType, CreateActualConverter);
      }

      public override bool CanConvertFrom(ITypeDescriptorContext context, Type sourceType) =>
          _innerConverter.CanConvertFrom(context, sourceType);
      public override bool CanConvertTo(ITypeDescriptorContext context, Type destinationType) =>
          _innerConverter.CanConvertTo(context, destinationType);
      public override object ConvertFrom(ITypeDescriptorContext context, CultureInfo culture, object value) =>
          _innerConverter.ConvertFrom(context, culture, value);
      public override object ConvertTo(ITypeDescriptorContext context, CultureInfo culture, object value, Type destinationType) =>
          _innerConverter.ConvertTo(context, culture, value, destinationType);

      private static TypeConverter CreateActualConverter(Type StronglyTypedIDType) {
        if (!StronglyTypedIDHelper.IsStronglyTypedID(StronglyTypedIDType, out var idType)) {
          throw new InvalidOperationException($"The type '{StronglyTypedIDType}' is not a strongly typed id");
        }

        var actualConverterType = typeof(StronglyTypedIDConverter<>).MakeGenericType(idType);
        return (TypeConverter)Activator.CreateInstance(actualConverterType, StronglyTypedIDType)!;
      }
    }

    public static class StronglyTypedIDHelper {
      private static readonly ConcurrentDictionary<Type, Delegate> StronglyTypedIDFactories = new();

      public static Func<TValue, object> GetFactory<TValue>(Type StronglyTypedIDType)
          where TValue : notnull {
        return (Func<TValue, object>)StronglyTypedIDFactories.GetOrAdd(
            StronglyTypedIDType,
            CreateFactory<TValue>);
      }

      private static Func<TValue, object> CreateFactory<TValue>(Type StronglyTypedIDType)
          where TValue : notnull {
        if (!IsStronglyTypedID(StronglyTypedIDType)) {
          throw new ArgumentException($"Type '{StronglyTypedIDType}' is not a strongly-typed id type", nameof(StronglyTypedIDType));
        }

        var ctor = StronglyTypedIDType.GetConstructor(new[] { typeof(TValue) });
        if (ctor is null) {
          throw new ArgumentException($"Type '{StronglyTypedIDType}' doesn't have a constructor with one parameter of type '{typeof(TValue)}'", nameof(StronglyTypedIDType));
        }

        var param = Expression.Parameter(typeof(TValue), "value");
        var body = Expression.New(ctor, param);
        var lambda = Expression.Lambda<Func<TValue, object>>(body, param);
        return lambda.Compile();
      }

      public static bool IsStronglyTypedID(Type type) => IsStronglyTypedID(type, out _);

      public static bool IsStronglyTypedID(Type type, [NotNullWhen(true)] out Type idType) {
        if (type is null) {
          throw new ArgumentNullException(nameof(type));
        }

        if (type.BaseType is Type baseType &&
              baseType.IsGenericType &&
              baseType.GetGenericTypeDefinition() == typeof(StronglyTypedID<>)) {
          idType = baseType.GetGenericArguments()[0];
          return true;
        }

        idType = null;
        return false;
      }
    }


    public struct IdAsStruct<T> : IEquatable<IdAsStruct<T>>, IIdAsStruct<T> {
      private readonly Guid _value;

      public IdAsStruct(string value) {
        bool success;
        string iValue;
        if (string.IsNullOrEmpty(value)) {
          _value = Guid.NewGuid();
        }
        else {
          // Hack, used because only ServiceStack Json serializers add extra enclosing ".
          //  but, neither simpleJson nor NewtonSoft will serialize this at all
          iValue = value.Trim('"');
          success = Guid.TryParse(iValue, out Guid newValue);
          if (!success) { throw new NotSupportedException($"Guid.TryParse failed, value {value} cannot be parsed as a GUID"); }
          _value = newValue;
        }
      }

      public IdAsStruct(Guid value) {
        _value = value;
      }

      public override bool Equals(object obj) {
        return obj is IdAsStruct<T> id && Equals(id);
      }

      public bool Equals(IdAsStruct<T> other) {
        return _value.Equals(other._value);
      }

      public override int GetHashCode() => _value.GetHashCode();

      public override string ToString() {
        return _value.ToString();
      }

      public static bool operator ==(IdAsStruct<T> left, IdAsStruct<T> right) {
        return left.Equals(right);
      }

      public static bool operator !=(IdAsStruct<T> left, IdAsStruct<T> right) {
        return !(left == right);
      }
    }
  }
