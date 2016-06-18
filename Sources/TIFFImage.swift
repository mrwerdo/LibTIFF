import Geometry
import CLibTIFF

public class TIFFImage : ImageProtocol {
    public var size: Size
    public private(set) var buffer: UnsafeMutablePointer<UInt32>
    public var channelCount: Int {
        return hasAlpha ? 4 : 3
    }
    public private(set) var hasAlpha: Bool

    public init(size: Size, hasAlpha: Bool = false) {
        self.hasAlpha = true
        self.size = size
        let c = size.width * size.height * (hasAlpha ? 4 : 3)
        self.buffer = UnsafeMutablePointer(allocatingCapacity: c)
    }
}
