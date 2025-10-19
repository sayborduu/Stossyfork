//
//  OGGDecoder.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation

func downloadAudioFile(from urlString: String, completion: @escaping (URL?) -> Void) {
    guard let url = URL(string: urlString) else {
        print("Invalid URL string.")
        completion(nil)
        return
    }

    let fileManager = FileManager.default
    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let identifier = UUID().uuidString

    let task = URLSession.shared.downloadTask(with: url) { tempLocalUrl, response, error in
        if let error {
            print("Failed to download file: \(error)")
            completion(nil)
            return
        }

        guard let tempLocalUrl else {
            print("No file URL.")
            completion(nil)
            return
        }

        let responseFilename = response?.suggestedFilename ?? ""
        let responseExtension = URL(fileURLWithPath: responseFilename).pathExtension
        let urlExtension = url.pathExtension
        let mimeExtension = extensionFromMime(response?.mimeType)

        let chosenExtension = [responseExtension, urlExtension, mimeExtension]
            .first { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) } ?? "tmp"

        let destinationURL = documentsDirectory.appendingPathComponent("\(identifier).\(chosenExtension)")

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: tempLocalUrl, to: destinationURL)
            print("File downloaded and saved to \(destinationURL)")
            completion(destinationURL)
        } catch {
            print("Failed to move file: \(error)")
            completion(nil)
        }
    }

    task.resume()
}

private func extensionFromMime(_ mimeType: String?) -> String {
    guard let mimeType else { return "" }
    switch mimeType.lowercased() {
    case "audio/ogg":
        return "ogg"
    case "audio/ogg; codecs=opus":
        return "ogg"
    case "audio/mp4", "audio/m4a", "audio/mp4a-latm", "audio/aac":
        return "m4a"
    case "audio/wav", "audio/x-wav":
        return "wav"
    default:
        return ""
    }
}

