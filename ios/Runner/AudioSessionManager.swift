import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private init() {}
    
    /// Configurer la session audio pour les appels
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.voiceChat, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ [iOS Audio] Error setting up audio session: \(error.localizedDescription)")
        }
    }
    
    /// Basculer le haut-parleur On/Off
    /// - Parameter enabled: true pour activer le haut-parleur, false pour l'écouteur
    func setSpeaker(enabled: Bool) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            if enabled {
                // Activer le haut-parleur
                try audioSession.overrideOutputAudioPort(.speaker)
                print("✅ [iOS Audio] Speaker ON")
            } else {
                // Revenir à l'écouteur interne
                try audioSession.overrideOutputAudioPort(.none)
                print("✅ [iOS Audio] Speaker OFF (Earpiece)")
            }
        } catch {
            print("❌ [iOS Audio] Error setting speaker: \(error.localizedDescription)")
        }
    }
}
