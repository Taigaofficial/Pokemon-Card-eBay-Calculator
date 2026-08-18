import Foundation
import AVFoundation
import Observation

/// Plays back a note's original recording. One note plays at a time;
/// starting another (or tapping the playing one) stops the current playback.
@Observable
final class PlaybackService: NSObject, AVAudioPlayerDelegate {
    static let shared = PlaybackService()

    private(set) var playingNoteID: UUID?
    private var player: AVAudioPlayer?

    private override init() {
        super.init()
    }

    func isPlaying(_ note: Note) -> Bool {
        playingNoteID == note.id
    }

    func toggle(_ note: Note) {
        if playingNoteID == note.id {
            stop()
            return
        }
        guard let url = note.audioFileURL else { return }
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            self.player = player
            playingNoteID = note.id
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingNoteID = nil
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        playingNoteID = nil
    }
}
