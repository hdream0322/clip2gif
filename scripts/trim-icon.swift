#!/usr/bin/env swift
// Trims fully/near transparent padding around an icon's artwork and rescales
// the cropped content to fill a square canvas (preserving aspect ratio).
//
// Usage: swift scripts/trim-icon.swift <in.png> <out.png> [canvas=1024] [marginPct=0]
//   marginPct: optional transparent safe margin as % of canvas (e.g. 4 for a
//              subtle macOS-style inset). 0 = edge-to-edge fill.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: trim-icon.swift <in.png> <out.png> [canvas] [marginPct]\n".data(using: .utf8)!)
    exit(2)
}
let inPath = args[1]
let outPath = args[2]
let canvas = args.count > 3 ? Int(args[3]) ?? 1024 : 1024
let marginPct = args.count > 4 ? Double(args[4]) ?? 0 : 0
let alphaThreshold: UInt8 = 16   // treat alpha <= this as transparent

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write("cannot read \(inPath)\n".data(using: .utf8)!); exit(1)
}
let w = img.width, h = img.height
let bytesPerRow = w * 4
var buf = [UInt8](repeating: 0, count: bytesPerRow * h)
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: bytesPerRow, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write("cannot create context\n".data(using: .utf8)!); exit(1)
}
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

var minX = w, minY = h, maxX = -1, maxY = -1
for y in 0..<h {
    for x in 0..<w {
        let a = buf[y * bytesPerRow + x * 4 + 3]
        if a > alphaThreshold {
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
    }
}
guard maxX >= minX, maxY >= minY else {
    FileHandle.standardError.write("image is fully transparent\n".data(using: .utf8)!); exit(1)
}
let cw = maxX - minX + 1, ch = maxY - minY + 1
let pctW = Double(cw) / Double(w) * 100, pctH = Double(ch) / Double(h) * 100
FileHandle.standardError.write(
  String(format: "content bbox: x=%d y=%d %dx%d (%.1f%% x %.1f%% of %dx%d)\n",
         minX, minY, cw, ch, pctW, pctH, w, h).data(using: .utf8)!)

// CoreGraphics origin is bottom-left; convert the top-left bbox.
let cropRect = CGRect(x: minX, y: h - maxY - 1, width: cw, height: ch)
guard let cropped = img.cropping(to: cropRect) else {
    FileHandle.standardError.write("crop failed\n".data(using: .utf8)!); exit(1)
}

let margin = Double(canvas) * marginPct / 100.0
let avail = Double(canvas) - 2 * margin
let scale = avail / Double(max(cw, ch))     // fill: longest side -> avail, keep aspect
let dw = Double(cw) * scale, dh = Double(ch) * scale
let ox = (Double(canvas) - dw) / 2.0, oy = (Double(canvas) - dh) / 2.0

guard let out = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write("cannot create out context\n".data(using: .utf8)!); exit(1)
}
out.interpolationQuality = .high
out.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))
out.draw(cropped, in: CGRect(x: ox, y: oy, width: dw, height: dh))

guard let result = out.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write("cannot write \(outPath)\n".data(using: .utf8)!); exit(1)
}
CGImageDestinationAddImage(dest, result, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write("finalize failed\n".data(using: .utf8)!); exit(1)
}
FileHandle.standardError.write(
  String(format: "wrote %@ (%dx%d, content scaled to %.0fx%.0f, margin %.1f%%)\n",
         outPath, canvas, canvas, dw, dh, marginPct).data(using: .utf8)!)
