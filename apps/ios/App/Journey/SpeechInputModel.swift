import Foundation
import Observation
@preconcurrency import AVFoundation
@preconcurrency import Speech

@MainActor
@Observable
final class SpeechInputModel {
    private(set) var isRecording = false
    private(set) var transcript = ""
    var errorMessage: String?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var sessionID = UUID()
    private var starting = false

    func start() async {
        guard !starting, !isRecording else { return }
        starting = true; errorMessage = nil
        let current = UUID(); sessionID = current
        defer { starting = false }
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard current == sessionID else { return }
        guard speechAllowed else { errorMessage = "语音识别权限未开启，仍可使用键盘输入。"; return }
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard current == sessionID else { return }
        guard micAllowed else { errorMessage = "麦克风权限未开启，仍可使用键盘输入。"; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.isAvailable else {
            errorMessage = "语音服务暂时不可用，请使用键盘输入。"; return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                errorMessage = "未找到可用麦克风，请使用键盘输入。"; return
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            self.engine = engine; self.request = request
            transcript = ""
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = result?.isFinal == true
                let failed = error != nil
                Task { @MainActor [weak self] in
                    guard let self, self.sessionID == current else { return }
                    if let text { self.transcript = text }
                    if finished || failed {
                        if failed && self.transcript.isEmpty { self.errorMessage = "没有听清，可以重试或使用键盘。" }
                        self.stop()
                    }
                }
            }
            engine.prepare(); try engine.start(); isRecording = true
        } catch { stop(); errorMessage = "录音暂时无法开始，请使用键盘输入。" }
    }
    func stop() {
        sessionID = UUID()
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio(); recognition?.cancel()
        engine = nil; request = nil; recognition = nil; isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
