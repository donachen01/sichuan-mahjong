#!/usr/bin/env swift
import Foundation
import Vision
import ImageIO

struct Record: Codable {
    let file: String
    let text: [String]
}

guard CommandLine.arguments.count == 3 else {
    fputs("usage: ocr_subtitles.swift FRAME_DIR OUTPUT_JSON\n", stderr)
    exit(2)
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let files = try FileManager.default.contentsOfDirectory(at: directory,
    includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "jpg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
var records: [Record] = []

for file in files {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "en-US"]
    request.usesLanguageCorrection = true
    // Teaching captions are normally in the lower two thirds; retain the whole
    // frame so Mahjong UI labels can corroborate the narration.
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    records.append(Record(file: file.lastPathComponent, text: lines))
}

let data = try JSONEncoder().encode(records)
try data.write(to: output, options: .atomic)
print("OCR records: \(records.count)")
