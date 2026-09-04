import SwiftUI

/// "Where does this come from?" — the provenance surface. Every statistic in the
/// app is one tap from this sheet.
struct SourceSheet: View {
    let sources: [Source]
    var metricDefinition: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    if let metricDefinition {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            SectionHeader(title: "What this measures")
                            Text(metricDefinition)
                                .font(.body)
                                .foregroundStyle(Theme.Palette.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        SectionHeader(
                            title: sources.count == 1 ? "Data source" : "Data sources",
                            subtitle: "Every number in CivicAI comes from a published federal dataset."
                        )
                        // Indexed so two datasets with identical names can't collapse into one row.
                        ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                            sourceCard(source)
                        }
                    }
                }
                .padding(Theme.Space.lg)
            }
            .appBackground()
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close sources")
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func sourceCard(_ source: Source) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                if let metricName = source.metricName {
                    Text(metricName.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.Palette.primary)
                }

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(source.organization)
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.foreground)
                    Text(source.name)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.foregroundMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let methodology = source.methodology {
                    labelled("How it's collected", methodology)
                }

                if let updated = Format.monthYear(source.lastUpdated) {
                    labelled("Last updated", updated)
                }

                if let url = source.webURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("Open \(source.organization) dataset in Safari")
                    .accessibilityHint(url.absoluteString)
                }
            }
        }
    }

    private func labelled(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.foregroundMuted)
            Text(body)
                .font(.footnote)
                .foregroundStyle(Theme.Palette.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
