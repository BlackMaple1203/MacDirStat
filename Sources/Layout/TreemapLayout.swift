import SwiftUI

public struct TreemapLayout {

    public static func compute(root: FSNode, in rect: CGRect, colorMap: ExtensionColorMap) -> [TreemapCell] {
        var cells: [TreemapCell] = []
        guard rect.width > 1, rect.height > 1, root.size > 0 else { return cells }
        let children = root.children.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !children.isEmpty else { return cells }
        let totalSize = Double(root.size)
        let pixelArea = Double(rect.width) * Double(rect.height)
        let areas = children.map { Double($0.size) / totalSize * pixelArea }
        squarify(areas: areas[...], nodes: children[...], row: [], rowNodes: [], rect: rect, depth: 0, colorMap: colorMap, cells: &cells)
        return cells
    }

    private static func squarify(
        areas: ArraySlice<Double>,
        nodes: ArraySlice<FSNode>,
        row: [Double],
        rowNodes: [FSNode],
        rect: CGRect,
        depth: Int,
        colorMap: ExtensionColorMap,
        cells: inout [TreemapCell]
    ) {
        guard rect.width > 1, rect.height > 1 else { return }

        if areas.isEmpty {
            if !row.isEmpty {
                layoutRow(row: row, rowNodes: rowNodes, rect: rect, depth: depth, colorMap: colorMap, cells: &cells)
            }
            return
        }

        let w = min(rect.width, rect.height)
        let candidate = row + [areas.first!]

        if row.isEmpty || worst(candidate, w: Double(w)) <= worst(row, w: Double(w)) {
            squarify(areas: areas.dropFirst(), nodes: nodes.dropFirst(),
                     row: candidate, rowNodes: rowNodes + [nodes.first!],
                     rect: rect, depth: depth, colorMap: colorMap, cells: &cells)
        } else {
            layoutRow(row: row, rowNodes: rowNodes, rect: rect, depth: depth, colorMap: colorMap, cells: &cells)
            let remaining = cutRect(row: row, from: rect)
            squarify(areas: areas, nodes: nodes, row: [], rowNodes: [],
                     rect: remaining, depth: depth, colorMap: colorMap, cells: &cells)
        }
    }

    private static func worst(_ row: [Double], w: Double) -> Double {
        guard !row.isEmpty, w > 0 else { return .infinity }
        let s = row.reduce(0, +)
        guard s > 0, let rmax = row.max(), let rmin = row.min(), rmin > 0 else { return .infinity }
        return max(w * w * rmax / (s * s), s * s / (w * w * rmin))
    }

    private static func layoutRow(
        row: [Double],
        rowNodes: [FSNode],
        rect: CGRect,
        depth: Int,
        colorMap: ExtensionColorMap,
        cells: inout [TreemapCell]
    ) {
        let s = row.reduce(0, +)
        guard s > 0 else { return }

        let isWide = rect.width >= rect.height
        let stripThickness = CGFloat(s) / (isWide ? rect.width : rect.height)
        var offset: CGFloat = isWide ? rect.minX : rect.minY

        for (area, node) in zip(row, rowNodes) {
            let itemLength = CGFloat(area) / CGFloat(s) * (isWide ? rect.width : rect.height)
            let itemRect: CGRect = isWide
                ? CGRect(x: offset, y: rect.minY, width: itemLength, height: stripThickness)
                : CGRect(x: rect.minX, y: offset, width: stripThickness, height: itemLength)
            offset += itemLength

            guard itemRect.width > 1, itemRect.height > 1 else { continue }

            if node.isDirectory && !node.children.isEmpty {
                let dirChildren = node.children.filter { $0.size > 0 }.sorted { $0.size > $1.size }
                let totalSize = Double(node.size)
                let childArea = Double(itemRect.width) * Double(itemRect.height)
                let childAreas = dirChildren.map { Double($0.size) / totalSize * childArea }
                squarify(areas: childAreas[...], nodes: dirChildren[...], row: [], rowNodes: [],
                         rect: itemRect, depth: depth + 1, colorMap: colorMap, cells: &cells)
            } else {
                cells.append(TreemapCell(node: node, rect: itemRect, color: colorMap.color(for: node.fileExtension), depth: depth))
            }
        }
    }

    private static func cutRect(row: [Double], from rect: CGRect) -> CGRect {
        let s = row.reduce(0, +)
        guard s > 0 else { return rect }
        let isWide = rect.width >= rect.height
        let thickness = CGFloat(s) / (isWide ? rect.width : rect.height)
        return isWide
            ? CGRect(x: rect.minX, y: rect.minY + thickness, width: rect.width, height: max(0, rect.height - thickness))
            : CGRect(x: rect.minX + thickness, y: rect.minY, width: max(0, rect.width - thickness), height: rect.height)
    }
}
