namespace ATAP.Utilities.Images.Enumerations
{

  public enum GPSMetadataEnums
  {
    // GPS Metadata
    // ToDo: Handle a 4-byte identifier
    // GPSVersion = 0x0000,
    GPSVersion = 0x0000,
    GPSLatitudeRef = 0x0001,
    GPSLatitude = 0x0002,
    GPSLongitudeRef = 0x0003,
    GPSLongitude = 0x0004,
    GPSAltitudeRef = 0x0005,
    GPSAltitude = 0x0006,
    GPSTimeStamp = 0x0007,
    GPSSatellites = 0x0008,
    GPSStatus = 0x0009,
    GPSMeasureMode = 0x000A,
    GPSDOP = 0x000B,
    GPSSpeed = 0x000C,
    GPSTrack = 0x000E, // Ambiguity - Chat GPT couldn't decide on value for the property name
    GPSImgDirectionRef = 0x0010, // Ambiguity -  possibly 0xD. Chat GPT couldn't decide on value for the property name
    GPSImgDirection = 0x0011, // Ambiguity - possibly 0xD. Chat GPT couldn't decide on value for the property name
    GPSDestLatitudeRef = 0x0013,
    GPSDestLatitude = 0x0014,
    GPSDestLongitudeRef = 0x0015,
    GPSDestLongitude = 0x0016,
    GPSDestBearingRef = 0x0017,
    GPSDestBearing = 0x0018,
    GPSDestDistanceRef = 0x0019,
    GPSDestDistance = 0x001A,
  }

  public enum ImageMetadataEnums
  {
    // exif Metadata
    ImageDescription = 0x010E,
    Make = 0x010F,
    Model = 0x0110,
    Software = 0x0131,
    Artist = 0x013B,
    ExposureTime = 0x829A,
    FNumber = 0x829D,
    ExposureProgram = 0x8822,
    ISOSpeedRatings = 0x8827,
    DateTimeOriginal = 0x9003,
    DateTimeDigitized = 0x9004,
    ExposureBiasValue = 0x9204,
    MaxApertureValue = 0x9205,
    MeteringMode = 0x9207,
    Flash = 0x9209,
    FocalLength = 0x920A,
    ColorSpace = 0xA001,
    ExifImageWidth = 0xA002,
    ExifImageHeight = 0xA003,
    ExifInteroperabilityOffset = 0xA005,
    CustomRendered = 0xA401,
    ExposureMode = 0xA402,
    WhiteBalance = 0xA403,
    DigitalZoomRatio = 0xA404,
    FocalLengthIn35mmFilm = 0xA405,
    SceneCaptureType = 0xA406,
    GainControl = 0xA407,
    Contrast = 0xA408,
    Saturation = 0xA409,
    Sharpness = 0xA40A,
    SubjectDistanceRange = 0xA40C

    // ICC Metadata
  }
}
