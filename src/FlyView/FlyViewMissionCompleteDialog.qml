import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Dialog which shows up when a flight completes. Prompts the user for things like whether they should remove the plan from the vehicle.
Item {
    id:      missionCompleteDialogHelper
    visible: false

    property var missionController
    property var geoFenceController
    property var rallyPointController
    property var planMasterController

    function removePlanFromVehicle() {
        if (planMasterController && planMasterController.removeAllFromVehicle) {
            planMasterController.removeAllFromVehicle()
        } else {
            QGroundControl.showMessageDialog(
                missionCompleteDialogHelper,
                qsTr("清除计划"),
                qsTr("计划控制器不可用。"))
        }
    }

    // The following code is used to track vehicle states for showing the mission complete dialog
    property var  _activeVehicle:                   QGroundControl.multiVehicleManager.activeVehicle
    property bool _vehicleArmed:                    _activeVehicle ? _activeVehicle.armed : true // true here prevents pop up from showing during shutdown
    property bool _vehicleWasArmed:                 false
    property bool _vehicleInMissionFlightMode:      _activeVehicle ? (_activeVehicle.flightMode === _activeVehicle.missionFlightMode) : false
    property bool _vehicleWasInMissionFlightMode:   false
    property bool _showMissionCompleteDialog:       _vehicleWasArmed && _vehicleWasInMissionFlightMode &&
                                                    (missionController.containsItems || geoFenceController.containsItems || rallyPointController.containsItems ||
                                                     (_activeVehicle ? _activeVehicle.cameraTriggerPoints.count !== 0 : false))

    on_VehicleArmedChanged: {
        if (_vehicleArmed) {
            _vehicleWasArmed = true
            _vehicleWasInMissionFlightMode = _vehicleInMissionFlightMode
        } else {
            if (_showMissionCompleteDialog) {
                missionCompleteDialogFactory.open()
            }
            _vehicleWasArmed = false
            _vehicleWasInMissionFlightMode = false
        }
    }

    on_VehicleInMissionFlightModeChanged: {
        if (_vehicleInMissionFlightMode && _vehicleArmed) {
            _vehicleWasInMissionFlightMode = true
        }
    }

    QGCPopupDialogFactory {
        id: missionCompleteDialogFactory

        dialogComponent: missionCompleteDialogComponent
    }

    Component {
        id: missionCompleteDialogComponent

        QGCPopupDialog {
            id:         missionCompleteDialog
            title:      qsTr("飞行计划已完成")
            buttons:    Dialog.Close

            property var activeVehicleCopy: _activeVehicle
            onActiveVehicleCopyChanged:
                if (!activeVehicleCopy) {
                    missionCompleteDialog.close()
                }

            ColumnLayout {
                id:         column
                width:      40 * ScreenTools.defaultFontPixelWidth
                spacing:    ScreenTools.defaultFontPixelHeight

                QGCLabel {
                    Layout.fillWidth:       true
                    text:                   qsTr("已拍摄 %1 张图像").arg(_activeVehicle.cameraTriggerPoints.count)
                    horizontalAlignment:    Text.AlignHCenter
                    visible:                _activeVehicle.cameraTriggerPoints.count !== 0
                }

                QGCButton {
                    Layout.fillWidth:   true
                    text:               qsTr("从飞行器清除计划")
                    visible:            !_activeVehicle.communicationLost// && !_activeVehicle.apmFirmware  // ArduPilot has a bug somewhere with mission clear
                    onClicked: {
                        missionCompleteDialogHelper.removePlanFromVehicle()
                        missionCompleteDialog.close()
                    }
                }

                QGCButton {
                    Layout.fillWidth:   true
                    Layout.alignment:   Qt.AlignHCenter
                    text:               qsTr("保留飞行器上的计划")
                    onClicked:          missionCompleteDialog.close()

                }

                Rectangle {
                    Layout.fillWidth:   true
                    color:              qgcPal.text
                    height:             1
                }

                ColumnLayout {
                    Layout.fillWidth:   true
                    spacing:            ScreenTools.defaultFontPixelHeight
                    visible:            !_activeVehicle.communicationLost && globals.guidedControllerFlyView.showResumeMission

                    QGCButton {
                        Layout.fillWidth:   true
                        Layout.alignment:   Qt.AlignHCenter
                        text:               qsTr("从航点 %1 继续任务").arg(globals.guidedControllerFlyView._resumeMissionIndex)

                        onClicked: {
                            globals.guidedControllerFlyView.executeAction(globals.guidedControllerFlyView.actionResumeMission, null, null)
                            missionCompleteDialog.close()
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth:   true
                        wrapMode:           Text.WordWrap
                        text:               qsTr("继续任务会从上次飞过的航点重建当前任务，并上传到飞行器用于下一次飞行。")
                    }
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    color:              qgcPal.warningText
                    text:               qsTr("如果要更换电池后继续任务，请不要断开与飞行器的连接。")
                    visible:            globals.guidedControllerFlyView.showResumeMission
                }
            }
        }
    }
}
