//
//  Player.swift
//  MotifEngine
//
//  Transport, ported from AMT005's AUMIDIPlayer.
//
//  The original ran a `while` loop on a background queue that slept in 100 ms slices, compared
//  each note's onset against an accumulating position variable, and dispatched note-offs with
//  `DispatchQueue.main.asyncAfter`. That design has three defects beyond the drift and jitter
//  described in PlaybackSchedule:
//
//    * The note-offs could not be cancelled. `asyncAfter` hands the work to the queue and gives
//      nothing back, so `stop()` could silence the sampler but could not un-schedule the note-offs
//      already in flight. Stop, then immediately start something else, and the previous piece's
//      note-offs arrive in the middle of the new one, cutting notes short. Here every scheduled
//      action is a DispatchWorkItem that is retained and cancelled.
//    * `@Published` properties were written from the playback queue. Publishing from a background
//      thread while SwiftUI reads on the main thread is a data race, and it is the kind that
//      shows up as a crash months later under load. All state here is mutated on the main queue.
//    * A busy loop ran for the whole duration of playback, sleeping and waking ten times a second
//      whether or not anything was due. Nothing here runs between events.
//
//  The transport now does no timekeeping of its own. It asks the schedule when things happen,
//  takes one start instant, and hands the system a set of absolute deadlines. The playhead is
//  read from the clock when someone asks, never accumulated.
//

import Foundation
import MotifAlgebra

public final class Player: ObservableObject {

    public enum State: String, Sendable {
        case stopped, playing, paused
    }

    // MARK: - Observable state

    @Published public private(set) var state: State = .stopped

    /// Musical position in beats. Computed from the clock on demand; see `refreshPosition()`.
    @Published public private(set) var positionBeats: Double = 0

    /// Set when playback could not produce sound, rather than failing silently.
    @Published public private(set) var lastError: String?

    public var onFinished: (() -> Void)?

    // MARK: - Collaborators

    private let engine: PlaybackEngine
    private let queue = DispatchQueue(label: "com.motifsuite.player", qos: .userInitiated)

    // MARK: - Playback state

    private var schedule: PlaybackSchedule?
    private var pending: [DispatchWorkItem] = []
    private var startInstant: DispatchTime?
    private var startDate: Date?
    private var elapsedWhenPaused: Double = 0
    private var displayTimer: Timer?

    /// A little runway so the first note is scheduled rather than fired late.
    private let leadIn: Double = 0.06

    public init(engine: PlaybackEngine = PlaybackEngine()) {
        self.engine = engine
    }

    deinit {
        displayTimer?.invalidate()
        pending.forEach { $0.cancel() }
    }

    // MARK: - Transport

    public func play(_ schedule: PlaybackSchedule) {
        stop(notifying: false)

        guard !schedule.isEmpty else { return }

        do {
            try engine.start()
            try engine.requireInstrument()
        } catch {
            lastError = String(describing: error)
            return
        }

        self.schedule = schedule
        self.elapsedWhenPaused = 0
        self.lastError = nil

        beginScheduling(from: 0)
        state = .playing
        startDisplayTimer()
    }

    public func pause() {
        guard state == .playing else { return }

        elapsedWhenPaused = elapsedSeconds()
        cancelPending()
        engine.allNotesOff()
        stopDisplayTimer()
        state = .paused
    }

    public func resume() {
        guard state == .paused, schedule != nil else { return }

        do {
            try engine.start()
        } catch {
            lastError = String(describing: error)
            return
        }

        beginScheduling(from: elapsedWhenPaused)
        state = .playing
        startDisplayTimer()
    }

    public func togglePlayPause(_ schedule: PlaybackSchedule) {
        switch state {
        case .playing: pause()
        case .paused: resume()
        case .stopped: play(schedule)
        }
    }

    public func stop() { stop(notifying: true) }

    private func stop(notifying: Bool) {
        cancelPending()
        engine.allNotesOff()
        stopDisplayTimer()

        let wasActive = state != .stopped
        state = .stopped
        positionBeats = schedule?.startBeat.doubleValue ?? 0
        elapsedWhenPaused = 0
        startInstant = nil
        startDate = nil

        if notifying && wasActive { onFinished?() }
    }

    // MARK: - Scheduling

    /// Hands the system absolute deadlines for everything still to come.
    ///
    /// `offset` is how far into the piece we are resuming from, so the same method serves both
    /// starting and resuming; nothing about a resumed playback is a special case beyond which
    /// events are still ahead of us.
    private func beginScheduling(from offset: Double) {
        guard let schedule else { return }

        let start = DispatchTime.now() + leadIn
        startInstant = start
        startDate = Date().addingTimeInterval(leadIn - offset)

        for event in schedule.events {
            // A note already sounding at the resume point is restarted for its remainder rather
            // than skipped; dropping it leaves an audible hole in a held bass line.
            let onset = max(event.onsetSeconds, offset)
            guard event.endSeconds > offset else { continue }

            let onDelay = onset - offset
            let offDelay = event.endSeconds - offset

            let midi = event.midi
            let velocity = event.velocity
            let channel = event.channel

            let noteOn = DispatchWorkItem { [engine] in
                engine.noteOn(midi, velocity: velocity, channel: channel)
            }
            let noteOff = DispatchWorkItem { [engine] in
                engine.noteOff(midi, channel: channel)
            }

            pending.append(noteOn)
            pending.append(noteOff)

            queue.asyncAfter(deadline: start + onDelay, execute: noteOn)
            queue.asyncAfter(deadline: start + offDelay, execute: noteOff)
        }

        // End of piece.
        let finish = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { self?.stop(notifying: true) }
        }
        pending.append(finish)
        queue.asyncAfter(deadline: start + (schedule.totalSeconds - offset), execute: finish)
    }

    private func cancelPending() {
        pending.forEach { $0.cancel() }
        pending.removeAll()
    }

    // MARK: - Position

    private func elapsedSeconds() -> Double {
        guard let startDate, state == .playing else { return elapsedWhenPaused }
        return max(0, Date().timeIntervalSince(startDate))
    }

    /// Reads the playhead from the clock. Deliberately a query rather than an accumulator — the
    /// value cannot drift because nothing is stored between calls.
    public func refreshPosition() {
        guard let schedule else { return }
        positionBeats = schedule.beatPosition(atElapsed: elapsedSeconds())
    }

    private func startDisplayTimer() {
        stopDisplayTimer()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.refreshPosition()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
}

// MARK: - Convenience

public extension Player {

    /// Play a phrase directly.
    func play(_ phrase: Phrase,
              tempo: Tempo = Tempo(),
              voices: PlaybackSchedule.VoiceFilter = .all) {
        play(PlaybackSchedule(phrase: phrase, tempo: tempo, voices: voices))
    }
}
