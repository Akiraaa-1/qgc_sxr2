import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Toolbar for Plan View
RowLayout {
    required property var planMasterController
    property bool showRallyPointsHelp: false

    signal toolbarButtonClicked()

    id: root
    spacing: ScreenTools.defaultFontPixelWidth

    property var _planMasterController: planMasterController
    property var _missionController: _planMasterController.missionController
    property var _geoFenceController: _planMasterController.geoFenceController
    property var _rallyPointController: _planMasterController.rallyPointController
    property bool _controllerOffline: _planMasterController.offline
    property var _saveDirty: _planMasterController.dirtyForSave
    property var _uploadDirty: _planMasterController.dirtyForUpload
    property var _syncInProgress: _planMasterController.syncInProgress
    property var _visualItems: _missionController.visualItems
    property bool _hasPlanItems: _planMasterController.containsItems

    readonly property real _margins: ScreenTools.defaultFontPixelWidth

    function _uploadClicked() {
        if (_syncInProgress) {
            QGroundControl.showMessageDialog(root,
                                             qsTr("无法上传"),
                                             qsTr("计划仍在与飞行器同步。请等待当前同步结束后再上传。"))
            return
        }

        switch (_planMasterController.readyForSaveState()) {
        case VisualMissionItem.NotReadyForSaveData:
            QGroundControl.showMessageDialog(root,
                                             qsTr("无法上传"),
                                             qsTr("计划中有未完成的项目。请补全所有项目后重新上传。"))
            return
        case VisualMissionItem.NotReadyForSaveTerrain:
            QGroundControl.showMessageDialog(root,
                                             qsTr("无法上传"),
                                             qsTr("计划正在等待服务器地形数据以计算正确高度。"))
            return
        }

        switch (_missionController.sendToVehiclePreCheck()) {
        case MissionController.SendToVehiclePreCheckStateOk:
            _planMasterController.sendToVehicle()
            break
        case MissionController.SendToVehiclePreCheckStateNoActiveVehicle:
            QGroundControl.showMessageDialog(root, qsTr("发送到飞行器"), qsTr("必须连接飞行器后才能上传计划。"))
            break
        case MissionController.SendToVehiclePreCheckStateActiveMission:
            QGroundControl.showMessageDialog(root, qsTr("发送到飞行器"), qsTr("上传新计划前必须先暂停当前任务。"))
            break
        case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch:
            QGroundControl.showMessageDialog(root,
                                             qsTr("计划上传"),
                                             qsTr("此计划创建时使用的固件或机型与当前上传目标不一致，可能导致错误或异常行为。\n\n建议按当前固件和机型重新创建计划。\n\n点击“OK”仍然上传。"),
                                             Dialog.Ok | Dialog.Cancel,
                                             function() { _planMasterController.sendToVehicle() })
            break
        }
    }

    function _downloadClicked() {
        if (_saveDirty) {
            QGroundControl.showMessageDialog(root, qsTr("下载"),
                                         qsTr("当前有未保存的更改。从飞行器下载会丢失这些更改，确定继续吗？"),
                                         Dialog.Yes | Dialog.Cancel,
                                         function() { _planMasterController.loadFromVehicle() })
        } else {
            _planMasterController.loadFromVehicle()
        }
    }

    function _openButtonClicked() {
        if (_saveDirty || _uploadDirty) {
            QGroundControl.showMessageDialog(root, qsTr("打开计划"),
                                        qsTr("当前有未保存或未发送的更改。加载新的计划会丢失这些更改，确定继续吗？"),
                                        Dialog.Yes | Dialog.Cancel,
                                        function() { _planMasterController.loadFromSelectedFile() } )
        } else {
            _planMasterController.loadFromSelectedFile()
        }
    }

    function _saveButtonClicked() {
        if (_planMasterController.currentPlanFileName === "") {
            if (_planMasterController.currentPlanFile === "") {
                // No file and no name typed — open the file dialog
                _planMasterController.saveToSelectedFile()
            } else {
                // Have a file but name was cleared — save to the existing file
                _planMasterController.saveToCurrent()
            }
            return
        }

        if (_planMasterController.currentPlanFile === "" || _planMasterController.planFileRenamed) {
            // First save with a typed name, or name was changed since last save
            let fullName = _planMasterController.currentPlanFileName + "." + _planMasterController.fileExtension
            let msg = _planMasterController.resolvedPlanFileExists()
                ? qsTr("'%1' 已存在。是否覆盖？").arg(fullName)
                : qsTr("是否另存为 '%1'？").arg(fullName)
            QGroundControl.showMessageDialog(root, qsTr("保存"), msg,
                Dialog.Yes | Dialog.No,
                function() { _planMasterController.saveWithCurrentName() })
        } else {
            _planMasterController.saveToCurrent()
        }
    }

    function _saveAsKMLClicked() {
        // Don't save if we only have Mission Settings item
        if (_visualItems.count > 1) {
            _planMasterController.saveKmlToSelectedFile()
        }
    }

    function _storageClearButtonClicked() {
        QGroundControl.showMessageDialog(root, qsTr("清除"),
                                     qsTr("确定要从计划编辑器中移除所有项目吗？"),
                                     Dialog.Yes | Dialog.Cancel,
                                     function() { _planMasterController.removeAll(); })
    }

    function _vehicleClearButtonClicked() {
        QGroundControl.showMessageDialog(root, qsTr("清除"),
                                     qsTr("确定要从飞行器和计划编辑器中移除此计划吗？"),
                                     Dialog.Yes | Dialog.Cancel,
                                     function() {
                                        _planMasterController.removeAllFromVehicle()
                                     })
    }

    function _clearClicked() {
        if (_planMasterController.offline || _syncInProgress) {
            _storageClearButtonClicked();
        } else {
            _vehicleClearButtonClicked();
        }
    }

    QGCPalette { id: qgcPal }

    QGCButton {
        text: qsTr("Open")
        iconSource: "/qmlimages/Plan.svg"
        onClicked: { toolbarButtonClicked(); _openButtonClicked() }
    }

    QGCButton {
        text: qsTr("Save")
        iconSource: "/res/SaveToDisk.svg"
        enabled: !_syncInProgress && _hasPlanItems
        primary: _saveDirty
        onClicked: { toolbarButtonClicked(); _saveButtonClicked() }
    }

    QGCButton {
        id: uploadButton
        text: qsTr("Upload")
        iconSource: "/res/UploadToVehicle.svg"
        enabled: _hasPlanItems
        primary: _uploadDirty
        onClicked: { toolbarButtonClicked(); _uploadClicked() }
    }

    QGCButton {
        text: qsTr("Clear")
        iconSource: "/res/TrashCan.svg"
        onClicked: { toolbarButtonClicked(); _clearClicked() }
    }

    QGCButton {
        iconSource: "qrc:/qmlimages/Hamburger.svg"

        onClicked: {
            let position = Qt.point(width, height / 2)
            // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
            position = mapToItem(globals.parent, position)
            var dropPanel = hamburgerDropPanelComponent.createObject(mainWindow, { clickRect: Qt.rect(position.x, position.y, 0, 0) })
            dropPanel.open()
        }
    }

    QGCLabel {
        text:    qsTr("Click in map to add rally points")
        visible: root.showRallyPointsHelp
        Layout.alignment: Qt.AlignVCenter
    }

    Component {
        id: hamburgerDropPanelComponent

        DropPanel {
            id: dropPanel

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Save as KML")
                        enabled: !_syncInProgress && _hasPlanItems

                        onClicked: {
                            dropPanel.close()
                            _saveAsKMLClicked()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Download")
                        enabled: !_syncInProgress && !_controllerOffline
                        visible: !_syncInProgress

                        onClicked: {
                            dropPanel.close()
                            _downloadClicked()
                        }
                    }
                }
            }
        }
    }
}
