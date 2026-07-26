import SwiftUI

/// The menu bar popup: header, provider cards, menu-bar picker, footer.
struct MenuPopover: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.openSettings) private var openSettings

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ProviderRegistry.all, id: \.id) { provider in
                        ProviderCard(provider: provider, snapshot: store.snapshots[provider.id])
                    }
                }
                .padding(12)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { h in
                    measuredCardsHeight = h
                }
            }
            .frame(height: min(max(measuredCardsHeight ?? estimatedCardsHeight, 120), 940))
            Divider()
            menuBarSection
            Divider()
            footer
        }
        .frame(width: 340)
        .onAppear { store.refreshIfStale() }
    }

    /// Exact content height once layout reports it (tracks window/balance
    /// changes as snapshots arrive). Until then the estimate below is used.
    @State private var measuredCardsHeight: CGFloat? = nil

    /// Estimated cards height from the data — close enough for first layout;
    /// `measuredCardsHeight` takes over for the exact fit.
    private var estimatedCardsHeight: CGFloat {
        var total: CGFloat = 24  // padding: 12 top + 12 bottom
        for (index, provider) in ProviderRegistry.all.enumerated() {
            if index > 0 { total += 10 }  // VStack spacing
            total += cardHeight(snapshot: store.snapshots[provider.id])
        }
        return total
    }

    private func cardHeight(snapshot: UsageSnapshot?) -> CGFloat {
        var h: CGFloat = 20 + 20  // card padding + header row
        if let snapshot {
            if snapshot.error != nil { h += 38 }      // error line
            h += CGFloat(snapshot.windows.count) * 52 // label+reset, bar, "N% used" + spacing
            if snapshot.balanceText != nil { h += 24 }
            if let spend = snapshot.spend {
                if spend.tokens.total > 0 { h += 34 }   // value row + token detail
                if spend.chargedUSD != nil { h += 18 }
                if spend.chargePercent != nil { h += 9 }  // charge bar
                if spend.hasUnpriced { h += 16 }
            }
        } else {
            h += 38  // setup hint / loading line
        }
        return h
    }

    private var header: some View {
        HStack(spacing: 8) {
            ProviderGlyph(kind: .owl, color: .primary)
                .frame(width: 15, height: 15)
            Text("UsageOwl").font(.headline)
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await store.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
            }
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit UsageOwl")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// Per-provider toggles for the menu bar label — applies immediately.
    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("MENU BAR")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(ProviderRegistry.all, id: \.id) { provider in
                HStack(spacing: 8) {
                    ProviderGlyph(kind: ProviderGlyph.Kind(providerID: provider.id), color: .primary)
                        .frame(width: 13, height: 13)
                    Text(provider.name).font(.callout)
                    Spacer()
                    Toggle("", isOn: menuBarBinding(for: provider.id))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func menuBarBinding(for providerID: String) -> Binding<Bool> {
        Binding(
            get: { store.isShownInMenuBar(providerID) },
            set: { store.setShownInMenuBar(providerID, $0) }
        )
    }

    private var footer: some View {
        HStack {
            if let updated = store.lastUpdated {
                Text("Last updated: \(Self.timeFormatter.string(from: updated))")
            } else {
                Text("Not refreshed yet")
            }
            Spacer()
            Text("No telemetry")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ProviderCard: View {
    let provider: any AIProvider
    let snapshot: UsageSnapshot?

    private var primaryWindow: UsageWindow? {
        guard let snapshot, snapshot.error == nil else { return nil }
        return snapshot.primaryWindow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Text(provider.name).font(.headline)
                if let plan = snapshot?.planLabel {
                    Text(plan)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(provider.brandColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(provider.brandColor.opacity(0.16)))
                }
                Spacer()
                ProviderGlyph(kind: ProviderGlyph.Kind(providerID: provider.id), color: provider.brandColor)
                    .frame(width: 14, height: 14)
                Text(primaryWindow.map { Format.percent($0.usedPercent) } ?? "--")
                    .font(.callout.monospacedDigit().bold())
                    .foregroundStyle(primaryWindow == nil ? Color.secondary : Color.primary)
            }

            if let snapshot {
                if let error = snapshot.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(snapshot.windows.enumerated()), id: \.element.id) { index, window in
                    if index > 0 { Divider().opacity(0.6) }
                    WindowRow(window: window)
                }
                if let balance = snapshot.balanceText {
                    Label(balance, systemImage: "creditcard")
                        .font(.caption)
                }
                if let spend = snapshot.spend {
                    SpendRows(spend: spend)
                }
            } else if provider.isAvailable() {
                Label("Loading…", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(provider.setupHint, systemImage: "key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Spend, split so a flat-rate estimate can't be mistaken for a bill.
///
/// "API value" is what the month's work would have cost at list rates — the
/// number a subscription is measured against. "Charged" is money actually
/// billed, and only appears when the provider reports some.
struct SpendRows: View {
    let spend: SpendSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if spend.tokens.total > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("API value \(spend.periodLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Format.usd(spend.apiEquivalentUSD))
                        .font(.caption.monospacedDigit().weight(.medium))
                }
                HStack(spacing: 6) {
                    Text("\(Format.compactTokens(spend.tokens.total)) tokens")
                    Spacer()
                    Text("\(Format.compactTokens(spend.tokens.cacheRead)) cached")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            if let charged = spend.chargedUSD {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Extra usage \(spend.periodLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let limit = spend.chargeLimitUSD {
                        Text("\(Format.usd(charged, cents: true)) / \(Format.usd(limit, cents: true))")
                            .font(.caption.monospacedDigit().weight(.medium))
                    } else {
                        Text(Format.usd(charged, cents: true))
                            .font(.caption.monospacedDigit().weight(.medium))
                    }
                    if let percent = spend.chargePercent {
                        Text(Format.percent(percent))
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(GaugeColor.color(for: percent))
                    }
                }
                if let percent = spend.chargePercent {
                    ThinProgressBar(percent: percent).frame(height: 3)
                }
            }
            if spend.hasUnpriced {
                // Never fold an unknown rate into the total as zero.
                Text("\(Format.compactTokens(spend.unpricedTokens)) tokens on a model with no known rate")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WindowRow: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Format.displayLabel(window.label))
                    .font(.callout.weight(.medium))
                Spacer()
                if let reset = Format.resetText(window.resetDate) {
                    Text(reset)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ThinProgressBar(percent: window.usedPercent)
                .frame(height: 4)
            Text("\(Format.percent(window.usedPercent)) used")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Hairline progress bar tinted by status color.
struct ThinProgressBar: View {
    let percent: Double  // 0...100

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(GaugeColor.color(for: percent))
                    .frame(width: geo.size.width * min(max(percent, 0), 100) / 100)
            }
        }
    }
}
