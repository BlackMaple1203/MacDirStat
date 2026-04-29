import SwiftUI

struct TreemapRenderer {

    static func draw(
        cells: [TreemapCell],
        selectedNode: FSNode?,
        highlightedExtension: String?,
        duplicatesReady: Bool,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        for cell in cells {
            let isSelected = cell.node.id == selectedNode?.id
            let isDimmed = highlightedExtension != nil && cell.node.fileExtension != highlightedExtension
            let isDuplicate = duplicatesReady && cell.node.duplicateGroupID != nil

            // 1.5pt gap between cells
            let drawRect = cell.rect.insetBy(dx: 1.5, dy: 1.5)
            guard drawRect.width > 1, drawRect.height > 1 else { continue }

            let radius = min(3.0, min(drawRect.width, drawRect.height) * 0.06)
            let cellPath = Path(roundedRect: drawRect, cornerRadius: radius)

            var color = cell.color
            if isDimmed { color = color.opacity(0.18) }

            // Base fill
            context.fill(cellPath, with: .color(color))

            // Top-left highlight for depth illusion
            if !isDimmed {
                context.stroke(cellPath, with: .color(.white.opacity(0.13)), lineWidth: 0.5)
            }

            // Duplicate stripe overlay
            if isDuplicate && !isDimmed {
                context.drawLayer { ctx in
                    ctx.clip(to: cellPath)
                    let spacing: CGFloat = 9
                    var x = drawRect.minX - drawRect.height
                    while x < drawRect.maxX + drawRect.height {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: drawRect.minY))
                        path.addLine(to: CGPoint(x: x + drawRect.height, y: drawRect.maxY))
                        ctx.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 2.5)
                        x += spacing
                    }
                }
            }

            // Selection: glow + bright ring
            if isSelected {
                let ringInset = drawRect.insetBy(dx: 1.5, dy: 1.5)
                let ringPath = Path(roundedRect: ringInset, cornerRadius: max(0, radius - 1.5))
                var glowCtx = context
                glowCtx.addFilter(.shadow(color: .white.opacity(0.85), radius: 6, x: 0, y: 0))
                glowCtx.stroke(ringPath, with: .color(.white), lineWidth: 2.5)
                context.stroke(ringPath, with: .color(.white), lineWidth: 2)
            }

            // Labels
            if !isDimmed {
                drawLabel(context: &context, node: cell.node, rect: drawRect)
            }
        }
    }

    private static func drawLabel(context: inout GraphicsContext, node: FSNode, rect: CGRect) {
        let w = rect.width, h = rect.height
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxTextWidth = w - 10

        if w > 100 && h > 48 {
            // Two-line: name + size
            let nameResolved = context.resolve(
                Text(node.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            )
            let sizeResolved = context.resolve(
                Text(ByteFormatter.string(from: node.size))
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.72))
            )

            let nameSize = nameResolved.measure(in: CGSize(width: maxTextWidth, height: h))
            let sizeSize = sizeResolved.measure(in: CGSize(width: maxTextWidth, height: h))
            guard nameSize.width <= maxTextWidth else { return }

            let gap: CGFloat = 3
            let blockH = nameSize.height + gap + sizeSize.height
            let nameY = center.y - blockH / 2 + nameSize.height / 2
            let sizeY = nameY + nameSize.height / 2 + gap + sizeSize.height / 2

            var ctx = context
            ctx.addFilter(.shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1))
            ctx.draw(nameResolved, at: CGPoint(x: center.x, y: nameY), anchor: .center)
            if sizeSize.width <= maxTextWidth {
                ctx.draw(sizeResolved, at: CGPoint(x: center.x, y: sizeY), anchor: .center)
            }

        } else if w > 48 && h > 20 {
            // One-line: name only
            let nameResolved = context.resolve(
                Text(node.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
            )
            let nameSize = nameResolved.measure(in: CGSize(width: maxTextWidth, height: h))
            guard nameSize.width <= maxTextWidth else { return }

            var ctx = context
            ctx.addFilter(.shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1))
            ctx.draw(nameResolved, at: center, anchor: .center)
        }
    }

    static func cell(at point: CGPoint, in cells: [TreemapCell]) -> TreemapCell? {
        cells.last(where: { $0.rect.contains(point) })
    }
}
