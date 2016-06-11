// -----------------------------------------------------------------------------
// Coordinates image data between the program and file systems.
// -----------------------------------------------------------------------------
import CLibTIFF
import Geometry

public enum TIFFError : ErrorProtocol {
    /// Stores the reference to the tag.
    case SetField(Int32)

    /// Stores the reference to the tag.
    case GetField(Int32)

    case Open
    case Flush
    case WriteScanline
}

public class TIFFFile {
    /// Stores a reference to the image handle (The contents is of type 
    /// `TIFF*` in C)
    private var tiffref: OpaquePointer
    /// Stores the full path of the file.
    public private(set) var path: String
    /// Accesses the attributes of the TIFF file. 
    public private(set) var attributes: Attributes
    /// The size of the image (in pixels). If you want to resize the image, then
    /// you should create a new one.
    public var size: Size {
        return Size(Int(attributes.width), Int(attributes.height))
    }

    /// Stores the contents of the image. It must be in the form:
     ///
    ///     When y=0, x1, x2, x3, x4, x5, ..., xN
    ///     When y=1, x1, x2, x3, x4, x5, ..., xN
    ///     When y=., ..., ...,           ..., xN
    ///     When y=K, x1, x2, x3, x4, x5, ..., xN
    ///
    public private(set) var buffer: UnsafeMutablePointer<UInt8> 

    public var hasAlpha: Bool {
        // TODO: This is lazy and probably incorrect.
        return attributes.samplesPerPixel == 4
    }

    public enum Mode : String {
        case Read = "r"
        case Write = "w"
        case ReadWrite = "a"
    }

    public private(set) var mode: Mode

    public init(forReadingAt path: String) throws {
        self.mode = .Read
        self.path = path
        guard let ptr = TIFFOpen(path, self.mode.rawValue) else {
            throw TIFFError.Open
        }
        self.tiffref = ptr
        self.attributes = try Attributes(tiffref: ptr)
        let size = Int(attributes.width) * Int(attributes.height)
        let byteCount = size * Int(attributes.bitsPerSample)
        self.buffer = UnsafeMutablePointer(allocatingCapacity: byteCount)
    }

    public struct Attributes {
        var tiffref: OpaquePointer

        public private(set) var samples         : [UInt16]  = []
        public private(set) var bitsPerSample   : UInt32    = 0
        public private(set) var samplesPerPixel : UInt32    = 0
        public private(set) var rowsPerStrip    : UInt32    = 0
        public private(set) var photometric     : UInt32    = 0
        public private(set) var orientation     : UInt32    = 0
        public private(set) var width           : UInt32    = 0
        public private(set) var height          : UInt32    = 0

        init(tiffref: OpaquePointer) throws {
            self.tiffref    = tiffref
            bitsPerSample   = try read(tag: TIFFTAG_BITSPERSAMPLE)
            samplesPerPixel = try read(tag: TIFFTAG_SAMPLESPERPIXEL)
            rowsPerStrip    = try read(tag: TIFFTAG_ROWSPERSTRIP)
            photometric     = try read(tag: TIFFTAG_PHOTOMETRIC)
            orientation     = try read(tag: TIFFTAG_ORIENTATION)
            samples         = try readSamples()
        }

        /// Warning: `value` must be of type UInt16, or UInt32.
        func write(_ value: Any, for tag: Int32) throws {
            let result: Int32
            switch value {
            case is UInt16:
                result = TIFFSetField_uint16(tiffref, 
                                             UInt32(bitPattern: tag), 
                                             value as! UInt16)
            case is UInt32:
                result = TIFFSetField_uint32(tiffref,
                                             UInt32(bitPattern: tag),
                                             value as! UInt32)
            default:
                fatalError("cannot write `value` whose type is not UInt32 or UInt16")
            }
            guard result == 1 else {
                throw TIFFError.SetField(tag)
            }
        }

        /// Warning: Only UInt16 and UInt32 types are support.
        func read<T: Any>(tag: Int32) throws -> T {
            let result: Int32
            switch T.self {
            case is UInt16.Type:
                var value = UInt16(0)
                result = TIFFGetField_uint16(tiffref,
                                             UInt32(bitPattern: tag),
                                             &value)
                guard result == 1 else {
                    throw TIFFError.SetField(tag)
                }
                return value as! T
            case is UInt32.Type:
                var value = UInt32(0)
                result = TIFFGetField_uint32(tiffref,
                                             UInt32(bitPattern: tag),
                                             &value)
                guard result == 1 else {
                    throw TIFFError.SetField(tag)
                }
                return value as! T
            default:
                fatalError("cannot read a tag whose value is \(T.self). It must be either UInt32 or UInt16.")
            }
        }

        func readSamples() throws -> [UInt16] {
            var count: UInt16 = 4
            typealias Ptr = UnsafeMutablePointer<UInt16>
            var buff: Ptr? = Ptr(allocatingCapacity: Int(count))
            let result = TIFFGetField_ExtraSample(tiffref,
                                                  &count,
                                                  &buff)
            guard result == 1 else {
                throw TIFFError.GetField(TIFFTAG_EXTRASAMPLES)
            }
            var samples = [UInt16](repeating: 0, count: Int(count))
            if let buff = buff {
                for index in 0..<Int(count) {
                    samples[index] = buff[index]
                }
            } else {
                throw TIFFError.GetField(TIFFTAG_EXTRASAMPLES)
            }
            return samples 
        }

        func writeSamples(samples: [UInt16]) throws {
            var samples = samples
            let result = TIFFSetField_ExtraSample(tiffref,
                                                  UInt16(samples.count),
                                                  &samples)
            guard result == 1 else {
                throw TIFFError.SetField(TIFFTAG_EXTRASAMPLES)
            }
        }
    }
}

