enum PlatformError: Error, Equatable {
    case dataUnavailable(String)
    case commandFailed(status: Int32)
}
