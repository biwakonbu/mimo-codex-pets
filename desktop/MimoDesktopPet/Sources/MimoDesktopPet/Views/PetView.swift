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
            .frame(
                width: CGFloat(PetSpeechBubbleLayout.productionSpriteWidth),
                height: CGFloat(PetSpeechBubbleLayout.productionSpriteHeight)
            )
        }
        .frame(
            width: CGFloat(PetSpeechBubbleLayout.productionWindowWidth),
            height: CGFloat(PetSpeechBubbleLayout.productionWindowHeight),
            alignment: .top
        )
        .background(Color.clear)
    }
}

private struct ProductionBubbleStackView: View {
    let bubbles: [PetSpeechBubble]

    var body: some View {
        let visible = Array(bubbles.prefix(PetSpeechBubbleLayout.productionVisibleLimit))

        ZStack(alignment: .bottom) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, bubble in
                let placement = PetSpeechBubbleLayout.placement(
                    for: index,
                    role: bubble.role,
                    visibleCount: visible.count
                )
                BubbleView(
                    text: bubble.text,
                    role: bubble.role,
                    showsTail: index == visible.count - 1,
                    maxTextWidth: placement.maxTextWidth,
                    fillOpacity: placement.fillOpacity,
                    accentColor: BubbleAccentPalette.color(for: index, role: bubble.role)
                )
                .offset(
                    x: CGFloat(placement.horizontalOffset),
                    y: CGFloat(placement.verticalOffset)
                )
                .zIndex(placement.zIndex)
            }
        }
        .frame(
            width: CGFloat(PetSpeechBubbleLayout.productionStackWidth),
            height: CGFloat(PetSpeechBubbleLayout.productionStackHeight),
            alignment: .bottom
        )
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
    var maxTextWidth: Double?
    var fillOpacity: Double?
    var accentColor: Color?

    var body: some View {
        let resolvedFillOpacity = fillOpacity ?? (role == .status ? 0.94 : 0.88)
        let accent = accentColor ?? Color(red: 0.36, green: 0.58, blue: 0.86)
        let bubbleFill = Color.white
        let borderColor = role == .status
            ? Color.black.opacity(0.1)
            : accent.opacity(0.28)

        VStack(spacing: 0) {
            HStack(spacing: role == .status ? 0 : 7) {
                if role == .conversation {
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.92))
                        .frame(width: 4, height: 18)
                }

                Text(text)
                    .font(.system(size: role == .status ? 13 : 12, weight: role == .status ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(PetSpeechBubbleLayout.lineLimit(for: role))
                    .minimumScaleFactor(role == .status ? 0.9 : 0.82)
                    .truncationMode(.tail)
                    .multilineTextAlignment(role == .status ? .center : .leading)
            }
            .padding(.horizontal, role == .status ? 12 : 10)
            .padding(.vertical, role == .status ? 8 : 7)
            .frame(maxWidth: CGFloat(maxTextWidth ?? (role == .status ? 284 : 252)))
            .background(bubbleFill.opacity(resolvedFillOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: role == .status ? 1 : 1.2)
            )
            .shadow(color: Color.black.opacity(role == .status ? 0.12 : 0.08), radius: role == .status ? 5 : 3, x: 0, y: 2)

            if showsTail {
                BubbleTail()
                    .fill(bubbleFill.opacity(resolvedFillOpacity))
                    .frame(width: 18, height: 9)
                    .offset(y: -1)
                    .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
            }
        }
    }
}

private enum BubbleAccentPalette {
    static func color(for index: Int, role: PetSpeechBubbleRole) -> Color? {
        guard role == .conversation else { return nil }
        let colors = [
            Color(red: 0.28, green: 0.52, blue: 0.86),
            Color(red: 0.14, green: 0.58, blue: 0.52),
            Color(red: 0.76, green: 0.42, blue: 0.24)
        ]
        return colors[max(0, index - 1) % colors.count]
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
