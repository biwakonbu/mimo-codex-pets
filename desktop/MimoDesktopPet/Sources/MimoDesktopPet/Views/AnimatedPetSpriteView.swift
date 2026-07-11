import SwiftUI
import MimoDesktopPetCore

struct AnimatedPetSpriteView: View {
    let animation: PetAnimationState
    let frameProvider: AtlasFrameImageProvider?
    let onFrameChanged: (PetAnimationState, Int) -> Void

    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.36, on: .main, in: .common).autoconnect()

    init(
        animation: PetAnimationState,
        frameProvider: AtlasFrameImageProvider?,
        onFrameChanged: @escaping (PetAnimationState, Int) -> Void = { _, _ in }
    ) {
        self.animation = animation
        self.frameProvider = frameProvider
        self.onFrameChanged = onFrameChanged
    }

    var body: some View {
        Group {
            if let image = frameProvider?.image(for: animation, frame: frameIndex % frameCount) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .accessibilityLabel("Mimo")
            } else {
                fallbackView
            }
        }
        .onAppear {
            onFrameChanged(animation, frameIndex % frameCount)
        }
        .onReceive(timer) { _ in
            let nextFrame = (frameIndex + 1) % frameCount
            frameIndex = nextFrame
            onFrameChanged(animation, nextFrame)
        }
        .onChange(of: animation) {
            frameIndex = 0
            onFrameChanged(animation, 0)
        }
    }

    private var frameCount: Int {
        PetAtlasContract.spec(for: animation).frameCount
    }

    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
            Text("Mimo")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
