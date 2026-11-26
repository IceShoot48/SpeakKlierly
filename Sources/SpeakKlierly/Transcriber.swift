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
        let provider = try await CaptureInputSequenceProvider.providerWithSession(
            from: microphone,
            compatibleWith: [transcriber]
        )
        let captureSession = provider.captureSession

        // The capture sequence only ends when the session is deallocated, so audio is forwarded
        // through our own stream that we can end the moment the user stops talking.
        let (inputSequence, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
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

        captureSession.startRunning()

        self.analyzer = analyzer
        self.captureSession = captureSession
        let output = provider.captureAudioDataOutput
        audioOutputLock.withLock { audioOutput = output }
        self.inputContinuation = continuation
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
        forwardingTask?.cancel()
        inputContinuation?.finish()
        analyzer = nil
        captureSession = nil
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
        guard let decibels else { return 0 }
        // Map roughly -50 dB...0 dB onto 0...1.
        return min(max((decibels + 50) / 50, 0), 1)
    }
}
