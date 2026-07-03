import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

// Exposes the set of battery parameters taking into account the availability of the parameters.
// Only the _SOURCE parameter can be assumed to be always available. The remainder of the parameters
// may or may not be available depending on the _SOURCE setting.
QtObject {
    property var controller     ///< FactPanelController
    property int batteryIndex   ///< 1-based battery index
    readonly property int _safeBatteryIndex: Math.max(1, batteryIndex)

    property Fact battSource:                   controller.getParameterFact(-1, "BAT#_SOURCE".replace       ("#", _safeBatteryIndex))
    property Fact battNumCells:                 controller.getParameterFact(-1, "BAT#_N_CELLS".replace      ("#", _safeBatteryIndex), false)
    property Fact battHighVolt:                 controller.getParameterFact(-1, "BAT#_V_CHARGED".replace    ("#", _safeBatteryIndex), false)
    property Fact battLowVolt:                  controller.getParameterFact(-1, "BAT#_V_EMPTY".replace      ("#", _safeBatteryIndex), false)
    property Fact battVoltLoadDrop:             controller.getParameterFact(-1, "BAT#_V_LOAD_DROP".replace  ("#", _safeBatteryIndex), false)
    property Fact battVoltageDivider:           controller.getParameterFact(-1, "BAT#_V_DIV".replace        ("#", _safeBatteryIndex), false)
    property Fact battAmpsPerVolt:              controller.getParameterFact(-1, "BAT#_A_PER_V".replace      ("#", _safeBatteryIndex), false)

    property bool battNumCellsAvailable:        controller.parameterExists(-1, "BAT#_N_CELLS".replace       ("#", _safeBatteryIndex))
    property bool battHighVoltAvailable:        controller.parameterExists(-1, "BAT#_V_CHARGED".replace     ("#", _safeBatteryIndex))
    property bool battLowVoltAvailable:         controller.parameterExists(-1, "BAT#_V_EMPTY".replace       ("#", _safeBatteryIndex))
    property bool battVoltLoadDropAvailable:    controller.parameterExists(-1, "BAT#_V_LOAD_DROP".replace   ("#", _safeBatteryIndex))
    property bool battVoltageDividerAvailable:  controller.parameterExists(-1, "BAT#_V_DIV".replace         ("#", _safeBatteryIndex))
    property bool battAmpsPerVoltAvailable:     controller.parameterExists(-1, "BAT#_A_PER_V".replace       ("#", _safeBatteryIndex))
}
