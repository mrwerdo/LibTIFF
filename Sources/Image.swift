// -----------------------------------------------------------------------------
// Image.swift
// -----------------------------------------------------------------------------

import Geometry

/// Protocol which all images should conform to.
/// 
/// When working with images, we generally want:
/// 
///  - width
///  - height
///  - access to the pixels
///  - want that access to be easy
///  - what to initalise it with a size?
///  - what to control the data type of each individual color channel (i.e. 
///     64 bits per color channel)
///  - size of channels ( basically what we were saying before about 64 bits)
///  - number of channels
/// 

public struct Pixel<Channel> {
    public var count: Int
    public var channels: UnsafeMutablePointer<Channel>
    public var index: Int

    public init(channels: UnsafeMutablePointer<Channel>, count: Int, index: Int) {
        self.count = count
        self.channels = channels
        self.index = index
    }
}

public protocol ImageProtocol : Collection {
    associatedtype Channel

    var size: Size { get }
    var channelCount: Int { get }
    var buffer: UnsafeMutablePointer<Channel> { get }
}

extension ImageProtocol {
    public subscript(i: Int) -> Pixel<Channel> {
        let index = i * channelCount
        return Pixel(channels: buffer.advanced(by: index), 
                     count: channelCount, 
                     index: index)
    }
}

extension ImageProtocol {
    public var startIndex: Int {
        return 0
    }
    public var endIndex: Int {
        return size.width * size.height
    }
    public var underestimatedCount: Int {
        return endIndex
    }
    public func index(after i: Int) -> Int {
        return i + 1
    }
}

struct ImageIterator<Image: ImageProtocol> : IteratorProtocol {
    var index: Int
    var image: Image
    
    mutating func next() -> Pixel<Image.Channel>? {
        let next = index
        guard next != image.endIndex else {
            return nil
        }
        index += 1
        return image[next]
    }
    
    init(_ image: Image) {
        self.image = image
        self.index = 0
    }
}

extension ImageProtocol {
    func makeIterator() -> ImageIterator<Self> {
        return ImageIterator(self)
    }
}
