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

            var color = cell.color
            if isDimmed { color = color.opacity(0.25) }

            // Fill cell
            context.fill(Path(cell.rect), with: .color(color))

            // Duplicate stripe overlay
            if isDuplicate {
                context.drawLayer { ctx in
                    ctx.clip(to: Path(cell.rect))
                    var x = cell.rect.minX
                    while x < cell.rect.maxX + cell.rect.height {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: cell.rect.minY))
                        path.addLine(to: CGPoint(x: x - cell.rect.height, y: cell.rect.maxY))
                        ctx.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 2)
                        x += 6
                    }
                }
            }

            // Selection ring
            if isSelected {
                let ringRect = cell.rect.insetBy(dx: 1.5, dy: 1.5)
                context.stroke(Path(ringRect), with: .color(.white), lineWidth: 2.5)
                context.stroke(Path(cell.rect), with: .color(.black.opacity(0.6)), lineWidth: 1)
            }

            // Label for large enough cells
            if cell.rect.width > 40 && cell.rect.height > 18 {
                let resolved = context.resolve(Text(cell.node.name).font(.system(size: 10)).foregroundStyle(.white))
                let textSize = resolved.measure(in: cell.rect.size)
                if textSize.width < cell.rect.width - 4 {
                    context.draw(resolved, at: CGPoint(x: cell.rect.midX, y: cell.rect.midY), anchor: .center)
                }
            }
        }
    }

    static func cell(at point: CGPoint, in cells: [TreemapCell]) -> TreemapCell? {
        cells.last(where: { $0.rect.contains(point) })
    }
}
