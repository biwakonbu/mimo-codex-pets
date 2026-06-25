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
                .padding(.top, CGFloat(PetSpeechBubbleLayout.productionTopPadding))

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
    @State private var previousVisibleIDs: [String] = []
    @State private var birthPulseVisible = false
    @State private var birthPulseGeneration = 0

    var body: some View {
        let visible = Array(bubbles.prefix(PetSpeechBubbleLayout.productionVisibleLimit))
        let stackSignature = visible.map { "\($0.id)|\($0.role.rawValue)|\($0.tone.rawValue)|\($0.activityKind?.rawValue ?? "none")|\($0.text)" }.joined(separator: "\n")

        ZStack(alignment: .bottom) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, bubble in
                let placement = PetSpeechBubbleLayout.placement(
                    for: index,
                    role: bubble.role,
                    visibleCount: visible.count,
                    variationSeed: visualSeed(for: bubble)
                )
                BubbleView(
                    text: bubble.text,
                    role: bubble.role,
                    tone: bubble.tone,
                    activityKind: bubble.activityKind,
                    showsTail: index == 0,
                    minTextWidth: placement.minTextWidth,
                    maxTextWidth: placement.maxTextWidth,
                    fillOpacity: placement.fillOpacity,
                    fontScale: placement.fontScale,
                    tailHorizontalOffset: placement.tailHorizontalOffset,
                    accentColor: BubbleAccentPalette.color(for: index, role: bubble.role, tone: bubble.tone),
                    accessibilityIndex: index
                )
                .scaleEffect(CGFloat(placement.scale), anchor: .center)
                .rotationEffect(.degrees(placement.rotationDegrees), anchor: .center)
                .offset(
                    x: CGFloat(placement.horizontalOffset),
                    y: CGFloat(placement.verticalOffset)
                )
                .zIndex(placement.zIndex)
                .transition(ProductionBubbleMotion.transition(for: index, visibleCount: visible.count))
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.verticalOffset)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.horizontalOffset)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.scale)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.fontScale)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.rotationDegrees)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: stackSignature)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: visible.count)
            }
        }
        .overlay(alignment: .bottom) {
            BubbleBirthPulseView(isVisible: birthPulseVisible)
                .id(birthPulseGeneration)
                .offset(y: CGFloat(PetSpeechBubbleLayout.birthPulseOffsetY))
                .allowsHitTesting(false)
        }
        .frame(
            width: CGFloat(PetSpeechBubbleLayout.productionStackWidth),
            height: CGFloat(PetSpeechBubbleLayout.productionStackHeight),
            alignment: .bottom
        )
        .onAppear {
            previousVisibleIDs = visible.map(\.id)
        }
        .onChange(of: stackSignature) {
            updateBirthPulse(nextIDs: visible.map(\.id))
        }
    }

    private func updateBirthPulse(nextIDs: [String]) {
        let shouldPulse = PetSpeechBubbleMotionPolicy.shouldTriggerBirthPulse(
            previousIDs: previousVisibleIDs,
            nextIDs: nextIDs
        )
        previousVisibleIDs = nextIDs
        guard shouldPulse else { return }
        triggerBirthPulse()
    }

    private func triggerBirthPulse() {
        birthPulseGeneration += 1
        let generation = birthPulseGeneration
        birthPulseVisible = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000)
            withAnimation(.spring(
                response: PetSpeechBubbleLayout.birthPulseSpringResponse,
                dampingFraction: PetSpeechBubbleLayout.birthPulseSpringDampingFraction,
                blendDuration: 0.05
            )) {
                birthPulseVisible = true
            }
            try? await Task.sleep(nanoseconds: UInt64(PetSpeechBubbleLayout.birthPulseDuration * 1_000_000_000))
            guard birthPulseGeneration == generation else { return }
            withAnimation(.easeOut(duration: PetSpeechBubbleLayout.birthPulseFadeOutDuration)) {
                birthPulseVisible = false
            }
        }
    }

    private func visualSeed(for bubble: PetSpeechBubble) -> String {
        let parts = PetSpeechBubbleTextParts.parse(bubble.text)
        if let threadTitle = parts.threadTitle {
            return "\(bubble.role.rawValue)|\(threadTitle)"
        }
        return "\(bubble.role.rawValue)|\(bubble.tone.rawValue)|\(bubble.id)"
    }
}

private enum ProductionBubbleMotion {
    static func stackAnimation(for index: Int) -> Animation {
        let timing = PetSpeechBubbleMotionTiming.stackTiming(for: index)
        return Animation.spring(
            response: timing.response,
            dampingFraction: timing.dampingFraction,
            blendDuration: 0.1
        )
        .delay(timing.delay)
    }

    static let contentAnimation = Animation.easeInOut(
        duration: PetSpeechBubbleLayout.contentAnimationDuration
    )

    static func transition(for index: Int, visibleCount: Int) -> AnyTransition {
        let insertionScale = PetSpeechBubbleLayout.transitionInsertionScale
        let insertionOffset = PetSpeechBubbleLayout.transitionInsertionOffsetY
        let removalOffset = PetSpeechBubbleLayout.transitionRemovalOffsetY

        return .asymmetric(
            insertion: .modifier(
                active: BubbleBirthTransitionModifier(
                    opacity: 0,
                    scale: insertionScale,
                    yOffset: insertionOffset,
                    blurRadius: 2.4
                ),
                identity: BubbleBirthTransitionModifier(
                    opacity: 1,
                    scale: 1,
                    yOffset: 0,
                    blurRadius: 0
                )
            ),
            removal: .modifier(
                active: BubbleBirthTransitionModifier(
                    opacity: 0,
                    scale: PetSpeechBubbleLayout.transitionRemovalScale,
                    yOffset: removalOffset,
                    blurRadius: 1.6
                ),
                identity: BubbleBirthTransitionModifier(
                    opacity: 1,
                    scale: 1,
                    yOffset: 0,
                    blurRadius: 0
                )
            )
        )
    }

    static var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 3)),
            removal: .opacity.combined(with: .offset(y: -3))
        )
    }
}

private struct BubbleBirthTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: Double
    let yOffset: Double
    let blurRadius: Double

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(CGFloat(scale), anchor: .bottom)
            .offset(y: CGFloat(yOffset))
            .blur(radius: CGFloat(blurRadius))
    }
}

private struct BubbleBirthPulseView: View {
    let isVisible: Bool

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(isVisible ? 0.68 : 0), lineWidth: 1.35)
                .frame(
                    width: CGFloat(PetSpeechBubbleLayout.birthPulseWidth),
                    height: CGFloat(PetSpeechBubbleLayout.birthPulseHeight)
                )
                .scaleEffect(
                    x: isVisible ? 1.0 : 0.36,
                    y: isVisible ? 0.9 : 0.34,
                    anchor: .center
                )

            Capsule(style: .continuous)
                .stroke(Color(red: 0.58, green: 0.78, blue: 1.0).opacity(isVisible ? 0.42 : 0), lineWidth: 1.0)
                .frame(
                    width: CGFloat(PetSpeechBubbleLayout.birthPulseWidth + 20),
                    height: CGFloat(PetSpeechBubbleLayout.birthPulseHeight + 8)
                )
                .scaleEffect(isVisible ? 1.14 : 0.48, anchor: .center)

            Capsule(style: .continuous)
                .stroke(Color(red: 0.9, green: 0.97, blue: 1.0).opacity(isVisible ? 0.24 : 0), lineWidth: 0.8)
                .frame(
                    width: CGFloat(PetSpeechBubbleLayout.birthPulseWidth + 38),
                    height: CGFloat(PetSpeechBubbleLayout.birthPulseHeight + 14)
                )
                .scaleEffect(isVisible ? 1.2 : 0.54, anchor: .center)
        }
        .opacity(isVisible ? 1 : 0)
        .blur(radius: isVisible ? 0 : 0.8)
        .animation(.easeOut(duration: PetSpeechBubbleLayout.birthPulseDuration * 0.9), value: isVisible)
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
    var activityKind: CodexConversationActivityKind?
    var showsTail = true
    var minTextWidth: Double?
    var maxTextWidth: Double?
    var fillOpacity: Double?
    var fontScale: Double = 1
    var tailHorizontalOffset: Double = 0
    var accentColor: Color?
    var accessibilityIndex: Int?

    var body: some View {
        let resolvedFillOpacity = fillOpacity ?? defaultFillOpacity
        let accent = accentColor ?? Color(red: 0.36, green: 0.58, blue: 0.86)
        let cornerRadius = bubbleCornerRadius
        let bubbleShape = BubbleBodyShape(cornerRadius: cornerRadius, waviness: bubbleWaviness)
        let tailFill = Color.white
        let borderColor = role == .status && tone == .neutral
            ? Color(red: 0.54, green: 0.67, blue: 0.88).opacity(0.24)
            : accent.opacity(borderOpacity)
        let glowColor = Color(red: 0.48, green: 0.64, blue: 0.92)
        let resolvedFontScale = CGFloat(fontScale)
        let textIdentity = "\(role.rawValue)|\(tone.rawValue)|\(activityKind?.rawValue ?? "none")|\(text)"

        VStack(spacing: 0) {
            HStack(spacing: leadingMarkerSpacing) {
                if showsStateMarker {
                    BubbleStateMarker(
                        role: role,
                        tone: tone,
                        activityKind: activityKind,
                        accentColor: accent
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.86, anchor: .center)))
                }

                ZStack(alignment: .leading) {
                    TypewriterBubbleTextContent(
                        text: text,
                        role: role,
                        accentColor: accent,
                        fontSize: fontSize * resolvedFontScale,
                        fontWeight: fontWeight,
                        minimumScaleFactor: minimumScaleFactor,
                        fontScale: resolvedFontScale
                    )
                    .id(textIdentity)
                    .transition(ProductionBubbleMotion.contentTransition)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(ProductionBubbleMotion.contentAnimation, value: textIdentity)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(
                minWidth: resolvedMinTextWidth.map { CGFloat($0) },
                maxWidth: CGFloat(maxTextWidth ?? defaultMaxTextWidth),
                alignment: .leading
            )
            .background(
                bubbleShape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(resolvedFillOpacity),
                                Color(red: 0.985, green: 0.996, blue: 1.0).opacity(resolvedFillOpacity),
                                Color(red: 0.935, green: 0.972, blue: 1.0).opacity(resolvedFillOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .bottomTrailing) {
                if showsDecorativePips {
                    BubbleDecorativePips(color: accent, count: decorativePipCount)
                        .padding(.trailing, decorativePipsTrailingPadding)
                        .padding(.bottom, decorativePipsBottomPadding)
                }
            }
            .overlay(
                bubbleShape
                    .strokeBorder(Color.white.opacity(isPrimaryBubble ? 0.92 : 0.78), lineWidth: isPrimaryBubble ? 1.2 : 0.8)
                    .padding(isPrimaryBubble ? 2 : 1.2)
            )
            .overlay(
                bubbleShape
                    .strokeBorder(borderColor, lineWidth: isPrimaryBubble ? 1.5 : 1.0)
            )
            .shadow(color: glowColor.opacity(isPrimaryBubble ? 0.14 : 0.075), radius: isPrimaryBubble ? 6 : 3.2, x: 0, y: isPrimaryBubble ? 2 : 1)
            .shadow(color: Color.black.opacity(isPrimaryBubble ? 0.065 : 0.035), radius: isPrimaryBubble ? 4 : 2.2, x: 0, y: isPrimaryBubble ? 2 : 1.0)

            if showsTail {
                BubbleTail()
                    .fill(tailFill.opacity(resolvedFillOpacity))
                    .overlay(
                        BubbleTailSideBorder()
                            .stroke(
                                borderColor.opacity(0.78),
                                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                            )
                    )
                    .frame(width: tailWidth, height: tailHeight)
                    .offset(x: CGFloat(tailHorizontalOffset), y: -1)
                    .shadow(color: glowColor.opacity(0.08), radius: 2, x: 0, y: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(text)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilitySortPriority(accessibilitySortPriority)
        .animation(ProductionBubbleMotion.contentAnimation, value: tone)
        .animation(ProductionBubbleMotion.contentAnimation, value: activityKind?.rawValue ?? "none")
    }

    private var accessibilityIdentifier: String {
        if let accessibilityIndex {
            return PetSpeechBubbleAccessibility.bubbleIdentifier(index: accessibilityIndex, role: role)
        }
        return "\(PetSpeechBubbleAccessibility.identifier).bubble.debug.\(role.rawValue)"
    }

    private var accessibilityLabel: String {
        if let accessibilityIndex {
            return PetSpeechBubbleAccessibility.bubbleElementLabel(index: accessibilityIndex, role: role, text: text)
        }
        return "Mimo speech bubble: \(text)"
    }

    private var accessibilitySortPriority: Double {
        guard let accessibilityIndex else { return 0 }
        return PetSpeechBubbleAccessibility.bubbleSortPriority(index: accessibilityIndex)
    }

    private var defaultFillOpacity: Double {
        switch role {
        case .status, .focus:
            return 0.97
        case .conversation:
            return 0.92
        case .overflow:
            return 0.9
        }
    }

    private var borderOpacity: Double {
        switch role {
        case .status:
            return 0.18
        case .focus:
            return 0.24
        case .conversation:
            return 0.16
        case .overflow:
            return 0.18
        }
    }

    private var leadingMarkerSpacing: CGFloat {
        guard showsStateMarker else { return 0 }
        switch role {
        case .status:
            return 10
        case .focus:
            return 11
        case .conversation, .overflow:
            return 7
        }
    }

    private var fontSize: CGFloat {
        switch role {
        case .status, .focus:
            return 14.2
        case .conversation:
            return 11.4
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
            return 20
        case .focus:
            return 20
        case .conversation:
            return 11
        case .overflow:
            return 10
        }
    }

    private var verticalPadding: CGFloat {
        switch role {
        case .status, .focus:
            return 15
        case .conversation:
            return 8
        case .overflow:
            return 7
        }
    }

    private var defaultMaxTextWidth: Double {
        switch role {
        case .status, .focus:
            return 360
        case .conversation:
            return 214
        case .overflow:
            return 188
        }
    }

    private var resolvedMinTextWidth: Double? {
        if let minTextWidth {
            return minTextWidth
        }
        switch role {
        case .status:
            return 292
        case .focus:
            return 300
        case .conversation:
            return 190
        case .overflow:
            return 156
        }
    }

    private var bubbleCornerRadius: CGFloat {
        switch role {
        case .focus:
            return 25
        case .status:
            return 23
        case .conversation:
            return 14
        case .overflow:
            return 13
        }
    }

    private var bubbleWaviness: CGFloat {
        switch role {
        case .status, .focus:
            return 1.0
        case .conversation:
            return 0.72
        case .overflow:
            return 0.58
        }
    }

    private var showsDecorativePips: Bool {
        switch role {
        case .status:
            return tone != .neutral
        case .focus:
            return false
        case .conversation, .overflow:
            return true
        }
    }

    private var decorativePipCount: Int {
        role == .overflow ? 2 : 3
    }

    private var decorativePipsTrailingPadding: CGFloat {
        switch role {
        case .conversation:
            return 12
        case .overflow:
            return 10
        case .status, .focus:
            return 14
        }
    }

    private var decorativePipsBottomPadding: CGFloat {
        switch role {
        case .conversation:
            return 8
        case .overflow:
            return 7
        case .status, .focus:
            return 10
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

    private var isPrimaryBubble: Bool {
        role == .status || role == .focus
    }

    private var tailWidth: CGFloat {
        isPrimaryBubble ? 40 : 26
    }

    private var tailHeight: CGFloat {
        isPrimaryBubble ? 18 : 12
    }
}

private struct BubbleBodyShape: InsettableShape {
    var cornerRadius: CGFloat
    var waviness: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let width = rect.width
        let height = rect.height
        let radius = min(cornerRadius, min(width, height) * 0.42)
        let wave = min(max(waviness, 0), 1.4)
        let topLift = 2.0 * wave
        let sideWave = 4.2 * wave
        let bottomDrop = 3.6 * wave

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius * 1.05, y: rect.minY + topLift))
        path.addCurve(
            to: CGPoint(x: rect.midX - width * 0.12, y: rect.minY + topLift * 0.15),
            control1: CGPoint(x: rect.minX + width * 0.22, y: rect.minY - topLift * 0.35),
            control2: CGPoint(x: rect.midX - width * 0.28, y: rect.minY + topLift * 0.45)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - radius * 1.04, y: rect.minY + topLift),
            control1: CGPoint(x: rect.midX + width * 0.14, y: rect.minY - topLift * 0.45),
            control2: CGPoint(x: rect.maxX - width * 0.24, y: rect.minY + topLift * 0.45)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - sideWave, y: rect.midY),
            control1: CGPoint(x: rect.maxX - radius * 0.24, y: rect.minY + radius * 0.1),
            control2: CGPoint(x: rect.maxX + sideWave * 0.36, y: rect.midY - height * 0.25)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - radius * 0.92, y: rect.maxY - radius * 0.32),
            control1: CGPoint(x: rect.maxX + sideWave * 0.22, y: rect.midY + height * 0.22),
            control2: CGPoint(x: rect.maxX - radius * 0.12, y: rect.maxY - radius * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX + width * 0.12, y: rect.maxY - bottomDrop),
            control1: CGPoint(x: rect.maxX - width * 0.22, y: rect.maxY + bottomDrop * 0.3),
            control2: CGPoint(x: rect.midX + width * 0.28, y: rect.maxY - bottomDrop * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + radius * 0.94, y: rect.maxY - radius * 0.28),
            control1: CGPoint(x: rect.midX - width * 0.15, y: rect.maxY + bottomDrop * 0.28),
            control2: CGPoint(x: rect.minX + width * 0.23, y: rect.maxY - bottomDrop * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + sideWave, y: rect.midY),
            control1: CGPoint(x: rect.minX + radius * 0.12, y: rect.maxY - radius * 0.06),
            control2: CGPoint(x: rect.minX - sideWave * 0.3, y: rect.midY + height * 0.24)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + radius * 1.05, y: rect.minY + topLift),
            control1: CGPoint(x: rect.minX - sideWave * 0.22, y: rect.midY - height * 0.24),
            control2: CGPoint(x: rect.minX + radius * 0.18, y: rect.minY + radius * 0.1)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> BubbleBodyShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

private struct BubbleDecorativePips: View {
    let color: Color
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(0, count), id: \.self) { index in
                Circle()
                    .fill(color.opacity(index == 0 ? 0.58 : 0.44))
                    .frame(width: 5, height: 5)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TypewriterBubbleTextContent: View {
    let text: String
    let role: PetSpeechBubbleRole
    let accentColor: Color
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let minimumScaleFactor: CGFloat
    let fontScale: CGFloat

    @State private var visibleText = ""
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        BubbleTextContent(
            text: resolvedVisibleText,
            role: role,
            accentColor: accentColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            minimumScaleFactor: minimumScaleFactor,
            fontScale: fontScale
        )
        .onAppear(perform: restartAnimation)
        .onChange(of: text) { _, _ in restartAnimation() }
        .onChange(of: role) { _, _ in restartAnimation() }
        .onDisappear(perform: cancelAnimation)
    }

    private var resolvedVisibleText: String {
        guard shouldTypewrite else { return text }
        if visibleText.isEmpty {
            return PetSpeechBubbleTypewriter.visibleBubbleText(for: text, role: role, elapsed: 0)
        }
        return visibleText
    }

    private var shouldTypewrite: Bool {
        role != .overflow && !text.isEmpty
    }

    private func restartAnimation() {
        cancelAnimation()
        guard shouldTypewrite else {
            visibleText = text
            return
        }

        let fullText = text
        let bubbleRole = role
        let frameInterval = PetSpeechBubbleLayout.typewriterFrameInterval
        let stepNanoseconds = UInt64(frameInterval * 1_000_000_000)
        let duration = PetSpeechBubbleTypewriter.durationForBubbleText(for: fullText, role: bubbleRole)

        visibleText = PetSpeechBubbleTypewriter.visibleBubbleText(
            for: fullText,
            role: bubbleRole,
            elapsed: 0
        )
        animationTask = Task { @MainActor in
            let startedAt = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed >= duration {
                    visibleText = fullText
                    break
                }

                visibleText = PetSpeechBubbleTypewriter.visibleBubbleText(
                    for: fullText,
                    role: bubbleRole,
                    elapsed: elapsed
                )

                do {
                    try await Task.sleep(nanoseconds: stepNanoseconds)
                } catch {
                    break
                }
            }
        }
    }

    private func cancelAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

private struct BubbleTextContent: View {
    let text: String
    let role: PetSpeechBubbleRole
    let accentColor: Color
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let minimumScaleFactor: CGFloat
    let fontScale: CGFloat

    var body: some View {
        let parts = PetSpeechBubbleTextParts.parse(text)

        if role == .focus, let threadTitle = parts.threadTitle {
            VStack(alignment: .leading, spacing: role == .focus ? 2 : 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if let prefix = parts.prefix {
                        Text(prefix)
                            .font(.system(size: titleFontSize * fontScale - 0.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                    }

                    Text(threadTitle)
                        .font(.system(size: titleFontSize * fontScale, weight: .semibold))
                        .foregroundStyle(accentColor.opacity(0.96))
                        .lineLimit(PetSpeechBubbleLayout.titleLineLimit(for: role))
                        .minimumScaleFactor(0.82)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(parts.summary)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundStyle(.primary)
                    .lineLimit(PetSpeechBubbleLayout.summaryLineLimit(for: role))
                    .minimumScaleFactor(minimumScaleFactor)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if role == .conversation, let threadTitle = parts.threadTitle {
            VStack(alignment: .leading, spacing: 2) {
                Text(threadTitle)
                    .font(.system(size: titleFontSize * fontScale, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.96))
                    .lineLimit(PetSpeechBubbleLayout.titleLineLimit(for: role))
                    .minimumScaleFactor(0.82)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(parts.summary)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundStyle(.primary)
                    .lineLimit(PetSpeechBubbleLayout.summaryLineLimit(for: role))
                    .minimumScaleFactor(minimumScaleFactor)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(text)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundStyle(.primary)
                .lineLimit(PetSpeechBubbleLayout.lineLimit(for: role))
                .minimumScaleFactor(minimumScaleFactor)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titleFontSize: CGFloat {
        switch role {
        case .focus:
            return 12.8
        case .conversation:
            return 10.2
        case .overflow:
            return 9.4
        case .status:
            return 11.5
        }
    }
}

private struct BubbleStateMarker: View {
    let role: PetSpeechBubbleRole
    let tone: PetSpeechBubbleTone
    let activityKind: CodexConversationActivityKind?
    let accentColor: Color

    @ViewBuilder
    var body: some View {
        switch role {
        case .focus:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accentColor.opacity(0.92))
                .frame(width: 30, height: 30)
                .overlay(markerImage.font(.system(size: 12, weight: .bold)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: accentColor.opacity(0.16), radius: 3, x: 0, y: 1)
        case .status:
            Circle()
                .fill(accentColor.opacity(0.88))
                .frame(width: 22, height: 22)
                .overlay(markerImage.font(.system(size: 10, weight: .bold)))
                .shadow(color: accentColor.opacity(0.16), radius: 2.5, x: 0, y: 1)
        case .conversation:
            Circle()
                .fill(accentColor.opacity(0.82))
                .frame(width: 15, height: 15)
                .overlay(markerImage.font(.system(size: 7.2, weight: .bold)))
                .shadow(color: accentColor.opacity(0.14), radius: 2, x: 0, y: 0.8)
        case .overflow:
            ZStack {
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(0.86))
                markerImage
                    .font(.system(size: 8.8, weight: .bold))
                    .offset(y: -0.5)
            }
            .frame(width: 18, height: 18)
            .shadow(color: accentColor.opacity(0.14), radius: 2, x: 0, y: 0.8)
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
        case .overflow:
            return "plus"
        case .active:
            return activitySymbolName ?? "ellipsis"
        case .neutral:
            return activitySymbolName ?? "circle.fill"
        }
    }

    private var activitySymbolName: String? {
        guard let activityKind else { return nil }
        switch activityKind {
        case .message:
            return nil
        case .userRequest:
            return "person.fill"
        case .assistantMessage:
            return "text.bubble.fill"
        case .plan:
            return "list.bullet"
        case .reasoning, .contextCompaction:
            return "brain.head.profile"
        case .command:
            return "terminal.fill"
        case .test:
            return "checklist"
        case .fileChange:
            return "doc.fill"
        case .fileRead:
            return "doc.text.fill"
        case .tool:
            return "wrench.fill"
        case .subAgent:
            return "person.2.fill"
        case .webSearch:
            return "globe"
        case .browser:
            return "safari.fill"
        case .search:
            return "magnifyingglass"
        case .image:
            return "photo.fill"
        case .imageGeneration:
            return "sparkles"
        case .sleep:
            return "moon.fill"
        case .review:
            return "checkmark"
        case .skill:
            return "puzzlepiece.fill"
        case .mention:
            return "paperclip"
        case .threadStatus:
            return "waveform.path.ecg"
        }
    }
}

private enum BubbleAccentPalette {
    static func color(for index: Int, role: PetSpeechBubbleRole, tone: PetSpeechBubbleTone) -> Color? {
        switch tone {
        case .failed:
            return Color(red: 0.78, green: 0.36, blue: 0.42)
        case .waiting:
            return Color(red: 0.78, green: 0.58, blue: 0.28)
        case .review:
            return Color(red: 0.28, green: 0.62, blue: 0.50)
        case .overflow:
            return Color(red: 0.42, green: 0.47, blue: 0.55)
        case .active, .neutral:
            break
        }
        guard role != .status else { return nil }
        if role == .focus {
            return Color(red: 0.36, green: 0.56, blue: 0.86)
        }
        if role == .overflow {
            return Color(red: 0.42, green: 0.47, blue: 0.55)
        }
        let colors = [
            Color(red: 0.36, green: 0.56, blue: 0.86),
            Color(red: 0.26, green: 0.60, blue: 0.55),
            Color(red: 0.74, green: 0.50, blue: 0.34)
        ]
        return colors[max(0, index - 1) % colors.count]
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.maxY - rect.height * 0.18),
            control2: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.18)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.18),
            control2: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.maxY - rect.height * 0.18)
        )
        path.closeSubpath()
        return path
    }
}

private struct BubbleTailSideBorder: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: rect.midX, y: rect.maxY - 0.5)
        let leftRoot = CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + 1)
        let rightRoot = CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + 1)

        path.move(to: leftRoot)
        path.addCurve(
            to: tip,
            control1: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.22),
            control2: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.maxY - rect.height * 0.18)
        )
        path.addCurve(
            to: rightRoot,
            control1: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.maxY - rect.height * 0.18),
            control2: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.22)
        )

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
