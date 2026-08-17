//
//  PlaybackEngineTests.swift
//  MotifEngineTests
//
//  A smoke test for the one part of MotifEngine that touches hardware.
//
//  It cannot assert that anything was audible — nothing in a unit test can hear. What it can
//  assert is the failure mode that actually bit AMT005: an engine that starts, accepts note-on
//  messages, and produces silence because no instrument ever loaded. That state is now
//  observable through `hasInstrument`, so it can be checked.
//
//  Written to be lenient about the audio device itself. A machine with no output device is not
//  a broken build, so the instrument assertions only apply once the engine has actually started.
//

import XCTest
@testable import MotifEngine
import MotifAlgebra

final class PlaybackEngineTests: XCTestCase {

    func testEngineStartsAndLoadsAnInstrument() throws {
        let engine = PlaybackEngine()

        XCTAssertFalse(engine.hasInstrument, "nothing should be loaded before it is asked for")

        do {
            try engine.start()
        } catch {
            throw XCTSkip("no usable audio device here: \(error)")
        }

        XCTAssertTrue(engine.isRunning)

        // The failure this exists to catch: a running engine with nothing loaded.
        XCTAssertTrue(engine.loadDefaultInstrument(),
                      "no instrument could be loaded, so playback would be silent")
        XCTAssertTrue(engine.hasInstrument)
        XCTAssertNoThrow(try engine.requireInstrument())

        // Exercise the note path. Nothing to assert beyond "does not trap".
        engine.noteOn(60, velocity: 80, channel: 0)
        engine.noteOff(60, channel: 0)
        engine.allNotesOff()

        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }

    /// Out-of-range MIDI values are clamped rather than trapping on the UInt8 conversion.
    /// `UInt8(200)` is fine, but `UInt8(-1)` and `UInt8(300)` both crash, and note numbers
    /// arrive from transforms that can carry a pitch anywhere.
    func testOutOfRangeNoteNumbersAreClamped() throws {
        let engine = PlaybackEngine()
        guard (try? engine.start()) != nil else {
            throw XCTSkip("no usable audio device here")
        }
        defer { engine.stop() }

        engine.noteOn(-40, velocity: -10, channel: -3)
        engine.noteOn(9_000, velocity: 9_000, channel: 99)
        engine.noteOff(-40, channel: -3)
        engine.noteOff(9_000, channel: 99)
    }

    /// A transform can move a phrase clean off the keyboard. The schedule still describes it —
    /// clamping is the sound layer's business, not the algebra's — so this checks the two agree
    /// that nothing traps on the way through.
    func testExtremeTranspositionSurvivesScheduling() throws {
        let seed = Phrase([Note(Rational(0), Rational(1), 35)], in: .cMajor)
        let far = Transform.translate(400).apply(to: seed)

        let schedule = PlaybackSchedule(phrase: far, tempo: Tempo())
        XCTAssertEqual(schedule.events.count, 1)
        XCTAssertGreaterThan(schedule.events[0].midi, 127,
                             "the algebra should report the true pitch, however unplayable")

        let engine = PlaybackEngine()
        guard (try? engine.start()) != nil else {
            throw XCTSkip("no usable audio device here")
        }
        defer { engine.stop() }

        engine.noteOn(schedule.events[0].midi, velocity: 80, channel: 0)
        engine.noteOff(schedule.events[0].midi, channel: 0)
    }
}
