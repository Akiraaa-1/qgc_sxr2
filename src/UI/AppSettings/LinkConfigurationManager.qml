import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SettingsGroupLayout {
    id: _root
    heading: qsTr("Links")

    property var _linkManager: QGroundControl.linkManager

    Repeater {
        model: _linkManager.linkConfigurations

        RowLayout {
            Layout.fillWidth:   true
            visible:            !object.dynamic

            QGCLabel {
                Layout.fillWidth:   true
                text:               object.name
            }
            QGCColoredImage {
                height:                 ScreenTools.minTouchPixels
                width:                  height
                sourceSize.height:      height
                fillMode:               Image.PreserveAspectFit
                mipmap:                 true
                smooth:                 true
                color:                  qgcPalEdit.text
                source:                 "/res/pencil.svg"
                enabled:                !object.link

                QGCPalette {
                    id: qgcPalEdit
                    colorGroupEnabled: parent.enabled
                }

                QGCMouseArea {
                    fillItem: parent
                    onClicked: {
                        var editingConfig = _linkManager.startConfigurationEditing(object)
                        linkDialogFactory.open({ editingConfig: editingConfig, originalConfig: object })
                    }
                }
            }
            QGCColoredImage {
                height:                 ScreenTools.minTouchPixels
                width:                  height
                sourceSize.height:      height
                fillMode:               Image.PreserveAspectFit
                mipmap:                 true
                smooth:                 true
                color:                  qgcPalDelete.text
                source:                 "/res/TrashDelete.svg"

                QGCPalette {
                    id: qgcPalDelete
                    colorGroupEnabled: parent.enabled
                }

                QGCMouseArea {
                    fillItem:   parent
                    onClicked:  QGroundControl.showMessageDialog(
                                    _root,
                                    qsTr("Delete Link"),
                                    qsTr("Are you sure you want to delete '%1'?").arg(object.name),
                                    Dialog.Ok | Dialog.Cancel,
                                    function () {
                                        _linkManager.removeConfiguration(object)
                                    })
                }
            }
            QGCButton {
                text:       object.link ? qsTr("Disconnect") : qsTr("Connect")
                onClicked: {
                    if (object.link) {
                        object.link.disconnect()
                    } else {
                        _linkManager.createConnectedLink(object)
                    }
                }
            }
        }
    }

    LabelledButton {
        label:      qsTr("Add New Link")
        buttonText: qsTr("Add")

        onClicked: {
            var editingConfig = _linkManager.createConfiguration(ScreenTools.isSerialAvailable ? LinkConfiguration.TypeSerial : LinkConfiguration.TypeUdp, "")
            linkDialogFactory.open({ editingConfig: editingConfig, originalConfig: null })
        }
    }

    QGCPopupDialogFactory {
        id: linkDialogFactory

        dialogComponent: linkDialogComponent
    }

    Component {
        id: linkDialogComponent

        QGCPopupDialog {
            id: linkDialog
            title:                  originalConfig ? qsTr("Edit Link") : qsTr("Add New Link")
            buttons:                Dialog.Save | Dialog.Cancel
            acceptButtonEnabled:    nameField.text !== ""
            maxContentAvailableWidth: Math.min(mainWindow.width - (ScreenTools.defaultFontPixelWidth * 8), ScreenTools.defaultFontPixelWidth * 64)
            maxContentAvailableHeight: mainWindow.height - (ScreenTools.defaultFontPixelHeight * 8)

            property var originalConfig
            property var editingConfig
            readonly property real _dialogContentWidth: ScreenTools.defaultFontPixelWidth * 46
            readonly property real _fieldLabelWidth: ScreenTools.defaultFontPixelWidth * 15

            QGCPopupStyle { id: popupStyle }

            onAccepted: {
                linkSettingsLoader.item.saveSettings()
                editingConfig.name = nameField.text
                if (originalConfig) {
                    _linkManager.endConfigurationEditing(originalConfig, editingConfig)
                } else {
                    editingConfig.dynamic = false
                    _linkManager.endCreateConfiguration(editingConfig)
                }
            }

            onRejected: _linkManager.cancelConfigurationEditing(editingConfig)

            ColumnLayout {
                width: linkDialog._dialogContentWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.75

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Create and configure a communication link profile.")
                    color: popupStyle.secondaryTextColor
                    font.pointSize: ScreenTools.defaultFontPointSize - 1
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: formContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.8)
                    color: popupStyle.panelBackground
                    radius: popupStyle.cornerRadius
                    border.width: 1
                    border.color: popupStyle.borderColor

                    ColumnLayout {
                        id: formContent
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.9
                        spacing: ScreenTools.defaultFontPixelHeight * 0.8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth

                            QGCLabel {
                                Layout.preferredWidth: linkDialog._fieldLabelWidth
                                text: qsTr("Name")
                                color: popupStyle.primaryTextColor
                                font.pointSize: ScreenTools.defaultFontPointSize
                            }

                            QGCTextField {
                                id:                 nameField
                                Layout.fillWidth:   true
                                text:               editingConfig.name
                                placeholderText:    qsTr("Enter name")
                                borderRadius:       popupStyle.cornerRadius
                                borderWidth:        1
                                focusBorderWidth:   1
                                showFocusGlow:      true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: popupStyle.borderColor
                            opacity: 0.8
                        }

                        QGCCheckBoxSlider {
                            Layout.fillWidth:   true
                            text:               qsTr("Automatically Connect on Start")
                            checked:            editingConfig.autoConnect
                            onCheckedChanged:   editingConfig.autoConnect = checked
                        }

                        QGCCheckBoxSlider {
                            Layout.fillWidth:   true
                            text:               qsTr("High Latency")
                            checked:            editingConfig.highLatency
                            onCheckedChanged:   editingConfig.highLatency = checked
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: popupStyle.borderColor
                            opacity: 0.8
                        }

                        LabelledComboBox {
                            Layout.fillWidth:       true
                            label:                  qsTr("Type")
                            comboBoxPreferredWidth: ScreenTools.defaultFontPixelWidth * 18
                            enabled:                originalConfig == null
                            model:                  _linkManager.linkTypeStrings
                            Component.onCompleted:  comboBox.currentIndex = editingConfig.linkType

                            onActivated: (index) => {
                                if (index !== editingConfig.linkType) {
                                    var name = nameField.text
                                    editingConfig = _linkManager.createConfiguration(index, name)
                                }
                            }
                        }

                        Loader {
                            id:     linkSettingsLoader
                            Layout.fillWidth: true
                            source: editingConfig && editingConfig.settingsURL ? editingConfig.settingsURL : ""
                            asynchronous: true

                            property var subEditConfig:         editingConfig
                            property int _firstColumnWidth:     linkDialog._fieldLabelWidth
                            property int _secondColumnWidth:    ScreenTools.defaultFontPixelWidth * 24
                            property int _rowSpacing:           ScreenTools.defaultFontPixelHeight * 0.55
                            property int _colSpacing:           ScreenTools.defaultFontPixelWidth * 0.8

                            onStatusChanged: {
                                if (status === Loader.Error) {
                                    console.warn("Failed to load link settings page:", source)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
