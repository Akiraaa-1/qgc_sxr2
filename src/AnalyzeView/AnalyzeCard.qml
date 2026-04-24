import QtQuick

Rectangle {
    AnalyzePalette { id: analyzePalette }

    radius:         analyzePalette.cornerRadius
    color:          analyzePalette.surface
    border.width:   analyzePalette.borderWidth
    border.color:   analyzePalette.border
}
