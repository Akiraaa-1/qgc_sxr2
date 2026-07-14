import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

/// Popup container for preflight checklists
QGCPopupDialog {
    id:         _root
    title:      qsTr("飞行前检查单")
    buttons:    Dialog.Close
    rejectButtonText: qsTr("关闭")
    showTitleAccent: true
    useExplicitActionColors: true
    actionSecondaryBackgroundColor: "#2A2E2B"
    actionSecondaryBorderColor: "#454B45"
    actionSecondaryTextColor: "#F0F3EA"
    actionButtonRadius: ScreenTools.defaultFontPixelHeight * 0.28

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _useChecklist:      QGroundControl.settingsManager.appSettings.useChecklist.rawValue && QGroundControl.corePlugin.options.preFlightChecklistUrl.toString().length
    property bool   _enforceChecklist:  _useChecklist && QGroundControl.settingsManager.appSettings.enforceChecklist.rawValue
    property bool   _checklistComplete: _activeVehicle && (_activeVehicle.checkListState === Vehicle.CheckListPassed)

    on_ActiveVehicleChanged: _showPreFlightChecklistIfNeeded()

    Connections {
        target:                             mainWindow
        onShowPreFlightChecklistIfNeeded:   _root._showPreFlightChecklistIfNeeded()
    }

    function _showPreFlightChecklistIfNeeded() {
        if (_activeVehicle && !_checklistComplete && _enforceChecklist) {
            popupTimer.restart()
        }
    }

    Timer {
        id:             popupTimer
        interval:       1000
        repeat:         false
        onTriggered: {
            if (!_checklistComplete) {
                _root.open()
            } else {
                _root.close()
            }
        }
    }

    Loader {
        id:     checkList
        source: QGroundControl.corePlugin.options.preFlightChecklistUrl
    }

    property alias checkListItem: checkList.item

    Connections {
        target: checkList.item
        onAllChecksPassedChanged: {
            if (target.allChecksPassed) {
                popupTimer.restart()
            }
        }
    }
}
