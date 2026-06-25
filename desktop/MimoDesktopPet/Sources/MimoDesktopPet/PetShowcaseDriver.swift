import Foundation
import MimoDesktopPetCore

@MainActor
final class PetShowcaseDriver {
    private let viewModel: PetViewModel
    private var task: Task<Void, Never>?
    private let durationScale: Double

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel
        durationScale = Self.environmentDouble("MIMO_SHOWCASE_DURATION_SCALE", default: 1.0)
    }

    func start() {
        stop()
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                for scene in PetShowcaseSequence.scenes {
                    guard !Task.isCancelled else { return }
                    viewModel.apply(showcaseScene: scene)
                    let duration = max(0.2, scene.duration * durationScale)
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private static func environmentDouble(_ key: String, default defaultValue: Double) -> Double {
        guard
            let raw = ProcessInfo.processInfo.environment[key],
            let value = Double(raw),
            value.isFinite,
            value > 0
        else {
            return defaultValue
        }
        return value
    }
}
