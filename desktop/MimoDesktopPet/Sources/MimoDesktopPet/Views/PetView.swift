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
            if visible.count > 1 {
                BubbleClusterGuide(visibleCount: visible.count)
                    .stroke(
                        Color(red: 0.35, green: 0.56, blue: 0.82).opacity(0.18),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .frame(
                        width: CGFloat(PetSpeechBubbleLayout.productionStackWidth),
                        height: CGFloat(PetSpeechBubbleLayout.productionStackHeight)
                    )
                    .zIndex(0)
            }

            ForEach(Array(visible.enumerated()), id: \.element.id) { index, bubble in
                let placement = PetSpeechBubbleLayout.placement(
                    for: index,
                    role: bubble.role,
                    visibleCount: visible.count
                )
                BubbleView(
                    text: bubble.text,
                    role: bubble.role,
                    tone: bubble.tone,
                    showsTail: index == 0,
                    maxTextWidth: placement.maxTextWidth,
                    fillOpacity: placement.fillOpacity,
                    accentColor: BubbleAccentPalette.color(for: index, role: bubble.role, tone: bubble.tone)
                )
                .scaleEffect(CGFloat(placement.scale), anchor: .center)
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

private struct BubbleClusterGuide: Shape {
    let visibleCount: Int

    func path(in rect: CGRect) -> Path {
        let count = max(1, min(visibleCount, PetSpeechBubbleLayout.productionVisibleLimit))
        var path = Path()
        guard count > 1 else { return path }

        let primaryAnchor = CGPoint(x: rect.midX, y: rect.maxY - 24)
        for index in 1..<count {
            let placement = PetSpeechBubbleLayout.placement(
                for: index,
                role: .conversation,
                visibleCount: count
            )
            let secondaryAnchor = CGPoint(
                x: rect.midX + CGFloat(placement.horizontalOffset),
                y: rect.maxY - 24 + CGFloat(placement.verticalOffset)
            )
            let control = CGPoint(
                x: (primaryAnchor.x + secondaryAnchor.x) / 2,
                y: min(primaryAnchor.y, secondaryAnchor.y) - 12
            )
            path.move(to: primaryAnchor)
            path.addQuadCurve(to: secondaryAnchor, control: control)
        }
        return path
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
    var tone: PetSpeechBubbleTone = .neutral
    var showsTail = true
    var maxTextWidth: Double?
    var fillOpacity: Double?
    var accentColor: Color?

    var body: some View {
        let resolvedFillOpacity = fillOpacity ?? defaultFillOpacity
        let accent = accentColor ?? Color(red: 0.36, green: 0.58, blue: 0.86)
        let bubbleFill = Color.white
        let borderColor = role == .status && tone == .neutral ? Color.black.opacity(0.1) : accent.opacity(borderOpacity)

        VStack(spacing: 0) {
            HStack(spacing: leadingMarkerSpacing) {
                if showsStateMarker {
                    BubbleStateMarker(role: role, tone: tone, accentColor: accent)
                }

                BubbleTextContent(
                    text: text,
                    role: role,
                    accentColor: accent,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    minimumScaleFactor: minimumScaleFactor
                )
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(
                minWidth: role == .overflow ? 158 : nil,
                maxWidth: CGFloat(maxTextWidth ?? defaultMaxTextWidth)
            )
            .background(bubbleFill.opacity(resolvedFillOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: role == .focus ? 1.4 : (role == .status ? 1 : 1.2))
            )
            .shadow(color: Color.black.opacity(role == .overflow ? 0.07 : 0.1), radius: role == .overflow ? 3 : 5, x: 0, y: 2)

            if showsTail {
                BubbleTail()
                    .fill(bubbleFill.opacity(resolvedFillOpacity))
                    .frame(width: 18, height: 9)
                    .offset(y: -1)
                    .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
            }
        }
    }

    private var defaultFillOpacity: Double {
        switch role {
        case .status, .focus:
            return 0.94
        case .conversation:
            return 0.88
        case .overflow:
            return 0.9
        }
    }

    private var borderOpacity: Double {
        switch role {
        case .status:
            return 0.1
        case .focus:
            return 0.38
        case .conversation:
            return 0.28
        case .overflow:
            return 0.34
        }
    }

    private var leadingMarkerSpacing: CGFloat {
        guard showsStateMarker else { return 0 }
        switch role {
        case .status:
            return 7
        case .focus:
            return 8
        case .conversation, .overflow:
            return 7
        }
    }

    private var fontSize: CGFloat {
        switch role {
        case .status, .focus:
            return 13
        case .conversation:
            return 12
        case .overflow:
            return 11.5
        }
    }

    private var fontWeight: Font.Weight {
        switch role {
        case .status, .focus, .conversation, .overflow:
            return .medium
        }
    }

    private var minimumScaleFactor: CGFloat {
        switch role {
        case .status, .focus:
            return 0.9
        case .conversation:
            return 0.82
        case .overflow:
            return 0.86
        }
    }

    private var horizontalPadding: CGFloat {
        switch role {
        case .status:
            return 12
        case .focus:
            return 11
        case .conversation:
            return 10
        case .overflow:
            return 9
        }
    }

    private var verticalPadding: CGFloat {
        switch role {
        case .status, .focus:
            return 8
        case .conversation:
            return 7
        case .overflow:
            return 6
        }
    }

    private var defaultMaxTextWidth: Double {
        switch role {
        case .status, .focus:
            return 284
        case .conversation:
            return 252
        case .overflow:
            return 176
        }
    }

    private var showsStateMarker: Bool {
        switch role {
        case .status:
            return tone != .neutral
        case .focus, .conversation, .overflow:
            return true
        }
    }
}

private struct BubbleTextContent: View {
    let text: String
    let role: PetSpeechBubbleRole
    let accentColor: Color
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let minimumScaleFactor: CGFloat

    var body: some View {
        let parts = PetSpeechBubbleTextParts.parse(text)

        if role != .status, let threadTitle = parts.threadTitle {
            VStack(alignment: .leading, spacing: role == .focus ? 2 : 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if role == .focus, let prefix = parts.prefix {
                        Text(prefix)
                            .font(.system(size: titleFontSize - 0.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                    }

                    Text(threadTitle)
                        .font(.system(size: titleFontSize, weight: .semibold))
                        .foregroundStyle(accentColor.opacity(0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .truncationMode(.tail)
                }

                Text(parts.summary)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundStyle(.primary)
                    .lineLimit(role == .focus ? 2 : 1)
                    .minimumScaleFactor(minimumScaleFactor)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
        } else {
            Text(text)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundStyle(.primary)
                .lineLimit(PetSpeechBubbleLayout.lineLimit(for: role))
                .minimumScaleFactor(minimumScaleFactor)
                .truncationMode(.tail)
                .multilineTextAlignment(role == .status ? .center : .leading)
        }
    }

    private var titleFontSize: CGFloat {
        switch role {
        case .focus:
            return 10.8
        case .conversation:
            return 9.8
        case .overflow:
            return 9.4
        case .status:
            return 10
        }
    }
}

private struct BubbleStateMarker: View {
    let role: PetSpeechBubbleRole
    let tone: PetSpeechBubbleTone
    let accentColor: Color

    @ViewBuilder
    var body: some View {
        switch role {
        case .focus:
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(accentColor.opacity(0.96))
                .frame(width: 20, height: 24)
                .overlay(markerImage.font(.system(size: 9.5, weight: .bold)))
        case .status:
            Circle()
                .fill(accentColor.opacity(0.94))
                .frame(width: 18, height: 18)
                .overlay(markerImage.font(.system(size: 8.5, weight: .bold)))
        case .conversation:
            Circle()
                .fill(accentColor.opacity(0.92))
                .frame(width: 14, height: 14)
                .overlay(markerImage.font(.system(size: 7.2, weight: .bold)))
        case .overflow:
            ZStack {
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(0.9))
                markerImage
                    .font(.system(size: 8.8, weight: .bold))
                    .offset(y: -0.5)
            }
            .frame(width: 18, height: 18)
        }
    }

    private var markerImage: some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.white)
    }

    private var symbolName: String {
        switch tone {
        case .failed:
            return "exclamationmark"
        case .waiting:
            return "hourglass"
        case .review:
            return "checkmark"
        case .active:
            return "ellipsis"
        case .overflow:
            return "plus"
        case .neutral:
            return "circle.fill"
        }
    }
}

private enum BubbleAccentPalette {
    static func color(for index: Int, role: PetSpeechBubbleRole, tone: PetSpeechBubbleTone) -> Color? {
        switch tone {
        case .failed:
            return Color(red: 0.78, green: 0.24, blue: 0.22)
        case .waiting:
            return Color(red: 0.82, green: 0.56, blue: 0.18)
        case .review:
            return Color(red: 0.16, green: 0.55, blue: 0.34)
        case .overflow:
            return Color(red: 0.42, green: 0.47, blue: 0.55)
        case .active, .neutral:
            break
        }
        guard role != .status else { return nil }
        if role == .focus {
            return Color(red: 0.24, green: 0.49, blue: 0.86)
        }
        if role == .overflow {
            return Color(red: 0.42, green: 0.47, blue: 0.55)
        }
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
