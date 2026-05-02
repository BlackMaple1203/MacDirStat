import SwiftUI

struct TreemapRenderer {

    // Visual gap between sibling arcs (radians)
    private static let padAngle: Double = 0.006

    static func draw(
        cells: [TreemapCell],
        hoveredNode: FSNode?,
        selectedNode: FSNode?,
        highlightedExtension: String?,
        duplicatesReady: Bool,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        for cell in cells {
            let arcSpan = cell.endAngle - cell.startAngle
            guard arcSpan > padAngle * 2 else { continue }

            let isHovered  = cell.node.id == hoveredNode?.id
            let isSelected = cell.node.id == selectedNode?.id
            let isDimmed   = highlightedExtension != nil && cell.node.fileExtension != highlightedExtension
            let isDuplicate = duplicatesReady && cell.node.duplicateGroupID != nil

            let path = makePath(cell: cell, center: center)

            var fillColor = cell.color
            if isDimmed { fillColor = fillColor.opacity(0.12) }
            // directories slightly more opaque than files — squirreldisk style
            let baseOpacity: Double = cell.node.isDirectory ? 0.90 : 0.80
            if !isDimmed { fillColor = fillColor.opacity(baseOpacity) }

            context.fill(path, with: .color(fillColor))

            // Hover: bright white overlay
            if isHovered && !isDimmed {
                context.fill(path, with: .color(.white.opacity(0.18)))
            }

            // Subtle border
            if !isDimmed {
                context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 0.5)
            }

            // Duplicate dot
            if isDuplicate && !isDimmed {
                let r = cell.midRadius
                let cx = center.x + r * cos(cell.midAngle)
                let cy = center.y + r * sin(cell.midAngle)
                let dot = Path(ellipseIn: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5))
                context.fill(dot, with: .color(.white.opacity(0.75)))
            }

            // Selection glow
            if isSelected {
                var glowCtx = context
                glowCtx.addFilter(.shadow(color: .white.opacity(0.9), radius: 10, x: 0, y: 0))
                glowCtx.stroke(path, with: .color(.white), lineWidth: 2.0)
                context.stroke(path, with: .color(.white.opacity(0.95)), lineWidth: 1.5)
            }

            // Arc label
            if !isDimmed {
                drawLabel(context: &context, cell: cell, center: center)
            }
        }
    }

    // MARK: - Path construction

    /// Builds the annular-sector (donut-slice) path for one arc cell.
    static func makePath(cell: TreemapCell, center: CGPoint) -> Path {
        let pad = min(padAngle, (cell.endAngle - cell.startAngle) * 0.10)
        let s = cell.startAngle + pad
        let e = cell.endAngle - pad
        guard e > s else { return Path() }

        var path = Path()
        // Outer arc: clockwise=false goes screen-clockwise in SwiftUI's Y-down coord system
        path.addArc(center: center, radius: cell.outerRadius,
                    startAngle: .radians(s), endAngle: .radians(e), clockwise: false)
        // Inner arc: reverse direction to close the shape
        path.addArc(center: center, radius: cell.innerRadius,
                    startAngle: .radians(e), endAngle: .radians(s), clockwise: true)
        path.closeSubpath()
        return path
    }

    // MARK: - Labels

    private static func drawLabel(context: inout GraphicsContext, cell: TreemapCell, center: CGPoint) {
        // Only label arcs with enough visual space
        let arcLen = cell.arcLength
        let bandH  = cell.outerRadius - cell.innerRadius
        guard arcLen > 42 && bandH > 13 else { return }

        let r  = cell.midRadius
        let cx = center.x + r * cos(cell.midAngle)
        let cy = center.y + r * sin(cell.midAngle)
        let pt = CGPoint(x: cx, y: cy)
        let maxW = min(arcLen - 10, 110)

        var ctx = context
        ctx.addFilter(.shadow(color: .black.opacity(0.55), radius: 1.5, x: 0, y: 1))

        if arcLen > 80 && bandH > 28 {
            let nameText = ctx.resolve(
                Text(cell.node.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
            )
            let sizeText = ctx.resolve(
                Text(ByteFormatter.string(from: cell.node.size))
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
            )
            let ns = nameText.measure(in: CGSize(width: maxW, height: 20))
            let ss = sizeText.measure(in: CGSize(width: maxW, height: 16))
            guard ns.width <= maxW else { return }

            let gap: CGFloat = 2
            let blockH = ns.height + gap + ss.height
            ctx.draw(nameText, at: CGPoint(x: pt.x, y: pt.y - blockH / 2 + ns.height / 2), anchor: .center)
            if ss.width <= maxW {
                ctx.draw(sizeText, at: CGPoint(x: pt.x, y: pt.y + blockH / 2 - ss.height / 2), anchor: .center)
            }
        } else {
            let nameText = ctx.resolve(
                Text(cell.node.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white)
            )
            let ns = nameText.measure(in: CGSize(width: maxW, height: 20))
            guard ns.width <= maxW else { return }
            ctx.draw(nameText, at: pt, anchor: .center)
        }
    }

    // MARK: - Hit testing

    /// Returns the deepest arc cell under `point`.
    static func cell(at point: CGPoint, center: CGPoint, in cells: [TreemapCell]) -> TreemapCell? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let r  = sqrt(dx * dx + dy * dy)
        var angle = atan2(dy, dx)
        // Normalise to [-π/2, 3π/2] to match our arc angle range
        if angle < -.pi / 2 { angle += 2 * .pi }

        return cells.last { cell in
            r >= cell.innerRadius && r < cell.outerRadius &&
            angle >= cell.startAngle && angle < cell.endAngle
        }
    }

    static func isInCenter(point: CGPoint, center: CGPoint) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt(dx * dx + dy * dy) < TreemapLayout.centerRadius
    }
}
