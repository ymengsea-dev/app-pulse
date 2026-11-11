/// Opening an app remembers which metric it was opened from, so its page shows that metric.
struct AppRoute: Hashable {
    let appID: String
    let metric: UsageMetric
}
