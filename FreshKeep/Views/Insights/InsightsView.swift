import SwiftUI
import SwiftData
import Charts
import FreshKeepCore

/// Impact dashboard: how much food (and money) the user has rescued, plus recipes
/// that use up whatever is expiring next.
struct InsightsView: View {
    @Query private var items: [PantryItem]
    @State private var appeared = false

    private var records: [ItemRecord] { items.map(\.record) }
    private var insights: WasteInsights { WasteInsights() }
    private var summary: WasteSummary { insights.summary(for: records) }

    private var suggestions: [RecipeSuggestion] {
        var available: [String: Int] = [:]
        for item in items where item.status == .active {
            guard let id = item.profile?.id else { continue }
            available[id] = min(available[id] ?? .max, item.freshness().daysLeft)
        }
        return RecipeSuggester().suggestions(available: available, limit: 4)
    }

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: Spacing.m)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if summary.eatenCount + summary.wastedCount == 0 {
                        ContentUnavailableView("No history yet", systemImage: "chart.bar.xaxis",
                                               description: Text("Mark items as eaten or wasted and your impact will show up here."))
                    } else {
                        hero
                        LazyVGrid(columns: columns, spacing: Spacing.m) { statTiles }
                        weeklyChart
                        if !summary.wastedByCategory.isEmpty { categoryChart }
                    }
                    if !suggestions.isEmpty { recipes }
                }
                .padding()
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground)
            .navigationTitle("Insights")
            .navigationDestination(for: RecipeSuggestion.self) { RecipeDetailView(suggestion: $0) }
            .onAppear { withAnimation(.gentleSpring) { appeared = true } }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        let rate = summary.rescueRate ?? 0
        return HStack(spacing: Spacing.l) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: appeared ? rate : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(rate.formatted(.percent.precision(.fractionLength(0))))
                    .font(.rounded(.title2, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text("Rescue rate").font(.rounded(.headline))
                Text("You ate \(summary.eatenCount) of \(summary.eatenCount + summary.wastedCount) items before they expired.")
                    .font(.rounded(.subheadline))
                    .opacity(0.9)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(Spacing.xl)
        .background(.brandGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statTiles: some View {
        let streak = insights.zeroWasteStreak(for: records)
        StatTile(title: "Money saved", value: summary.moneySaved.formatted(.currency(code: "LKR").precision(.fractionLength(0))),
                 symbol: "banknote.fill", tint: .brand)
        StatTile(title: "Items rescued", value: "\(summary.eatenCount)", symbol: "checkmark.seal.fill", tint: .brand)
        StatTile(title: "Wasted", value: "\(summary.wastedCount)", symbol: "xmark.bin.fill", tint: .orange)
        StatTile(title: "CO₂e avoided", value: "\(summary.co2SavedKg.formatted(.number.precision(.fractionLength(1)))) kg",
                 symbol: "leaf.fill", tint: .teal)
        StatTile(title: "Zero-waste streak", value: "\(streak) day\(streak == 1 ? "" : "s")", symbol: "flame.fill", tint: .citrus)
        StatTile(title: "Money lost", value: summary.moneyWasted.formatted(.currency(code: "LKR").precision(.fractionLength(0))),
                 symbol: "exclamationmark.triangle.fill", tint: .red)
    }

    private var weeklyChart: some View {
        let buckets = insights.weekly(for: records)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Last 6 weeks").font(.rounded(.headline))
            Chart {
                ForEach(buckets) { bucket in
                    BarMark(x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                            y: .value("Items", appeared ? bucket.eaten : 0))
                        .foregroundStyle(by: .value("Outcome", "Eaten"))
                        .cornerRadius(4)
                    BarMark(x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                            y: .value("Items", appeared ? bucket.wasted : 0))
                        .foregroundStyle(by: .value("Outcome", "Wasted"))
                        .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale(["Eaten": Color.brand, "Wasted": Color.orange])
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                }
            }
            .frame(height: 220)
            .accessibilityLabel("Weekly chart of eaten and wasted items")
        }
        .freshCard()
    }

    private var categoryChart: some View {
        let data = summary.wastedByCategory.sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: Spacing.m) {
            Text("What gets wasted most").font(.rounded(.headline))
            HStack(spacing: Spacing.l) {
                Chart(data, id: \.key) { entry in
                    SectorMark(angle: .value("Items", entry.value), innerRadius: .ratio(0.6), angularInset: 2)
                        .foregroundStyle(by: .value("Category", entry.key.displayName))
                        .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(width: 140, height: 140)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data, id: \.key) { entry in
                        Label("\(entry.key.displayName): \(entry.value)", systemImage: entry.key.symbolName)
                            .font(.rounded(.subheadline))
                    }
                    Text("Tip: buy these in smaller amounts.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .freshCard()
    }

    private var recipes: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Use it up").font(.rounded(.title3, weight: .bold))
            Text("Recipes that rescue what's expiring next.").font(.rounded(.subheadline)).foregroundStyle(.secondary)
            ForEach(suggestions) { suggestion in
                NavigationLink(value: suggestion) {
                    HStack(spacing: Spacing.m) {
                        Text(suggestion.recipe.emoji).font(.system(size: 34))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.recipe.title).font(.rounded(.headline))
                            Text("Uses \(suggestion.usesUp.count) of your items · \(suggestion.recipe.minutes) min")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .freshCard(padding: Spacing.m)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            Text(value)
                .font(.rounded(.title2, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.rounded(.subheadline))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .freshCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    InsightsView()
        .modelContainer(SampleData.previewContainer)
}
