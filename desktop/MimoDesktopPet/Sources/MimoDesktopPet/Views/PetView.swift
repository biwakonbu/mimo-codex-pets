import SwiftUI
import MimoDesktopPetCore

struct PetView: View {
    @ObservedObject var viewModel: PetViewModel
    let frameProvider: AtlasFrameImageProvider?

    var body: some View {
        Group {
            if viewModel.debugOverlay {
                DebugPetView(viewModel: viewModel, frameProvider: frameProvider)
            } else {
                ProductionPetView(viewModel: viewModel, frameProvider: frameProvider)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ProductionPetView: View {
    @ObservedObject var viewModel: PetViewModel
    let frameProvider: AtlasFrameImageProvider?

    var body: some View {
        VStack(spacing: 0) {
            ProductionBubbleStackView(bubbles: viewModel.visibleBubbles)
                .padding(.top, 4)

            AnimatedPetSpriteView(
                animation: viewModel.presentation.animation,
                frameProvider: frameProvider
            )
            .frame(width: 192, height: 208)
        }
        .frame(width: 360, height: 350, alignment: .top)
        .background(Color.clear)
    }
}

private struct ProductionBubbleStackView: View {
    let bubbles: [PetSpeechBubble]

    var body: some View {
        VStack(spacing: -1) {
            ForEach(Array(bubbles.prefix(3).enumerated()), id: \.element.id) { index, bubble in
                BubbleView(
                    text: bubble.text,
                    role: bubble.role,
                    showsTail: index == min(bubbles.count, 3) - 1
                )
                .offset(x: horizontalOffset(for: index))
                .zIndex(Double(3 - index))
            }
        }
        .frame(width: 344, height: 136, alignment: .bottom)
    }

    private func horizontalOffset(for index: Int) -> CGFloat {
        switch index {
        case 0:
            return 0
        case 1:
            return -18
        default:
            return 16
        }
    }
}

private struct DebugPetView: View {
    @ObservedObject var viewModel: PetViewModel
    let frameProvider: AtlasFrameImageProvider?

    var body: some View {
        VStack(spacing: 10) {
            BubbleView(text: viewModel.presentation.bubbleText)

            AnimatedPetSpriteView(
                animation: viewModel.presentation.animation,
                frameProvider: frameProvider
            )
            .frame(width: 176, height: 190)

            ConversationFeedView(lines: viewModel.conversationLines)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 320, height: 430)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct BubbleView: View {
    let text: String
    var role: PetSpeechBubbleRole = .status
    var showsTail = true

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: role == .status ? 13 : 12, weight: role == .status ? .medium : .regular))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, role == .status ? 12 : 10)
                .padding(.vertical, role == .status ? 8 : 7)
                .frame(maxWidth: role == .status ? 284 : 252)
                .background(Color.white.opacity(role == .status ? 0.94 : 0.88), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(role == .status ? 0.14 : 0.1), radius: role == .status ? 8 : 6, x: 0, y: 3)

            if showsTail {
                BubbleTail()
                    .fill(Color.white.opacity(role == .status ? 0.94 : 0.88))
                    .frame(width: 18, height: 9)
                    .offset(y: -1)
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
            }
        }
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct ConversationFeedView: View {
    let lines: [CodexConversationLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.suffix(4).enumerated()), id: \.offset) { _, line in
                ConversationLineView(line: line)
            }
            if lines.isEmpty {
                Text("Codex の会話を待っています")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 292, height: 126, alignment: .topLeading)
        .padding(10)
        .background(Color(red: 0.985, green: 0.985, blue: 0.99), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ConversationLineView: View {
    let line: CodexConversationLine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(line.threadTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(line.speaker)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(line.isAssistant ? Color.blue : Color.green)
                    .lineLimit(1)
            }

            Text(line.text)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
