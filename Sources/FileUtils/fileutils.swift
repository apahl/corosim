import Foundation
// swift doc generate . -n FileUtils -o docs -f html

/// Writes a text blob (String) to file. Convenience wrapper
/// Returns true, if the operation was successful, false otherwise
public func writeTextToFile(text: String, to fileName: String) -> Bool {
    FileManager().createFile(atPath: fileName, contents: "".data(using: .utf8))

    let file = FileHandle(forWritingAtPath: fileName)

    if file != nil {
        let data = text.data(using: .utf8)
        file!.write(data!)

        do {
            try file!.close()
        } catch { return false }
    } else {
        return false
    }
    return true
}

/// Writes a list of strings to a file, separated by newlines.
/// This convenience function should only be used for smallish lists.
/// Returns true, if the operation was successful, false otherwise.
public func writeListToFile(list: [String], to fileName: String) -> Bool {
    let text = list.joined(separator: "\n")
    return FileManager().createFile(atPath: fileName, contents: text.data(using: .utf8))
}
