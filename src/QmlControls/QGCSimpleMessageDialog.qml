import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    id: root

    QGCPopupStyle { id: popupStyle }

    property string text:           ""
    property var    acceptFunction: null        // Mainly used by MainRootWindow.showMessage to specify accept function in call
    property var    closeFunction:  null

    function localizedText(message) {
        let localizedMessage = message || ""
        const replacements = [
            { "pattern": /Switching communication to secondary link\./gi, "text": qsTr("正在切换通信到备用链路。") },
            { "pattern": /Switching communication to new primary link/gi, "text": qsTr("正在切换通信到新的主链路") },
            { "pattern": /Communication regained on primary link/gi, "text": qsTr("主链路通信已恢复") },
            { "pattern": /Communication regained on secondary link/gi, "text": qsTr("备用链路通信已恢复") },
            { "pattern": /Communication regained/gi, "text": qsTr("通信已恢复") },
            { "pattern": /Communication lost on primary link\./gi, "text": qsTr("主链路通信丢失。") },
            { "pattern": /Communication lost on secondary link\./gi, "text": qsTr("备用链路通信丢失。") }
        ]

        for (let i = 0; i < replacements.length; i++) {
            localizedMessage = localizedMessage.replace(replacements[i].pattern, replacements[i].text)
        }
        return localizedMessage
    }

    showTitleAccent: true
    useExplicitActionColors: true
    actionPrimaryBackgroundColor: "#9EC6D2"
    actionPrimaryBorderColor:     "#9EC6D2"
    actionPrimaryTextColor:       "#111827"
    actionSecondaryBackgroundColor: "#252A2F"
    actionSecondaryBorderColor:     "#3A4048"
    actionSecondaryTextColor:       "#E5E7EB"
    actionButtonRadius: ScreenTools.defaultFontPixelHeight * 0.28

    onAccepted: {
        if (acceptFunction) {
            acceptFunction()
        }
    }

    onClosed: {
        if (closeFunction) {
            closeFunction()
        }
    }

    ColumnLayout {
        spacing: ScreenTools.defaultFontPixelHeight * 0.65

        Rectangle {
            Layout.preferredWidth: Math.max(mainWindow.width / (ScreenTools.isMobile ? 2 : 3), headerMinWidth)
            Layout.preferredHeight: label.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.35)
            color: Qt.rgba(0.11, 0.13, 0.15, 0.86)
            radius: ScreenTools.defaultFontPixelHeight * 0.34
            border.width: 1
            border.color: "#343A42"

            QGCLabel {
                id:                     label
                anchors.fill:           parent
                anchors.margins:        ScreenTools.defaultFontPixelHeight * 0.65
                wrapMode:               Text.WordWrap
                color:                  "#C8D1DC"
                lineHeight:             1.12
                lineHeightMode:         Text.ProportionalHeight
                text:                   root.localizedText(root.text)
            }
        }
    }
}
