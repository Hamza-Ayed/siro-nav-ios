import Foundation
import AVFoundation

public struct VoicePromptItem: Codable, Sendable {
    public let file: String
    public let text: String
    public let category: String
    public let priority: Int

    public init(file: String, text: String, category: String, priority: Int = 2) {
        self.file = file
        self.text = text
        self.category = category
        self.priority = priority
    }
}

public final class NavVoiceCatalog: @unchecked Sendable {
    public static let shared = NavVoiceCatalog()
    private var prompts: [String: VoicePromptItem] = [:]

    private init() {
        loadManifest()
    }

    private func loadManifest() {
        if let url = Bundle.module.url(forResource: "manifest", withExtension: "json", subdirectory: "Resources/audio/ar") ??
                     Bundle.module.url(forResource: "manifest", withExtension: "json") {
            if let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rawPrompts = json["prompts"] as? [String: [String: Any]] {
                for (key, val) in rawPrompts {
                    let file = val["file"] as? String ?? ""
                    let text = val["text"] as? String ?? ""
                    let category = val["category"] as? String ?? ""
                    let priority = val["priority"] as? Int ?? 2
                    prompts[key] = VoicePromptItem(file: file, text: text, category: category, priority: priority)
                }
            }
        }
    }

    public func registerPrompt(id: String, prompt: VoicePromptItem) {
        prompts[id] = prompt
    }

    public func getPrompt(_ id: String) -> VoicePromptItem? {
        return prompts[id]
    }

    public var count: Int {
        return prompts.count
    }
}

public final class NavVoiceEngine: @unchecked Sendable {
    public var isMuted: Bool = false
    private var audioPlayer: AVAudioPlayer?

    public init() {}

    public func playPrompt(id: String) {
        guard !isMuted else { return }
        guard let prompt = NavVoiceCatalog.shared.getPrompt(id) else { return }

        let fileName = prompt.file.replacingOccurrences(of: ".mp3", with: "")
        if let url = Bundle.module.url(forResource: fileName, withExtension: "mp3", subdirectory: "Resources/audio/ar") ??
                     Bundle.module.url(forResource: fileName, withExtension: "mp3") {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        }
    }

    public func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
