import Photos
import SwiftUI
import UIKit

@MainActor
final class PhotoLibraryViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var accessDenied = false
    @Published private(set) var isDownloadingOriginal = false
    private var hasLoaded = false

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        accessDenied = false
        defer {
            isLoading = false
            hasLoaded = true
        }

        guard await PhotoLibraryAccess.request() else {
            accessDenied = true
            assets = []
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var fetchedAssets: [PHAsset] = []
        fetchedAssets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            fetchedAssets.append(asset)
        }
        assets = fetchedAssets
    }

    func originalFileURL(for asset: PHAsset) async throws -> URL {
        isDownloadingOriginal = true
        defer { isDownloadingOriginal = false }
        return try await PhotoLibraryAssetLoader.loadOriginal(asset: asset)
    }
}

private enum PhotoLibraryAssetLoader {
    enum LoadError: LocalizedError {
        case noResource
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .noResource:
                "iCloud 中没有找到这张照片的原始资源。"
            case .downloadFailed:
                "无法从 iCloud 下载原始照片，请检查网络后重试。"
            }
        }
    }

    static func loadOriginal(asset: PHAsset) async throws -> URL {
        let rawMarkers = ["arw", "srf", "sr2", "dng", "camera-raw"]
        let resources = PHAssetResource.assetResources(for: asset)
        let rawResource = resources.first { resource in
            let identifier = resource.uniformTypeIdentifier.lowercased()
            let filename = resource.originalFilename.lowercased()
            return rawMarkers.contains { identifier.contains($0) || filename.hasSuffix(".\($0)") }
        }
        let resource = rawResource
            ?? resources.first(where: { $0.type == .fullSizePhoto })
            ?? resources.first(where: { $0.type == .photo })
        guard let resource else {
            throw LoadError.noResource
        }

        let originalExtension = (resource.originalFilename as NSString).pathExtension
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(originalExtension.isEmpty ? "arw" : originalExtension)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: destination,
                options: options
            ) { error in
                if error == nil {
                    continuation.resume(returning: destination)
                } else {
                    continuation.resume(throwing: LoadError.downloadFailed)
                }
            }
        }
    }
}

struct PhotoLibraryHome: View {
    @ObservedObject var library: PhotoLibraryViewModel
    let onSelect: (PHAsset) -> Void
    @Environment(\.openURL) private var openURL

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !library.assets.isEmpty {
                    Text("\(library.assets.count)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(GrainTheme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 4)

            if library.accessDenied {
                permissionView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(library.assets, id: \.localIdentifier) { asset in
                            Button {
                                onSelect(asset)
                            } label: {
                                AssetThumbnail(asset: asset)
                                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await library.refresh()
                }
            }
        }
        .task {
            await library.loadIfNeeded()
        }
        .overlay {
            if library.isLoading || library.isDownloadingOriginal {
                VStack(spacing: 10) {
                    ProgressView().tint(GrainTheme.paper)
                    Text(library.isDownloadingOriginal ? "正在从 iCloud 下载原图" : "正在载入照片")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(GrainTheme.paper)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(.black.opacity(0.74), in: Capsule())
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 35, weight: .light))
                .foregroundStyle(GrainTheme.muted)
            Text("需要照片访问权限")
                .font(.system(size: 18, weight: .semibold, design: .serif))
            Text("允许读取照片后，才能显示相册并从 iCloud 获取 RAW 原文件。")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(GrainTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(GrainTheme.black)
            .padding(.horizontal, 20)
            .frame(height: 42)
            .background(GrainTheme.paper, in: Capsule())
            Spacer()
        }
    }
}

private struct AssetThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ZStack {
                    GrainTheme.surface
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 17, weight: .light))
                            .foregroundStyle(GrainTheme.muted.opacity(0.5))
                    }
                }
                .clipped()
            }
        .clipped()
        .onAppear(perform: requestThumbnail)
        .onDisappear {
            if let requestID {
                PHImageManager.default().cancelImageRequest(requestID)
            }
        }
    }

    private func requestThumbnail() {
        guard image == nil else { return }
        let target = CGSize(width: 360, height: 360)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFill,
            options: options
        ) { result, info in
            if let result {
                DispatchQueue.main.async {
                    image = result
                }
            }
        }
    }
}
