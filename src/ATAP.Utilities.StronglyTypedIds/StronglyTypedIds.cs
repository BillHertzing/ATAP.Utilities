using System;
// For Converter
using System.ComponentModel;
using System.Collections.Concurrent;
using System.Globalization;
using System.Linq.Expressions;
using System.Linq;
using System.Reflection;
using System.Collections;
using System.Collections.Generic;
// For the NotNullWhenAttribute used in code
using System.Diagnostics.CodeAnalysis;

namespace ATAP.Utilities.StronglyTypedId {
  // Attribution for IdAsStruct<T>(earlier): taken from answers provided to this question: https://stackoverflow.com/questions/53748675/strongly-typed-guid-as-generic-struct
  // Modifications: CheckValue and all references removed, because our use case requires Guid.Empty to be a valid value
  // Attribution 1/8/2021:[Using C# 9 records as strongly-typed ids](https://thomaslevesque.com/2020/10/30/using-csharp-9-records-as-strongly-typed-ids/)

  /// <summary>
  /// XML Commen text regarding `public record GuidStronglyTypedId`
  /// </summary>
  public record GuidStronglyTypedId : AbstractStronglyTypedId<Guid>, IGuidStronglyTypedId {
    /// <summary>
    ///
    /// </summary>
    /// <param name="value"></param>
    public GuidStronglyTypedId(Guid value) : base(value) { }
    /// <summary>
    ///
    /// </summary>
    public GuidStronglyTypedId() : base() { }
    /// <summary>
    ///
    /// </summary>
    /// <returns></returns>
    public override string ToString() => base.ToString();

  }
  /// <summary>
  ///
  /// </summary>
  public record IntStronglyTypedId : AbstractStronglyTypedId<int>, IIntStronglyTypedId {
    /// <summary>
    ///
    /// </summary>
    /// <param name="value"></param>
    public IntStronglyTypedId(int value) : base(value) { }
    /// <summary>
    ///
    /// </summary>
    public IntStronglyTypedId() : base() { }
    /// <summary>
    ///
    /// </summary>
    /// <returns></returns>
    public override string ToString() => base.ToString();
  }

  /// <summary>
  ///
  /// </summary>
  /// <typeparam name="TValue"></typeparam>
  [TypeConverter(typeof(StronglyTypedIdConverter))]
  public abstract record AbstractStronglyTypedId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {
    /// <summary>
    ///
    /// </summary>
    public TValue Value { get; init; }
    /// <summary>
    ///
    /// </summary>
    /// <returns></returns>
    public override string ToString() { var str = Value.ToString(); return str; }
    /// <summary>
    ///
    /// </summary>
    public AbstractStronglyTypedId() {
      Value = (typeof(TValue)) switch {
              Type when typeof(TValue) == typeof(int) => (TValue)(object)new Random().Next(),
              Type when typeof(TValue) == typeof(Guid) => (TValue)(object)Guid.NewGuid(),
        _ => throw new Exception(FormattableString.Invariant($"Invalid TValue type {typeof(TValue)}"))
      };
    }
    /// <summary>
    ///
    /// </summary>
    /// <param name="value"></param>
    public AbstractStronglyTypedId(TValue value) {
      Value = value;
    }
    /// <summary>
    ///
    /// </summary>
    /// <returns></returns>
    public static bool AllowedTValue() {
      return (typeof(TValue)) switch {
        Type when typeof(TValue) == typeof(int) => true,
        Type when typeof(TValue) == typeof(Guid) => true,
        _ => false,
      };
    }
    /// <summary>
    ///
    /// </summary>
    /// <returns></returns>
    private static TValue RandomTValue() {
      if (!AllowedTValue()) {
        throw new Exception(String.Format("Invalid TValue type {0}", typeof(TValue)));
      }
      return (typeof(TValue)) switch {
        Type intType when intType == typeof(int) => (TValue)(object)new Random().Next(),
        Type GuidType when GuidType == typeof(Guid) => (TValue)(object)Guid.NewGuid(),
        // ToDo: replace with custom exception and message
        _ => throw new ArgumentException("Type of TValue is not supported"),
      };
    }
  }

  [TypeConverter(typeof(StronglyTypedIdConverter))]
  public class StronglyTypedIdConverter<TValue> : TypeConverter
    where TValue : notnull {
    private static readonly TypeConverter IdValueConverter = GetIdValueConverter();

    private static TypeConverter GetIdValueConverter() {
      var converter = TypeDescriptor.GetConverter(typeof(TValue));
      if (!converter.CanConvertFrom(typeof(string))) {
        throw new InvalidOperationException(
                $"Type '{typeof(TValue)}' doesn't have a converter that can convert from string");
      }

      return converter;
    }

    private readonly Type _type;
    public StronglyTypedIdConverter(Type type) {
      _type = type;
    }

    public override bool CanConvertFrom(ITypeDescriptorContext? context, Type sourceType) {
      return sourceType == typeof(string)
          || sourceType == typeof(TValue)
          || base.CanConvertFrom(context, sourceType);
    }

    public override bool CanConvertTo(ITypeDescriptorContext? context, Type? destinationType) {
      return destinationType == typeof(string)
          || destinationType == typeof(TValue)
          || base.CanConvertTo(context, destinationType);
    }

    public override object ConvertFrom(ITypeDescriptorContext? context, CultureInfo? culture, object value) {
      if (value is string s) {
        value = IdValueConverter.ConvertFrom(s);
      }

      if (value is TValue idValue) {
        var factory = StronglyTypedIdHelper.GetFactory<TValue>(_type);
        return factory(idValue);
      }

      return base.ConvertFrom(context, culture, value);
    }

    public override object ConvertTo(ITypeDescriptorContext? context, CultureInfo? culture, object? value, Type destinationType) {
      if (value is null) {
        throw new ArgumentNullException(nameof(value));
      }

      var stronglyTypedId = (AbstractStronglyTypedId<TValue>)value;
      TValue idValue = stronglyTypedId.Value;
      if (destinationType == typeof(string)) {
        return idValue.ToString()!;
      }

      if (destinationType == typeof(TValue)) {
        return idValue;
      }

      return base.ConvertTo(context, culture, value, destinationType);
    }
  }
  public class StronglyTypedIdConverter : TypeConverter {
    private static readonly ConcurrentDictionary<Type, TypeConverter> ActualConverters = new();

    private readonly TypeConverter _innerConverter;

    public StronglyTypedIdConverter(Type stronglyTypedIdType) {
      _innerConverter = ActualConverters.GetOrAdd(stronglyTypedIdType, CreateActualConverter);
    }

    public override bool CanConvertFrom(ITypeDescriptorContext? context, Type sourceType) =>
        _innerConverter.CanConvertFrom(context, sourceType);
    public override bool CanConvertTo(ITypeDescriptorContext? context, Type? destinationType) =>
        _innerConverter.CanConvertTo(context, destinationType);
    public override object ConvertFrom(ITypeDescriptorContext? context, CultureInfo? culture, object value) =>
        _innerConverter.ConvertFrom(context, culture, value);
    public override object ConvertTo(ITypeDescriptorContext? context, CultureInfo? culture, object? value, Type? destinationType) =>
        _innerConverter.ConvertTo(context, culture, value, destinationType);

    private static TypeConverter CreateActualConverter(Type stronglyTypedIdType) {
      if (!StronglyTypedIdHelper.IsStronglyTypedId(stronglyTypedIdType, out var idType)) {
        throw new InvalidOperationException($"The type '{stronglyTypedIdType}' is not a strongly typed id");
      }

      var actualConverterType = typeof(StronglyTypedIdConverter<>).MakeGenericType(idType);
      return (TypeConverter)Activator.CreateInstance(actualConverterType, stronglyTypedIdType)!;
    }
  }

  public static class StronglyTypedIdHelper {
    private static readonly ConcurrentDictionary<Type, Delegate> StronglyTypedIdFactories = new();

    public static Func<TValue, object> GetFactory<TValue>(Type stronglyTypedIdType)
        where TValue : notnull {
      return (Func<TValue, object>)StronglyTypedIdFactories.GetOrAdd(
          stronglyTypedIdType,
          CreateFactory<TValue>);
    }
    // attribution [Get All Types in an Assembly](https://haacked.com/archive/2012/07/23/get-all-types-in-an-assembly.aspx/)
    // ToDo: move to an ATAP Utility assembly that extends reflection over assembly's metadata
    public static IEnumerable<Type?> GetLoadableTypes(this Assembly assembly) {
      if (assembly == null) {
        throw new ArgumentNullException(nameof(assembly));
      }
      try {
        return assembly.GetTypes();
      }
      catch (ReflectionTypeLoadException e) {
        // ToDo: Improve exception handling to also report on assemblies that fail GetTypes()
        return e.Types.Where(t => t != null);
      }
    }
    // Attribution: [Get all types implementing specific open generic type](https://stackoverflow.com/questions/8645430/get-all-types-implementing-specific-open-generic-type)
    public static IEnumerable<Type> GetAllTypesImplementingOpenGenericType(this Assembly assembly, Type openGenericType) {
      return from x in assembly.GetTypes()
             from z in x.GetInterfaces()
             let y = x.BaseType
             where
               (y != null && y.IsGenericType &&
                openGenericType.IsAssignableFrom(y.GetGenericTypeDefinition())) ||
               (z.IsGenericType &&
                openGenericType.IsAssignableFrom(z.GetGenericTypeDefinition()))
             select x;
    }

    private static Func<TValue, object> CreateFactory<TValue>(Type stronglyTypedIdType)
        where TValue : notnull {
      if (!IsStronglyTypedId(stronglyTypedIdType)) {
        throw new ArgumentException($"Type '{stronglyTypedIdType}' is not a strongly-typed id type", nameof(stronglyTypedIdType));
      }
      // This starts the extensions to Mssr. Levesque's code to handle Deserialization of IAbstractStronglyTypedId
      // Attribution:[Get all types implementing specific open generic type](https://stackoverflow.com/questions/8645430/get-all-types-implementing-specific-open-generic-type)
      // Attribution:[Find all types implementing a certain generic interface with specific T type](https://stackoverflow.com/questions/33694960/find-all-types-implementing-a-certain-generic-interface-with-specific-t-type)
      Type sTIdType;
      ConstructorInfo? ctor;
      if (stronglyTypedIdType.IsInterface) {
        // Get the Interface name, strip the preceding 'I'.
        var STIdTypeName = stronglyTypedIdType.Name.Remove(0, 1);
        var idType = stronglyTypedIdType.GetGenericArguments()[0];
        var loadedAssemblies = AppDomain.CurrentDomain.GetAssemblies();
        var allTypes = loadedAssemblies.SelectMany(assembly => assembly.GetTypes());
        var typesImplementing =
          loadedAssemblies.SelectMany(assembly => assembly.GetAllTypesImplementingOpenGenericType(typeof(AbstractStronglyTypedId<TValue>)));
        // var GuidSTIdTypex = allTypes
        //   .FirstOrDefault(t => t.IsAssignableFrom((typeof (AbstractStronglyTypedId<TValue>))) &&
        //                        t.GetInterfaces().Any(x =>
        //                          x.IsGenericType &&
        //                          x.GetGenericTypeDefinition() == typeof(AbstractStronglyTypedId<TValue>) &&
        //                          x.GetGenericArguments()[0] ==  typeof(Guid)));

        // ToDo: wrap in a try/catch block
        switch (typeof(TValue)) {
          case Type intType when intType == typeof(int):
            sTIdType = allTypes.Where(t => t.Name == "IntStronglyTypedId").Single();
            ctor = sTIdType.GetConstructor(new[] { typeof(int) });
            break;
          case Type GuidType when GuidType == typeof(Guid):
            sTIdType = allTypes.Where(t => t.Name == "GuidStronglyTypedId").Single();
            ctor = sTIdType.GetConstructor(new[] { typeof(Guid) });
            break;
          default:
            // ToDo: replace with custom exception and message
            throw new ArgumentException($"Type '{typeof(TValue)}' is neither Guid nor int");

        };
        //ctor = sTIdType.GetTypeInfo().DeclaredConstructors.ToList()[1];
        if (ctor is null) {
          // ToDo: replace with custom exception and message
          throw new ArgumentException($"Type '{stronglyTypedIdType}' converted to `{sTIdType}` doesn't have a constructor with one parameter of type '{typeof(TValue)}'");
        }
        // This ends the extensions to Mssr. Levesque's code to handle Deserialization of IAbstractStronglyTypedId
      }
      else {
        ctor = stronglyTypedIdType.GetConstructor(new[] { typeof(TValue) });
        if (ctor is null) {
          // ToDo: replace with custom exception and message
          throw new ArgumentException($"Type '{stronglyTypedIdType}' doesn't have a constructor with one parameter of type '{typeof(TValue)}'");
        }
      }

      var param = Expression.Parameter(typeof(TValue), "value");
      var body = Expression.New(ctor, param);
      var lambda = Expression.Lambda<Func<TValue, object>>(body, param);
      return lambda.Compile();
    }

    public static bool IsStronglyTypedId(Type type) => IsStronglyTypedId(type, out _);
    // NotNulWhen attribute for an out argument is only supported in NetCore3.0 and later
#if NETCOREAPP2_0 || NETCOREAPP2_1 || NETSTANDARD2_0 || NETDESKTOP || NETFRAMEWORK
    public static bool IsStronglyTypedId(Type type, out Type idType) {
#else
    public static bool IsStronglyTypedId(Type type, [NotNullWhen(true)] out Type idType) {
#endif
      if (type is null) {
        throw new ArgumentNullException(nameof(type));
      }
      if (type.BaseType is Type baseType &&
            baseType.IsGenericType &&
            baseType.GetGenericTypeDefinition() == typeof(AbstractStronglyTypedId<>)) {
        idType = baseType.GetGenericArguments()[0];
        return true;
      }
      // This starts the extensions to Mssr. Levesque's code to handle serialization of IAbstractStronglyTypedId
      if (type.IsInterface && type.IsGenericType && type.GetGenericTypeDefinition() == typeof(IAbstractStronglyTypedId<>)) {
        idType = type.GetGenericArguments()[0];
        return true;
      } // This ends the extensions to Mssr. Levesque's code to handle serialization of IAbstractStronglyTypedId

      idType = null;
      return false;
      }
    }

    // The IdAsStruct is deprectated
    // public struct IdAsStruct<T> : IEquatable<IdAsStruct<T>>, IIdAsStruct<T> where T : notnull{
      // private readonly Guid _value;

      // public IdAsStruct(string value) {
        // bool success;
        // string iValue;
        // if (string.IsNullOrEmpty(value)) {
          // _value = Guid.NewGuid();
        // }
        // else {
          // // Hack, used because only ServiceStack Json serializers add extra enclosing ".
          // //  but, neither simpleJson nor NewtonSoft will serialize this at all
          // iValue = value.Trim('"');
          // success = Guid.TryParse(iValue, out Guid newValue);
          // if (!success) { throw new NotSupportedException($"Guid.TryParse failed, value {value} cannot be parsed as a GUID"); }
          // _value = newValue;
        // }
      // }

      // public IdAsStruct(Guid value) {
        // _value = value;
      // }

      // public override bool Equals(object obj) {
        // return obj is IdAsStruct<T> id && Equals(id);
      // }

      // public bool Equals(IdAsStruct<T> other) {
        // return _value.Equals(other._value);
      // }

      // public override int GetHashCode() => _value.GetHashCode();

      // public override string ToString() {
        // return _value.ToString();
      // }

      // public static bool operator ==(IdAsStruct<T> left, IdAsStruct<T> right) {
        // return left.Equals(right);
      // }

      // public static bool operator !=(IdAsStruct<T> left, IdAsStruct<T> right) {
        // return !(left == right);
      // }
    // }
  }
