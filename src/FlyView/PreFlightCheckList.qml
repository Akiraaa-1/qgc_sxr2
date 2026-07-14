import QtQuick
import QtQuick.Controls
import QtQml.Models
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

ColumnLayout {
    spacing: ScreenTools.defaultFontPixelHeight * 0.55

    property real _verticalMargin: ScreenTools.defaultFontPixelHeight / 2

    Loader {
        id:     modelContainer
        source: "qrc:/qml/QGroundControl/FlyView/DefaultChecklist.qml"
    }

    property bool allChecksPassed:  false
    property var  vehicleCopy:      globals.activeVehicle

    onVehicleCopyChanged: {
        if (checkListRepeater.model) {
            checkListRepeater.model.reset()
        }
    }

    onAllChecksPassedChanged: {
        if (allChecksPassed) {
            globals.activeVehicle.checkListState = Vehicle.CheckListPassed
        } else {
            globals.activeVehicle.checkListState = Vehicle.CheckListFailed
        }
    }

    function _handleGroupPassedChanged(index, passed) {
        if (passed) {
            // Collapse current group
            var group = checkListRepeater.itemAt(index)
            group._checked = false
            // Expand next group
            if (index + 1 < checkListRepeater.count) {
                group = checkListRepeater.itemAt(index + 1)
                group.enabled = true
                group._checked = true
            }
        }

        // Walk the list and check if any group is failing
        var allPassed = true
        for (var i=0; i < checkListRepeater.count; i++) {
            if (!checkListRepeater.itemAt(i).passed) {
                allPassed = false
                break
            }
        }
        allChecksPassed = allPassed;
    }

    //-- Pick a checklist model that matches the current airframe type (if any)
    function _updateModel() {
        var vehicle = globals.activeVehicle
        if (!vehicle) {
            vehicle = QGroundControl.multiVehicleManager.offlineEditingVehicle
        }

        if(vehicle.multiRotor) {
            modelContainer.source = "qrc:/qml/QGroundControl/FlyView/MultiRotorChecklist.qml"
        } else if(vehicle.vtol) {
            modelContainer.source = "qrc:/qml/QGroundControl/FlyView/VTOLChecklist.qml"
        } else if(vehicle.rover) {
            modelContainer.source = "qrc:/qml/QGroundControl/FlyView/RoverChecklist.qml"
        } else if(vehicle.sub) {
            modelContainer.source = "qrc:/qml/QGroundControl/FlyView/SubChecklist.qml"
        } else if(vehicle.fixedWing) {
            modelContainer.source = "qrc:/qml/QGroundControl/FlyView/FixedWingChecklist.qml"
        } else {
            modelContainer.source = "qrc:/qml/QGroundControl/FlyView/DefaultChecklist.qml"
        }
        return
    }

    Component.onCompleted: {
        _updateModel()
    }

    onVisibleChanged: {
        if(globals.activeVehicle) {
            if(visible) {
                _updateModel()
            }
        }
    }

    // We delay the updates when a group passes so the user can see all items green for a moment prior to hiding
    Timer {
        id:         delayedGroupPassed
        interval:   750

        property int index

        onTriggered: _handleGroupPassedChanged(index, true /* passed */)
    }

    function groupPassedChanged(index, passed) {
        if (passed) {
            delayedGroupPassed.index = index
            delayedGroupPassed.restart()
        } else {
            _handleGroupPassedChanged(index, passed)
        }
    }

    // Header/title of checklist
    RowLayout {
        Layout.fillWidth:   true
        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
        spacing:            ScreenTools.defaultFontPixelWidth * 0.55

        QGCLabel {
            Layout.fillWidth:   true
            text:               allChecksPassed ? qsTr("检查已通过") : qsTr("检查进行中")
            color:              allChecksPassed ? "#9BCF89" : "#F0F3EA"
            font.weight:        Font.DemiBold
            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.74
            verticalAlignment:  Text.AlignVCenter
        }
        Rectangle {
            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.65
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.65
            Layout.alignment:   Qt.AlignVCenter
            color:              resetMouseArea.pressed ? "#222720" : (resetMouseArea.containsMouse ? "#30362F" : "#272B28")
            radius:             ScreenTools.defaultFontPixelHeight * 0.24
            border.width:       1
            border.color:       "#454B45"

            QGCColoredImage {
                anchors.centerIn: parent
                width:          parent.height * 0.52
                height:         width
                source:         "/qmlimages/MapSyncBlack.svg"
                color:          "#F0F3EA"
                fillMode:       Image.PreserveAspectFit
            }

            QGCMouseArea {
                id: resetMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: checkListRepeater.model.reset()
            }
        }
    }

    // All check list items
    Repeater {
        id:     checkListRepeater
        model:  modelContainer.item.model
    }
}
