import Foundation
import AVFoundation
import Observation

/// Records high-quality compressed M4A (AAC) audio, with the audio session
/// configured so Bluetooth microphones (AirPods etc.) are usable.
@Observable
final class AudioService: NSObject, AVAudioRecorderDelegate {
    static let shared = AudioService()

    private(set) var isRecording = false
    private(set) var lastRecordingURL: URL?
    /// Live input level in 0...1, driven by a metering timer while recording.
    private(set) var inputLevel: Float = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?

    private override init() {
        super.init()
    }

    enum AudioServiceError: LocalizedError {
        case microphonePermissionDenied
        case recorderInitFailed

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                "Microphone access is denied. Enable it in Settings → Privacy → Microphone."
            case .recorderInitFailed:
                "Could not start the audio recorder."
            }
        }
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }

    // MARK: - Recording

    /// Starts a new recording and returns the destination file URL.
    @discardableResult
    func startRecording() async throws -> URL {
        guard !isRecording else { return recorder!.url }

        guard await requestPermission() else {
            throw AudioServiceError.microphonePermissionDenied
        }

        try configureSession()

        let fileName = "minddrop-\(Int(Date.now.timeIntervalSince1970)).m4a"
        let url = URL.documentsDirectory.appending(path: fileName)

        // High-quality compressed AAC in an M4A container.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else {
            throw AudioServiceError.recorderInitFailed
        }
        recorder.delegate = self
        recorder.isMeteringEnabled = true

        guard recorder.record() else {
            throw AudioServiceError.recorderInitFailed
        }

        self.recorder = recorder
        isRecording = true
        startMetering()
        return url
    }

    /// Stops the active recording and returns the URL of the finished file.
    @discardableResult
    func stopRecording() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        let url = recorder.url
        self.recorder = nil
        isRecording = false
        stopMetering()
        lastRecordingURL = url
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
        return url
    }

    // MARK: - Session

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // The HFP option enables recording from Bluetooth headset mics
        // (AirPods); A2DP/defaultToSpeaker keep playback sensible.
        // .allowBluetooth was renamed .allowBluetoothHFP in the Xcode 26 SDK.
        #if compiler(>=6.2)
        let options: AVAudioSession.CategoryOptions = [
            .allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker,
        ]
        #else
        let options: AVAudioSession.CategoryOptions = [
            .allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker,
        ]
        #endif
        try session.setCategory(.playAndRecord, mode: .default, options: options)
        try session.setActive(true)
    }

    // MARK: - Metering

    private func startMetering() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            // Map dBFS (-160...0) to 0...1 for the UI.
            let power = recorder.averagePower(forChannel: 0)
            self.inputLevel = max(0, min(1, (power + 50) / 50))
        }
        // startRecording may run off the main thread; the main run loop is
        // the only one guaranteed to be spinning.
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        inputLevel = 0
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            isRecording = false
            stopMetering()
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
        stopMetering()
    }
}
