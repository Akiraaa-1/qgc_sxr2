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
    property bool clearRemovesVehicleByDefault: false

    signal toolbarButtonClicked()
    signal uploadRequested()
    signal downloadRequested()
    signal openRequested()
    signal saveRequested()
    signal saveKmlRequested()
    signal clearRequested(bool removeFromVehicle)

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
        uploadRequested()
    }

    function _downloadClicked() {
        downloadRequested()
    }

    function _openButtonClicked() {
        openRequested()
    }

    function _saveButtonClicked() {
        saveRequested()
    }

    function _saveAsKMLClicked() {
        saveKmlRequested()
    }

    function _primaryClearButtonClicked() {
        clearRequested(clearRemovesVehicleByDefault)
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
        text: clearRemovesVehicleByDefault ? qsTr("清除飞控航线") : qsTr("清空编辑器")
        iconSource: "/res/TrashCan.svg"
        enabled: !_syncInProgress && (clearRemovesVehicleByDefault || _hasPlanItems)
        onClicked: { toolbarButtonClicked(); _primaryClearButtonClicked() }
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

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("仅清空编辑器")
                        enabled: !_syncInProgress && _hasPlanItems
                        visible: !_syncInProgress && clearRemovesVehicleByDefault

                        onClicked: {
                            dropPanel.close()
                            clearRequested(false)
                        }
                    }
                }
            }
        }
    }
}
