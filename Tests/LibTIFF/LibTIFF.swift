import XCTest
import Geometry
import CLibTIFF
@testable import LibTIFF

class TIFFImageTests : XCTestCase {

    var basePath: String!
    var tempPath: String!

    func path(function: String = #function) -> String {
        let path = "\(basePath!)\(function).tiff"
        return path
    }

    override func setUp() {
        let template = "/tmp/tmpdir.XXXXXX"
        template.withCString { (cstr) in 
            if let cpath = mkdtemp(UnsafeMutablePointer(cstr)) {
                let path = String(cString: cpath)
                basePath = path + "/"
                tempPath = path
            } else {
                exit(EXIT_FAILURE)
            }
        }
    }

    override func tearDown() {
        if unlink(tempPath) != -1 {
            exit(EXIT_FAILURE)
        }
    }

    func testWritingAndReading() {
        let size = 100 * 100 * 3
        var written = [UInt8](repeating: 0, count: size)
        let image = try! TIFFImage<UInt8>(writingAt: path(), size: Size(100, 100), hasAlpha: false)

        // Turn on every red pixel.
        var c = 0
        while c < size {
            let v: UInt8 = c % 3 == 0 ? 255 : 0
            image.buffer[c] = v
            c += 1
        }

        for i in 0..<size {
            written[i] = image.buffer[i]
        }

        try! image.write()
        image.close()

        let reading = try! TIFFImage<UInt8>(readingAt: path())
        for i in 0..<size {
            XCTAssert(written[i] == reading.buffer[i], "contents of written file != contents of read file")
        }
    }

    func testBlueAndGreenImageVertical() {
        let size = 100 * 100 * 3
        var written = [UInt8](repeating: 0, count: size)
        let image = try! TIFFImage<UInt8>(writingAt: path(), size: Size(100, 100), hasAlpha: false)

        for y in 0..<100 {
            for x in 0..<100 {
                let offset = x % 3
                let index = y * 300 + 3 * x + offset
                image.buffer[index] = 255
            }
        }

        for i in 0..<size {
            written[i] = image.buffer[i]
        }

        try! image.write()
        image.close()

        let reading = try! TIFFImage<UInt8>(readingAt: path())
        for i in 0..<size {
            XCTAssert(written[i] == reading.buffer[i], "contents of written file != contents of read file")
        }
    }

    func testBlueAndGreenImageHorizontal() {
        let size = 100 * 100 * 3
        var written = [UInt8](repeating: 0, count: size)
        let image = try! TIFFImage<UInt8>(writingAt: path(), size: Size(100, 100), hasAlpha: false)

        for y in 0..<100 {
            let offset = y % 3
            for x in 0..<100 {
                let index = y * 300 + 3 * x + offset
                image.buffer[index] = 255
            }
        }

        for i in 0..<size {
            written[i] = image.buffer[i]
        }

        try! image.write()
        image.close()

        let reading = try! TIFFImage<UInt8>(readingAt: path())
        for i in 0..<size {
            XCTAssert(written[i] == reading.buffer[i], "contents of written file != contents of read file")
        }
    }


    /**

    Note, this program crashes as TIFFFile.close() is called twice in a row.
    There was nothing in the docs which say you can't call close twice.

    It no longer crashes.

    */
    func testMultipleCloses() {
        let size = 100 * 100 * 3
        var written = [UInt8](repeating: 0, count: size)
        let image = try! TIFFImage<UInt8>(writingAt: path(), size: Size(100, 100), hasAlpha: false)

        for y in 0..<100 {
            for dx in 0..<100 {
                let x = dx * 3
                let index = y * 300 + x
                image.buffer[index + 0] = 255
                image.buffer[index + 1] = 0
                image.buffer[index + 2] = 0
            }
        }
        for i in 0..<size {
            written[i] = image.buffer[i]
        }

        try! image.write()
        image.close()
        image.close()

        let reading = try! TIFFImage<UInt8>(readingAt: path())
        for i in 0..<size {
            if written[i] != reading.buffer[i] {
                print(written[i], reading.buffer[i], "contents of written file != contents of read file")
            }
        }
    }

    func testWritingWithoutFileBacking() {

        let image = TIFFImage<UInt8>(size: Size(128, 128))
        
        var counter: UInt32 = 0
        for pixel in image {
            let d = pixel.channels
            for k in 0..<image.channelCount {
                d[k] = UInt8(truncatingBitPattern: counter)
                counter += 1
            }
        }
        counter = 0
        while counter < UInt32(image.size.width * image.size.height * image.channelCount) {
            let i = Int(counter)
            if UInt8(truncatingBitPattern: counter) != image.buffer[i] {
                print(counter, image.buffer[i], "contents of image.buffer != input")
            }
            counter += 1
        }
        try! image.open(at: path(), mode: "w")
        try! image.write()
        counter = 0
        while counter < UInt32(image.size.width * image.size.height * image.channelCount) {
            let i = Int(counter)
            if UInt8(truncatingBitPattern: counter) != image.buffer[i] {
                print(counter, image.buffer[i], "contents of image.buffer != input")
            }
            counter += 1
        }
        image.close()
    }

    func testBitsPerSampleUInt32() {
        let size = 100 * 100 * 3
        var written = [UInt32](repeating: 0, count: size)
        let image = try! TIFFImage<UInt32>(writingAt: path(), size: Size(100, 100), hasAlpha: false)

        for y in 0..<100 {
            for dx in 0..<100 {
                let x = dx * 3
                let index = y * 300 + x
                image.buffer[index + 0] = 4294967295
                image.buffer[index + 1] = 0
                image.buffer[index + 2] = 0
            }
        }

        for i in 0..<size {
            written[i] = image.buffer[i]
        }

        try! image.write()
        image.close()

        let reading = try! TIFFImage<UInt32>(readingAt: path())
        for i in 0..<size {
            if written[i] != reading.buffer[i] {
                print(written[i], reading.buffer[i], "contents of written file != contents of read file")
            }
        }
        print(path())
    }

    static var allTests : [(String, (TIFFImageTests) -> () throws -> Void)] {
        return [
            ("testWritingAndReading",           testWritingAndReading),
            ("testBlueAndGreenVertical",        testBlueAndGreenImageVertical),
            ("testBlueAndGreenImageHorizontal", testBlueAndGreenImageHorizontal),
            ("testMultipleCloses",              testMultipleCloses),
            ("testWritingWithoutFileBacking",   testWritingWithoutFileBacking),
            ("testBitsPerSampleUInt32",         testBitsPerSampleUInt32)
        ]
    }
}
