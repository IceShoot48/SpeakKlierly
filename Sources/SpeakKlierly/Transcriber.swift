import AVFoundation
import Speech

enum TranscriberError: LocalizedError {
    case unsupportedLocale
    case noMicrophone
    case notRunning

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale: "Your system language isn't supported for on-device dictation."
        case .noMicrophone: "No microphone was found."
        case .notRunning: "Dictation isn't running."
        }
    }
}

/// Captures microphone audio and transcribes it fully on-device with `DictationTranscriber`.
///
/// Not main-actor isolated on purpose: the audio engine tap runs on a real-time audio thread,
/// and a tap closure created in a main-actor context would trip Swift's isolation checks.
final class Transcriber: @unchecked Sendable {
    private var analyzer: SpeechAnalyzer?
    private var captureSession: AVCaptureSession?
    /// Used instead of `captureSession` on macOS 26, where `CaptureInputSequenceProvider` doesn't exist.
    private var audioEngine: AVAudioEngine?
    private let engineLevel = EngineLevel()
    /// Read from the main thread by the level meter, so it's guarded by a lock.
    private var audioOutput: AVCaptureAudioDataOutput?
    private let audioOutputLock = NSLock()
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var forwardingTask: Task<Void, Never>?
    private var analysisTask: Task<CMTime?, Error>?
    private var resultsTask: Task<String, Error>?

    /// Downloads the speech model for the current language if it isn't installed yet.
    func prepareAssets() async throws {
        let transcriber = try await makeModule()
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    func start() async throws {
        let transcriber = try await makeModule()
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw TranscriberError.noMicrophone
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // The capture sequence only ends when the session is deallocated, so audio is forwarded
        // through our own stream that we can end the moment the user stops talking.
        let (inputSequence, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

        if #available(macOS 27, *) {
            let provider = try await CaptureInputSequenceProvider.providerWithSession(
                from: microphone,
                compatibleWith: [transcriber]
            )
            let captureInputs = provider.analyzerInputs
            forwardingTask = Task {
                do {
                    for try await input in captureInputs {
                        try Task.checkCancellation()
                        continuation.yield(input)
                    }
                } catch {}
                continuation.finish()
            }
            self.captureSession = provider.captureSession
            let output = provider.captureAudioDataOutput
            audioOutputLock.withLock { audioOutput = output }
        } else {
            // macOS 26 has no CaptureInputSequenceProvider, so tap the microphone with
            // AVAudioEngine and convert buffers to the format the analyzer wants.
            audioEngine = try await startAudioEngine(for: transcriber, continuation: continuation)
        }

        // Collect finalized phrases; the stream ends once the analyzer finishes.
        resultsTask = Task {
            var phrases: [String] = []
            for try await result in transcriber.results where result.isFinal {
                let phrase = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                if !phrase.isEmpty { phrases.append(phrase) }
            }
            return phrases.joined(separator: " ")
        }
        analysisTask = Task {
            try await analyzer.analyzeSequence(inputSequence)
        }

        captureSession?.startRunning()

        self.analyzer = analyzer
        self.inputContinuation = continuation
    }

    /// Fallback microphone capture for macOS 26.
    private func startAudioEngine(
        for transcriber: DictationTranscriber,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) async throws -> AVAudioEngine {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw TranscriberError.noMicrophone
        }
        let targetFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let converter = BufferConverter(from: inputFormat, to: targetFormat ?? inputFormat)
        let level = engineLevel
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            level.update(from: buffer)
            if let converted = converter.convert(buffer) {
                continuation.yield(AnalyzerInput(buffer: converted))
            }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw error
        }
        return engine
    }

    /// Stops listening and returns the full transcript.
    func stop() async throws -> String {
        guard let analyzer, let analysisTask, let resultsTask else {
            throw TranscriberError.notRunning
        }
        endCapture()

        if let lastSampleTime = try await analysisTask.value {
            try await analyzer.finalizeAndFinish(through: lastSampleTime)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await resultsTask.value
    }

    /// Abandons the current session without producing text.
    func cancel() async {
        let analyzer = analyzer
        analysisTask?.cancel()
        resultsTask?.cancel()
        endCapture()
        await analyzer?.cancelAndFinishNow()
    }

    private func endCapture() {
        captureSession?.stopRunning()
        if let audioEngine {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        engineLevel.reset()
        forwardingTask?.cancel()
        inputContinuation?.finish()
        analyzer = nil
        captureSession = nil
        audioEngine = nil
        audioOutputLock.withLock { audioOutput = nil }
        inputContinuation = nil
        forwardingTask = nil
        analysisTask = nil
        resultsTask = nil
    }

    private func makeModule() async throws -> DictationTranscriber {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            throw TranscriberError.unsupportedLocale
        }
        // Long-form dictation with automatic punctuation; good for emails and prompts.
        return DictationTranscriber(locale: locale, preset: .longDictation)
    }

    /// Current microphone loudness scaled to 0...1, for the on-screen level meter.
    func currentLevel() -> Float {
        let decibels = audioOutputLock.withLock {
            audioOutput?.connections.flatMap(\.audioChannels).map(\.averagePowerLevel).max()
        }
        guard let decibels = decibels ?? engineLevel.decibels else { return 0 }
        // Map roughly -50 dB...0 dB onto 0...1.
        return min(max((decibels + 50) / 50, 0), 1)
    }
}

/// Converts microphone buffers to the analyzer's audio format. Only used from the audio tap thread.
private final class BufferConverter: @unchecked Sendable {
    private let converter: AVAudioConverter?
    private let outputFormat: AVAudioFormat

    init(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) {
        self.outputFormat = outputFormat
        converter = inputFormat == outputFormat ? nil : AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return nil }
        let input = InputOnce(buffer)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            input.next(inputStatus)
        }
        guard status != .error, error == nil, output.frameLength > 0 else { return nil }
        return output
    }
}

/// Hands one buffer to `AVAudioConverter`, then reports that no more data is ready.
private final class InputOnce: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }

    func next(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        guard let buffer else {
            status.pointee = .noDataNow
            return nil
        }
        self.buffer = nil
        status.pointee = .haveData
        return buffer
    }
}

/// Microphone loudness from the AVAudioEngine tap, read by the level meter on the main thread.
private final class EngineLevel: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Float?

    var decibels: Float? { lock.withLock { value } }

    func reset() { lock.withLock { value = nil } }

    func update(from buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let frames = Int(buffer.frameLength)
        var peak: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            var sum: Float = 0
            for i in 0..<frames { sum += channels[channel][i] * channels[channel][i] }
            peak = max(peak, (sum / Float(frames)).squareRoot())
        }
        let db = 20 * log10(max(peak, 0.000_01))
        lock.withLock { value = db }
    }
}
