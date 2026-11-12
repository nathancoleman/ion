// Lifts the main subject out of a photo with Vision and writes a transparent PNG.
// Usage: swift tools/cutout.swift <input.jpg> <output.png> [instance indexes, e.g. 1,2]
import AppKit
import CoreImage
import Vision

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: cutout <in> <out.png> [instances]")
    exit(1)
}
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])

let handler = VNImageRequestHandler(url: input)
let request = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([request])
guard let result = request.results?.first else {
    print("no subject found")
    exit(1)
}
print("instances:", result.allInstances.map { $0 })
var instances = result.allInstances
if args.count >= 4, !args[3].hasPrefix("--") {
    instances = IndexSet(args[3].split(separator: ",").compactMap { Int($0) })
}
// --full keeps the original frame size (needed to pair the cutout with its
// source photo, e.g. to recover the ground shadow).
let full = CommandLine.arguments.contains("--full")
let buffer = try result.generateMaskedImage(
    ofInstances: instances, from: handler, croppedToInstancesExtent: !full
)
let image = CIImage(cvPixelBuffer: buffer)
let context = CIContext()
try context.writePNGRepresentation(
    of: image, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
)
print("wrote", output.path, image.extent.size)
