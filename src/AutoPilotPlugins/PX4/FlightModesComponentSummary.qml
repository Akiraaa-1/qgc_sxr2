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

    FactPanelController { id: controller; }

    property Fact _nullFact
    property Fact _rcMapFltmode:    controller.parameterExists(-1, "RC_MAP_FLTMODE") ? controller.getParameterFact(-1, "RC_MAP_FLTMODE") : _nullFact

	ColumnLayout {
		id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
		spacing: 0

		VehicleSummaryRow {
			labelText: qsTr("模式切换开关")
			valueText: _rcMapFltmode.value === 0 ? qsTr("需要设置") : _rcMapFltmode.enumStringValue
		}
		Repeater {
			model: 6
			VehicleSummaryRow {
				labelText: qsTr("飞行模式 %1").arg(index + 1)
				valueText: controller.getParameterFact(-1, "COM_FLTMODE" + (index + 1)).enumStringValue
			}
		}
    }
}
