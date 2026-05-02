import SwiftUI
import AppKit

private extension Color {
    func darkened(by fraction: Double) -> Color {
        guard fraction > 0 else { return self }
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: max(0, Double(b) - fraction), opacity: Double(a))
    }
}

public struct TreemapLayout {

    /// Radius of the empty center hole (shows current directory info)
    static let centerRadius: CGFloat = 76
    /// Max number of depth rings shown
    private static let maxDepth = 5
    /// Skip arcs smaller than this angle (avoids invisible slivers)
    private static let minArcAngle: Double = 0.018  // ~1.0°
    /// Darkening per depth level (squirreldisk-style, capped at 0.48)
    private static let depthDarken: [Double] = [0.0, 0.18, 0.30, 0.40, 0.48, 0.54]

    public static func compute(root: FSNode, in rect: CGRect, colorMap: ExtensionColorMap) -> [TreemapCell] {
        var cells: [TreemapCell] = []
        guard rect.width > 1, rect.height > 1, root.size > 0 else { return cells }

        let children = root.children.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !children.isEmpty else { return cells }

        // Compute band width so the sunburst fills the view
        let maxR = min(rect.width, rect.height) / 2 - 10
        guard maxR > centerRadius + 20 else { return cells }
        let bandW = (maxR - centerRadius) / CGFloat(maxDepth)

        // Assign a unique rainbow hue to each top-level child
        var topColors: [UUID: Color] = [:]
        let n = max(children.count, 1)
        for (i, child) in children.enumerated() {
            let hue = Double(i) / Double(n)
            topColors[child.id] = Color(hue: hue, saturation: 0.72, brightness: 0.92)
        }

        layout(children, parentStart: -.pi / 2, parentEnd: 1.5 * .pi,
               depth: 0, groupColor: nil, topColors: topColors,
               centerR: centerRadius, bandW: bandW, cells: &cells)
        return cells
    }

    private static func layout(
        _ children: [FSNode],
        parentStart: Double,
        parentEnd: Double,
        depth: Int,
        groupColor: Color?,
        topColors: [UUID: Color],
        centerR: CGFloat,
        bandW: CGFloat,
        cells: inout [TreemapCell]
    ) {
        guard depth < maxDepth else { return }

        let totalSize = children.reduce(Int64(0)) { $0 + $1.size }
        guard totalSize > 0 else { return }

        let totalAngle = parentEnd - parentStart
        let innerR = centerR + CGFloat(depth) * bandW
        // 3pt radial gap between bands (matches squirreldisk's `d.y1 * radius - 3`)
        let outerR = innerR + bandW - 3

        var angle = parentStart

        for child in children {
            let fraction = Double(child.size) / Double(totalSize)
            let arcAngle = fraction * totalAngle
            let arcEnd = angle + arcAngle

            guard arcAngle >= minArcAngle else { angle = arcEnd; continue }

            // Resolve color: top-level uses rainbow hue, children inherit parent hue with darkening
            let baseColor = groupColor ?? topColors[child.id] ?? Color(hue: 0, saturation: 0.72, brightness: 0.92)
            let darken = depth < depthDarken.count ? depthDarken[depth] : 0.54
            let cellColor = darken > 0 ? baseColor.darkened(by: darken) : baseColor

            cells.append(TreemapCell(
                node: child,
                startAngle: angle,
                endAngle: arcEnd,
                innerRadius: innerR,
                outerRadius: outerR,
                color: cellColor,
                depth: depth
            ))

            if child.isDirectory && !child.children.isEmpty {
                let sorted = child.children.filter { $0.size > 0 }.sorted { $0.size > $1.size }
                layout(sorted, parentStart: angle, parentEnd: arcEnd,
                       depth: depth + 1, groupColor: baseColor,
                       topColors: topColors, centerR: centerR, bandW: bandW, cells: &cells)
            }

            angle = arcEnd
        }
    }
}
