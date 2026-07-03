import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight
    width: parent.width  // grows when Loader is wider than implicitWidth

    property string _naString: qsTr("N/A")

    FactPanelController { id: controller; }

    property int _indexedBatteryParamCount: {
        var batteryIndex = 1
        while (controller.parameterExists(-1, "BAT" + batteryIndex + "_SOURCE")) {
            batteryIndex++
        }
        return batteryIndex - 1
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Repeater {
            model: _indexedBatteryParamCount

            Loader {
                Layout.fillWidth: true
                sourceComponent: batterySummaryComponent

                property int    batteryIndex:       index + 1
                property bool   showBatteryIndex:   _indexedBatteryParamCount > 1
            }
        }
    }

    Component {
        id: batterySummaryComponent

        ColumnLayout {
            width: parent ? parent.width : implicitWidth
            spacing: 0

            property var  _controller:      controller
            property int  _batteryIndex:    batteryIndex

            BatteryParams {
                id:             battParams
                controller:     _controller
                batteryIndex:   _batteryIndex
            }

            VehicleSummaryRow {
                labelText: showBatteryIndex ? qsTr("电池 %1 来源").arg(batteryIndex) : qsTr("电池来源")
                valueText: battParams.battSource.enumStringValue
            }

            VehicleSummaryRow {
                labelText: showBatteryIndex ? qsTr("电池 %1 满电").arg(batteryIndex) : qsTr("电池满电")
                valueText: battParams.battHighVoltAvailable ? battParams.battHighVolt.valueString + " " + battParams.battHighVolt.units : _naString
            }

            VehicleSummaryRow {
                labelText: showBatteryIndex ? qsTr("电池 %1 空电").arg(batteryIndex) : qsTr("电池空电")
                valueText: battParams.battLowVoltAvailable ? battParams.battLowVolt.valueString + " " + battParams.battLowVolt.units : _naString
            }

            VehicleSummaryRow {
                labelText: showBatteryIndex ? qsTr("电池 %1 电芯数").arg(batteryIndex) : qsTr("电芯数")
                valueText: battParams.battNumCellsAvailable ? battParams.battNumCells.valueString : _naString
            }
        }
    }
}
