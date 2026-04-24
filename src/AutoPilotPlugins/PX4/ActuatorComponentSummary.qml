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
    readonly property var _actuators: _activeVehicle ? _activeVehicle.actuators : null

    function _countText(count, singularText, pluralText) {
        if (count === 1) {
            return "1 " + singularText
        }
        return count + " " + pluralText
    }

    function _geometryText() {
        if (!_actuators || !_actuators.mixer) {
            return qsTr("Unavailable")
        }

        if (_actuators.mixer.title && _actuators.mixer.title !== "") {
            return _actuators.mixer.title
        }

        return _actuators.isMultirotor ? qsTr("Multirotor") : qsTr("Configured")
    }

    function _outputsText() {
        if (!_actuators || !_actuators.actuatorOutputs) {
            return qsTr("Unavailable")
        }

        return _countText(_actuators.actuatorOutputs.count, qsTr("group"), qsTr("groups"))
    }

    function _testText() {
        if (!_actuators || !_actuators.actuatorTest || !_actuators.actuatorTest.actuators) {
            return qsTr("Unavailable")
        }

        const count = _actuators.actuatorTest.actuators.count
        return count > 0
            ? _countText(count, qsTr("channel"), qsTr("channels"))
            : qsTr("Unavailable")
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        VehicleSummaryRow {
            labelText: qsTr("Geometry")
            valueText: root._geometryText()
        }

        VehicleSummaryRow {
            labelText: qsTr("Outputs")
            valueText: root._outputsText()
        }

        VehicleSummaryRow {
            labelText: qsTr("Status")
            valueText: root._actuators
                ? (root._actuators.hasUnsetRequiredFunctions ? qsTr("Setup required") : qsTr("Ready"))
                : qsTr("Unavailable")
            valueColor: root._actuators && root._actuators.hasUnsetRequiredFunctions ? qgcPal.warningText : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("Testing")
            valueText: root._testText()
        }
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: root.enabled
    }
}
