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
        let image = try! TIFFImage(writingAt: path(), size: Size(100, 100), hasAlpha: false)

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

        let reading = try! TIFFImage(readingAt: path())
        for i in 0..<size {
            XCTAssert(written[i] == reading.buffer[i], "contents of written file != contents of read file")
        }
    }

    func testBlueAndGreenImageVertical() {
        let size = 100 * 100 * 3
        var written = [UInt8](repeating: 0, count: size)
        let image = try! TIFFImage(writingAt: path(), size: Size(100, 100), hasAlpha: false)

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

        let reading = try! TIFFImage(readingAt: path())
        for i in 0..<size {
            XCTAssert(written[i] == reading.buffer[i], "contents of written file != contents of read file")
        }
    }

    func testBlueAndGreenImageHorizontal() {
        let size = 100 * 100 * 3
        var written = [UInt8](repeating: 0, count: size)
        let image = try! TIFFImage(writingAt: path(), size: Size(100, 100), hasAlpha: false)

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

        let reading = try! TIFFImage(readingAt: path())
        for i in 0..<size {
            XCTAssert(written[i] == reading.buffer[i], "contents of written file != contents of read file")
        }
    }

    static var allTests : [(String, (TIFFImageTests) -> () throws -> Void)] {
        return [
            ("testWritingAndReading", testWritingAndReading),
            ("testBlueAndGreenVertical", testBlueAndGreenImageVertical),
            ("testBlueAndGreenImageHorizontal", testBlueAndGreenImageHorizontal),
        ]
    }
}
