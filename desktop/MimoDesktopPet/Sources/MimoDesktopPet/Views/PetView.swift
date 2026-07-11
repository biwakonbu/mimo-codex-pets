import SwiftUI
import MimoDesktopPetCore

private let productionCoordinateSpaceName = "MimoDesktopPet.productionSurface.coordinateSpace"

private struct BubbleFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

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
        ZStack(alignment: .topLeading) {
            KataribeStageView(
                stage: viewModel.kataribeStage,
                hoveredBubbleId: viewModel.hoveredBubbleId,
                isPetMoving: viewModel.isPetMoving,
                onBubbleFramesChanged: viewModel.updateBubbleFrames,
                onOpenBubble: { bubble in
                    _ = viewModel.openThread(for: bubble)
                }
            )

            AnimatedPetSpriteView(
                animation: viewModel.presentation.animation,
                frameProvider: frameProvider
            )
            .frame(
                width: CGFloat(PetKataribeStageLayout.spriteFrame.width),
                height: CGFloat(PetKataribeStageLayout.spriteFrame.height)
            )
            .position(
                x: CGFloat(PetKataribeStageLayout.spriteFrame.x + PetKataribeStageLayout.spriteFrame.width / 2),
                y: CGFloat(PetKataribeStageLayout.spriteFrame.y + PetKataribeStageLayout.spriteFrame.height / 2)
            )
            .zIndex(4)
        }
        .frame(
            width: CGFloat(PetKataribeStageLayout.windowWidth),
            height: CGFloat(PetKataribeStageLayout.windowHeight),
            alignment: .topLeading
        )
        .background(Color.clear)
        .coordinateSpace(name: productionCoordinateSpaceName)
    }
}

private struct KataribeStageView: View {
    let stage: PetKataribeStagePresentation
    let hoveredBubbleId: String?
    let isPetMoving: Bool
    let onBubbleFramesChanged: ([String: PetDragFrame]) -> Void
    let onOpenBubble: (PetSpeechBubble) -> Void

    var body: some View {
        let reportFrame = PetKataribeStageLayout.reportFrame(
            forTextLength: stage.reportLayoutTextLength
        )
        let selectedIndex = stage.charms.firstIndex(where: \.isSelected)
        let reportAccent = selectedIndex.map {
            KataribePalette.charmAccent(index: $0, tone: stage.report.tone)
        } ?? KataribePalette.accent(for: stage.report.tone)
        ZStack(alignment: .topLeading) {
            KataribeReportView(
                report: stage.report,
                pageNumber: stage.pageNumber,
                pageCount: stage.pageCount,
                accent: reportAccent,
                isHovered: hoveredBubbleId == stage.report.id,
                onOpen: stage.report.threadId == nil ? nil : { onOpenBubble(stage.report) }
            )
            .frame(width: CGFloat(reportFrame.width))
            .background {
                measuredFrame(for: stage.report.id)
            }
            .frame(
                width: CGFloat(reportFrame.width),
                height: CGFloat(reportFrame.height),
                alignment: .bottomLeading
            )
            .position(
                x: CGFloat(reportFrame.x + reportFrame.width / 2),
                y: CGFloat(reportFrame.y + reportFrame.height / 2)
            )
            .animation(.spring(response: 0.55, dampingFraction: 0.88), value: reportFrame.height)
            .zIndex(2)

            ForEach(Array(stage.charms.enumerated()), id: \.element.id) { index, charm in
                let bubble = charm.interactionBubble
                let frame = PetKataribeStageLayout.charmFrame(
                    at: index,
                    totalCount: stage.charms.count
                )
                let propagationIndex = max(0, stage.charms.count - 1 - index)
                KataribeChatCharmView(
                    charm: charm,
                    index: index,
                    isHovered: hoveredBubbleId == charm.id,
                    isPetMoving: isPetMoving,
                    onOpen: { onOpenBubble(bubble) }
                )
                .frame(width: CGFloat(frame.width), height: CGFloat(frame.height))
                .position(
                    x: CGFloat(frame.x + frame.width / 2),
                    y: CGFloat(frame.y + frame.height / 2)
                )
                .background {
                    measuredFrame(for: charm.id)
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .combined(with: .offset(y: PetKataribeCharmMotion.feedInsertionOffsetY))
                            .combined(with: .scale(scale: 0.94, anchor: .bottom)),
                        removal: .opacity
                            .combined(with: .offset(y: PetKataribeCharmMotion.feedRemovalOffsetY))
                            .combined(with: .scale(scale: 0.98, anchor: .top))
                    )
                )
                .animation(
                    .spring(
                        response: PetKataribeCharmMotion.feedSpringResponse,
                        dampingFraction: PetKataribeCharmMotion.feedSpringDamping
                    )
                    .delay(Double(propagationIndex) * PetKataribeCharmMotion.feedPropagationDelay),
                    value: stage.charms.map(\.id)
                )
                .zIndex(charm.isSelected ? 3 : 1)
            }
        }
        .frame(
            width: CGFloat(PetKataribeStageLayout.windowWidth),
            height: CGFloat(PetKataribeStageLayout.windowHeight),
            alignment: .topLeading
        )
        .onPreferenceChange(BubbleFramePreferenceKey.self) { framesById in
            let surfaceHeight = PetKataribeStageLayout.windowHeight
            onBubbleFramesChanged(framesById.mapValues { frame in
                PetDragFrame(
                    x: Double(frame.minX),
                    y: surfaceHeight - Double(frame.maxY),
                    width: Double(frame.width),
                    height: Double(frame.height)
                )
            })
        }
    }

    private func measuredFrame(for id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: BubbleFramePreferenceKey.self,
                value: [id: proxy.frame(in: .named(productionCoordinateSpaceName))]
            )
        }
    }
}

private struct KataribeReportView: View {
    let report: PetSpeechBubble
    let pageNumber: Int
    let pageCount: Int
    let accent: Color
    let isHovered: Bool
    let onOpen: (() -> Void)?

    private var title: String {
        guard let rawTitle = report.threadTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTitle.isEmpty
        else { return "Mimoからのお話" }
        return rawTitle
    }

    private var bodyText: String {
        let parts = PetSpeechBubbleTextParts.parse(report.text)
        return parts.threadTitle == nil ? report.text : parts.summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 34)
                    .background(accent, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.13))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)

                if onOpen != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent.opacity(0.82))
                        .padding(.top, 3)
                        .accessibilityHidden(true)
                        .help("このチャットをCodexで開く")
                }
            }

            Capsule()
                .fill(accent.opacity(0.28))
                .frame(height: 1)
                .padding(.vertical, 7)

            KataribeTypewriterText(text: bodyText)
                .id("\(report.id)|\(report.text)")
                .transition(.opacity.combined(with: .offset(y: 3)))
                .animation(.easeOut(duration: 0.3), value: report.text)

            if pageCount > 1 {
                HStack {
                    Spacer()
                    Text("\(pageNumber) / \(pageCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .monospacedDigit()
                }
                .padding(.top, 5)
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 1.0, green: 0.982, blue: 0.925).opacity(0.985))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(isHovered ? 0.62 : 0.34), lineWidth: isHovered ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.13 : 0.07), radius: isHovered ? 7 : 4, x: 0, y: 2)
        .scaleEffect(isHovered ? 1.008 : 1)
        .animation(.easeOut(duration: 0.18), value: isHovered)
        .animation(.easeInOut(duration: 0.3), value: report.tone)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("mimo.kataribe.report")
        .accessibilityLabel("Mimoの報告。チャット名: \(title)")
        .accessibilityValue(bodyText + (pageCount > 1 ? "。\(pageNumber) / \(pageCount)ページ" : ""))
        .accessibilitySortPriority(100)
        .modifier(KataribeAccessibilityActionModifier(action: onOpen))
    }
}

private struct KataribeChatCharmView: View {
    let charm: PetKataribeChatCharm
    let index: Int
    let isHovered: Bool
    let isPetMoving: Bool
    let onOpen: () -> Void

    @State private var isBreathing = false
    @State private var breathingTask: Task<Void, Never>?
    @State private var updatePulseActive = false
    @State private var updatePulseTask: Task<Void, Never>?
    @State private var hasPendingUpdatePulse = false

    private var accent: Color {
        KataribePalette.charmAccent(index: index, tone: charm.tone)
    }

    private var pausesAmbientMotion: Bool {
        isHovered || isPetMoving
    }

    var body: some View {
        let breathingScale = pausesAmbientMotion || !isBreathing
            ? 1
            : PetKataribeCharmMotion.breathingScale
        let emphasisScale = updatePulseActive
            ? PetKataribeCharmMotion.updatePulseScale
            : (isHovered ? PetKataribeCharmMotion.hoverScale : 1)
        HStack(spacing: 7) {
            Circle()
                .fill(accent)
                .frame(width: charm.isSelected ? 9 : 7, height: charm.isSelected ? 9 : 7)
                .overlay {
                    if charm.isSelected {
                        Circle()
                            .stroke(accent.opacity(0.18), lineWidth: 2)
                            .frame(width: 15, height: 15)
                    }
                }
                .accessibilityHidden(true)

            Text(charm.title)
                .font(.system(size: 10.2, weight: charm.isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.18))
                .lineLimit(3)
                .minimumScaleFactor(0.76)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if charm.isSelected {
                Image(systemName: "sparkle")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.85))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(accent.opacity(charm.isSelected ? 0.12 : 0.035))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    accent.opacity(updatePulseActive || isHovered ? 0.56 : (charm.isSelected ? 0.5 : 0.24)),
                    lineWidth: updatePulseActive || isHovered || charm.isSelected ? 1.2 : 0.8
                )
        )
        .shadow(
            color: updatePulseActive
                ? accent.opacity(0.32)
                : Color.black.opacity(isHovered || charm.isSelected ? 0.1 : 0.055),
            radius: updatePulseActive ? 7 : (isHovered || charm.isSelected ? 4 : 2),
            x: 0,
            y: 1
        )
        .offset(x: charm.isSelected || isHovered ? -1 : 0)
        .offset(y: pausesAmbientMotion || !isBreathing ? 0 : PetKataribeCharmMotion.breathingOffsetY)
        .scaleEffect(breathingScale * emphasisScale)
        .opacity(pausesAmbientMotion ? 1 : (isBreathing ? 0.98 : 1))
        .animation(.easeOut(duration: 0.18), value: isHovered)
        .animation(.easeInOut(duration: 0.28), value: charm.isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("mimo.kataribe.charm.\(index)")
        .accessibilityLabel("チャット: \(charm.title)")
        .accessibilityValue(charm.isSelected ? "Mimoがお話し中。Codexで開けます" : "Codexで開けます")
        .accessibilityAddTraits(.isButton)
        .accessibilitySortPriority(Double(90 - index))
        .accessibilityAction(named: "Codexで開く", onOpen)
        .onAppear {
            restartBreathing()
            requestUpdatePulse()
        }
        .onChange(of: pausesAmbientMotion) { _, _ in
            restartBreathing()
            if pausesAmbientMotion {
                hasPendingUpdatePulse = hasPendingUpdatePulse || updatePulseTask != nil
                cancelUpdatePulse()
            } else if hasPendingUpdatePulse {
                requestUpdatePulse()
            }
        }
        .onChange(of: charm.updateSignature) { _, _ in requestUpdatePulse() }
        .onDisappear {
            cancelBreathing()
            cancelUpdatePulse()
        }
    }

    private func restartBreathing() {
        cancelBreathing()
        guard !pausesAmbientMotion else {
            isBreathing = false
            return
        }
        let delay = 0.18 + Double((index * 7) % 5) * 0.13
        let duration = 2.8 + Double((index * 11) % 7) * 0.17
        breathingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    private func cancelBreathing() {
        breathingTask?.cancel()
        breathingTask = nil
    }

    private func requestUpdatePulse() {
        guard !pausesAmbientMotion else {
            hasPendingUpdatePulse = true
            return
        }
        hasPendingUpdatePulse = false
        restartUpdatePulse()
    }

    private func restartUpdatePulse() {
        cancelUpdatePulse()
        let delay = 0.08 + Double(index) * 0.055
        updatePulseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            for _ in 0..<PetKataribeCharmMotion.updatePulseCount {
                withAnimation(.easeInOut(duration: PetKataribeCharmMotion.updatePulseHalfDuration)) {
                    updatePulseActive = true
                }
                try? await Task.sleep(
                    nanoseconds: UInt64(PetKataribeCharmMotion.updatePulseHalfDuration * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: PetKataribeCharmMotion.updatePulseHalfDuration)) {
                    updatePulseActive = false
                }
                try? await Task.sleep(
                    nanoseconds: UInt64(PetKataribeCharmMotion.updatePulseHalfDuration * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
            }
            updatePulseTask = nil
        }
    }

    private func cancelUpdatePulse() {
        updatePulseTask?.cancel()
        updatePulseTask = nil
        updatePulseActive = false
    }
}

private struct KataribeTypewriterText: View {
    let text: String
    @State private var visibleText = ""
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Text(visibleText.isEmpty ? PetSpeechBubbleTypewriter.visiblePrefix(
            for: text,
            elapsed: 0,
            charactersPerSecond: PetKataribeStageLayout.typewriterCharactersPerSecond
        ) : visibleText)
            .font(.system(size: 15.2, weight: .medium, design: .rounded))
            .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.17))
            .lineSpacing(2)
            .lineLimit(4)
            .minimumScaleFactor(0.88)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear(perform: restartAnimation)
            .onChange(of: text) { _, _ in restartAnimation() }
            .onDisappear(perform: cancelAnimation)
    }

    private func restartAnimation() {
        cancelAnimation()
        let fullText = text
        visibleText = PetSpeechBubbleTypewriter.visiblePrefix(
            for: fullText,
            elapsed: 0,
            charactersPerSecond: PetKataribeStageLayout.typewriterCharactersPerSecond
        )
        let duration = PetSpeechBubbleTypewriter.duration(
            for: fullText,
            charactersPerSecond: PetKataribeStageLayout.typewriterCharactersPerSecond
        )
        animationTask = Task { @MainActor in
            let startedAt = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed >= duration {
                    visibleText = fullText
                    return
                }
                visibleText = PetSpeechBubbleTypewriter.visiblePrefix(
                    for: fullText,
                    elapsed: elapsed,
                    charactersPerSecond: PetKataribeStageLayout.typewriterCharactersPerSecond
                )
                try? await Task.sleep(nanoseconds: 33_333_333)
            }
        }
    }

    private func cancelAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

private struct KataribeAccessibilityActionModifier: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Codexで開く", action)
        } else {
            content
        }
    }
}

private enum KataribePalette {
    static func accent(for tone: PetSpeechBubbleTone) -> Color {
        switch tone {
        case .failed:
            return Color(red: 0.84, green: 0.38, blue: 0.42)
        case .waiting:
            return Color(red: 0.88, green: 0.60, blue: 0.30)
        case .review:
            return Color(red: 0.45, green: 0.66, blue: 0.39)
        case .active:
            return Color(red: 0.38, green: 0.62, blue: 0.84)
        case .neutral, .overflow:
            return Color(red: 0.83, green: 0.47, blue: 0.39)
        }
    }

    static func charmAccent(index: Int, tone: PetSpeechBubbleTone) -> Color {
        if tone == .failed || tone == .waiting {
            return accent(for: tone)
        }
        let colors = [
            Color(red: 0.88, green: 0.48, blue: 0.40),
            Color(red: 0.40, green: 0.63, blue: 0.84),
            Color(red: 0.48, green: 0.68, blue: 0.43),
            Color(red: 0.86, green: 0.66, blue: 0.34),
            Color(red: 0.68, green: 0.52, blue: 0.78),
            Color(red: 0.38, green: 0.68, blue: 0.68)
        ]
        return colors[max(0, index) % colors.count]
    }
}

private struct ProductionBubbleStackView: View {
    let bubbles: [PetSpeechBubble]
    let hoveredBubbleId: String?
    let onBubbleFramesChanged: ([String: PetDragFrame]) -> Void
    let onOpenBubble: (PetSpeechBubble) -> Void
    @State private var previousVisibleIDs: [String] = []
    @State private var birthPulseVisible = false
    @State private var birthPulseGeneration = 0
    @State private var cloudFloatPhase = false

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
                    threadTitle: bubble.threadTitle,
                    isOpenable: bubble.threadId != nil,
                    minTextWidth: placement.minTextWidth,
                    maxTextWidth: placement.maxTextWidth,
                    fillOpacity: placement.fillOpacity,
                    fontScale: placement.fontScale,
                    organicRotationDegrees: placement.rotationDegrees,
                    accentColor: BubbleAccentPalette.color(for: index, role: bubble.role, tone: bubble.tone),
                    accessibilityIndex: index,
                    isHovered: hoveredBubbleId == bubble.id,
                    onOpen: bubble.threadId == nil ? nil : { onOpenBubble(bubble) }
                )
                .scaleEffect(CGFloat(placement.scale), anchor: .center)
                .rotationEffect(.degrees(placement.rotationDegrees), anchor: .center)
                .offset(
                    x: CGFloat(
                        placement.horizontalOffset +
                            (cloudFloatPhase ? placement.floatingHorizontalOffset : -placement.floatingHorizontalOffset)
                    ),
                    y: CGFloat(
                        placement.verticalOffset +
                            (cloudFloatPhase ? placement.floatingVerticalOffset : -placement.floatingVerticalOffset)
                    )
                )
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: BubbleFramePreferenceKey.self,
                            value: [bubble.id: proxy.frame(in: .named(productionCoordinateSpaceName))]
                        )
                    }
                }
                .zIndex(placement.zIndex)
                .transition(ProductionBubbleMotion.transition(for: index, visibleCount: visible.count))
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.verticalOffset)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.horizontalOffset)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.scale)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.fontScale)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: placement.rotationDegrees)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: stackSignature)
                .animation(ProductionBubbleMotion.stackAnimation(for: index), value: visible.count)
                .animation(ProductionBubbleMotion.floatAnimation(for: placement), value: cloudFloatPhase)
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
            cloudFloatPhase = true
        }
        .onChange(of: stackSignature) {
            updateBirthPulse(nextIDs: visible.map(\.id))
        }
        .onPreferenceChange(BubbleFramePreferenceKey.self) { framesById in
            let surfaceHeight = PetSpeechBubbleLayout.productionWindowHeight
            onBubbleFramesChanged(framesById.mapValues { frame in
                PetDragFrame(
                    x: Double(frame.minX),
                    y: surfaceHeight - Double(frame.maxY),
                    width: Double(frame.width),
                    height: Double(frame.height)
                )
            })
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
        if let title = bubble.threadTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return "\(bubble.role.rawValue)|\(title)"
        }
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
            blendDuration: PetSpeechBubbleLayout.stackAnimationBlendDuration
        )
        .delay(timing.delay)
    }

    static let contentAnimation = Animation.easeInOut(
        duration: PetSpeechBubbleLayout.contentAnimationDuration
    )

    static func floatAnimation(for placement: PetSpeechBubblePlacement) -> Animation {
        guard placement.floatingDuration > 0 else {
            return .linear(duration: 0)
        }
        return Animation.easeInOut(duration: placement.floatingDuration)
            .delay(placement.floatingDelay)
            .repeatForever(autoreverses: true)
    }

    static func transition(for index: Int, visibleCount: Int) -> AnyTransition {
        let insertionScale = PetSpeechBubbleLayout.transitionInsertionScale
        let insertionOffset = PetSpeechBubbleLayout.transitionInsertionOffsetY
        let removalOffset = PetSpeechBubbleLayout.transitionRemovalOffsetY

        return .asymmetric(
            insertion: .modifier(
                active: BubbleBirthTransitionModifier(
                    opacity: 0,
                    scale: insertionScale,
                    xOffset: birthXOffset(for: index),
                    yOffset: insertionOffset,
                    rotationDegrees: birthRotation(for: index),
                    blurRadius: 2.8
                ),
                identity: BubbleBirthTransitionModifier(
                    opacity: 1,
                    scale: 1,
                    xOffset: 0,
                    yOffset: 0,
                    rotationDegrees: 0,
                    blurRadius: 0
                )
            ),
            removal: .modifier(
                active: BubbleBirthTransitionModifier(
                    opacity: 0,
                    scale: PetSpeechBubbleLayout.transitionRemovalScale,
                    xOffset: -birthXOffset(for: index) * 0.36,
                    yOffset: removalOffset,
                    rotationDegrees: -birthRotation(for: index) * 0.52,
                    blurRadius: 1.8
                ),
                identity: BubbleBirthTransitionModifier(
                    opacity: 1,
                    scale: 1,
                    xOffset: 0,
                    yOffset: 0,
                    rotationDegrees: 0,
                    blurRadius: 0
                )
            )
        )
    }

    private static func birthXOffset(for index: Int) -> Double {
        switch index {
        case 1:
            return -42
        case 2:
            return 42
        case 3:
            return 18
        default:
            return 0
        }
    }

    private static func birthRotation(for index: Int) -> Double {
        switch index {
        case 1:
            return -10
        case 2:
            return 10
        case 3:
            return 7
        default:
            return 0
        }
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
    let xOffset: Double
    let yOffset: Double
    let rotationDegrees: Double
    let blurRadius: Double

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(CGFloat(scale), anchor: .bottom)
            .rotationEffect(.degrees(rotationDegrees), anchor: .bottom)
            .offset(x: CGFloat(xOffset), y: CGFloat(yOffset))
            .blur(radius: CGFloat(blurRadius))
    }
}

private struct BubbleBirthPulseView: View {
    let isVisible: Bool

    var body: some View {
        Color.clear
            .frame(
                width: CGFloat(PetSpeechBubbleLayout.birthPulseWidth),
                height: CGFloat(PetSpeechBubbleLayout.birthPulseHeight)
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
    var tone: PetSpeechBubbleTone = .neutral
    var activityKind: CodexConversationActivityKind?
    var threadTitle: String?
    var isOpenable = false
    var minTextWidth: Double?
    var maxTextWidth: Double?
    var fillOpacity: Double?
    var fontScale: Double = 1
    var organicRotationDegrees: Double = 0
    var accentColor: Color?
    var accessibilityIndex: Int?
    var isHovered = false
    var onOpen: (() -> Void)?

    var body: some View {
        let resolvedFillOpacity = fillOpacity ?? defaultFillOpacity
        let accent = accentColor ?? Color(red: 0.36, green: 0.58, blue: 0.86)
        let cornerRadius = bubbleCornerRadius
        let bubbleShape = BubbleBodyShape(cornerRadius: cornerRadius, waviness: bubbleWaviness)
        let borderColor = role == .status && tone == .neutral
            ? Color(red: 0.54, green: 0.67, blue: 0.88).opacity(0.24)
            : accent.opacity(borderOpacity)
        let bodyFill = LinearGradient(
            colors: [
                Color.white.opacity(resolvedFillOpacity),
                Color(red: 0.985, green: 0.996, blue: 1.0).opacity(resolvedFillOpacity),
                Color(red: 0.935, green: 0.972, blue: 1.0).opacity(resolvedFillOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let resolvedFontScale = CGFloat(fontScale)
        let textIdentity = "\(role.rawValue)|\(tone.rawValue)|\(activityKind?.rawValue ?? "none")|\(text)"

        VStack(spacing: isPrimaryBubble ? -5 : 0) {
            HStack(spacing: leadingMarkerSpacing) {
                if showsStateMarker {
                    BubbleStateMarker(
                        role: role,
                        tone: tone,
                        activityKind: activityKind,
                        accentColor: accent,
                        displayIndex: accessibilityIndex
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.86, anchor: .center)))
                }

                ZStack(alignment: .leading) {
                    TypewriterBubbleTextContent(
                        text: text,
                        role: role,
                        threadTitle: threadTitle,
                        isOpenable: isOpenable,
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
                minHeight: minimumBubbleHeight,
                alignment: .leading
            )
            .background(
                bubbleShape
                    .fill(bodyFill)
            )
            .overlay(alignment: tapeAlignment) {
                if showsScrapbookTape {
                    BubbleScrapbookTape(color: tapeColor)
                        .rotationEffect(.degrees(tapeRotationDegrees))
                        .offset(x: tapeXOffset, y: tapeYOffset)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showsDecorativePips {
                    BubbleDecorativePips(color: accent, count: decorativePipCount)
                        .padding(.trailing, decorativePipsTrailingPadding)
                        .padding(.bottom, decorativePipsBottomPadding)
                }
            }
            .overlay(
                bubbleShape
                    .strokeBorder(borderColor, lineWidth: isPrimaryBubble ? 1.1 : 0.9)
            )
            .compositingGroup()
            .shadow(
                color: Color.black.opacity(isHovered ? 0.13 : (isPrimaryBubble ? 0.08 : 0.055)),
                radius: isHovered ? 8 : (isPrimaryBubble ? 5.5 : 3.2),
                x: 0,
                y: isHovered ? 3 : (isPrimaryBubble ? 2 : 1)
            )

            if showsPrimaryConnector {
                BubbleSoftConnector()
                    .fill(bodyFill)
                    .overlay(
                        BubbleSoftConnector()
                            .stroke(borderColor.opacity(0.72), lineWidth: 0.85)
                    )
                    .frame(width: 88, height: 20)
                    .compositingGroup()
                    .shadow(color: Color.black.opacity(0.035), radius: 2.6, x: 0, y: 1)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(text)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilitySortPriority(accessibilitySortPriority)
        .modifier(BubbleAccessibilityActionModifier(isOpenable: isOpenable, action: onOpen))
        .scaleEffect(isHovered ? 1.018 : 1, anchor: .center)
        .animation(.easeOut(duration: 0.14), value: isHovered)
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
        let openableSuffix = isOpenable ? "。Codexで開けます" : ""
        if let accessibilityIndex {
            return PetSpeechBubbleAccessibility.bubbleElementLabel(index: accessibilityIndex, role: role, text: text) + openableSuffix
        }
        return "Mimo speech bubble: \(text)\(openableSuffix)"
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
            return 14
        case .conversation, .overflow:
            return 7
        }
    }

    private var fontSize: CGFloat {
        switch role {
        case .status, .focus:
            return 16.2
        case .conversation:
            return 12.2
        case .overflow:
            return 11.9
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
            return 0.88
        case .overflow:
            return 0.86
        }
    }

    private var horizontalPadding: CGFloat {
        switch role {
        case .status:
            return 22
        case .focus:
            return 22
        case .conversation:
            return 13
        case .overflow:
            return 10
        }
    }

    private var verticalPadding: CGFloat {
        switch role {
        case .status, .focus:
            return 16
        case .conversation:
            return 11
        case .overflow:
            return 9
        }
    }

    private var defaultMaxTextWidth: Double {
        switch role {
        case .status, .focus:
            return 404
        case .conversation:
            return 218
        case .overflow:
            return 184
        }
    }

    private var resolvedMinTextWidth: Double? {
        if let minTextWidth {
            return minTextWidth
        }
        switch role {
        case .status:
            return 320
        case .focus:
            return 336
        case .conversation:
            return 178
        case .overflow:
            return 154
        }
    }

    private var bubbleCornerRadius: CGFloat {
        switch role {
        case .focus:
            return 24
        case .status:
            return 24
        case .conversation:
            return 17
        case .overflow:
            return 15
        }
    }

    private var bubbleWaviness: CGFloat {
        switch role {
        case .status, .focus:
            return 0
        case .conversation:
            return 0
        case .overflow:
            return 0
        }
    }

    private var showsDecorativePips: Bool {
        switch role {
        case .status:
            return tone != .neutral
        case .focus:
            return true
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

    private var minimumBubbleHeight: CGFloat {
        switch role {
        case .status, .focus:
            return 104
        case .conversation:
            return 66
        case .overflow:
            return 42
        }
    }

    private var showsPrimaryConnector: Bool {
        false
    }

    private var showsScrapbookTape: Bool {
        switch role {
        case .conversation, .overflow:
            return true
        case .status, .focus:
            return false
        }
    }

    private var tapeAlignment: Alignment {
        organicRotationDegrees < 0 ? .topLeading : .topTrailing
    }

    private var tapeColor: Color {
        switch tone {
        case .failed:
            return Color(red: 1.0, green: 0.62, blue: 0.72)
        case .waiting:
            return Color(red: 1.0, green: 0.82, blue: 0.44)
        case .review:
            return Color(red: 0.66, green: 0.86, blue: 0.76)
        case .overflow:
            return Color(red: 0.74, green: 0.78, blue: 0.86)
        case .active, .neutral:
            return organicRotationDegrees < 0
                ? Color(red: 0.98, green: 0.76, blue: 0.84)
                : Color(red: 0.72, green: 0.84, blue: 1.0)
        }
    }

    private var tapeRotationDegrees: Double {
        organicRotationDegrees < 0 ? -8 : 8
    }

    private var tapeXOffset: CGFloat {
        organicRotationDegrees < 0 ? 18 : -18
    }

    private var tapeYOffset: CGFloat {
        -7
    }
}

private struct BubbleAccessibilityActionModifier: ViewModifier {
    let isOpenable: Bool
    let action: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOpenable {
            content
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: Text("Codexで開く")) {
                    action?()
                }
        } else {
            content.accessibilityAddTraits(.isStaticText)
        }
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
        var path = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        let bump = min(max(waviness, 0), 0.24)
        if bump > 0 {
            let capWidth = rect.width * (0.42 + bump * 0.5)
            let capHeight = min(rect.height * 0.14, 8 + bump * 20)
            let capRect = CGRect(
                x: rect.midX - capWidth / 2,
                y: rect.minY - capHeight * 0.18,
                width: capWidth,
                height: capHeight
            )
            path.addRoundedRect(
                in: capRect,
                cornerSize: CGSize(width: capHeight / 2, height: capHeight / 2),
                style: RoundedCornerStyle.continuous
            )
        }
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

private struct BubbleScrapbookTape: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0.88),
                        color.opacity(0.56)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.4, style: .continuous)
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 4)
                    }
                }
                .padding(.horizontal, 5)
            )
            .frame(width: 42, height: 13)
            .shadow(color: color.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

private struct BubbleSoftConnector: Shape {
    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: 3, dy: 1)
        let topWidth = rect.width * 0.92
        let bottomWidth = rect.width * 0.72
        let leftTop = CGPoint(x: rect.midX - topWidth / 2, y: rect.minY + rect.height * 0.1)
        let rightTop = CGPoint(x: rect.midX + topWidth / 2, y: rect.minY + rect.height * 0.1)
        let leftBottom = CGPoint(x: rect.midX - bottomWidth / 2, y: rect.maxY - rect.height * 0.08)
        let rightBottom = CGPoint(x: rect.midX + bottomWidth / 2, y: rect.maxY - rect.height * 0.08)

        var path = Path()
        path.move(to: leftTop)
        path.addCurve(
            to: leftBottom,
            control1: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.16),
            control2: CGPoint(x: rect.midX - rect.width * 0.45, y: rect.maxY - rect.height * 0.2)
        )
        path.addCurve(
            to: rightBottom,
            control1: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.maxY + rect.height * 0.1),
            control2: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY + rect.height * 0.1)
        )
        path.addCurve(
            to: rightTop,
            control1: CGPoint(x: rect.midX + rect.width * 0.45, y: rect.maxY - rect.height * 0.2),
            control2: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.minY + rect.height * 0.16)
        )
        path.addCurve(
            to: leftTop,
            control1: CGPoint(x: rect.midX + rect.width * 0.25, y: rect.minY - rect.height * 0.04),
            control2: CGPoint(x: rect.midX - rect.width * 0.25, y: rect.minY - rect.height * 0.04)
        )
        path.closeSubpath()
        return path
    }
}

private struct TypewriterBubbleTextContent: View {
    let text: String
    let role: PetSpeechBubbleRole
    let threadTitle: String?
    let isOpenable: Bool
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
            threadTitle: threadTitle,
            isOpenable: isOpenable,
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
        (role == .focus || role == .status) && !text.isEmpty
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
    let threadTitle: String?
    let isOpenable: Bool
    let accentColor: Color
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let minimumScaleFactor: CGFloat
    let fontScale: CGFloat

    var body: some View {
        let parts = PetSpeechBubbleTextParts.parse(text)
        let resolvedThreadTitle = explicitThreadTitle ?? parts.threadTitle
        let summary = parts.threadTitle == nil ? text : parts.summary

        if role == .focus, let resolvedThreadTitle {
            VStack(alignment: .leading, spacing: role == .focus ? 2 : 1) {
                BubbleThreadTitleHeader(
                    prefix: parts.prefix,
                    title: resolvedThreadTitle,
                    role: role,
                    accentColor: accentColor,
                    fontSize: titleFontSize * fontScale,
                    isOpenable: isOpenable
                )

                Text(summary)
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
        } else if role == .conversation, let resolvedThreadTitle {
            VStack(alignment: .leading, spacing: 2) {
                BubbleThreadTitleHeader(
                    prefix: nil,
                    title: resolvedThreadTitle,
                    role: role,
                    accentColor: accentColor,
                    fontSize: titleFontSize * fontScale,
                    isOpenable: isOpenable
                )

                Text(summary)
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

    private var explicitThreadTitle: String? {
        guard let threadTitle else { return nil }
        let trimmed = threadTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if ["Codex", "Codex Session", "Codex Thread", "unknown-thread"].contains(trimmed) {
            return "このチャット"
        }
        return trimmed
    }
}

private struct BubbleThreadTitleHeader: View {
    let prefix: String?
    let title: String
    let role: PetSpeechBubbleRole
    let accentColor: Color
    let fontSize: CGFloat
    let isOpenable: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: role == .focus ? 6 : 4) {
            if let prefix {
                Text(prefix)
                    .font(.system(size: fontSize - 0.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }

            Image(systemName: "text.bubble.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(accentColor.opacity(0.72))
                .baselineOffset(-0.8)

            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(accentColor.opacity(0.98))
                .lineLimit(PetSpeechBubbleLayout.titleLineLimit(for: role))
                .minimumScaleFactor(0.82)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            if isOpenable {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.52))
                    .baselineOffset(-0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconSize: CGFloat {
        role == .focus ? 10.2 : 8.6
    }
}

private struct BubbleStateMarker: View {
    let role: PetSpeechBubbleRole
    let tone: PetSpeechBubbleTone
    let activityKind: CodexConversationActivityKind?
    let accentColor: Color
    let displayIndex: Int?

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
                .frame(width: 16, height: 16)
                .overlay(markerImage.font(.system(size: 7.8, weight: .bold)))
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

    private var displayNumber: String {
        guard let displayIndex else { return "•" }
        return "\(displayIndex + 1)"
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
