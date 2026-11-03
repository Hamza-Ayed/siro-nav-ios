import Foundation
import AVFoundation

public struct VoicePrompt: Codable, Sendable {
    public let file: String
    public let text: String
    public let category: String
    public let priority: Int
}

public struct VoiceManifest: Codable, Sendable {
    public let version: String
    public let language: String
    public let voiceName: String?
    public let prompts: [String: VoicePrompt]

    enum CodingKeys: String, CodingKey {
        case version, language, prompts
        case voiceName = "voice_name"
    }
}

public final class NavVoiceCatalog: @unchecked Sendable {
    public static let shared = NavVoiceCatalog()
    private var prompts: [String: VoicePrompt] = [:]

    private init() {
        loadManifest()
    }

    private func loadManifest() {
        guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json", subdirectory: "Resources/audio/ar") ??
                        Bundle.module.url(forResource: "manifest", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(VoiceManifest.self, from: data)
            self.prompts = manifest.prompts
        } catch {
            print("[NavVoiceCatalog] Failed to load voice manifest: \(error)")
        }
    }

    public func getPrompt(_ id: String) -> VoicePrompt? {
        return prompts[id]
    }

    public var count: Int {
        return prompts.count
    }
}

public final class NavVoiceEngine: @unchecked Sendable {
    public var isMuted: Bool = false
    private var audioPlayer: AVAudioPlayer?
    private var lastPlayedPromptId: String?

    public init() {}

    public func resolvePromptId(
        maneuverType: Int,
        distanceMeters: Double,
        priority: Int = 2,
        exitNumber: Int? = nil
    ) -> String? {
        // Immediate turn (<= 35m)
        if distanceMeters <= 35.0 || priority == 0 {
            return resolveImmediatePrompt(maneuverType: maneuverType, exitNumber: exitNumber)
        }

        // Quantized distance bins matching studio audio library
        if distanceMeters >= 35.0 && distanceMeters <= 65.0 {
            switch maneuverType {
            case 1, 2, 3: return "after_50m_turn_right"
            case -1, -2, -3: return "after_50m_turn_left"
            case 6, -6: return "after_50m_roundabout"
            default: return nil
            }
        }

        if distanceMeters > 65.0 && distanceMeters <= 130.0 {
            switch maneuverType {
            case 1, 2, 3: return "after_100m_turn_right"
            case -1, -2, -3: return "after_100m_turn_left"
            case 8, -8, -98: return "after_100m_u_turn"
            default: return nil
            }
        }

        if distanceMeters > 130.0 && distanceMeters <= 180.0 {
            switch maneuverType {
            case 1, 2, 3: return "after_150m_turn_right"
            case -1, -2, -3: return "after_150m_turn_left"
            default: return nil
            }
        }

        if distanceMeters > 180.0 && distanceMeters <= 235.0 {
            switch maneuverType {
            case 1, 2, 3: return "after_200m_turn_right"
            case -1, -2, -3: return "after_200m_turn_left"
            default: return nil
            }
        }

        if distanceMeters > 235.0 && distanceMeters <= 350.0 {
            switch maneuverType {
            case 1, 2, 3: return "after_300m_turn_right"
            case -1, -2, -3: return "after_300m_turn_left"
            case 6, -6: return "after_300m_roundabout"
            default: return nil
            }
        }

        if distanceMeters > 350.0 && distanceMeters <= 650.0 {
            switch maneuverType {
            case 1, 2, 3: return "after_500m_turn_right"
            case -1, -2, -3: return "after_500m_turn_left"
            case 6, -6: return "after_500m_roundabout"
            case 4, 5: return "after_500m_exit"
            default: return nil
            }
        }

        if distanceMeters > 650.0 && distanceMeters <= 1200.0 {
            switch maneuverType {
            case 1, 2, 3: return "after_1km_turn_right"
            case -1, -2, -3: return "after_1km_turn_left"
            case 4, 5: return "after_1km_exit"
            default: return nil
            }
        }

        return nil
    }

    private func resolveImmediatePrompt(maneuverType: Int, exitNumber: Int?) -> String {
        switch maneuverType {
        case 1, 2, 3: return "turn_right_now"
        case -1, -2, -3: return "turn_left_now"
        case 8, -8, -98: return "u_turn_now"
        case 4, 5: return "take_exit_now"
        case 6, -6:
            if let exit = exitNumber, exit >= 1 && exit <= 6 {
                return "roundabout_exit_\(exit)"
            } else {
                return "enter_roundabout_now"
            }
        default: return "straight_through_intersection"
        }
    }

    public func handleInstruction(maneuverType: Int, distanceMeters: Double, priority: Int = 2, exitNumber: Int? = nil) {
        guard let promptId = resolvePromptId(
            maneuverType: maneuverType,
            distanceMeters: distanceMeters,
            priority: priority,
            exitNumber: exitNumber
        ) else { return }

        if promptId != lastPlayedPromptId {
            lastPlayedPromptId = promptId
            playPrompt(id: promptId)
        }
    }

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
