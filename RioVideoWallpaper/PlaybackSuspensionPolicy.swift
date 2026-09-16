//
//  PlaybackSuspensionPolicy.swift
//  RioVideoWallpaper
//

import Foundation

struct PlaybackSuspensionPolicy {
    struct ScreenSnapshot: Equatable {
        var width: Double
        var height: Double
        var x: Double = 0
        var y: Double = 0
        var displayID: String = ""

        var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    }

    struct WindowSnapshot: Equatable {
        var ownerPID: pid_t
        var layer: Int
        var width: Double
        var height: Double
        var x: Double = 0
        var y: Double = 0
        var alpha: Double = 1

        var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    }

    static func shouldSuspend(
        screensAreSleeping: Bool,
        frontmostPID: pid_t?,
        currentPID: pid_t,
        windows: [WindowSnapshot],
        screens: [ScreenSnapshot],
        sizeTolerance: Double = 2.0
    ) -> Bool {
        screensAreSleeping || (!screens.isEmpty && screens.allSatisfy { screen in
            frontmostAppCoversAnyScreen(
                frontmostPID: frontmostPID,
                currentPID: currentPID,
                windows: windows,
                screens: [screen],
                sizeTolerance: sizeTolerance
            )
        })
    }

    static func coveredDisplayIDs(
        frontmostPID: pid_t?,
        currentPID: pid_t,
        windows: [WindowSnapshot],
        screens: [ScreenSnapshot]
    ) -> Set<String> {
        Set(screens.filter {
            frontmostAppCoversAnyScreen(
                frontmostPID: frontmostPID,
                currentPID: currentPID,
                windows: windows,
                screens: [$0]
            )
        }.map(\.displayID))
    }

    static func suspendedVideoURLs(
        videoURLByDisplayID: [String: URL],
        coveredDisplayIDs: Set<String>,
        screensAreSleeping: Bool
    ) -> Set<URL> {
        let allURLs = Set(videoURLByDisplayID.values)
        guard !screensAreSleeping else { return allURLs }
        let visibleURLs = Set(videoURLByDisplayID.filter {
            !coveredDisplayIDs.contains($0.key)
        }.values)
        return allURLs.subtracting(visibleURLs)
    }

    static func frontmostAppCoversAnyScreen(
        frontmostPID: pid_t?,
        currentPID: pid_t,
        windows: [WindowSnapshot],
        screens: [ScreenSnapshot],
        sizeTolerance: Double = 2.0
    ) -> Bool {
        guard let frontmostPID, frontmostPID != currentPID else {
            return false
        }

        return windows.contains { window in
            guard window.ownerPID == frontmostPID, window.layer == 0, window.alpha >= 0.99 else {
                return false
            }

            return screens.contains { screen in
                window.frame.insetBy(dx: -sizeTolerance, dy: -sizeTolerance).contains(screen.frame)
            }
        }
    }
}
