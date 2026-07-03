import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight
    width: parent.width

    AirframeComponentController { id: controller }

    property Fact sysIdFact:        controller.getParameterFact(-1, "MAV_SYS_ID")
    property Fact sysAutoStartFact: controller.getParameterFact(-1, "SYS_AUTOSTART")

    property bool autoStartSet: sysAutoStartFact ? (sysAutoStartFact.value !== 0) : false

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        VehicleSummaryRow {
            labelText: qsTr("系统 ID")
            valueText: sysIdFact ? sysIdFact.valueString : ""
        }
        VehicleSummaryRow {
            labelText: qsTr("机架类型")
            valueText: autoStartSet ? controller.currentAirframeType : qsTr("需要设置")
        }
        VehicleSummaryRow {
            labelText: qsTr("飞行器")
            valueText: autoStartSet ? controller.currentVehicleName : qsTr("需要设置")
        }

        VehicleSummaryRow {
            labelText: qsTr("固件版本")
            valueText: globals.activeVehicle.firmwareMajorVersion === -1 ? qsTr("未知") : globals.activeVehicle.firmwareMajorVersion + "." + globals.activeVehicle.firmwareMinorVersion + "." + globals.activeVehicle.firmwarePatchVersion + globals.activeVehicle.firmwareVersionTypeString
        }
        VehicleSummaryRow {
            visible: globals.activeVehicle.firmwareCustomMajorVersion !== -1
            labelText: qsTr("自定义固件版本")
            valueText: globals.activeVehicle.firmwareCustomMajorVersion + "." + globals.activeVehicle.firmwareCustomMinorVersion + "." + globals.activeVehicle.firmwareCustomPatchVersion
        }
    }
}
