// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import os
import QuartzCore
import Speech

/// Hold-to-talk dictation: hold Right Option, speak, release, and the words
/// are pasted where the cursor is. Any other key pressed while holding (⌥ plus
/// a letter, Esc) cancels instead. Recognition
/// runs on this Mac through Apple's Speech framework, so no audio leaves it
/// when on-device models are available. Requires Microphone, Speech
/// Recognition, macOS Dictation switched on, and Accessibility (for the key
/// tap and the synthesized ⌘V).
///
/// Switched on and off from the Dictation section of the Tools settings page.
final class DictationService {
    static let shared = DictationService()

    static let enabledKey = "dictationEnabled"

    private enum State { case idle, arming, listening, transcribing }

    /// A tap shorter than this is treated as an accidental press, not speech.
    private static let minimumHold: TimeInterval = 0.25
    /// How long to wait for the final transcript after listening stops.
    private static let finalResultTimeout: TimeInterval = 6
    /// A forgotten session stops on its own instead of keeping the mic on.
    private static let maximumListening: TimeInterval = 5 * 60
    private static let rightOptionKeyCode: UInt16 = 61
    /// The device-dependent bit for the right Option key (NX_DEVICERALTKEYMASK),
    /// so a held left Option is never mistaken for it.
    private static let rightOptionDownMask: UInt64 = 0x40

    private var state = State.idle
    private var eventTap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var pressedAt: Date?
    private var cancelledByOtherKey = false

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var finishWork: DispatchWorkItem?
    private var listeningLimitWork: DispatchWorkItem?

    private let hud = DictationHUD()
    private let log = Logger(subsystem: "com.vorssaint.dictation", category: "dictation")
    private var bufferCount = 0

    private init() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
    }

    /// Whether macOS Dictation is on. The Speech framework refuses to run
    /// while it is off (kLSRErrorDomain 201), so Settings warns about it.
    /// The preference is absent until Dictation is first turned on.
    static var isSystemDictationOn: Bool {
        CFPreferencesCopyAppValue("Dictation Enabled" as CFString,
                                  "com.apple.assistant.support" as CFString) as? Bool ?? false
    }

    static func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reinstalls the key tap too: one created before Accessibility was
    /// granted never receives events, so a grant needs a fresh one.
    func syncWithPreferences() {
        stop()
        if UserDefaults.standard.bool(forKey: Self.enabledKey) { start() }
    }

    /// A listen-only event tap: it hears keys whichever app is in front,
    /// Vorssaint's own windows included, and never delays or swallows one.
    private func start() {
        guard eventTap == nil else { return }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap,
                                          place: .headInsertEventTap,
                                          options: .listenOnly,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: { _, type, event, userInfo in
                                              if let userInfo {
                                                  let service = Unmanaged<DictationService>
                                                      .fromOpaque(userInfo).takeUnretainedValue()
                                                  service.handle(type: type, event: event)
                                              }
                                              return Unmanaged.passUnretained(event)
                                          },
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            log.error("event tap unavailable trusted=\(AXIsProcessTrusted())")
            return
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        tapSource = source
        log.notice("event tap installed trusted=\(AXIsProcessTrusted())")
    }

    private func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let tapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes)
        }
        eventTap = nil
        tapSource = nil
        pressedAt = nil
        cancel()
    }

    // MARK: Key handling

    /// Runs on the main run loop, where the tap's source is installed.
    private func handle(type: CGEventType, event: CGEvent) {
        // macOS switches a tap off when it thinks the tap is stuck; turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyDown {
            // ⌥ plus a letter types a special character, and Esc means stop:
            // either way, not dictation.
            if pressedAt != nil, !cancelledByOtherKey {
                cancelledByOtherKey = true
                log.notice("cancel: key typed while held")
                cancel()
            }
            return
        }
        guard type == .flagsChanged else { return }
        let flags = event.flags
        guard keyCode == Self.rightOptionKeyCode else {
            // Another modifier joined in (⌥⌘…): leave the shortcut alone.
            if pressedAt != nil, !cancelledByOtherKey {
                cancelledByOtherKey = true
                log.notice("cancel: another modifier pressed")
                cancel()
            }
            return
        }
        let isDown = flags.rawValue & Self.rightOptionDownMask != 0
        let otherModifiers = flags.intersection([.maskShift, .maskControl, .maskCommand, .maskSecondaryFn])
        if isDown, otherModifiers.isEmpty, pressedAt == nil {
            pressedAt = Date()
            cancelledByOtherKey = false
            beginListening()
        } else if !isDown, let pressedAt {
            self.pressedAt = nil
            let held = Date().timeIntervalSince(pressedAt)
            if cancelledByOtherKey || held < Self.minimumHold {
                cancel()
            } else {
                finishListening()
            }
        }
    }

    // MARK: Recording

    private func beginListening() {
        guard state == .idle else { return }
        state = .arming
        Self.requestPermissions { [weak self] granted in
            guard let self else { return }
            // The key may have been released while a permission prompt was up.
            guard self.state == .arming, self.pressedAt != nil else {
                if self.state == .arming { self.state = .idle }
                return
            }
            guard granted else {
                self.state = .idle
                NSSound.beep()
                return
            }
            self.startRecognition()
        }
    }

    private func startRecognition() {
        let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer, recognizer.isAvailable else {
            log.error("recognizer unavailable for \(Locale.current.identifier, privacy: .public)")
            state = .idle
            NSSound.beep()
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        log.notice("start locale=\(recognizer.locale.identifier, privacy: .public) onDevice=\(recognizer.supportsOnDeviceRecognition)")
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            teardownAudio()
            state = .idle
            NSSound.beep()
            return
        }
        input.removeTap(onBus: 0)
        log.notice("input format \(format.sampleRate) Hz, \(format.channelCount) ch")
        bufferCount = 0
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, weak request] buffer, _ in
            request?.append(buffer)
            let level = Self.level(of: buffer)
            DispatchQueue.main.async {
                guard let self, self.state == .listening else { return }
                self.bufferCount += 1
                self.hud.setLevel(level)
            }
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            log.error("audio engine failed: \(error.localizedDescription, privacy: .public)")
            teardownAudio()
            state = .idle
            NSSound.beep()
            return
        }

        latestTranscript = ""
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.log.error("recognition error: \(String(describing: error), privacy: .public)")
                    // A failure before any words were heard will never produce
                    // text: say why now instead of listening to nothing.
                    if self.state == .listening || (self.state == .transcribing && self.latestTranscript.isEmpty) {
                        self.fail(with: error)
                        return
                    }
                }
                if let result {
                    self.log.notice("result final=\(result.isFinal) chars=\(result.bestTranscription.formattedString.count)")
                    self.latestTranscript = result.bestTranscription.formattedString
                    if result.isFinal, self.state == .transcribing { self.deliver() }
                } else if error != nil, self.state == .transcribing {
                    self.deliver()
                }
            }
        }
        state = .listening
        hud.show(.listening)

        let limit = DispatchWorkItem { [weak self] in
            guard self?.state == .listening else { return }
            self?.log.notice("stop: listening limit reached")
            self?.finishListening()
        }
        listeningLimitWork = limit
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maximumListening, execute: limit)
    }

    private func finishListening() {
        guard state == .listening else {
            cancel()
            return
        }
        state = .transcribing
        listeningLimitWork?.cancel()
        listeningLimitWork = nil
        log.notice("stopped after \(self.bufferCount) audio buffers")
        hud.show(.transcribing)
        stopAudio()
        request?.endAudio()
        let work = DispatchWorkItem { [weak self] in
            guard self?.state == .transcribing else { return }
            self?.deliver()
        }
        finishWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.finalResultTimeout, execute: work)
    }

    private func deliver() {
        let text = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        log.notice("deliver chars=\(text.count) trusted=\(AXIsProcessTrusted())")
        reset()
        guard !text.isEmpty else { return }
        guard AXIsProcessTrusted() else {
            Permissions.shared.requestAccessibility()
            return
        }
        let started = TransientPaste.shared.paste(text, didFail: { [log] in
            log.error("paste failed")
            NSSound.beep()
        })
        log.notice("paste started=\(started)")
    }

    private func fail(with error: Error) {
        reset()
        NSSound.beep()
        let nsError = error as NSError
        // kLSRErrorDomain 201: the Speech framework refuses to run while macOS
        // Dictation is off, even though Apple's own dictation key is not used.
        let strings = FeatureStrings.dictation(L10n.shared.language)
        if nsError.domain == "kLSRErrorDomain", nsError.code == 201 {
            hud.flash(strings.turnOnSystemDictation)
            Self.openKeyboardSettings()
        } else {
            hud.flash(strings.failed)
        }
    }

    private func cancel() {
        guard state != .idle else { return }
        reset()
    }

    private func reset() {
        finishWork?.cancel()
        finishWork = nil
        listeningLimitWork?.cancel()
        listeningLimitWork = nil
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        teardownAudio()
        state = .idle
        hud.hide()
    }

    private func stopAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    /// Stops the engine and releases the microphone, so the orange mic
    /// indicator is only on while a session is listening.
    private func teardownAudio() {
        stopAudio()
        audioEngine.reset()
    }

    /// Loudness of one buffer from 0 (silence) to 1 (loud speech), on a
    /// decibel scale so quiet voices still move the icon.
    private static func level(of buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count { sum += samples[index] * samples[index] }
        let rms = (sum / Float(count)).squareRoot()
        let decibels = 20 * log10(max(rms, 1e-7))
        return CGFloat(min(max((decibels + 50) / 40, 0), 1))
    }

    // MARK: Permissions

    private static func requestPermissions(_ completion: @escaping (Bool) -> Void) {
        requestSpeech { speechGranted in
            guard speechGranted else { return completion(false) }
            requestMicrophone(completion)
        }
    }

    private static func requestSpeech(_ completion: @escaping (Bool) -> Void) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: completion(true)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async { completion(status == .authorized) }
            }
        default: completion(false)
        }
    }

    private static func requestMicrophone(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default: completion(false)
        }
    }
}

/// A small floating badge at the bottom of the screen that says dictation is
/// listening or working. It never takes focus or clicks.
///
/// While listening, the red dot sends out a pulsing ring and swells with the
/// voice; while transcribing, the dot turns gray and breathes.
private final class DictationHUD {
    enum Phase { case listening, transcribing }

    private static let height: CGFloat = 40
    private static let standardWidth: CGFloat = 170
    private static let dotSize: CGFloat = 10

    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "")
    private let iconView = NSView()
    private let dotLayer = CALayer()
    private let ringLayer = CAShapeLayer()
    private var smoothedLevel: CGFloat = 0
    private var hideWork: DispatchWorkItem?

    func show(_ phase: Phase) {
        // Built first so the label carries its font when it is measured.
        if panel == nil { panel = makePanel() }
        let strings = FeatureStrings.dictation(L10n.shared.language)
        switch phase {
        case .listening: label.stringValue = strings.listening
        case .transcribing: label.stringValue = strings.transcribing
        }
        // Some languages run longer than the English badge.
        let width = max(Self.standardWidth, label.attributedStringValue.size().width + 56)
        let panel = preparePanel(width: width)
        switch phase {
        case .listening:
            setColor(.systemRed)
            startPulse()
        case .transcribing:
            setColor(.systemGray)
            startBreathing()
        }
        panel.orderFrontRegardless()
    }

    /// Feeds the microphone loudness, 0 to 1, into the dot's size.
    func setLevel(_ level: CGFloat) {
        // Rise quickly with the voice, fall back gently between words.
        let factor: CGFloat = level > smoothedLevel ? 0.6 : 0.15
        smoothedLevel += (level - smoothedLevel) * factor
        let scale = 1 + smoothedLevel * 0.8
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.08)
        dotLayer.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        stopAnimations()
        panel?.orderOut(nil)
    }

    /// Shows a short message for a few seconds, then hides itself.
    func flash(_ message: String) {
        if panel == nil { panel = makePanel() }
        label.stringValue = message
        let width = max(Self.standardWidth, label.attributedStringValue.size().width + 56)
        let panel = preparePanel(width: width)
        stopAnimations()
        setColor(.systemOrange)
        panel.orderFrontRegardless()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
    }

    // MARK: Animation

    private func startPulse() {
        stopAnimations()
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 2.6
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.7
        fade.toValue = 0
        let pulse = CAAnimationGroup()
        pulse.animations = [scale, fade]
        pulse.duration = 1.2
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ringLayer.add(pulse, forKey: "pulse")
    }

    private func startBreathing() {
        stopAnimations()
        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = 1
        breathe.toValue = 0.3
        breathe.duration = 0.6
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dotLayer.add(breathe, forKey: "breathe")
    }

    private func stopAnimations() {
        ringLayer.removeAllAnimations()
        dotLayer.removeAllAnimations()
        ringLayer.opacity = 0
        smoothedLevel = 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    private func setColor(_ color: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dotLayer.backgroundColor = color.cgColor
        ringLayer.strokeColor = color.cgColor
        CATransaction.commit()
    }

    // MARK: Layout

    private func preparePanel(width: CGFloat) -> NSPanel {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        hideWork?.cancel()
        hideWork = nil
        panel.setContentSize(NSSize(width: width, height: Self.height))
        // The shadow is traced from the rounded content; retrace it at the new width.
        panel.invalidateShadow()
        label.frame.size.width = width - 50
        position(panel)
        return panel
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: Self.standardWidth, height: Self.height)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.state = .active
        // A layer corner radius leaves the blur's square corners showing as a
        // pale box; a stretchable mask image rounds the blur itself.
        background.maskImage = Self.pillMask(radius: size.height / 2)
        background.autoresizingMask = [.width, .height]

        // The icon area is larger than the dot so the ring and the swelling
        // dot have room to grow before the badge's edge clips them.
        let iconSize: CGFloat = 28
        iconView.frame = NSRect(x: 9, y: (size.height - iconSize) / 2, width: iconSize, height: iconSize)
        iconView.wantsLayer = true
        let center = CGPoint(x: iconSize / 2, y: iconSize / 2)
        let dotBounds = CGRect(x: 0, y: 0, width: Self.dotSize, height: Self.dotSize)

        ringLayer.bounds = dotBounds
        ringLayer.position = center
        ringLayer.path = CGPath(ellipseIn: dotBounds, transform: nil)
        ringLayer.fillColor = nil
        ringLayer.lineWidth = 1.5
        ringLayer.opacity = 0

        dotLayer.bounds = dotBounds
        dotLayer.position = center
        dotLayer.cornerRadius = Self.dotSize / 2

        iconView.layer?.addSublayer(ringLayer)
        iconView.layer?.addSublayer(dotLayer)

        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.frame = NSRect(x: 40, y: (size.height - 18) / 2, width: size.width - 50, height: 18)

        background.addSubview(iconView)
        background.addSubview(label)
        panel.contentView = background
        return panel
    }

    /// A capsule mask that keeps its round ends however wide the badge grows.
    private static func pillMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 60))
    }
}
