import KomentCore
import SwiftUI

struct Theme {
    struct ColumnWidth {
        let minimum: CGFloat
        let ideal: CGFloat
        let maximum: CGFloat
    }

    enum Density {
        case wide
        case compact
        case narrow

        var isCompact: Bool {
            self != .wide
        }
    }

    let cardRadius: CGFloat = 22
    let boxRadius: CGFloat = 12
    let tabRadius: CGFloat = 9

    let hairGap: CGFloat = 2
    let tightGap: CGFloat = 4
    let smallGap: CGFloat = 7
    let gap: CGFloat = 10
    let wideGap: CGFloat = 16
    let gutter: CGFloat = 18
    let cardInset: CGFloat = 18
    let titlebarInset: CGFloat = 30

    let panelWidth: CGFloat = 440
    let panelMinimumWidth: CGFloat = 360
    let panelMinimumHeight: CGFloat = 240
    let panelGap: CGFloat = 10
    let panelBottomInset: CGFloat = 28
    let noteMinimumHeight: CGFloat = 96
    let snippetLines = 2
    let detailHeight: CGFloat = 176
    let compactDetailHeight: CGFloat = 150
    let commentsMinimumHeight: CGFloat = 300
    let terminalMinimumHeight: CGFloat = 160
    let terminalHeight: CGFloat = 280
    let gripHeight: CGFloat = 13
    let gripWidth: CGFloat = 44
    let gripThickness: CGFloat = 4
    let dotSize: CGFloat = 7
    let closeGlyph: CGFloat = 8
    let searchWidth: CGFloat = 250
    let searchMinimumWidth: CGFloat = 110
    let tabMinimumWidth: CGFloat = 96
    let tabMaximumWidth: CGFloat = 190
    let emptyWidth: CGFloat = 380
    let windowWidth: CGFloat = 1020
    let windowHeight: CGFloat = 760
    let windowMinimumWidth: CGFloat = 480
    let windowMinimumHeight: CGFloat = 480
    let compactWidth: CGFloat = 940
    let narrowWidth: CGFloat = 720
    let sheetWidth: CGFloat = 560
    let sheetMinimumWidth: CGFloat = 380
    let sheetNoteHeight: CGFloat = 180
    let readingWidth: CGFloat = 620
    let readingHeight: CGFloat = 660
    let readingMinimumWidth: CGFloat = 440
    let readingMinimumHeight: CGFloat = 320

    let whenColumn = ColumnWidth(minimum: 86, ideal: 112, maximum: 140)
    let statusColumn = ColumnWidth(minimum: 70, ideal: 82, maximum: 110)
    let projectColumn = ColumnWidth(minimum: 96, ideal: 150, maximum: 260)
    let appColumn = ColumnWidth(minimum: 68, ideal: 100, maximum: 150)
    let fileColumn = ColumnWidth(minimum: 130, ideal: 230, maximum: 420)
    let narrowFileColumn = ColumnWidth(minimum: 96, ideal: 150, maximum: 300)

    let heading = Font.system(size: 16, weight: .semibold)
    let title = Font.system(size: 13, weight: .semibold)
    let body = Font.system(size: 13)
    let strongBody = Font.system(size: 13, weight: .medium)
    let label = Font.system(size: 11, weight: .medium)
    let caption = Font.system(size: 11)
    let mono = Font.system(size: 12, design: .monospaced)
    let monoStrong = Font.system(size: 12, weight: .semibold, design: .monospaced)
    let monoSmall = Font.system(size: 10, design: .monospaced)
    let monoTiny = Font.system(size: 9, design: .monospaced)

    let warn = Color.orange
    let good = Color.green
    let bad = Color.red
    let accent = Color.accentColor
    let softFill = 0.3
    let chipTint = 0.26

    let morph = Animation.smooth(duration: 0.3)
    let snap = Animation.snappy(duration: 0.18)

    func density(for width: CGFloat) -> Density {
        if width < narrowWidth { return .narrow }
        if width < compactWidth { return .compact }
        return .wide
    }

    func tint(_ status: CommentStatus) -> Color {
        switch status {
        case .open: return warn
        case .drifted: return bad
        case .resolved: return good
        }
    }
}

extension EnvironmentValues {
    @Entry var theme = Theme()
}
