/// What the sidebar can show: a usage metric, or the privacy view of background programs.
enum SidebarItem: Hashable {
    case metric(UsageMetric)
    case background
}
