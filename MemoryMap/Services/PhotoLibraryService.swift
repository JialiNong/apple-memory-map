import Photos
import UIKit

/// Reads photo metadata from the on-device library (PhotoKit). No image data is loaded here.
final class PhotoLibraryService: @unchecked Sendable {
    static var currentStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func canRead(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    /// Asks for read/write access. Write access is not used in v1, but v2 will let the user
    /// batch-assign locations to old photos, and asking twice later is a worse experience.
    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// Fetches every image's id, date and location, newest first.
    /// Call off the main thread: on a large library this takes a moment.
    func fetchAllPhotos() -> [PhotoItem] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: options)
        var items: [PhotoItem] = []
        items.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            let point = asset.location.map { GeoPoint($0.coordinate) }
            items.append(PhotoItem(
                id: asset.localIdentifier,
                date: asset.creationDate,
                location: (point?.isValid ?? false) ? point : nil,
                isFavorite: asset.isFavorite
            ))
        }
        return items
    }
}

/// Thread-safe one-shot flag.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

/// Loads thumbnails and full-size images on demand, with PhotoKit's own caching.
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()

    private let manager = PHCachingImageManager()

    func image(
        for localIdentifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        // .highQualityFormat calls the handler exactly once, which the continuation requires.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        // Photos optimized to iCloud only exist as a small preview locally.
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            // Belt and braces: a continuation must resume exactly once, even if PhotoKit
            // ever calls back twice (e.g. a degraded image followed by the final one).
            let once = ResumeOnce()
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                if once.claim() { continuation.resume(returning: image) }
            }
        }
    }
}
