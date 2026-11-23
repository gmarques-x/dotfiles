// Finder's sidebar Favourites: put folders right after the first one given, in order.
//   swift sidebar.swift /Applications ~ ~/Developer          arrange them
//   swift sidebar.swift --check /Applications ~ ~/Developer  only say what would change
// The first folder must already be a favourite (Applications is, on a new Mac); other
// favourites stay where they are. Does nothing when the order is already right.
// Uses the LSSharedFileList API: deprecated, but still the one Finder reads.
import CoreServices
import Foundation

var args = Array(CommandLine.arguments.dropFirst())
let check = args.first == "--check"
if check { args.removeFirst() }
let wanted = args.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
guard wanted.count > 1 else { exit(0) }

guard let list = LSSharedFileListCreate(nil, kLSSharedFileListFavoriteItems.takeUnretainedValue(), nil)?
  .takeRetainedValue() else { exit(1) }

func snapshot() -> [(item: LSSharedFileListItem, path: String?)] {
  var seed: UInt32 = 0
  let items = LSSharedFileListCopySnapshot(list, &seed)?.takeRetainedValue() as? [LSSharedFileListItem] ?? []
  return items.map { item in
    let url = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL?
    return (item, url?.standardizedFileURL.path)
  }
}

let paths = snapshot().map { $0.path ?? "" }
guard let start = paths.firstIndex(of: wanted[0]) else {
  FileHandle.standardError.write("\(wanted[0]) is not in the sidebar\n".data(using: .utf8)!)
  exit(1)
}
if Array(paths[start...].prefix(wanted.count)) == wanted {
  if check { print("already in order") }
  exit(0)
}
if check {
  print("would place after \(wanted[0]): \(wanted.dropFirst().joined(separator: ", "))")
  exit(0)
}

// Each folder goes right after the one before it (never at "the top": that
// marker can't be passed safely from Swift).
var anchor = snapshot()[start].item
for path in wanted.dropFirst() {
  for entry in snapshot() where entry.path == path {
    LSSharedFileListItemRemove(list, entry.item)
  }
  guard let added = LSSharedFileListInsertItemURL(list, anchor, nil, nil,
                                                  URL(fileURLWithPath: path) as CFURL, nil, nil) else { exit(1) }
  anchor = added
}
