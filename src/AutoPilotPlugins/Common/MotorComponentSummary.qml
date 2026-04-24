import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight
    width: parent.width

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property int _motorCount: _activeVehicle ? _activeVehicle.motorCount : -1

    function _motorCountText() {
        if (_motorCount < 0) {
            return qsTr("Unknown")
        }

        if (_motorCount === 1) {
            return qsTr("1 motor")
        }

        return qsTr("%1 motors").arg(_motorCount)
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        VehicleSummaryRow {
            labelText: qsTr("Mode")
            valueText: qsTr("Legacy motor test")
        }

        VehicleSummaryRow {
            labelText: qsTr("Motor Count")
            valueText: root._motorCountText()
            valueColor: root._motorCount < 0 ? qgcPal.warningText : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("Control")
            valueText: qsTr("Single + All")
        }

        VehicleSummaryRow {
            labelText: qsTr("Safety")
            valueText: qsTr("Prop removal required")
            valueColor: qgcPal.warningText
        }
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: root.enabled
    }
}
