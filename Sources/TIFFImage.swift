import Geometry
import CLibTIFF

public class TIFFImage {

	public var tiffref: OpaquePointer // TIFF* in c
	public var path: String

	public var size: Size
	/// Buffer must be stored like so:
	/// when	y=0, x1, x2, x3, x4, x5, ..., xN
	/// when	y=1, x1, x2, x3, x4, x5, ..., xN
	/// when	y=..., ...,
	/// when	y=N, x1, x2, x3, x4, x5, ..., xN
	public var buffer: UnsafeMutablePointer<UInt8>
	/// Set this to `true` to have the buffer detroyed when the object goes out of scope.
	public var ownsBuffer: Bool = false
	private(set) var hasAlpha: Bool

	private var bitsPerSample: UInt32
	private var samplesPerPixel: UInt32
	private var rowsPerStrip: UInt32 = 1
	private var extraChannels: [UInt16]
	private var photometric: UInt32
	private var planarconfig: UInt32
	private var orientation: UInt32

	public enum Errors : ErrorProtocol {
		case Open
		case Flush
		case WriteScanline
		case SetField
		case GetField
	}


    public init(readAt path: String) throws {
        guard let ptr = TIFFOpen(path, "r") else {
            throw Errors.Open
        }
        tiffref = ptr
        self.size = Size(0,0)
        self.hasAlpha = false
        self.buffer = UnsafeMutablePointer<UInt8>(allocatingCapacity: 0)
        self.path = path
        self.bitsPerSample = 0
        self.samplesPerPixel = 0
        self.rowsPerStrip = 0
        self.extraChannels = []
        self.photometric = 0
        self.planarconfig = 0
        self.orientation = 0

        try readFields()
    }


	public init(writeAt path: String, _ buffer: UnsafeMutablePointer<UInt8>, _ size: Size, hasAlpha: Bool) throws {
		guard let ptr = TIFFOpen(path, "w") else {
			throw Errors.Open
		}
		tiffref = ptr
		self.size			= size
		self.hasAlpha		= hasAlpha
		self.buffer			= buffer
		self.path			= path
		bitsPerSample		= 8
		samplesPerPixel		= 3 + (hasAlpha ? 1 : 0)
		rowsPerStrip		= 1
		photometric			= UInt32(PHOTOMETRIC_RGB)
		planarconfig		= UInt32(PLANARCONFIG_CONTIG)
		orientation			= UInt32(ORIENTATION_TOPLEFT)
		if hasAlpha {
			extraChannels	= [UInt16(EXTRASAMPLE_ASSOCALPHA)]
		} else {
			extraChannels	= []
		}
		try writeFields()
	}
	
	public func flush() throws {
		guard TIFFFlush(tiffref) == 1 else {
			throw Errors.Flush
		}
	}
	
	/// Call this explicitly if the object is in global scope, otherwise pending writes may not be written.
	/// Alternatively, use `flush()`.
	public func close() {
		TIFFClose(tiffref)
	}

	deinit {
		TIFFClose(tiffref)
		if ownsBuffer {
			buffer.deallocateCapacity(size.width * size.height * Int(samplesPerPixel))
		}
	}

	public func write() throws {
		for y in 0..<size.height {
			guard TIFFWriteScanline(tiffref, buffer.advanced(by: y * size.width * Int(samplesPerPixel)), UInt32(y), 0) == 1 else {
				throw Errors.WriteScanline
			}
		}
		try flush()
	}

	private func setField(_ tag: Int32, _ value: UInt32) throws {
		guard TIFFSetField_uint32(tiffref, UInt32(tag), value) == 1 else {
			throw Errors.SetField
		}
	}

	private func setSize(_ size: Size) throws {
		let width = UInt32(size.width)
		let height = UInt32(size.height)
		try setField(TIFFTAG_IMAGEWIDTH, width)
		try setField(TIFFTAG_IMAGELENGTH, height)
	}

	private func writeFields() throws {
		try setSize(size)
		try setField(TIFFTAG_BITSPERSAMPLE, bitsPerSample)
		try setField(TIFFTAG_SAMPLESPERPIXEL, samplesPerPixel)
		try setField(TIFFTAG_ROWSPERSTRIP, rowsPerStrip)
		if extraChannels.count > 0 {
			guard TIFFSetField_ExtraSample(tiffref, UInt16(extraChannels.count), &extraChannels) == 1 else {
				throw Errors.SetField
			}
		}
		try setField(TIFFTAG_PHOTOMETRIC, photometric)
		try setField(TIFFTAG_PLANARCONFIG, planarconfig)
		try setField(TIFFTAG_ORIENTATION, orientation)
	}

	private func getField(_ tag: Int32) throws -> UInt32 {
		var value: UInt32 = 0
		guard TIFFGetField_uint32(tiffref, UInt32(tag), &value) == 1 else {
			throw Errors.GetField
		}
		return value
	}

	private func getSize() throws -> Size {
		let width = try getField(TIFFTAG_IMAGEWIDTH)
		let height = try getField(TIFFTAG_IMAGELENGTH)
		return Size(Int(width), Int(height))
	}

	private func readFields() throws {
		size = try getSize()
		bitsPerSample = try getField(TIFFTAG_BITSPERSAMPLE)
		samplesPerPixel = try getField(TIFFTAG_SAMPLESPERPIXEL)
		rowsPerStrip = try getField(TIFFTAG_ROWSPERSTRIP)
		// TODO: Implement a function to get a C array - for extraChannels

        var count: UInt16 = 4
        var channels: UnsafeMutablePointer<UInt16>? = UnsafeMutablePointer<UInt16>(allocatingCapacity: Int(count))
        guard TIFFGetField_ExtraSample(tiffref, &count, &channels) == 1 else {
            throw Errors.GetField
        }
        if let channels = channels {
            for index in 0..<Int(count) {
                extraChannels[index] = channels[index]
            }
        } else {
            throw Errors.GetField
        }

		photometric = try getField(TIFFTAG_PHOTOMETRIC)
		planarconfig = try getField(TIFFTAG_PLANARCONFIG)
		orientation = try getField(TIFFTAG_ORIENTATION)
	}
}
