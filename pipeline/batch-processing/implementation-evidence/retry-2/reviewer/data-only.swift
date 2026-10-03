import Foundation
import Darwin
func sample(_ label: String) {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { p in
        p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    print("ISOLATION \(label) status=\(status) footprint=\(info.phys_footprint)")
    fflush(stdout)
}
let mode=CommandLine.arguments[1]
sample("baseline")
for item in 1...6 {
    autoreleasepool {
        var data = mode == "count" ? Data(count:96000000) : Data(bytesNoCopy:calloc(96000000,1)!,count:96000000,deallocator:.free)
        data.withUnsafeMutableBytes { b in
            memset(b.baseAddress!,17,b.count)
            print("BUFFER \(item) \(b.baseAddress!)")
        }
        precondition(data[42] == 17)
    }
    sample("item=\(item)")
}
