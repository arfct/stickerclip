import Testing
import UIKit
@testable import StickerKit

struct StickerRendererTests {
    // MARK: Fixtures

    /// A flat-coloured image; `alpha` false gives fully opaque pixels.
    func image(width: Int, height: Int, alpha: Bool, color: UIColor = .systemBlue) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !alpha
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height).insetBy(dx: alpha ? 40 : 0, dy: alpha ? 40 : 0))
        }
    }

    /// Random RGBA noise: incompressible, so PNG output blows past the byte limit.
    func noise(edge: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: edge * edge * 4)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0 ... 255) }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cg = CGImage(
            width: edge, height: edge, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: edge * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
        return UIImage(cgImage: cg).pngData()!
    }

    /// The classic 1×1 transparent GIF.
    let tinyGIF = Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")!

    func longEdge(_ data: Data) -> Int {
        let image = UIImage(data: data)!
        return Int(max(image.size.width, image.size.height))
    }

    // MARK: Tests

    @Test func opaqueSourceBecomesJPEGAtRequestedSize() throws {
        let source = image(width: 1000, height: 600, alpha: false).jpegData(compressionQuality: 0.9)!
        let out = try StickerRenderer.render(image: source, options: .init(size: 408, hasBorder: false))
        #expect(out.format == .jpeg)
        #expect(out.size == 408)
        #expect(longEdge(out.data) == 408)
        #expect(out.data.count <= StickerSize.maxBytes)
    }

    @Test func transparentSourceBecomesPNG() throws {
        let source = image(width: 900, height: 900, alpha: true).pngData()!
        let out = try StickerRenderer.render(image: source, options: .init(size: 300, hasBorder: false))
        #expect(out.format == .png)
        #expect(longEdge(out.data) == 300)
    }

    @Test func borderForcesPNGAndStaysWithinSize() throws {
        let source = image(width: 1000, height: 600, alpha: false).jpegData(compressionQuality: 0.9)!
        let out = try StickerRenderer.render(image: source, options: .init(size: 408, hasBorder: true))
        #expect(out.format == .png)
        #expect(out.hasBorder)
        let edge = longEdge(out.data)
        #expect(edge <= 408 && edge >= 396, "border margins should bring the long edge back to about the requested size, got \(edge)")
    }

    @Test func stepsDownWhenEncodingExceedsByteLimit() throws {
        let out = try StickerRenderer.render(image: noise(edge: 1000), options: .init(size: 516, hasBorder: false))
        #expect(out.size < 516)
        #expect(out.data.count <= StickerSize.maxBytes)
        #expect(StickerSize.all.contains(out.size))
    }

    @Test func smallStillImagePassesThroughUnchanged() throws {
        let source = image(width: 200, height: 200, alpha: true).pngData()!
        let out = try StickerRenderer.render(image: source, options: .init(size: 408, hasBorder: false))
        #expect(out.data == source)
        #expect(out.format == .png)
    }

    @Test func gifPassesThroughEvenWhenBorderRequested() throws {
        let out = try StickerRenderer.render(image: tinyGIF, options: .init(size: 408, hasBorder: true))
        #expect(out.data == tinyGIF)
        #expect(out.format == .gif)
        #expect(out.hasBorder == false)
    }

    @Test func textBecomesTransparentPNG() throws {
        let out = try StickerRenderer.render(text: "Hi", options: .init(size: 408, hasBorder: true))
        #expect(out.format == .png)
        #expect(longEdge(out.data) <= 408)
        #expect(StickerRenderer.hasAlpha(UIImage(data: out.data)!))
    }

    @Test func emptyTextIsRejected() {
        #expect(throws: StickerRenderer.Error.self) {
            try StickerRenderer.render(text: "  \n", options: .init())
        }
    }

    @Test func garbageIsRejected() {
        #expect(throws: StickerRenderer.Error.self) {
            try StickerRenderer.render(image: Data("not an image".utf8), options: .init())
        }
    }
}
