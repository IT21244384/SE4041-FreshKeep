import UIKit
import ImageIO

/// Memory-friendly image helpers.
///
/// Camera photos are ~12 MP (~48 MB decoded). Decoding them at full size for a 60 pt
/// thumbnail wastes memory, so we downsample with ImageIO (which never decodes the
/// full bitmap) and cache the small versions.
enum ImagePipeline {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150
        return cache
    }()

    /// Downsampled JPEG data suitable for storing with an item (max 1024 px).
    static func storageData(from data: Data, maxPixelSize: CGFloat = 1024) -> Data? {
        downsample(data: data, maxPixelSize: maxPixelSize)?.jpegData(compressionQuality: 0.75)
    }

    static func storageData(from image: UIImage, maxPixelSize: CGFloat = 1024) -> Data? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        return storageData(from: data, maxPixelSize: maxPixelSize)
    }

    /// Cached thumbnail keyed by item id.
    static func thumbnail(for key: String, data: Data, maxPixelSize: CGFloat = 160) -> UIImage? {
        let cacheKey = "\(key)-\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }
        guard let image = downsample(data: data, maxPixelSize: maxPixelSize) else { return nil }
        cache.setObject(image, forKey: cacheKey)
        return image
    }

    /// Clears cached thumbnails, called when an item's photo changes.
    static func clearCache() {
        cache.removeAllObjects()
    }

    static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
