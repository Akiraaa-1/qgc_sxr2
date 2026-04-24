import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    id:         root
    title:      qsTr("Select Mission Command")
    buttons:    Dialog.Cancel

    property var    vehicle
    property var    missionItem
    property var    map
    property bool   flyThroughCommandsAllowed

    QGCPopupStyle { id: popupStyle }

    ColumnLayout {
        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Category:")
                color: popupStyle.secondaryTextColor
            }

            QGCComboBox {
                id:                     categoryCombo
                Layout.preferredWidth:  30 * ScreenTools.defaultFontPixelWidth
                model:                  QGroundControl.missionCommandTree.categoriesForVehicle(vehicle)

                function categorySelected(category) {
                    commandList.model = QGroundControl.missionCommandTree.getCommandsForCategory(vehicle, category, flyThroughCommandsAllowed)
                }

                Component.onCompleted: {
                    var category  = missionItem.category
                    currentIndex = find(category)
                    categorySelected(category)
                }

                onActivated: (index) => { categorySelected(textAt(index)) }
            }
        }

        Repeater {
            id:                 commandList
            Layout.fillWidth:   true

            delegate: Rectangle {
                width:      parent.width
                height:     commandColumn.height + ScreenTools.defaultFontPixelHeight
                radius:     popupStyle.cornerRadius
                color:      commandMouseArea.pressed
                                ? popupStyle.pressedColor(popupStyle.panelBackground)
                                : (commandMouseArea.containsMouse
                                    ? popupStyle.hoverColor(popupStyle.panelBackground)
                                    : popupStyle.panelBackground)
                border.width: 1
                border.color: popupStyle.borderColor

                property var    mavCmdInfo: modelData
                property color  textColor:  popupStyle.primaryTextColor

                Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
                Behavior on border.color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }

                Column {
                    id:                 commandColumn
                    anchors.margins:    ScreenTools.defaultFontPixelWidth
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top

                    QGCLabel {
                        text:           mavCmdInfo.friendlyName
                        color:          textColor
                        font.bold:      true
                    }

                    QGCLabel {
                        anchors.margins:    ScreenTools.defaultFontPixelWidth
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        text:               mavCmdInfo.description
                        wrapMode:           Text.WordWrap
                        color:              popupStyle.secondaryTextColor
                    }
                }

                QGCMouseArea {
                    id:             commandMouseArea
                    anchors.fill:   parent
                    hoverEnabled:   true
                    onClicked: {
                        missionItem.setMapCenterHintForCommandChange(map.center)
                        missionItem.command = mavCmdInfo.command
                        root.close()
                    }
                }
            }
        }
    }
}
