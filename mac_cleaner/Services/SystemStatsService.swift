//
//  SystemStatsService.swift
//  mac_cleaner
//

import Foundation
import Darwin

struct SystemStatsSnapshot {
    var diskFreeBytes: Int64
    var diskTotalBytes: Int64
    var memoryUsedBytes: Int64
    var memoryTotalBytes: Int64

    var diskFreeLabel: String { ByteFormat.string(from: diskFreeBytes) }
    var diskUsage: Double {
        guard diskTotalBytes > 0 else { return 0 }
        return 1 - (Double(diskFreeBytes) / Double(diskTotalBytes))
    }

    var memoryUsage: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return Double(memoryUsedBytes) / Double(memoryTotalBytes)
    }
}

enum SystemStatsService {
    static func snapshot() -> SystemStatsSnapshot {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ])
        let free = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        let total = Int64(values?.volumeTotalCapacity ?? 0)

        let processInfo = ProcessInfo.processInfo
        let memTotal = Int64(processInfo.physicalMemory)
        // Approximate used memory via host statistics is more complex; use a conservative public approach.
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        var used: Int64 = 0
        if result == KERN_SUCCESS {
            let pageSize = Int64(vm_kernel_page_size)
            let active = Int64(stats.active_count) * pageSize
            let wired = Int64(stats.wire_count) * pageSize
            let compressed = Int64(stats.compressor_page_count) * pageSize
            used = active + wired + compressed
        }

        return SystemStatsSnapshot(
            diskFreeBytes: free,
            diskTotalBytes: total,
            memoryUsedBytes: used,
            memoryTotalBytes: memTotal
        )
    }
}
