//
//  main.swift
//  Wally
//
//  Created by George Sofianos on 24/1/22.
//

import Foundation
import SQLite


let DESKTOPPICTURE_DB_RELPATH = "Library/Application Support/Dock/desktoppicture.db"

enum Errors: Error {
    case fileNotExists(String)
    case sqliteDatabase(String)
}


/// Returns an absolute path for the given file path.
///
/// The "~" prefix, is expanded to the current user home directory path.
///
/// - Parameters:
///   - path: A given file path string.
/// - Returns: An absolute path string.
func getAbsolutePath(_ path: String) throws -> String {
    let absoluteImagePath: String
    if path.hasPrefix("/") {
        absoluteImagePath = path
    } else if path.hasPrefix("~") {
        absoluteImagePath = "\(FileManager.default.homeDirectoryForCurrentUser)/\(path)"
    } else {
        absoluteImagePath =  "\(FileManager.default.currentDirectoryPath)/\(path)"
    }


    if (!FileManager.default.fileExists(atPath: absoluteImagePath)) {
        throw Errors.fileNotExists("Provided file does not exist")
    }

    return absoluteImagePath
}

/// Updates SQLite desktoppicture.db to add a reference to the wallpaper and update user preferences.
///
/// - Parameters:
///   - imagePath: Path to the image to use set as wallpaper across virtual desktops.
func updateDesktopPictureDbWith(_ imagePath: String) throws {
    let userHomePath = FileManager.default.homeDirectoryForCurrentUser
    let db = try Connection("\(userHomePath)\(DESKTOPPICTURE_DB_RELPATH)")

    do {
        try db.savepoint {
            let dataTable = Table("data")
            let picturesTable = Table("pictures")
            let preferencesTable = Table("preferences")
            let value = Expression<String?>("value")

            try db.run(dataTable.delete())
            try db.run(preferencesTable.delete())

            let dataId = try db.run(dataTable.insert(value <- imagePath))

            for (index,_) in try db.prepare(picturesTable).enumerated() {
                let keyCol = Expression<Int>("key")
                let dataIdCol = Expression<Int64>("data_id");
                let pictureIdCol = Expression<Int64>("picture_id");
                try db.run(preferencesTable.insert(keyCol <- 1, dataIdCol <- dataId, pictureIdCol <- Int64(index+1)))
            }
        }
    } catch {
        throw Errors.sqliteDatabase("Could not update desktoppicture.db")
    }
}


/// Restarts macOS dock process to propagate db changes.
///
func restartMacOSDock() {
    let task = Process()
    task.launchPath = "/usr/bin/killall"
    task.arguments = ["Dock"]
    task.launch()
    task.waitUntilExit()
}


func main(args: [String]) {
    if args.count != 2 {
        print("usage: wally path/to/image.jpg")
        exit(1)
    }

    do {
        let imagePath = try getAbsolutePath(args[1])
        try updateDesktopPictureDbWith(imagePath)
        restartMacOSDock()
    } catch {
        print(error)
        exit(1)
    }
}

main(args: CommandLine.arguments)
