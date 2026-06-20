import SwiftUI

struct PetView: View {
    @ObservedObject var viewModel: PetViewModel
    let frameProvider: AtlasFrameImageProvider?

    var body: some View {
        VStack(spacing: 8) {
            BubbleView(text: viewModel.presentation.bubbleText)

            AnimatedPetSpriteView(
                animation: viewModel.presentation.animation,
                frameProvider: frameProvider
            )
            .frame(width: 192, height: 208)
        }
        .frame(width: 250, height: 300)
        .allowsHitTesting(false)
        .background(Color.clear)
    }
}

private struct BubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 220)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
    }
}
