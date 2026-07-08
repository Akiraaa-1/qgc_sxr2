import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQml
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView

/// Mission item edit control
Rectangle {
    required property var    missionItem         ///< MissionItem associated with this editor
    required property var    map                 ///< Map control
    property real            uiScale: 1.0

    signal clicked
    signal remove
    signal selectNextNotReadyItem
    signal editorExpandedAndLoaded

    id:             _root
    height:         _currentItem ? (editorLoader.y + editorLoader.height + _innerMargin) : (topRowLayout.y + topRowLayout.height + _margin)
    color:          theme.panelColor
    radius:         theme.radius
    opacity:        _currentItem ? 1.0 : 0.7
    border.width:   _readyForSave ? 1 : 2
    border.color:   _readyForSave ? (_currentItem ? theme.accentColor : theme.borderColor) : qgcPal.warningText

    property var    _masterController:          missionItem.masterController
    property var    _missionController:         _masterController.missionController
    property bool   _currentItem:               missionItem.isCurrentItem
    property color  _outerTextColor:            _currentItem ? theme.textColor : theme.secondaryTextColor
    property bool   _noMissionItemsAdded:       _missionController.visualItems ? _missionController.visualItems.count <= 1 : true
    property real   _sectionSpacer:             ScreenTools.defaultFontPixelWidth * uiScale / 2  // spacing between section headings
    property bool   _singleComplexItem:         _missionController.complexMissionItemNames.length === 1
    property bool   _readyForSave:              missionItem.readyForSaveState === VisualMissionItem.ReadyForSave

    readonly property real  _editFieldWidth:    Math.min(width - _innerMargin * 2, ScreenTools.defaultFontPixelWidth * 12 * uiScale)
    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth * uiScale / 2
    readonly property real  _innerMargin:       Math.max(2, 2 * uiScale)
    readonly property real  _radius:            ScreenTools.defaultFontPixelWidth * uiScale / 2
    readonly property real  _hamburgerSize:     commandPicker.height * 0.75
    readonly property real  _trashSize:         commandPicker.height * 0.75
    readonly property bool  _waypointsOnlyMode: QGroundControl.corePlugin.options.missionWaypointsOnly
    readonly property real  _editorAvailableWidth: Math.max(0, _root.width - (editorLoader.anchors.margins * 2))

    PlanEditorTheme { id: theme }

    Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }
    Behavior on border.color { ColorAnimation { duration: theme.stateAnimationDuration } }
    Behavior on opacity { NumberAnimation { duration: theme.stateAnimationDuration } }

    // setSource() injects missionItem before internal bindings activate
    function _loadEditor() {
        if (missionItem.isCurrentItem) {
            editorLoader.setSource(missionItem.editorQml, {
                missionItem:    _root.missionItem,
                availableWidth: Qt.binding(() => _root._editorAvailableWidth),
                uiScale:        _root.uiScale
            })
        } else {
            editorLoader.setSource("")
        }
    }

    Connections {
        target: missionItem
        function onIsCurrentItemChanged() { _root._loadEditor() }
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: enabled
    }

    FocusScope {
        id:             currentItemScope
        anchors.fill:   parent

        MouseArea {
            anchors.fill:   parent
            onClicked: {
                if (mainWindow.allowViewSwitch()) {
                    currentItemScope.focus = true
                    _root.clicked()
                }
            }
        }
    }

    QGCPopupDialogFactory {
        id: editPositionDialogFactory

        dialogComponent: editPositionDialog
    }

    Component {
        id: editPositionDialog

        EditPositionDialog {
            property bool _editCenterCoordinate: false

            onCoordinateChanged: {
                if (_editCenterCoordinate)
                    missionItem.centerCoordinate = coordinate
                else
                    missionItem.coordinate = coordinate
            }
        }
    }

    Row {
        id:                 topRowLayout
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.top:        parent.top
        spacing:            _margin

        Rectangle {
            id:                     notReadyForSaveIndicator
            anchors.verticalCenter: parent.verticalCenter
            width:                  _hamburgerSize
            height:                 width
            border.width:           1
            border.color:           qgcPal.warningText
            color:                  theme.inputColor
            radius:                 width / 2
            visible:                !_readyForSave

            QGCLabel {
                id:                 readyForSaveLabel
                anchors.centerIn:   parent
                //: Indicator in Plan view to show mission item is not ready for save/send
                text:               qsTr("?")
                color:              qgcPal.warningText
                font.pointSize:     ScreenTools.smallFontPointSize * _root.uiScale
            }
        }

        QGCColoredImage {
            id:                     deleteButton
            anchors.verticalCenter: parent.verticalCenter
            height:                 _hamburgerSize
            width:                  height
            sourceSize.height:      height
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
            smooth:                 true
            color:                  theme.secondaryTextColor
            visible:                _currentItem && missionItem.sequenceNumber !== 0
            source:                 "/res/TrashDelete.svg"

            QGCMouseArea {
                fillItem:   parent
                onClicked:  remove()
            }
        }

        Rectangle {
            id:                     commandPicker
            anchors.verticalCenter: parent.verticalCenter
            height:                 ScreenTools.implicitComboBoxHeight * _root.uiScale
            width:                  innerLayout.implicitWidth + (_margin * 2)
            visible:                !commandLabel.visible
            color:                  commandPickerMouseArea.pressed ? theme.panelPressedColor : (commandPickerMouseArea.containsMouse ? theme.panelHoverColor : theme.inputColor)
            radius:                 theme.radius
            border.width:           1
            border.color:           theme.borderColor

            Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }
            Behavior on border.color { ColorAnimation { duration: theme.stateAnimationDuration } }

            RowLayout {
                id:                     innerLayout
                anchors.fill:           parent
                anchors.leftMargin:     _margin
                anchors.rightMargin:    _margin
                spacing:                _padding

                property real _padding: ScreenTools.comboBoxPadding * _root.uiScale

                QGCLabel {
                    text:   missionItem.commandName
                    color:  theme.textColor
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * _root.uiScale
                }

                QGCColoredImage {
                    height:             ScreenTools.defaultFontPixelWidth * _root.uiScale
                    width:              height
                    fillMode:           Image.PreserveAspectFit
                    smooth:             true
                    antialiasing:       true
                    color:              theme.secondaryTextColor
                    source:             "/qmlimages/arrow-down.png"
                }
            }

            QGCMouseArea {
                id:         commandPickerMouseArea
                fillItem:   parent
                hoverEnabled: true
                onClicked:  commandDialogFactory.open()
            }

            QGCPopupDialogFactory {
                id: commandDialogFactory

                dialogComponent: commandDialog
            }

            Component {
                id: commandDialog

                MissionCommandDialog {
                    vehicle:                    _masterController.controllerVehicle
                    missionItem:                _root.missionItem
                    map:                        _root.map
                    // FIXME: Disabling fly through commands doesn't work since you may need to change from an RTL to something else
                    flyThroughCommandsAllowed:  true //_missionController.flyThroughCommandsAllowed
                }
            }
        }

        QGCLabel {
            id:                     commandLabel
            anchors.verticalCenter: parent.verticalCenter
            width:                  commandPicker.width
            height:                 commandPicker.height
            visible:                !missionItem.isCurrentItem || !missionItem.isSimpleItem || _waypointsOnlyMode || missionItem.isTakeoffItem
            verticalAlignment:      Text.AlignVCenter
            text:                   missionItem.commandName
            color:                  _outerTextColor
            font.pixelSize:         ScreenTools.defaultFontPixelHeight * _root.uiScale
        }
    }

    Component {
        id: hamburgerMenuDropPanelComponent

        DropPanel {
            id: hamburgerMenuDropPanel
            backgroundColor: theme.popupColor
            borderColor: theme.borderColor
            borderWidth: 1
            panelRadius: theme.radius
            onClosed: destroy()

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2

                    PlanButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Move to vehicle position")
                        enabled:            _activeVehicle && missionItem.specifiesCoordinate

                        onClicked: {
                            missionItem.coordinate = _activeVehicle.coordinate
                            hamburgerMenuDropPanel.close()
                        }

                        property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
                    }

                    PlanButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Move to previous item position")
                        enabled:            _missionController.previousCoordinate.isValid
                        onClicked: {
                            missionItem.coordinate = _missionController.previousCoordinate
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    PlanButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Edit position...")
                        enabled:            missionItem.specifiesCoordinate
                        onClicked: {
                            const editCenterCoordinate = missionItem.isSurveyItem
                            editPositionDialogFactory.open({
                                _editCenterCoordinate:   editCenterCoordinate,
                                coordinate:              editCenterCoordinate ? missionItem.centerCoordinate : missionItem.coordinate,
                                altitudeFact:            !editCenterCoordinate && missionItem.specifiesAltitude ? missionItem.altitude : null,
                                altitudeFrame:           !editCenterCoordinate && missionItem.specifiesAltitude ? missionItem.altitudeFrame : QGroundControl.AltitudeFrameNone,
                            })
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 1
                        color:                  theme.borderColor
                    }

                    PlanCheckBoxSlider {
                        Layout.fillWidth:   true
                        text:               qsTr("Show all values")
                        visible:            QGroundControl.corePlugin.showAdvancedUI
                        checked:            missionItem.isSimpleItem ? missionItem.rawEdit : false
                        enabled:            missionItem.isSimpleItem && !_waypointsOnlyMode

                        onClicked: {
                            missionItem.rawEdit = checked
                            if (missionItem.rawEdit && !missionItem.friendlyEditAllowed) {
                                missionItem.rawEdit = false
                                checked = false
                                QGroundControl.showMessageDialog(_root, qsTr("Mission Edit"), qsTr("You have made changes to the mission item which cannot be shown in Simple Mode"))
                            }
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 1
                        color:                  theme.borderColor
                    }

                    QGCLabel {
                        text:       qsTr("Item #%1").arg(missionItem.sequenceNumber)
                        enabled:    false
                        color:      theme.disabledTextColor
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * _root.uiScale
                    }
                }
            }
        }
    }

    QGCColoredImage {
        id:                     hamburger
        anchors.margins:        _margin
        anchors.right:          parent.right
        anchors.verticalCenter: topRowLayout.verticalCenter
        width:                  _hamburgerSize
        height:                 _hamburgerSize
        sourceSize.height:      _hamburgerSize
        source:                 "qrc:/qmlimages/Hamburger.svg"
        visible:                missionItem.isCurrentItem && missionItem.sequenceNumber !== 0
        color:                  theme.secondaryTextColor

        QGCMouseArea {
            fillItem:   hamburger
            onClicked: (position) => {
                currentItemScope.focus = true
                position = Qt.point(position.x, position.y)
                // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                position = mapToItem(globals.parent, position)

                var dropPanel = hamburgerMenuDropPanelComponent.createObject(mainWindow, { clickRect: Qt.rect(position.x, position.y, 0, 0) })
                dropPanel.open()
            }
        }
    }

    /*
    QGCLabel {
        id:                     notReadyForSaveLabel
        anchors.margins:        _margin
        anchors.left:           notReadyForSaveIndicator.right
        anchors.right:          parent.right
        anchors.top:            commandPicker.bottom
        visible:                _currentItem && !_readyForSave
        text:                   missionItem.readyForSaveState === VisualMissionItem.NotReadyForSaveTerrain ?
                                    qsTr("Incomplete: Waiting on terrain data.") :
                                    qsTr("Incomplete: Item not fully specified.")
        wrapMode:               Text.WordWrap
        horizontalAlignment:    Text.AlignHCenter
        color:                  qgcPal.warningText
    }

*/

    Loader {
        id:                 editorLoader
        anchors.margins:    _innerMargin
        anchors.left:       parent.left
        anchors.top:        topRowLayout.bottom
        asynchronous:       true

        Component.onCompleted: _root._loadEditor()
    }

    onHeightChanged: {
        if (_currentItem && editorLoader.status === Loader.Ready) {
            _editorHeightSettleTimer.restart()
        }
    }

    Timer {
        id: _editorHeightSettleTimer
        interval: 100
        onTriggered: _root.editorExpandedAndLoaded()
    }
}
