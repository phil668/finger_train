import AVFoundation
import Combine
import SwiftUI
import UIKit

enum TrainingPhase: Equatable {
    case ready
    case preparing
    case hanging
    case resting
    case setComplete
    case finished

    var label: String {
        switch self {
        case .ready: "READY"
        case .preparing: "GET ON"
        case .hanging: "HANG"
        case .resting: "REST"
        case .setComplete: "SET DONE"
        case .finished: "FINISHED"
        }
    }
}

@MainActor
final class TrainingTimer: NSObject, ObservableObject {
    @Published var phase: TrainingPhase = .ready
    @Published var secondsRemaining = 7
    @Published var currentRepetition = 0
    @Published var repetitionsPerSet = 5
    @Published var completedSets = 0
    @Published var preparationSeconds = 3
    @Published var isRunning = false
    @Published var voiceEnabled = true {
        didSet {
            if voiceEnabled {
                activateAudio()
            } else {
                speaker.stopSpeaking(at: .immediate)
                deactivateAudio()
            }
        }
    }

    let hangSeconds = 7
    let restSeconds = 3

    private var timer: Timer?
    private var cueTimer: Timer?
    private let speaker = AVSpeechSynthesizer()
    private let cuePause: TimeInterval = 1.0
    private var isAudioSessionActive = false
    private var audioDeactivationTask: Task<Void, Never>?

    var phaseColor: Color {
        switch phase {
        case .preparing: AppTheme.preparation
        case .resting, .setComplete, .finished: AppTheme.mint
        default: AppTheme.orange
        }
    }

    var progress: Double {
        switch phase {
        case .ready: 0
        case .setComplete, .finished: 1
        case .preparing: 1 - Double(secondsRemaining) / Double(preparationSeconds)
        case .hanging: 1 - Double(secondsRemaining) / Double(hangSeconds)
        case .resting: 1 - Double(secondsRemaining) / Double(restSeconds)
        }
    }

    var statusLine: String {
        switch phase {
        case .ready: "Set your grip and start when ready"
        case .preparing: "Find the edge and settle your fingers"
        case .hanging: "Keep your shoulders engaged"
        case .resting: "Release and relax your fingers"
        case .setComplete: "Choose another set or finish the session"
        case .finished: "Session complete"
        }
    }

    var displayValue: String {
        switch phase {
        case .setComplete, .finished: "✓"
        default: "\(secondsRemaining)"
        }
    }

    var primaryButtonTitle: String {
        if phase == .setComplete { return "START SET \(completedSets + 1)" }
        if phase == .finished { return "NEW SESSION" }
        if isRunning { return "PAUSE" }
        if phase == .ready { return "START SET 1" }
        return "RESUME"
    }

    var currentRepetitionDisplay: Int {
        switch phase {
        case .ready: 0
        case .setComplete, .finished: repetitionsPerSet
        default: currentRepetition
        }
    }

    var completedRepetitionMarkers: Int {
        switch phase {
        case .ready: 0
        case .preparing, .hanging: max(0, currentRepetition - 1)
        case .resting: currentRepetition
        case .setComplete, .finished: repetitionsPerSet
        }
    }

    var activeSetNumber: Int {
        phase == .setComplete || phase == .finished ? max(1, completedSets) : completedSets + 1
    }

    var estimatedSetDuration: String {
        let activeSeconds = repetitionsPerSet * (preparationSeconds + hangSeconds)
            + max(0, repetitionsPerSet - 1) * restSeconds
        let phaseCount = repetitionsPerSet * 2 + max(0, repetitionsPerSet - 1)
        let seconds = activeSeconds + phaseCount * Int(cuePause)
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }

    func toggle() {
        switch phase {
        case .finished:
            reset()
            startSet()
        case .setComplete, .ready:
            startSet()
        default:
            isRunning ? pause() : resume()
        }
    }

    func finishSession() {
        guard completedSets > 0 else { return }
        stopTimers()
        activateAudio()
        phase = .finished
        secondsRemaining = 0
        isRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
        speak("Session complete")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        deactivateAudio(after: 1.2)
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        stopTimers()
        speaker.stopSpeaking(at: .immediate)
        UIApplication.shared.isIdleTimerDisabled = false
        deactivateAudio()
    }

    func reset() {
        stopTimers()
        speaker.stopSpeaking(at: .immediate)
        phase = .ready
        secondsRemaining = hangSeconds
        currentRepetition = 0
        completedSets = 0
        isRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
        deactivateAudio()
    }

    private func startSet() {
        if phase == .finished { reset() }
        currentRepetition = 1
        phase = .preparing
        secondsRemaining = preparationSeconds
        resume()
    }

    private func resume() {
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        activateAudio()
        beginCurrentPhaseWithCue()
    }

    private func scheduleNextBeat() {
        timer?.invalidate()
        let newTimer = Timer(
            timeInterval: 1,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    @objc private func timerDidFire() {
        timer = nil
        guard isRunning else { return }

        if secondsRemaining > 1 {
            secondsRemaining -= 1
            announceCount(secondsRemaining)
            scheduleNextBeat()
        } else {
            advancePhase()
        }
    }

    private func advancePhase() {
        timer?.invalidate()
        timer = nil

        switch phase {
        case .preparing:
            phase = .hanging
            secondsRemaining = hangSeconds
            beginCurrentPhaseWithCue()
        case .hanging:
            if currentRepetition >= repetitionsPerSet {
                completeSet()
            } else {
                phase = .resting
                secondsRemaining = restSeconds
                beginCurrentPhaseWithCue()
            }
        case .resting:
            currentRepetition += 1
            phase = .preparing
            secondsRemaining = preparationSeconds
            beginCurrentPhaseWithCue()
        default:
            break
        }
    }

    private func completeSet() {
        stopTimers()
        completedSets += 1
        phase = .setComplete
        secondsRemaining = 0
        isRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
        speak("Set \(completedSets) complete")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        deactivateAudio(after: 1.2)
    }

    private func beginCurrentPhaseWithCue() {
        stopTimers()
        announcePhaseCue()

        let newTimer = Timer(
            timeInterval: cuePause,
            target: self,
            selector: #selector(beginCountdownAfterCue),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(newTimer, forMode: .common)
        cueTimer = newTimer
    }

    @objc private func beginCountdownAfterCue() {
        cueTimer = nil
        guard isRunning else { return }
        announceCount(secondsRemaining)
        scheduleNextBeat()
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        cueTimer?.invalidate()
        cueTimer = nil
    }

    private func announcePhaseCue() {
        let cue: String
        switch phase {
        case .preparing: cue = "Get on"
        case .hanging: cue = "Hang"
        case .resting: cue = "Rest"
        default: return
        }
        speak(cue)
        UIImpactFeedbackGenerator(style: phase == .hanging ? .heavy : .light).impactOccurred()
    }

    private func announceCount(_ count: Int) {
        speak("\(count)")
        UIImpactFeedbackGenerator(style: count <= 3 ? .medium : .light).impactOccurred()
    }

    private func speak(_ text: String) {
        guard voiceEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.50
        utterance.volume = 1
        speaker.speak(utterance)
    }

    private func activateAudio() {
        audioDeactivationTask?.cancel()
        audioDeactivationTask = nil
        guard voiceEnabled, !isAudioSessionActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            isAudioSessionActive = true
        } catch {
            // The visual timer still works when the audio session is unavailable.
        }
    }

    private func deactivateAudio(after delay: TimeInterval = 0) {
        audioDeactivationTask?.cancel()
        audioDeactivationTask = Task { @MainActor [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            self?.isAudioSessionActive = false
            self?.audioDeactivationTask = nil
        }
    }
}
