import Foundation
import UIKit

// MARK: - Device Info Tool

struct DeviceInfoTool: AgentTool {
    let name = "device_info"
    let description = "Get information about the device: battery level, storage, model, OS version, screen brightness."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "info_type": .init(
                type: "string",
                description: "Type of info to retrieve",
                enumValues: ["battery", "storage", "device", "all"]
            ),
        ],
        required: []
    )

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        let infoType = arguments["info_type"] as? String ?? "all"

        return await MainActor.run {
            let device = UIDevice.current
            device.isBatteryMonitoringEnabled = true

            var info: [String] = []

            if infoType == "battery" || infoType == "all" {
                let batteryLevel = Int(device.batteryLevel * 100)
                let batteryState: String = switch device.batteryState {
                case .charging: "Charging"
                case .full: "Full"
                case .unplugged: "Unplugged"
                default: "Unknown"
                }
                info.append("Battery: \(batteryLevel)% (\(batteryState))")
            }

            if infoType == "storage" || infoType == "all" {
                if let attrs = try? FileManager.default.attributesOfFileSystem(
                    forPath: NSHomeDirectory()
                ) {
                    let total = (attrs[.systemSize] as? Int64) ?? 0
                    let free = (attrs[.systemFreeSize] as? Int64) ?? 0
                    let used = total - free
                    info.append("Storage: \(format(bytes: used)) used / \(format(bytes: total)) total (\(format(bytes: free)) free)")
                }
            }

            if infoType == "device" || infoType == "all" {
                info.append("Device: \(device.name)")
                info.append("Model: \(device.model)")
                info.append("OS: \(device.systemName) \(device.systemVersion)")
                info.append("Screen Brightness: \(Int(UIScreen.main.brightness * 100))%")
            }

            return .success(info.joined(separator: "\n"))
        }
    }

    private func format(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
