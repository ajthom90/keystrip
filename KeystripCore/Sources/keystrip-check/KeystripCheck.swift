import Foundation
import KeystripCore

@main
struct KeystripCheck {
    static func main() {
        let arguments = CommandLine.arguments.dropFirst()
        let show = arguments.contains("--show")
        guard let path = arguments.first(where: { !$0.hasPrefix("--") }) else {
            print("usage: keystrip-check [--show] <file.dsi>")
            exit(2)
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let document = try DSIReader.read(data)
            var total = 0, identical = 0, unreadable = 0
            var mismatches: [(phone: String, field: Int, original: String, rewritten: String)] = []
            for phone in document.phones {
                for (fieldID, label) in phone.fields.sorted(by: { $0.key < $1.key }) {
                    total += 1
                    if label.isUnreadable {
                        unreadable += 1
                        print("  unreadable: phone \(phone.id) field \(fieldID)")
                        continue
                    }
                    let rewritten = RTFWriter.write(label.text)
                    if rewritten == label.originalRTF {
                        identical += 1
                    } else {
                        mismatches.append((phone.id, fieldID, label.originalRTF ?? "", rewritten))
                    }
                }
            }
            let noOpSave = try DSIWriter.write(document, previous: document, original: data)
            print("phones: \(document.phones.count)")
            print("labels: \(total), identical after rewrite: \(identical), mismatched: \(mismatches.count), unreadable: \(unreadable)")
            print("no-op save byte-identical: \(noOpSave == data)")
            for mismatch in mismatches {
                print("  mismatch: phone \(mismatch.phone) field \(mismatch.field)")
                if show {
                    print("    original:  \(mismatch.original)")
                    print("    rewritten: \(mismatch.rewritten)")
                }
            }
            exit(mismatches.isEmpty && unreadable == 0 && noOpSave == data ? 0 : 1)
        } catch {
            print("error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
