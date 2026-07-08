import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

Rectangle {
    id:     outerEditorRect
    height: innerEditorRect.y + innerEditorRect.height + (_margin * 2)
    radius: theme.radius
    color:  theme.panelColor
    border.width: 1
    border.color: theme.borderColor

    property var controller ///< RallyPointController
    property real uiScale: 1.0

    readonly property real  _margin: ScreenTools.defaultFontPixelWidth * uiScale / 2
    readonly property real  _radius: ScreenTools.defaultFontPixelWidth * uiScale / 2

    PlanEditorTheme { id: theme }

    QGCLabel {
        id:                 editorLabel
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.top:        parent.top
        text:               qsTr("Rally Points")
        color:              theme.textColor
    }

    Rectangle {
        id:                 innerEditorRect
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        editorLabel.bottom
        height:             infoLabel.height + (_margin * 2)
        color:              theme.inputColor
        radius:             theme.radius
        border.width:       1
        border.color:       theme.borderColor

        QGCLabel {
            id:                 infoLabel
            anchors.margins:    _margin
            anchors.top:        parent.top
            anchors.left:       parent.left
            anchors.right:      parent.right
            wrapMode:           Text.WordWrap
            font.pointSize:     ScreenTools.smallFontPointSize * outerEditorRect.uiScale
            text:               qsTr("Rally Points provide alternate landing points when performing a Return to Launch (RTL).")
            color:              theme.secondaryTextColor
        }
    }
}
