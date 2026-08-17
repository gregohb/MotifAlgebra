//
//  PlaybackEngine.swift
//  MotifEngine
//
//  The sound-producing layer, ported from AMT005's AUPlaybackEngine.
//
//  Structurally close to the original — AVAudioEngine driving an AVAudioUnitSampler is the right
//  shape and there was no reason to change it. What changed is failure behaviour. AMT005's
//  `startEngine`, `loadDefaultSound` and `configurePianoSound` swallowed their errors and printed,
//  so a sampler that failed to load its preset produced a running engine that was silent, and the
//  only evidence was a line in the console. Silence is the hardest audio bug to diagnose, and it
//  is exactly the one the code was arranging to hide. Here the failures are thrown or recorded.
//
//  This is the only file in MotifEngine that cannot be tested without audio hardware, which is
//  why it does as little as possible: it holds no timing logic and no musical state. Everything
//  that decides *when* is in PlaybackSchedule and Player.
//

import Foundation
import AVFoundation

public final class PlaybackEngine {

    public enum EngineError: Error, CustomStringConvertible {
        case engineFailedToStart(underlying: Error)
        case soundFontMissing(URL)
        case soundFontFailedToLoad(URL, underlying: Error)
        case noInstrumentLoaded

        public var description: String {
            switch self {
            case let .engineFailedToStart(e):
                return "the audio engine did not start: \(e.localizedDescription)"
            case let .soundFontMissing(url):
                return "no sound font at \(url.path)"
            case let .soundFontFailedToLoad(url, e):
                return "could not load \(url.lastPathComponent): \(e.localizedDescription)"
            case .noInstrumentLoaded:
                return "the sampler has no instrument loaded, so playback would be silent"
            }
        }
    }

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()

    /// Whether an instrument was actually loaded. A sampler with nothing loaded still accepts
    /// note-on messages and produces nothing, so this is tracked rather than assumed.
    public private(set) var hasInstrument = false

    public var isRunning: Bool { engine.isRunning }

    /// `masterGain` was deprecated in macOS 12; `overallGain` is the replacement.
    public var gain: Float {
        get { sampler.overallGain }
        set { sampler.overallGain = newValue }
    }

    public init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        sampler.overallGain = -6.0       // headroom; a full chord at unity clips
    }

    // MARK: - Lifecycle

    public func start() throws {
        guard !engine.isRunning else { return }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif

        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw EngineError.engineFailedToStart(underlying: error)
        }
    }

    public func stop() {
        allNotesOff()
        engine.stop()
    }

    // MARK: - Instrument

    /// Load a SoundFont or DLS bank.
    public func loadSoundFont(at url: URL,
                              program: UInt8 = 0,
                              bankMSB: UInt8 = 0x79,
                              bankLSB: UInt8 = 0) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EngineError.soundFontMissing(url)
        }
        do {
            try sampler.loadSoundBankInstrument(at: url,
                                                program: program,
                                                bankMSB: bankMSB,
                                                bankLSB: bankLSB)
            hasInstrument = true
        } catch {
            hasInstrument = false
            throw EngineError.soundFontFailedToLoad(url, underlying: error)
        }
    }

    /// Load whatever the system offers, in preference order.
    ///
    /// AMT005 tried a factory preset, printed on failure, and carried on regardless — so the
    /// caller had no way to know it was about to play nothing. This reports what happened.
    @discardableResult
    public func loadDefaultInstrument() -> Bool {
        // The system DLS bank is present on macOS and is what AVAudioUnitSampler expects.
        let systemBank = URL(fileURLWithPath:
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")

        if FileManager.default.fileExists(atPath: systemBank.path) {
            if (try? sampler.loadSoundBankInstrument(at: systemBank,
                                                     program: 0,
                                                     bankMSB: 0x79,
                                                     bankLSB: 0)) != nil {
                hasInstrument = true
                return true
            }
        }

        if let preset = sampler.auAudioUnit.factoryPresets?.first {
            sampler.auAudioUnit.currentPreset = preset
            hasInstrument = true
            return true
        }

        hasInstrument = false
        return false
    }

    /// Throws rather than returning false, for callers that would rather not check.
    public func requireInstrument() throws {
        if !hasInstrument { loadDefaultInstrument() }
        guard hasInstrument else { throw EngineError.noInstrumentLoaded }
    }

    // MARK: - Notes

    public func noteOn(_ midi: Int, velocity: Int, channel: Int) {
        guard engine.isRunning else { return }
        sampler.startNote(UInt8(clamping: midi),
                          withVelocity: UInt8(clamping: velocity),
                          onChannel: UInt8(clamping: channel))
    }

    public func noteOff(_ midi: Int, channel: Int) {
        guard engine.isRunning else { return }
        sampler.stopNote(UInt8(clamping: midi), onChannel: UInt8(clamping: channel))
    }

    /// All-notes-off on every channel. Sent on stop, on pause, and when a schedule is replaced —
    /// anywhere a pending note-off might otherwise be cancelled before it fires.
    public func allNotesOff() {
        for channel in 0 ..< 16 {
            sampler.sendController(123, withValue: 0, onChannel: UInt8(channel))
        }
    }
}

private extension UInt8 {
    init(clamping value: Int) {
        self = UInt8(Swift.max(0, Swift.min(127, value)))
    }
}
