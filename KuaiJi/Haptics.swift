//
//  Haptics.swift
//  KuaiJi
//
//  Centralized haptics with safe fallbacks for Simulator / unsupported devices.
//

import UIKit
import AudioToolbox
import CoreHaptics

enum Haptics {
    static func success() {
        if supportsHaptics {
            let g = UINotificationFeedbackGenerator()
            g.notificationOccurred(.success)
        } else {
            vibrateLegacy()
        }
    }

    static func lightImpact() {
        if supportsHaptics {
            let g = UIImpactFeedbackGenerator(style: .light)
            g.impactOccurred()
        } else {
            // no-op on unsupported devices
        }
    }

    static func vibrate() {
        if supportsHaptics {
            let g = UINotificationFeedbackGenerator()
            g.notificationOccurred(.success)
        } else {
            vibrateLegacy()
        }
    }

    // MARK: - Helpers

    private static var supportsHaptics: Bool {
        if #available(iOS 13.0, *) {
            return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        } else {
            return false
        }
    }

    private static func vibrateLegacy() {
        #if !targetEnvironment(simulator)
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        #endif
    }
}


