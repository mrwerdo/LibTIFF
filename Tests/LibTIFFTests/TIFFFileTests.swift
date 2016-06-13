import XCTest
import Geometry
@testable import LibTIFF

class TIFFFileTests : XCTestCase {
    func testWritingAndReading() {
        let size = 100 * 100 * 3
        var written = [UInt8](repeating: 0, count: size)
        let path = "/Users/mrwerdo/Desktop/test.tiff"
        let image = try! TIFFFile(writingAt: path, size: Size(100, 100), hasAlpha: false)
        
        for y in 0..<100 {
            for dx in 0..<100 {
                let x = dx * 4
                image.buffer[y * 100 + x + 0] = 255
                image.buffer[y * 100 + x + 1] = 0
                image.buffer[y * 100 + x + 2] = 0
            }
        }
        for i in 0..<size {
            written[i] = image.buffer[i]
        }

        try! image.write()
        image.close()

        let reading = try! TIFFFile(readingAt: path)
        for i in 0..<size {
            XCTAssert(written[i] == reading.buffer[i], "contents of written file != contents of read file")
        }
    }

    static var allTests : [(String, (TIFFFileTests) -> () throws -> Void)] {
        return [
            ("testWritingAndReading", testWritingAndReading),
        ]
    }
}
