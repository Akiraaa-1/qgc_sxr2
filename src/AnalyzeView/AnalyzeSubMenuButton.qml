import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SubMenuButton {
    id: control

    AnalyzePalette { id: analyzePalette }

    hoverEnabled:            !ScreenTools.isMobile
    implicitHeight:          ScreenTools.defaultFontPixelHeight * 2.6
    implicitWidth:           contentRow.implicitWidth + (ScreenTools.defaultFontPixelWidth * 2)
    imageColor:              checked ? analyzePalette.textPrimary : analyzePalette.textSecondary

    background: Rectangle {
        radius:         analyzePalette.cornerRadius
        border.width:   analyzePalette.borderWidth
        border.color:   control.checked ? analyzePalette.accent : analyzePalette.border
        color:          control.pressed
                            ? analyzePalette.surfacePressed
                            : (control.hovered ? analyzePalette.surfaceHover : analyzePalette.surface)

        Behavior on color { ColorAnimation { duration: analyzePalette.transitionDuration } }
        Behavior on border.color { ColorAnimation { duration: analyzePalette.transitionDuration } }
    }

    contentItem: RowLayout {
        id: contentRow
        spacing:                    ScreenTools.defaultFontPixelWidth
        anchors.leftMargin:         ScreenTools.defaultFontPixelWidth
        anchors.rightMargin:        ScreenTools.defaultFontPixelWidth
        anchors.left:               parent.left
        anchors.right:              parent.right
        anchors.verticalCenter:     parent.verticalCenter

        QGCColoredImage {
            Layout.alignment:       Qt.AlignVCenter
            source:                 control.imageResource
            sourceSize:             control.sourceSize
            width:                  ScreenTools.defaultFontPixelHeight * 1.8
            height:                 width
            fillMode:               Image.PreserveAspectFit
            color:                  control.imageColor
        }

        QGCLabel {
            Layout.fillWidth:       true
            verticalAlignment:      Text.AlignVCenter
            text:                   control.text
            color:                  control.checked ? analyzePalette.textPrimary : analyzePalette.textSecondary
        }
    }
}
