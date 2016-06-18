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
    case ReadScanline
    case InternalInconsistancy
    case InvalidReference
}

public class TIFFImage : ImageProtocol {
    /// Stores a reference to the image handle (The contents is of type 
    /// `TIFF*` in C)
    private var tiffref: OpaquePointer?
    /// Stores the full path of the file.
    public private(set) var path: String?
    /// Accesses the attributes of the TIFF file. 
    public private(set) var attributes: Attributes
    /// The size of the image (in pixels). If you want to resize the image, then
    /// you should create a new one.
    public var size: Size {
        get {
            return Size(Int(attributes.width), Int(attributes.height))
        }
        set {
            attributes.width = UInt32(newValue.width)
            attributes.height = UInt32(newValue.height)
        }
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
    public var channelCount: Int {
        return Int(attributes.samplesPerPixel)
    }

    public private(set) var mode: String?

    public init(readingAt path: String) throws {
        self.mode = "r"
        self.path = path
        guard let ptr = TIFFOpen(path, self.mode) else {
            throw TIFFError.Open
        }
        self.tiffref = ptr
        self.attributes = try Attributes(tiffref: ptr)
        let size = Int(attributes.width) * Int(attributes.height)
        let byteCount = size * Int(attributes.bitsPerSample)
        self.buffer = UnsafeMutablePointer(allocatingCapacity: byteCount)
        try read()
    }

    public init(writingAt path: String, size: Size, hasAlpha: Bool) throws {
        self.mode = "w"
        self.path = path
        guard let ptr = TIFFOpen(path, mode) else {
            throw TIFFError.Open
        }
        self.tiffref = ptr
        let extraSamples: [UInt16]
        if hasAlpha {
            extraSamples = [UInt16(EXTRASAMPLE_ASSOCALPHA)]
        } else {
            extraSamples = []
        } 
        self.attributes = try Attributes(writingAt: ptr,
                                         size: size,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 3 + (hasAlpha ? 1 : 0),
                                         rowsPerStrip: 1,
                                         photometric: UInt32(PHOTOMETRIC_RGB),
                                         planarconfig: UInt32(PLANARCONFIG_CONTIG),
                                         orientation: UInt32(ORIENTATION_TOPLEFT),
                                         extraSamples: extraSamples)
        let pixelCount = size.width * size.height
        let byteCount = pixelCount * Int(attributes.bitsPerSample)
        self.buffer = UnsafeMutablePointer(allocatingCapacity: byteCount)
    }

    public init(size: Size, hasAlpha: Bool) {
        self.mode = nil
        self.path = nil
        self.tiffref = nil
        let extraSamples = [UInt16(EXTRASAMPLE_ASSOCALPHA)]
        self.attributes = try! Attributes(size: size,
                                     bitsPerSample: 8,
                                     samplesPerPixel: hasAlpha ? 4 : 3,
                                     rowsPerStrip: 1,
                                     photometric: UInt32(PHOTOMETRIC_RGB),
                                     planarconfig: UInt32(PLANARCONFIG_CONTIG),
                                     orientation: UInt32(ORIENTATION_TOPLEFT),
                                     extraSamples: extraSamples)
        let pixelCount = size.width * size.height
        let byteCount = pixelCount * Int(attributes.bitsPerSample)
        self.buffer = UnsafeMutablePointer(allocatingCapacity: byteCount)
    }


    public func open(at path: String, mode: String) throws {
        self.mode = mode
        self.path = path
        guard let ptr = TIFFOpen(path, mode) else {
            throw TIFFError.Open
        }
        self.tiffref = ptr
        self.attributes = try Attributes(writingAt: ptr, coping: self.attributes)
    }

    deinit {
        let pixelCount = size.width * size.height
        let byteCount = pixelCount * Int(attributes.bitsPerSample)
        self.buffer.deallocateCapacity(byteCount)
        self.close()
    }

    public func close() {
        if let ref = tiffref {
            TIFFClose(ref)
            tiffref = nil
            attributes.tiffref = nil
        }
    }

    public func flush() throws {
        if let ref = tiffref {
            guard TIFFFlush(ref) == 1 else {
                throw TIFFError.Flush
            }
        } else {
            throw TIFFError.InvalidReference
        }
    }

    public struct Attributes {
        var tiffref: OpaquePointer?

        public private(set) var extraSamples: [UInt16]  = [] {
            didSet {
                _ = try? write(samples: extraSamples)
            }
        }
        public private(set) var bitsPerSample   : UInt32    = 0 {
            didSet {
                _ = try? write(bitsPerSample, for: TIFFTAG_BITSPERSAMPLE)
            }
        }
        public private(set) var samplesPerPixel : UInt32    = 0 {
            didSet {
                _ = try? write(samplesPerPixel, for: TIFFTAG_SAMPLESPERPIXEL)
            }
        }
        public private(set) var rowsPerStrip    : UInt32    = 0 {
            didSet {
                _ = try? write(rowsPerStrip, for: TIFFTAG_ROWSPERSTRIP)
            }
        }
        public private(set) var photometric     : UInt32    = 0 {
            didSet {
                _ = try? write(photometric, for: TIFFTAG_PHOTOMETRIC)
            }
        }
        public private(set) var planarconfig    : UInt32    = 0 {
            didSet {
                _ = try? write(planarconfig, for: TIFFTAG_PLANARCONFIG)
            }
        }
        public private(set) var orientation     : UInt32    = 0 {
            didSet {
                _ = try? write(orientation, for: TIFFTAG_ORIENTATION)
            }
        }
        public private(set) var width           : UInt32    = 0 {
            didSet {
                _ = try? write(width, for: TIFFTAG_IMAGEWIDTH)
            }
        }
        public private(set) var height          : UInt32    = 0 {
            didSet {
                _ = try? write(height, for: TIFFTAG_IMAGELENGTH)
            }
        }

        init(tiffref: OpaquePointer) throws {
            self.tiffref    = tiffref
            self.temporySettings = nil
            bitsPerSample   = try read(tag: TIFFTAG_BITSPERSAMPLE)
            samplesPerPixel = try read(tag: TIFFTAG_SAMPLESPERPIXEL)
            rowsPerStrip    = try read(tag: TIFFTAG_ROWSPERSTRIP)
            photometric     = try read(tag: TIFFTAG_PHOTOMETRIC)
            planarconfig    = try read(tag: TIFFTAG_PLANARCONFIG)
            orientation     = try read(tag: TIFFTAG_ORIENTATION)
            width           = try read(tag: TIFFTAG_IMAGEWIDTH)
            height          = try read(tag: TIFFTAG_IMAGELENGTH)
            if let es = try? readSamples() {
                extraSamples = es
            } else {
                extraSamples = []
            }
        }

        private var temporySettings: [Int32 : Any]?

        init(writingAt tiffref: OpaquePointer? = nil, 
             size: Size, 
             bitsPerSample: UInt32, 
             samplesPerPixel: UInt32, 
             rowsPerStrip: UInt32, 
             photometric: UInt32, 
             planarconfig: UInt32,
             orientation: UInt32, 
             extraSamples: [UInt16]) throws {

            self.tiffref = tiffref
            self.bitsPerSample      = bitsPerSample
            self.samplesPerPixel    = samplesPerPixel
            self.rowsPerStrip       = rowsPerStrip
            self.photometric        = photometric
            self.planarconfig       = planarconfig
            self.orientation        = orientation
            self.width              = UInt32(size.width)
            self.height             = UInt32(size.height)
            self.extraSamples       = extraSamples

            if tiffref == nil {
                temporySettings = [:]
            }

            try write(bitsPerSample, for: TIFFTAG_BITSPERSAMPLE)
            try write(samplesPerPixel, for: TIFFTAG_SAMPLESPERPIXEL)
            try write(rowsPerStrip, for: TIFFTAG_ROWSPERSTRIP)
            try write(photometric, for: TIFFTAG_PHOTOMETRIC)
            try write(planarconfig, for: TIFFTAG_PLANARCONFIG)
            try write(orientation, for: TIFFTAG_ORIENTATION)
            try write(width, for: TIFFTAG_IMAGEWIDTH)
            try write(height, for: TIFFTAG_IMAGELENGTH)
            try write(samples: extraSamples)
        }

        init(writingAt tiffref: OpaquePointer, coping attributes: Attributes) throws {
            self.tiffref = tiffref
            self.temporySettings = nil
            
            self.tiffref = tiffref
            self.bitsPerSample      = attributes.bitsPerSample
            self.samplesPerPixel    = attributes.samplesPerPixel
            self.rowsPerStrip       = attributes.rowsPerStrip
            self.photometric        = attributes.photometric
            self.planarconfig       = attributes.planarconfig
            self.orientation        = attributes.orientation
            self.width              = UInt32(attributes.width)
            self.height             = UInt32(attributes.height)
            self.extraSamples       = attributes.extraSamples

            try write(bitsPerSample, for: TIFFTAG_BITSPERSAMPLE)
            try write(samplesPerPixel, for: TIFFTAG_SAMPLESPERPIXEL)
            try write(rowsPerStrip, for: TIFFTAG_ROWSPERSTRIP)
            try write(photometric, for: TIFFTAG_PHOTOMETRIC)
            try write(planarconfig, for: TIFFTAG_PLANARCONFIG)
            try write(orientation, for: TIFFTAG_ORIENTATION)
            try write(width, for: TIFFTAG_IMAGEWIDTH)
            try write(height, for: TIFFTAG_IMAGELENGTH)
            try write(samples: extraSamples)
        }

        /// Warning: `value` must be of type UInt16, or UInt32.
        mutating func write(_ value: Any, for tag: Int32) throws {
            guard let ref = self.tiffref else {
                if temporySettings != nil {
                    temporySettings![tag] = value
                    return
                }
                throw TIFFError.InvalidReference
            }
                
            let result: Int32
            switch value {
            case is UInt16:
                result = TIFFSetField_uint16(ref, 
                                             UInt32(bitPattern: tag), 
                                             value as! UInt16)
            case is UInt32:
                result = TIFFSetField_uint32(ref,
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
            guard let ref = tiffref else {
                if temporySettings != nil{
                    switch T.self {
                    case is UInt16.Type:
                        fallthrough
                    case is UInt32.Type:
                        return temporySettings![tag] as! T
                    default:
                        fatalError("cannot read a tag whose value is \(T.self). It must be either UInt32 or UInt16.")
                    }

                }
                throw TIFFError.InvalidReference
            }

            let result: Int32
            switch T.self {
            case is UInt16.Type:
                var value = UInt16(0)
                result = TIFFGetField_uint16(ref,
                                             UInt32(bitPattern: tag),
                                             &value)
                guard result == 1 else {
                    throw TIFFError.SetField(tag)
                }
                return value as! T
            case is UInt32.Type:
                var value = UInt32(0)
                result = TIFFGetField_uint32(ref,
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
            guard let ref = tiffref else {
                if temporySettings != nil{
                    return temporySettings![TIFFTAG_EXTRASAMPLES] as! [UInt16]
                }
                throw TIFFError.InvalidReference
            }
            var count: UInt16 = 4
            typealias Ptr = UnsafeMutablePointer<UInt16>
            var buff: Ptr? = Ptr(allocatingCapacity: Int(count))
            let result = TIFFGetField_ExtraSample(ref,
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

        mutating func write(samples: [UInt16]) throws {
            guard let ref = tiffref else {
                if temporySettings != nil {
                    temporySettings![TIFFTAG_EXTRASAMPLES] = samples
                    return
                }
                throw TIFFError.InvalidReference
            }
            var samples = samples
            let result = TIFFSetField_ExtraSample(ref,
                                                  UInt16(samples.count),
                                                  &samples)
            guard result == 1 else {
                throw TIFFError.SetField(TIFFTAG_EXTRASAMPLES)
            }
        }
    }
}

extension TIFFImage {
    public func write() throws {
        try write(verticalRange: 0..<size.height)
        try flush()
    }

    public func write(verticalRange r: Range<Int>) throws {
        guard let ref = tiffref else {
            throw TIFFError.InvalidReference
        }

        for y in r.lowerBound..<r.upperBound {
            let samplesCount = Int(attributes.samplesPerPixel)
            guard samplesCount * size.width == TIFFScanlineSize(ref) else {
                throw TIFFError.InternalInconsistancy
            }
            let line = buffer.advanced(by: y * size.width * samplesCount)
            guard TIFFWriteScanline(ref, line, UInt32(y), 0) == 1 else {
                throw TIFFError.WriteScanline
            }
        }
    }

    public func read() throws {
        try read(verticalRange: 0..<size.height)
    }

    public func read(verticalRange r: Range<Int>) throws {
        guard let ref = tiffref else {
            throw TIFFError.InvalidReference
        }
        for y in r.lowerBound..<r.upperBound {
            let samplesCount = Int(attributes.samplesPerPixel)
            guard samplesCount * size.width == TIFFScanlineSize(ref) else {
                throw TIFFError.InternalInconsistancy
            }
            let line = buffer.advanced(by: y * size.width * samplesCount)
            guard TIFFReadScanline(ref, line, UInt32(y), 0) == 1 else {
                throw TIFFError.ReadScanline
            }
        }
    }
}
