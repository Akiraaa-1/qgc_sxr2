import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

QGCPopupDialog {
    id: root
    title:      qsTr("Load Parameters")
    buttons:    Dialog.Cancel | (paramController.diffList.count ? Dialog.Ok : 0)

    property var paramController

    onAccepted: paramController.sendDiff()

    Component.onDestruction: paramController.clearDiff();

    ColumnLayout {
        width:      Math.min(root.maxContentAvailableWidth, ScreenTools.defaultFontPixelWidth * 80)
        spacing:    ScreenTools.defaultDialogControlSpacing

        QGCLabel {
            Layout.fillWidth:       true
            wrapMode:               Text.WordWrap
            text:                   paramController.diffList.count ?
                                        qsTr("The following parameters from the loaded file differ from what is currently set on the Vehicle. Click 'Ok' to update them on the Vehicle.") :
                                        qsTr("There are no differences between the file loaded and the current settings on the Vehicle.")
        }

        QGCFlickable {
            Layout.fillWidth:       true
            Layout.preferredHeight: Math.min(root.maxContentAvailableHeight * 0.6, mainGrid.implicitHeight)
            visible:                paramController.diffList.count
            clip:                   true
            contentWidth:           width
            contentHeight:          mainGrid.implicitHeight

            GridLayout {
                id:         mainGrid
                width:      parent.width
                rows:       paramController.diffList.count + 1
                columns:    paramController.diffMultipleComponents ? 5 : 4
                flow:       GridLayout.TopToBottom

                QGCCheckBox {
                    checked: true
                    onClicked: {
                        for (var i=0; i<paramController.diffList.count; i++) {
                            paramController.diffList.get(i).load = checked
                        }
                    }
                }
                Repeater {
                    model: paramController.diffList
                    QGCCheckBox {
                        checked:    object.load
                        onClicked:  object.load = checked
                    }
                }

                Repeater {
                    model: paramController.diffMultipleComponents ? 1 : 0
                    QGCLabel { text: qsTr("Comp ID") }
                }
                Repeater {
                    model: paramController.diffMultipleComponents ? paramController.diffList : 0
                    QGCLabel { text: object.componentId }
                }

                QGCLabel { text: qsTr("Name") }
                Repeater {
                    model: paramController.diffList
                    QGCLabel { text: object.name }
                }

                QGCLabel { text: qsTr("File") }
                Repeater {
                    model: paramController.diffList
                    QGCLabel { text: object.fileValue + " " + object.units }
                }

                QGCLabel { text: qsTr("Vehicle") }
                Repeater {
                    model: paramController.diffList
                    QGCLabel { text: object.noVehicleValue ? qsTr("N/A") : object.vehicleValue + " " + object.units }
                }
            }
        }
    }
}
