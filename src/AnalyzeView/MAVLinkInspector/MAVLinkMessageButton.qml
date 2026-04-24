import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Button {
    id:                 control
    autoExclusive:      true
    leftPadding:        ScreenTools.defaultFontPixelWidth
    rightPadding:       leftPadding

    AnalyzePalette { id: analyzePalette }

    property real _compIDWidth: ScreenTools.defaultFontPixelWidth * 3
    property real _hzWidth:     ScreenTools.defaultFontPixelWidth * 6
    property real _nameWidth:   nameLabel.contentWidth

    background: Rectangle {
        anchors.fill:   parent
        radius:         analyzePalette.cornerRadius
        border.width:   analyzePalette.borderWidth
        border.color:   checked ? analyzePalette.accent : analyzePalette.border
        color:          checked ? analyzePalette.accent : (control.pressed ? analyzePalette.surfacePressed : (control.hovered ? analyzePalette.surfaceHover : analyzePalette.surface))

        Behavior on color { ColorAnimation { duration: analyzePalette.transitionDuration } }
        Behavior on border.color { ColorAnimation { duration: analyzePalette.transitionDuration } }
    }

    property double messageHz:  0
    property int    compID:     0

    contentItem: RowLayout {
        id:         rowLayout
        spacing:    ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text:                   control.compID
            color:                  checked ? analyzePalette.textPrimary : analyzePalette.textSecondary
            verticalAlignment:      Text.AlignVCenter
            Layout.minimumHeight:   ScreenTools.isMobile ? (ScreenTools.defaultFontPixelHeight * 2) : (ScreenTools.defaultFontPixelHeight * 1.5)
            Layout.minimumWidth:    _compIDWidth
        }
        QGCLabel {
            id:                     nameLabel
            text:                   control.text
            color:                  checked ? analyzePalette.textPrimary : analyzePalette.textSecondary
            Layout.fillWidth:       true
            Layout.alignment:       Qt.AlignVCenter
        }
        QGCLabel {
            color:                  checked ? analyzePalette.textPrimary : analyzePalette.textSecondary
            text:                   messageHz.toFixed(1) + 'Hz'
            horizontalAlignment:    Text.AlignRight
            Layout.minimumWidth:    _hzWidth
            Layout.alignment:       Qt.AlignVCenter
        }
    }

    Component.onCompleted: maxButtonWidth = Math.max(maxButtonWidth, _compIDWidth + _hzWidth + _nameWidth + (rowLayout.spacing * 2) + (control.leftPadding * 2))
}
