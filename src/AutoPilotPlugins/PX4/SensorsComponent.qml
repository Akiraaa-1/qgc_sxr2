import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.AutoPilotPlugins.PX4

SetupPage {
    centerPageLoader: true
    pageComponent:  pageComponent
    Component {
        id: pageComponent

        Item {
            id: sensorsPageRoot
            width: availableWidth
            height: availableHeight
            property bool _qgcPopupChrome: true
            property real _margins: ScreenTools.defaultFontPixelHeight

            property alias sectionNameFilter: sensorsSetup.sectionNameFilter

            function sectionVisible(name) {
                return sensorsSetup.sectionVisible(name)
            }

            Rectangle {
                anchors.fill: parent
                color: "#202020"
                border.width: 1
                border.color: "#333333"
                radius: 8
            }

            Rectangle {
                id: sensorsCard
                width: Math.max(0, parent.width - sensorsPageRoot._margins * 2)
                height: Math.max(0, parent.height - sensorsPageRoot._margins * 2)
                anchors.centerIn: parent
                color: "#2D2D2D"
                border.width: 1
                border.color: "#333333"
                radius: 8

                SensorsSetup {
                    id: sensorsSetup
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                    useDarkStyle: true
                }
            }
        }
    }
}
