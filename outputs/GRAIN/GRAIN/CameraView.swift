import AVFoundation
import CoreImage
import ImageIO
import Photos
import SwiftUI
import UniformTypeIdentifiers

enum CameraCaptureFormat: String, CaseIterable, Identifiable {
    case heif
    case png
    case raw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heif: "HEIF"
        case .png: "PNG"
        case .raw: "RAW"
        }
    }
}

enum CameraResolution: String, CaseIterable, Identifiable {
    case standard24
    case high48

    var id: String { rawValue }
    var title: String { self == .standard24 ? "24MP" : "48MP" }
    var targetPixels: Double { self == .standard24 ? 24_000_000 : 48_000_000 }
}

enum CameraAspect: String, CaseIterable, Identifiable {
    case portrait3x4
    case square
    case landscape4x3
    case landscape3x2
    case landscape16x9

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait3x4: "3:4"
        case .square: "1:1"
        case .landscape4x3: "4:3"
        case .landscape3x2: "3:2"
        case .landscape16x9: "16:9"
        }
    }

    var ratio: Double {
        switch self {
        case .portrait3x4: 3.0 / 4
        case .square: 1
        case .landscape4x3: 4.0 / 3
        case .landscape3x2: 3.0 / 2
        case .landscape16x9: 16.0 / 9
        }
    }
}

enum CameraTimer: String, CaseIterable, Identifiable {
    case off
    case three
    case ten

    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "计时关"
        case .three: "3 秒"
        case .ten: "10 秒"
        }
    }
    var seconds: Int {
        switch self {
        case .off: 0
        case .three: 3
        case .ten: 10
        }
    }
}

enum CameraFlashSetting: String, CaseIterable, Identifiable {
    case off
    case auto
    case on

    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "闪光关"
        case .auto: "自动闪光"
        case .on: "闪光开"
        }
    }
    var symbol: String {
        switch self {
        case .off: "bolt.slash"
        case .auto: "bolt.badge.automatic"
        case .on: "bolt.fill"
        }
    }
    var captureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .auto: .auto
        case .on: .on
        }
    }
}

struct CameraCaptureConfiguration {
    let format: CameraCaptureFormat
    let resolution: CameraResolution
    let aspect: CameraAspect
    let timer: CameraTimer
    let flash: CameraFlashSetting
    let livePhoto: Bool
}

@MainActor
final class CameraController: ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "studio.grain.camera.session")
    private var cameraDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var activeProcessors: [Int64: CameraPhotoCaptureProcessor] = [:]
    private var captureGeneration = 0
    private var microphoneAllowed = false

    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var countdown: Int?
    @Published private(set) var notice: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLivePhotoSupported = false
    @Published private(set) var isRawSupported = false
    @Published private(set) var maxPhotoDimensions = CMVideoDimensions(width: 0, height: 0)
    @Published private(set) var minimumZoom: CGFloat = 1
    @Published private(set) var maximumZoom: CGFloat = 8
    @Published private(set) var selectedZoom: CGFloat = 1
    @Published private(set) var exposureBias: Float = 0
    @Published private(set) var minimumExposureBias: Float = -2
    @Published private(set) var maximumExposureBias: Float = 2
    @Published private(set) var isUsingFrontCamera = false

    deinit {
        session.stopRunning()
    }

    func start() async {
        let cameraAllowed = await requestMediaAccess(for: .video)
        guard cameraAllowed else {
            errorMessage = "请在系统设置中允许 GRAIN 使用相机。"
            return
        }
        microphoneAllowed = await requestMediaAccess(for: .audio)

        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    func stop() {
        captureGeneration += 1
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func setZoom(_ zoom: CGFloat) {
        guard cameraDevice != nil else { return }
        sessionQueue.async { [weak self] in
            guard let self, var device = self.cameraDevice else { return }
            do {
                if !self.isUsingFrontCamera {
                    let wantsUltraWide = zoom <= 0.55
                    let isUltraWide = device.deviceType == .builtInUltraWideCamera
                    if wantsUltraWide, !isUltraWide,
                       let ultraWide = AVCaptureDevice.default(
                           .builtInUltraWideCamera,
                           for: .video,
                           position: .back
                       ),
                       self.replaceVideoInput(with: ultraWide) {
                        device = ultraWide
                    } else if !wantsUltraWide, isUltraWide,
                              let backCamera = self.discoverCamera(position: .back),
                              self.replaceVideoInput(with: backCamera) {
                        device = backCamera
                    }
                }

                let hardwareZoom: CGFloat
                if !self.isUsingFrontCamera,
                   zoom <= 0.55,
                   device.deviceType == .builtInUltraWideCamera {
                    hardwareZoom = min(max(1, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
                } else {
                    hardwareZoom = min(
                        max(zoom, device.minAvailableVideoZoomFactor),
                        device.maxAvailableVideoZoomFactor
                    )
                }

                try device.lockForConfiguration()
                device.cancelVideoZoomRamp()
                device.videoZoomFactor = hardwareZoom
                device.unlockForConfiguration()
                DispatchQueue.main.async { [weak self] in
                    self?.selectedZoom = zoom
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "无法切换相机倍率。"
                }
            }
        }
    }

    private func replaceVideoInput(with device: AVCaptureDevice) -> Bool {
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if let videoInput {
                session.removeInput(videoInput)
            }
            guard session.canAddInput(newInput) else {
                session.commitConfiguration()
                return false
            }
            session.addInput(newInput)
            session.commitConfiguration()
            videoInput = newInput
            cameraDevice = device
            publishDeviceCapabilities(
                device,
                liveSupported: photoOutput.isLivePhotoCaptureSupported,
                rawSupported: !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
            )
            return true
        } catch {
            return false
        }
    }

    func focus(at devicePoint: CGPoint, lock: Bool) {
        guard let cameraDevice else { return }
        sessionQueue.async {
            do {
                try cameraDevice.lockForConfiguration()
                if cameraDevice.isFocusPointOfInterestSupported {
                    cameraDevice.focusPointOfInterest = devicePoint
                    cameraDevice.focusMode = lock ? .locked : .autoFocus
                }
                if cameraDevice.isExposurePointOfInterestSupported {
                    cameraDevice.exposurePointOfInterest = devicePoint
                    cameraDevice.exposureMode = lock ? .locked : .autoExpose
                }
                cameraDevice.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "无法设置对焦区域。"
                }
            }
        }
    }

    func setExposureBias(_ value: Float) {
        guard let cameraDevice else { return }
        let clamped = min(max(value, cameraDevice.minExposureTargetBias), cameraDevice.maxExposureTargetBias)
        sessionQueue.async {
            do {
                try cameraDevice.lockForConfiguration()
                cameraDevice.setExposureTargetBias(clamped)
                cameraDevice.unlockForConfiguration()
                DispatchQueue.main.async { [weak self] in
                    self?.exposureBias = clamped
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "无法调整曝光补偿。"
                }
            }
        }
    }

    func toggleCamera() {
        let targetPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .back : .front
        guard let device = discoverCamera(position: targetPosition) else {
            errorMessage = "没有找到可切换的镜头。"
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                if let videoInput = self.videoInput {
                    self.session.removeInput(videoInput)
                }
                guard self.session.canAddInput(newInput) else {
                    self.session.commitConfiguration()
                    throw CameraError.cannotConfigure
                }
                self.session.addInput(newInput)
                self.session.commitConfiguration()
                self.videoInput = newInput
                self.cameraDevice = device
                self.publishDeviceCapabilities(
                    device,
                    liveSupported: self.photoOutput.isLivePhotoCaptureSupported,
                    rawSupported: !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
                )
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func capture(_ configuration: CameraCaptureConfiguration) {
        guard isReady, !isCapturing else { return }
        captureGeneration += 1
        let generation = captureGeneration
        isCapturing = true
        errorMessage = nil

        Task {
            if configuration.timer.seconds > 0 {
                for value in stride(from: configuration.timer.seconds, through: 1, by: -1) {
                    guard generation == captureGeneration else { return }
                    countdown = value
                    GrainHaptics.selection(enabled: true)
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            guard generation == captureGeneration else { return }
            countdown = nil
            performCapture(configuration)
        }
    }

    func cancelCapture() {
        captureGeneration += 1
        countdown = nil
        isCapturing = false
    }

    private func configureSession() {
        guard let device = discoverCamera(position: .back) else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "当前设备没有可用的后置相机。"
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            var didCommitConfiguration = false
            defer {
                if !didCommitConfiguration {
                    session.commitConfiguration()
                }
            }

            session.sessionPreset = .photo
            guard session.canAddInput(input) else {
                throw CameraError.cannotConfigure
            }
            session.addInput(input)
            videoInput = input

            if microphoneAllowed,
               let microphone = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: microphone),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }

            guard session.canAddOutput(photoOutput) else {
                throw CameraError.cannotConfigure
            }
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported

            let dimensions = device.activeFormat.supportedMaxPhotoDimensions
            let maximumDimensions = dimensions.max {
                Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
            }
            if let maximumDimensions {
                photoOutput.maxPhotoDimensions = maximumDimensions
            }

            cameraDevice = device
            let liveSupported = photoOutput.isLivePhotoCaptureSupported
            let rawSupported = !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
            let maxDims = maximumDimensions ?? CMVideoDimensions(width: 0, height: 0)

            session.commitConfiguration()
            didCommitConfiguration = true
            session.startRunning()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.maxPhotoDimensions = maxDims
                self.isReady = true
                self.publishDeviceCapabilities(
                    device,
                    liveSupported: liveSupported,
                    rawSupported: rawSupported
                )
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    private func discoverCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .back {
            if let triple = AVCaptureDevice.default(
                .builtInTripleCamera,
                for: .video,
                position: .back
            ) {
                return triple
            }
            if let dualWide = AVCaptureDevice.default(
                .builtInDualWideCamera,
                for: .video,
                position: .back
            ) {
                return dualWide
            }
            return AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            )
        }
        return AVCaptureDevice.default(
            .builtInTrueDepthCamera,
            for: .video,
            position: .front
        ) ?? AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        )
    }

    private func publishDeviceCapabilities(
        _ device: AVCaptureDevice,
        liveSupported: Bool,
        rawSupported: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.minimumZoom = device.minAvailableVideoZoomFactor
            self.maximumZoom = max(device.maxAvailableVideoZoomFactor, 8)
            self.selectedZoom = min(max(1, self.minimumZoom), self.maximumZoom)
            self.minimumExposureBias = device.minExposureTargetBias
            self.maximumExposureBias = device.maxExposureTargetBias
            self.exposureBias = min(max(0, device.minExposureTargetBias), device.maxExposureTargetBias)
            self.isUsingFrontCamera = device.position == .front
            self.isLivePhotoSupported = liveSupported
            self.isRawSupported = rawSupported
        }
    }

    private func performCapture(_ configuration: CameraCaptureConfiguration) {
        guard let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else {
            if configuration.format == .raw {
                finishCapture(error: CameraError.rawUnavailable)
                return
            }
            captureProcessed(configuration)
            return
        }

        if configuration.format == .raw {
            captureRaw(configuration, rawFormat: rawFormat)
        } else {
            captureProcessed(configuration)
        }
    }

    private func captureProcessed(_ configuration: CameraCaptureConfiguration) {
        let settings: AVCapturePhotoSettings
        if configuration.format == .heif,
           photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.hevc]
            )
        } else {
            settings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.jpeg]
            )
        }

        settings.photoQualityPrioritization = .quality
        applyCommonSettings(settings, configuration: configuration)
        settings.livePhotoMovieFileURL = configuration.livePhoto && isLivePhotoSupported
            ? temporaryLivePhotoURL()
            : nil
        if settings.livePhotoMovieFileURL != nil {
            settings.livePhotoVideoCodecType = .hevc
        }
        startProcessor(settings: settings, configuration: configuration)
    }

    private func captureRaw(
        _ configuration: CameraCaptureConfiguration,
        rawFormat: OSType
    ) {
        let settings = AVCapturePhotoSettings(
            rawPixelFormatType: rawFormat,
            processedFormat: nil
        )
        applyCommonSettings(settings, configuration: configuration)
        startProcessor(settings: settings, configuration: configuration)
    }

    private func applyCommonSettings(
        _ settings: AVCapturePhotoSettings,
        configuration: CameraCaptureConfiguration
    ) {
        if photoOutput.supportedFlashModes.contains(configuration.flash.captureMode) {
            settings.flashMode = configuration.flash.captureMode
        }

        let format = cameraDevice?.activeFormat
        let supported = format?.supportedMaxPhotoDimensions ?? []
        let desiredPixels = configuration.resolution.targetPixels
        let bestForTarget = supported
            .filter { Double($0.width) * Double($0.height) <= desiredPixels * 1.08 }
            .max(by: {
                Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
            })
        let fallbackMaximum = supported.max(by: {
            Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
        })
        if let bestForTarget {
            photoOutput.maxPhotoDimensions = bestForTarget
        } else if let fallbackMaximum {
            photoOutput.maxPhotoDimensions = fallbackMaximum
        }
        photoOutput.isHighResolutionCaptureEnabled = configuration.resolution == .high48
    }

    private func startProcessor(
        settings: AVCapturePhotoSettings,
        configuration: CameraCaptureConfiguration
    ) {
        let id = settings.uniqueID
        let processor = CameraPhotoCaptureProcessor(
            expectLivePhoto: settings.livePhotoMovieFileURL != nil
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.activeProcessors.removeValue(forKey: id)
                switch result {
                case .success(let output):
                    self.processCapturedOutput(output, configuration: configuration)
                case .failure(let error):
                    self.finishCapture(error: error)
                }
            }
        }
        activeProcessors[id] = processor
        photoOutput.capturePhoto(with: settings, delegate: processor)
    }

    private func processCapturedOutput(
        _ output: CameraCapturedOutput,
        configuration: CameraCaptureConfiguration
    ) {
        Task {
            do {
                let processed = try await Task.detached(priority: .userInitiated) {
                    try CameraImageProcessor.prepare(
                        output: output,
                        configuration: configuration
                    )
                }.value
                try await saveToPhotoLibrary(processed)
                GrainHaptics.mediumImpact(enabled: true)
                notice = "已保存到照片图库"
            } catch {
                errorMessage = error.localizedDescription
            }
            if let liveURL = output.livePhotoURL {
                try? FileManager.default.removeItem(at: liveURL)
            }
            isCapturing = false
        }
    }

    private func saveToPhotoLibrary(_ output: CameraPreparedOutput) async throws {
        guard await requestPhotoLibraryAddAccess() else {
            throw CameraError.photoLibraryDenied
        }
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = output.fileName
                options.uniformTypeIdentifier = output.uniformTypeIdentifier
                request.addResource(with: .photo, data: output.data, options: options)

                if let livePhotoURL = output.livePhotoURL {
                    let videoOptions = PHAssetResourceCreationOptions()
                    videoOptions.originalFilename = output.fileName
                        .replacingOccurrences(of: ".heif", with: ".mov")
                        .replacingOccurrences(of: ".png", with: ".mov")
                    request.addResource(
                        with: .pairedVideo,
                        fileURL: livePhotoURL,
                        options: videoOptions
                    )
                }
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: error ?? CameraError.saveFailed
                    )
                }
            }
        }
    }

    private func finishCapture(error: Error) {
        errorMessage = error.localizedDescription
        isCapturing = false
        countdown = nil
    }

    private func temporaryLivePhotoURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
    }

    private func requestMediaAccess(for mediaType: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: mediaType) {
                    continuation.resume(returning: $0)
                }
            }
        default:
            return false
        }
    }

    private func requestPhotoLibraryAddAccess() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(
                        returning: status == .authorized || status == .limited
                    )
                }
            }
        default:
            return false
        }
    }
}

private struct CameraCapturedOutput: @unchecked Sendable {
    let data: Data
    let livePhotoURL: URL?
}

private struct CameraPreparedOutput: @unchecked Sendable {
    let data: Data
    let fileName: String
    let uniformTypeIdentifier: String
    let livePhotoURL: URL?
}

private final class CameraPhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    typealias Completion = (Result<CameraCapturedOutput, Error>) -> Void

    private let expectLivePhoto: Bool
    private let completion: Completion
    private var photoData: Data?
    private var livePhotoURL: URL?
    private var captureError: Error?
    private var captureFinished = false

    init(expectLivePhoto: Bool, completion: @escaping Completion) {
        self.expectLivePhoto = expectLivePhoto
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            captureError = error
        } else {
            photoData = photo.fileDataRepresentation()
        }
        finishIfReady()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            captureError = error
        } else {
            livePhotoURL = outputFileURL
        }
        finishIfReady()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            captureError = error
        }
        captureFinished = true
        finishIfReady()
    }

    private func finishIfReady() {
        guard captureFinished else { return }
        if let captureError {
            completion(.failure(captureError))
            return
        }
        guard let photoData else {
            completion(.failure(CameraError.missingPhotoData))
            return
        }
        if expectLivePhoto, livePhotoURL == nil {
            completion(.failure(CameraError.livePhotoFailed))
            return
        }
        completion(.success(CameraCapturedOutput(
            data: photoData,
            livePhotoURL: expectLivePhoto ? livePhotoURL : nil
        )))
    }
}

private enum CameraImageProcessor {
    private static let context = CIContext(options: [
        .cacheIntermediates: false
    ])

    static func prepare(
        output: CameraCapturedOutput,
        configuration: CameraCaptureConfiguration
    ) throws -> CameraPreparedOutput {
        if configuration.format == .raw {
            return CameraPreparedOutput(
                data: output.data,
                fileName: "GRAIN-\(timestamp()).dng",
                uniformTypeIdentifier: "com.adobe.digital-negative",
                livePhotoURL: nil
            )
        }

        guard let source = CIImage(
            data: output.data,
            options: [.applyOrientationProperty: true]
        ) else {
            throw CameraError.imageDecodeFailed
        }

        let cropped = crop(source, to: configuration.aspect.ratio)
        let scaled = resize(cropped, targetPixels: configuration.resolution.targetPixels)
        let extent = scaled.extent.integral
        guard let image = context.createCGImage(
            scaled,
            from: extent,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.displayP3)
        ) else {
            throw CameraError.imageEncodeFailed
        }

        let format: CameraCaptureFormat = configuration.format == .png ? .png : .heif
        let type = format == .png ? UTType.png : UTType.heic
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw CameraError.imageEncodeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CameraError.imageEncodeFailed
        }

        let fileExtension = format == .png ? "png" : "heif"
        return CameraPreparedOutput(
            data: data as Data,
            fileName: "GRAIN-\(timestamp()).\(fileExtension)",
            uniformTypeIdentifier: type.identifier,
            livePhotoURL: output.livePhotoURL
        )
    }

    private static func crop(_ image: CIImage, to ratio: Double) -> CIImage {
        let extent = image.extent.integral
        let currentRatio = extent.width / max(extent.height, 1)
        let targetRatio = CGFloat(ratio)
        let cropRect: CGRect
        if currentRatio > targetRatio {
            let width = extent.height * targetRatio
            cropRect = CGRect(
                x: extent.midX - width / 2,
                y: extent.minY,
                width: width,
                height: extent.height
            )
        } else {
            let height = extent.width / targetRatio
            cropRect = CGRect(
                x: extent.minX,
                y: extent.midY - height / 2,
                width: extent.width,
                height: height
            )
        }
        return image.cropped(to: cropRect.integral)
    }

    private static func resize(_ image: CIImage, targetPixels: Double) -> CIImage {
        let extent = image.extent
        let currentPixels = Double(extent.width * extent.height)
        guard currentPixels > targetPixels, currentPixels > 0 else { return image }
        let scale = sqrt(targetPixels / currentPixels)
        return image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(
                by: CGAffineTransform(
                    translationX: -image.extent.minX * scale,
                    y: -image.extent.minY * scale
                )
            )
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: Date())
    }
}

private enum CameraError: LocalizedError {
    case cannotConfigure
    case rawUnavailable
    case missingPhotoData
    case livePhotoFailed
    case photoLibraryDenied
    case imageDecodeFailed
    case imageEncodeFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .cannotConfigure:
            "无法配置相机会话，请确认没有其他应用正在占用相机。"
        case .rawUnavailable:
            "当前相机镜头不支持 RAW 输出。"
        case .missingPhotoData:
            "相机没有返回照片数据。"
        case .livePhotoFailed:
            "实况照片视频处理失败，请重试。"
        case .photoLibraryDenied:
            "请在系统设置中允许 GRAIN 向照片图库添加照片。"
        case .imageDecodeFailed:
            "无法读取刚拍摄的照片。"
        case .imageEncodeFailed:
            "无法生成所选照片格式。"
        case .saveFailed:
            "照片保存失败，请检查存储空间。"
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let onFocus: (_ devicePoint: CGPoint, _ lock: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.focusTapped(_:))
        )
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.focusLocked(_:))
        )
        longPress.minimumPressDuration = 0.48
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        context.coordinator.parent = self
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    final class Coordinator: NSObject {
        var parent: CameraPreviewView

        init(parent: CameraPreviewView) {
            self.parent = parent
        }

        @objc func focusTapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? CameraPreviewUIView else { return }
            let screenPoint = gesture.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(
                fromLayerPoint: screenPoint
            )
            view.showFocusReticle(at: screenPoint, locked: false)
            parent.onFocus(devicePoint, false)
        }

        @objc func focusLocked(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let view = gesture.view as? CameraPreviewUIView
            else { return }
            let screenPoint = gesture.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(
                fromLayerPoint: screenPoint
            )
            view.showFocusReticle(at: screenPoint, locked: true)
            parent.onFocus(devicePoint, true)
        }
    }
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    private var latestFocusLayer: CALayer?

    func showFocusReticle(at point: CGPoint, locked: Bool) {
        latestFocusLayer?.removeFromSuperlayer()

        let reticle = CALayer()
        let size: CGFloat = locked ? 62 : 54
        reticle.frame = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )
        reticle.borderColor = UIColor(
            red: 0.851,
            green: 0.467,
            blue: 0.306,
            alpha: 1
        ).cgColor
        reticle.borderWidth = 1.4
        reticle.cornerRadius = 4
        reticle.backgroundColor = UIColor.clear.cgColor

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.35
        scale.toValue = 1
        scale.duration = 0.18
        reticle.add(scale, forKey: "focus-in")
        previewLayer.addSublayer(reticle)
        latestFocusLayer = reticle

        guard !locked else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self, weak reticle] in
            guard let reticle, self?.latestFocusLayer === reticle else { return }
            reticle.removeFromSuperlayer()
        }
    }
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var format: CameraCaptureFormat = .heif
    @State private var resolution: CameraResolution = .standard24
    @State private var aspect: CameraAspect = .portrait3x4
    @State private var timer: CameraTimer = .off
    @State private var flash: CameraFlashSetting = .auto
    @State private var livePhoto = false
    @State private var showGrid = true
    @State private var zoomGestureBase: CGFloat?

    private let zoomOptions: [CGFloat] = [0.5, 1, 2, 4, 8]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(
                session: camera.session,
                onFocus: { devicePoint, lock in
                    camera.focus(at: devicePoint, lock: lock)
                    GrainHaptics.lightImpact(enabled: true)
                }
            )
                .ignoresSafeArea()
                .simultaneousGesture(pinchToZoomGesture)
            framingOverlay

            VStack(spacing: 0) {
                topBar
                Spacer()
                cameraControls
            }

            if let countdown = camera.countdown {
                Text("\(countdown)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(GrainTheme.paper)
                    .frame(width: 160, height: 160)
                    .background(Color.black.opacity(0.48), in: Circle())
                    .transition(.scale.combined(with: .opacity))
            }

            if !camera.isReady,
               camera.errorMessage == nil {
                ProgressView()
                    .tint(GrainTheme.paper)
                    .padding(16)
                    .background(Color.black.opacity(0.62), in: Circle())
            }

            if let notice = camera.notice {
                VStack {
                    Text(notice)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrainTheme.black)
                        .padding(.horizontal, 13)
                        .frame(height: 30)
                        .background(GrainTheme.paper, in: Capsule())
                        .padding(.top, 62)
                    Spacer()
                }
            }

            if let error = camera.errorMessage {
                VStack(spacing: 12) {
                    Text("相机无法启动")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                    Text(error)
                        .font(.system(size: 10, design: .rounded))
                        .multilineTextAlignment(.center)
                    Button("关闭") { dismiss() }
                        .foregroundStyle(GrainTheme.black)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(GrainTheme.paper, in: Capsule())
                }
                .foregroundStyle(GrainTheme.paper)
                .padding(22)
                .background(GrainTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                .padding(28)
            }
        }
        .statusBarHidden()
        .task {
            await camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: format) { _, newValue in
            if newValue == .raw {
                livePhoto = false
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 11) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GrainTheme.paper)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                if let index = CameraFlashSetting.allCases.firstIndex(of: flash) {
                    flash = CameraFlashSetting.allCases[
                        (index + 1) % CameraFlashSetting.allCases.count
                    ]
                }
            } label: {
                Image(systemName: flash.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        flash == .off ? GrainTheme.paper.opacity(0.55) : GrainTheme.accent
                    )
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                livePhoto.toggle()
            } label: {
                Image(systemName: livePhoto ? "livephoto" : "livephoto.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(livePhoto ? GrainTheme.accent : GrainTheme.paper.opacity(0.62))
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!camera.isLivePhotoSupported || format == .raw)

            Button {
                showGrid.toggle()
                GrainHaptics.selection(enabled: true)
            } label: {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(showGrid ? GrainTheme.accent : GrainTheme.paper.opacity(0.62))
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(CameraTimer.allCases) { option in
                    Button(option.title) { timer = option }
                }
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                    if timer != .off {
                        Text("\(timer.seconds)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                    }
                }
                .foregroundStyle(timer == .off ? GrainTheme.paper.opacity(0.62) : GrainTheme.accent)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.58), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var cameraControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 5) {
                ForEach(zoomOptions, id: \.self) { zoom in
                    Button {
                        camera.setZoom(zoom)
                    } label: {
                        Text(zoomLabel(zoom))
                            .font(.system(size: zoom == camera.selectedZoom ? 12 : 10, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                zoom == camera.selectedZoom ? GrainTheme.black : GrainTheme.paper
                            )
                            .frame(width: zoom == camera.selectedZoom ? 42 : 34, height: 34)
                            .background(
                                zoom == camera.selectedZoom
                                    ? GrainTheme.paper
                                    : Color.black.opacity(0.54),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        (zoom < camera.minimumZoom
                            && !(zoom == 0.5 && !camera.isUsingFrontCamera))
                        || zoom > camera.maximumZoom
                    )
                }
            }

            HStack(spacing: 9) {
                Image(systemName: "sun.min")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(GrainTheme.muted)
                Slider(
                    value: Binding(
                        get: { Double(camera.exposureBias) },
                        set: { camera.setExposureBias(Float($0)) }
                    ),
                    in: Double(camera.minimumExposureBias)...Double(camera.maximumExposureBias),
                    step: 0.1
                )
                .tint(GrainTheme.accent)
                Text(String(format: "%+.1f", camera.exposureBias))
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(GrainTheme.paper)
                    .frame(width: 34, alignment: .trailing)
                Image(systemName: "sun.max")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GrainTheme.muted)
            }

            HStack(spacing: 8) {
                ForEach(CameraResolution.allCases) { option in
                    Button(option.title) {
                        resolution = option
                    }
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(resolution == option ? GrainTheme.black : GrainTheme.paper)
                    .frame(width: 50, height: 30)
                    .background(
                        resolution == option ? GrainTheme.paper : Color.black.opacity(0.54),
                        in: Capsule()
                    )
                    .buttonStyle(.plain)
                }

                Menu {
                    ForEach(CameraAspect.allCases) { option in
                        Button(option.title) { aspect = option }
                    }
                } label: {
                    MenuChip(title: aspect.title, symbol: "rectangle.ratio.4.to.3")
                }

                Menu {
                    ForEach(CameraCaptureFormat.allCases) { option in
                        Button(option.title) { format = option }
                    }
                } label: {
                    MenuChip(title: format.title, symbol: "doc")
                }
            }

            HStack {
                Text(livePhoto ? "LIVE" : "PHOTO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(livePhoto ? GrainTheme.accent : GrainTheme.paper.opacity(0.6))
                    .frame(width: 58)

                Spacer()

                Button {
                    camera.capture(
                        CameraCaptureConfiguration(
                            format: format,
                            resolution: resolution,
                            aspect: aspect,
                            timer: timer,
                            flash: flash,
                            livePhoto: livePhoto
                        )
                    )
                } label: {
                    ZStack {
                        Circle()
                            .stroke(GrainTheme.paper, lineWidth: 4)
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(camera.isCapturing ? GrainTheme.muted : GrainTheme.paper)
                            .frame(width: 62, height: 62)
                        if camera.isCapturing {
                            ProgressView()
                                .tint(GrainTheme.black)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!camera.isReady || camera.isCapturing)

                Spacer()

                Button {
                    camera.toggleCamera()
                    GrainHaptics.mediumImpact(enabled: true)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(GrainTheme.paper)
                        .frame(width: 46, height: 46)
                        .background(Color.black.opacity(0.54), in: Circle())
                }
                .buttonStyle(.plain)
                .frame(width: 58)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var framingOverlay: some View {
        GeometryReader { proxy in
            let available = CGSize(
                width: proxy.size.width - 30,
                height: proxy.size.height - 300
            )
            let rect = fittedFrame(for: aspect.ratio, in: available)
                .offsetBy(dx: 15, dy: 92)

            ZStack {
                if showGrid {
                    Path { path in
                        for index in 1...2 {
                            let x = rect.minX + rect.width * CGFloat(index) / 3
                            path.move(to: CGPoint(x: x, y: rect.minY))
                            path.addLine(to: CGPoint(x: x, y: rect.maxY))
                            let y = rect.minY + rect.height * CGFloat(index) / 3
                            path.move(to: CGPoint(x: rect.minX, y: y))
                            path.addLine(to: CGPoint(x: rect.maxX, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
                }

                Rectangle()
                    .stroke(Color.white.opacity(0.44), lineWidth: 1)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
    }

    private func fittedFrame(for ratio: Double, in size: CGSize) -> CGRect {
        let target = CGFloat(ratio)
        let sizeRatio = size.width / max(size.height, 1)
        let fitted: CGSize
        if sizeRatio > target {
            fitted = CGSize(width: size.height * target, height: size.height)
        } else {
            fitted = CGSize(width: size.width, height: size.width / target)
        }
        return CGRect(
            x: (size.width - fitted.width) / 2,
            y: (size.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    private func zoomLabel(_ zoom: CGFloat) -> String {
        zoom == floor(zoom) ? String(Int(zoom)) : String(format: "%.1f", zoom)
    }

    private var pinchToZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomGestureBase == nil {
                    zoomGestureBase = camera.selectedZoom
                }
                guard let zoomGestureBase else { return }
                camera.setZoom(zoomGestureBase * value)
            }
            .onEnded { _ in
                zoomGestureBase = nil
            }
    }

}

private struct MenuChip: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundStyle(GrainTheme.paper)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.black.opacity(0.54), in: Capsule())
    }
}
