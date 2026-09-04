import SwiftUI

/// Natural-language questions answered from this county's loaded datasets only.
/// Not a chat: one question, one sourced answer, with the data shown alongside it.
struct AskCivicAIView: View {
    let location: CountyLocation

    @StateObject private var viewModel = AskViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool
    @State private var showingSources = false
    @Environment(\.motionGate) private var motion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.xl) {
                        switch viewModel.state {
                        case .idle:      idleState
                        case .loading:   loadingState
                        case .failed(let error):
                            StatusView.error(error) { viewModel.retry() }
                        case .loaded(let response):
                            answer(response)
                        }
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.lg)
                    .padding(.bottom, 120)
                }
                inputBar
            }
            .navigationTitle("Ask CivicAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if viewModel.state.value != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New question") {
                            viewModel.reset()
                            inputFocused = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSources) {
                SourceSheet(sources: viewModel.state.value?.sources ?? [])
            }
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - States

    private var idleState: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Ask about \(location.county)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("CivicAI answers only from the federal datasets loaded for this county, and shows you the source for every number.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            SectionHeader(title: "Try one of these")
            VStack(spacing: Theme.Space.sm) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element) { index, suggestion in
                    Button {
                        Haptics.tap()
                        viewModel.question = suggestion
                        viewModel.submit(in: location)
                        inputFocused = false
                    } label: {
                        HStack(spacing: Theme.Space.md) {
                            Image(systemName: "text.bubble")
                                .foregroundStyle(Theme.Palette.primary)
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(Theme.Palette.foreground)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(Theme.Space.md)
                        .frame(minHeight: Theme.minTapTarget)
                        .glassChip()
                    }
                    .buttonStyle(PressableCardStyle())
                    .staggeredAppear(index: index)
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            HStack(spacing: Theme.Space.sm) {
                ProgressView()
                Text("Analyzing your question…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.foregroundMuted)
            }
            CardSurface {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    SkeletonBlock(height: 14)
                    SkeletonBlock(height: 14, width: 240)
                    SkeletonBlock(height: 14, width: 180)
                    SkeletonBlock(height: 90)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing your question")
    }

    // MARK: - Answer

    @ViewBuilder
    private func answer(_ response: AskResponse) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text(response.question)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(response.summary)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if !response.dataAvailable {
                StatusView(
                    symbol: "tray",
                    title: "No data for that question",
                    message: response.whatThisMeans,
                    actionTitle: "Ask something else",
                    action: {
                        viewModel.reset()
                        inputFocused = true
                    }
                )
            } else {
                if !response.keyFindings.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        SectionHeader(title: "Key findings")
                        ForEach(Array(response.keyFindings.enumerated()), id: \.element) { index, finding in
                            findingCard(finding).staggeredAppear(index: index)
                        }
                    }
                }

                if let chart = response.chart, chart.history.count > 1 {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        SectionHeader(title: "Trend over time", subtitle: chart.name)
                        CardSurface {
                            TrendChart(
                                history: chart.history,
                                format: chart.format,
                                metricName: chart.name,
                                height: 180
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    SectionHeader(title: "What this means")
                    CardSurface {
                        Text(response.whatThisMeans)
                            .font(.body)
                            .foregroundStyle(Theme.Palette.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !response.sources.isEmpty {
                    Button {
                        Haptics.tap()
                        showingSources = true
                    } label: {
                        Label("View sources (\(response.sources.count))", systemImage: "link.circle")
                    }
                    // Secondary, not primary: the send button already owns the
                    // screen's one orange CTA.
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityHint("Opens the datasets this answer was drawn from.")
                }
            }
        }
    }

    private func findingCard(_ finding: KeyFinding) -> some View {
        CardSurface {
            HStack(alignment: .top, spacing: Theme.Space.md) {
                // Backend returns an SF Symbol name, never an emoji.
                Image(systemName: finding.sfSymbol)
                    .font(.title3)
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(finding.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Palette.foregroundMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(finding.value)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Palette.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(finding.change)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Theme.Palette.foregroundMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(finding.title). \(finding.value). \(finding.change)")
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: Theme.Space.sm) {
            TextField("e.g., How has housing changed?", text: $viewModel.question, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .font(.body)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm)
                .frame(minHeight: Theme.minTapTarget)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(inputFocused ? Theme.Palette.primary : Theme.Palette.border, lineWidth: inputFocused ? 2 : 1)
                )
                .animation(motion.animation(Theme.Motion.micro), value: inputFocused)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .accessibilityLabel("Your question about \(location.county)")

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.Palette.onPrimary)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .background(
                        Circle().fill(viewModel.canSubmit ? Theme.Palette.primary : Theme.Palette.neutralTrend.opacity(0.4))
                    )
                    .scaleEffect(viewModel.canSubmit ? 1 : 0.92)
                    .animation(motion.animation(Theme.Motion.quick), value: viewModel.canSubmit)
            }
            .disabled(!viewModel.canSubmit)
            .accessibilityLabel("Send question")
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(Theme.Palette.border) }
    }

    private func send() {
        guard viewModel.canSubmit else { return }
        Haptics.tap()
        inputFocused = false
        viewModel.submit(in: location)
    }
}
