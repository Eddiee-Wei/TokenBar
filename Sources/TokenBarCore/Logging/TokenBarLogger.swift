import Foundation
import os

public enum TokenBarLogger {
    public static let subsystem = "com.tokenbar.TokenBar"
    public static let providers = Logger(subsystem: subsystem, category: "providers")
    public static let storage = Logger(subsystem: subsystem, category: "storage")
    public static let app = Logger(subsystem: subsystem, category: "app")
}
