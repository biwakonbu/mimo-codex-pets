import SwiftUI
import MimoDesktopPetCore

struct AnimatedPetSpriteView: View {
    let animation: PetAnimationState
    let frameProvider: AtlasFrameImageProvider?

    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()

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
        .onReceive(timer) { _ in
            frameIndex = (frameIndex + 1) % frameCount
        }
        .onChange(of: animation) {
            frameIndex = 0
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
