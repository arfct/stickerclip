import UIKit

/// Turns an image or a line of text into bytes Messages will accept as a
/// sticker: square-ish, at most `size` pixels on the long edge, under
/// `StickerSize.maxBytes`, PNG when there is transparency and JPEG otherwise.
///
/// Pure functions over `Data`; callers run them off the main actor.
public enum StickerRenderer {
    public struct Options: Sendable, Hashable {
        /// Long-edge pixel size of the output, including any border.
        public var size: Int
        public var hasBorder: Bool

        public init(size: Int = StickerSize.default, hasBorder: Bool = true) {
            self.size = size
            self.hasBorder = hasBorder
        }
    }

    public struct Output: Sendable {
        public let data: Data
        public let format: StickerFormat
        /// The size actually used; smaller than requested if the byte limit forced a step down.
        public let size: Int
        public let hasBorder: Bool
    }

    public enum Error: Swift.Error, Sendable {
        case undecodable
        case emptyText
    }

    // MARK: - Entry points

    public static func render(image data: Data, options: Options) throws -> Output {
        // An animated GIF is worth more than a border: pass it through intact
        // when it already fits, since decoding would keep only its first frame.
        if let format = StickerFormat(sniffing: data), format == .gif, data.count <= StickerSize.maxBytes,
           let image = UIImage(data: data), Int(max(image.size.width, image.size.height)) <= options.size {
            return Output(data: data, format: .gif, size: options.size, hasBorder: false)
        }
        guard let image = UIImage(data: data) else { throw Error.undecodable }

        // A still image that already fits needs no re-encoding, which keeps
        // the source's quality; the border makes a new image regardless.
        if !options.hasBorder, let format = StickerFormat(sniffing: data), format != .gif,
           data.count <= StickerSize.maxBytes, Int(max(image.size.width, image.size.height)) <= options.size {
            return Output(data: data, format: format, size: options.size, hasBorder: false)
        }

        return render(image, transparent: hasAlpha(image), options: options)
    }

    public static func render(text: String, options: Options) throws -> Output {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Error.emptyText }

        // Three characters or fewer is treated as emoji-sized.
        let font = UIFont.boldSystemFont(ofSize: trimmed.count <= 3 ? 320 : 160)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: UIColor.black, .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: trimmed, attributes: attributes)
        let bounds = attributed.boundingRect(
            with: CGSize(width: 1200, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
        )
        let canvas = CGSize(width: ceil(bounds.width) + 16, height: ceil(bounds.height) + 16)
        let image = renderer(size: canvas).image { _ in
            attributed.draw(in: CGRect(origin: CGPoint(x: 8, y: 8), size: bounds.size))
        }
        return render(image, transparent: true, options: options)
    }

    // MARK: - Pipeline

    /// Steps down through the size ladder until the encoding fits the byte limit.
    static func render(_ source: UIImage, transparent: Bool, options: Options) -> Output {
        let ladder = [options.size] + StickerSize.all.filter { $0 < options.size }
        var last: Output?
        for size in ladder {
            let output = render(source, transparent: transparent, size: size, border: options.hasBorder)
            if output.data.count <= StickerSize.maxBytes { return output }
            last = output
        }
        return last!
    }

    static func render(_ source: UIImage, transparent: Bool, size: Int, border: Bool) -> Output {
        let edge = CGFloat(size)
        var image: UIImage
        if border {
            // The stroke and shadow extend past the content, so the content is
            // fitted smaller and the margins bring the whole back to `size`.
            let thickness = max(edge / 20, 1)
            let blur = thickness / 2
            let margin = ceil(thickness + blur + thickness / 4)
            image = fitted(source, maxEdge: edge - 2 * margin)
            image = outlined(image, thickness: thickness)
            image = shadowed(image, blur: blur, offset: CGSize(width: 0, height: thickness / 4))
        } else {
            image = fitted(source, maxEdge: edge)
        }

        let usePNG = transparent || border
        let data = (usePNG ? image.pngData() : image.jpegData(compressionQuality: 0.7)) ?? Data()
        return Output(data: data, format: usePNG ? .png : .jpeg, size: size, hasBorder: border)
    }

    // MARK: - Drawing

    static func fitted(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let scale = maxEdge / max(image.size.width, image.size.height)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        return renderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// A solid outline around the opaque parts of the image, drawn by
    /// stamping the silhouette around a circle and colouring the union.
    static func outlined(_ image: UIImage, thickness: CGFloat, color: UIColor = .white, samples: Int = 16) -> UIImage {
        let size = CGSize(width: image.size.width + 2 * thickness, height: image.size.height + 2 * thickness)
        return renderer(size: size).image { context in
            for i in 0 ..< samples {
                let angle = CGFloat(i) / CGFloat(samples) * 2 * .pi
                let origin = CGPoint(x: thickness + cos(angle) * thickness, y: thickness + sin(angle) * thickness)
                image.draw(at: origin)
            }
            context.cgContext.setBlendMode(.sourceIn)
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.setBlendMode(.normal)
            image.draw(at: CGPoint(x: thickness, y: thickness))
        }
    }

    static func shadowed(_ image: UIImage, blur: CGFloat, offset: CGSize, color: UIColor = UIColor(white: 0.2, alpha: 0.333)) -> UIImage {
        let margin = blur + max(abs(offset.width), abs(offset.height))
        let size = CGSize(width: image.size.width + 2 * margin, height: image.size.height + 2 * margin)
        return renderer(size: size).image { context in
            context.cgContext.setShadow(offset: offset, blur: blur, color: color.cgColor)
            image.draw(at: CGPoint(x: margin, y: margin))
        }
    }

    static func hasAlpha(_ image: UIImage) -> Bool {
        guard let info = image.cgImage?.alphaInfo else { return false }
        switch info {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }

    /// Scale 1 so points are pixels; the output is a file, not a screen.
    private static func renderer(size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format)
    }
}
