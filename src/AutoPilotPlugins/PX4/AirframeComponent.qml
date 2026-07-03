import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SetupPage {
    id:             airframePage
    pageComponent:  (controller && controller.showCustomConfigPanel) ? customFrame : pageComponent
    centerDescriptionText: true

    QGCPopupStyle { id: popupStyle }

    AirframeComponentController {
        id:         controller
    }

    Component {
        id: customFrame
        Column {
            width:          availableWidth
            spacing:        ScreenTools.defaultFontPixelHeight * 2

            Item {
                width:      1
                height:     1
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width:      Math.min(parent.width, ScreenTools.defaultFontPixelWidth * 72)
                height:     customText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
                color:      popupStyle.panelBackground
                radius:     popupStyle.cornerRadius
                border.width: 1
                border.color: popupStyle.borderColor

                QGCLabel {
                    id:                 customText
                    anchors.fill:       parent
                    anchors.margins:    ScreenTools.defaultFontPixelHeight
                    wrapMode:           Text.WordWrap
                    color:              popupStyle.primaryTextColor
                    text:               qsTr("当前飞行器使用的是自定义机架配置。") +
                                        qsTr(" 该配置只能通过参数编辑器进行修改。\n\n") +
                                        qsTr("如果你想重置机架配置并选择标准配置，请点击下方的“重置”。")
                }
            }

            QGCButton {
                text:       qsTr("重置")
                enabled:    sys_autostart
                anchors.horizontalCenter: parent.horizontalCenter
                property Fact sys_autostart: controller.getParameterFact(-1, "SYS_AUTOSTART")
                showBorder: true
                backRadius: popupStyle.cornerRadius
                backgroundColor: popupStyle.secondaryButtonColor
                borderColor: popupStyle.borderColor
                textColor: popupStyle.primaryTextColor
                overlayColor: "#FFFFFF"
                hoverOverlayOpacity: 0.08
                pressedOverlayOpacity: 0.14
                stateAnimationDuration: popupStyle.stateAnimationDuration
                onClicked: {
                    if (sys_autostart) {
                        sys_autostart.value = 0
                    }
                }
            }
        }
    }

    Component {
        id: pageComponent

        Column {
            id:     mainColumn
            width:  availableWidth

            property real _minW:        ScreenTools.defaultFontPixelWidth * 30
            property real _boxWidth:    _minW
            property real _boxSpace:    ScreenTools.defaultFontPixelWidth

            readonly property real spacerHeight: ScreenTools.defaultFontPixelHeight

            onWidthChanged: {
                computeDimensions()
            }

            Component.onCompleted: computeDimensions()

            function computeDimensions() {
                var sw  = 0
                var rw  = 0
                var idx = Math.floor(mainColumn.width / (_minW + ScreenTools.defaultFontPixelWidth))
                if (idx < 1) {
                    _boxWidth = mainColumn.width
                    _boxSpace = 0
                } else {
                    _boxSpace = 0
                    if (idx > 1) {
                        _boxSpace = ScreenTools.defaultFontPixelWidth
                        sw = _boxSpace * (idx - 1)
                    }
                    rw = mainColumn.width - sw
                    _boxWidth = rw / idx
                }
            }

            Item {
                id:             helpApplyRow
                anchors.left:   parent.left
                anchors.right:  parent.right
                height:         Math.max(helpText.contentHeight, applyButton.height) + ScreenTools.defaultFontPixelHeight

                Rectangle {
                    anchors.fill: parent
                    color: popupStyle.panelBackground
                    radius: popupStyle.cornerRadius
                    border.width: 1
                    border.color: popupStyle.borderColor
                }

                QGCLabel {
                    id:             helpText
                    anchors.left:   parent.left
                    anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.6
                    anchors.right:  applyButton.left
                    anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.6
                    anchors.verticalCenter: parent.verticalCenter
                    text:           (controller.currentVehicleName != "" ?
                                         qsTr("已连接 %1。").arg(controller.currentVehicleName) :
                                         qsTr("机架未设置。")) +
                                    qsTr(" 要更改此配置，请在下方选择所需机架，然后点击“应用并重启”。")
                    font.bold:      true
                    wrapMode:       Text.WordWrap
                    color:          popupStyle.primaryTextColor
                }

                QGCButton {
                    id:             applyButton
                    anchors.right:  parent.right
                    anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.6
                    anchors.verticalCenter: parent.verticalCenter
                    text:           qsTr("应用并重启")
                    showBorder:     true
                    backRadius:     popupStyle.cornerRadius
                    backgroundColor: popupStyle.primaryButtonColor
                    borderColor:    popupStyle.borderColor
                    textColor:      popupStyle.primaryTextColor
                    overlayColor:   "#000000"
                    hoverOverlayOpacity: 0.12
                    pressedOverlayOpacity: 0.20
                    stateAnimationDuration: popupStyle.stateAnimationDuration
                    onClicked:      QGroundControl.showMessageDialog(airframePage, qsTr("应用并重启"),
                                                                 qsTr("点击“应用”将保存你对机架配置所做的更改。<br><br>\
                                                                        除遥控器校准外，所有飞行器参数都会被重置。<br><br>\
                                                                        飞行器也会重启以完成该过程。"),
                                                                 Dialog.Apply | Dialog.Cancel,
                                                                 function() { controller.changeAutostart() })
                }
            }

            Item {
                id:             lastSpacer
                height:         parent.spacerHeight
                width:          10
            }

            Flow {
                id:         flowView
                width:      parent.width
                spacing:    _boxSpace

                ButtonGroup {
                    id: airframeTypeExclusive
                }

                Repeater {
                    model: controller.airframeTypes

                    Rectangle {
                        width:  _boxWidth
                        height: ScreenTools.defaultFontPixelHeight * 14
                        color:  cardMouse.pressed
                                    ? popupStyle.pressedColor(popupStyle.panelBackground)
                                    : (cardMouse.containsMouse ? popupStyle.hoverColor(popupStyle.panelBackground) : popupStyle.panelBackground)
                        radius: popupStyle.cornerRadius
                        border.width: 1
                        border.color: popupStyle.borderColor
                        clip: true

                        readonly property real titleHeight: ScreenTools.defaultFontPixelHeight * 1.75
                        readonly property real innerMargin: ScreenTools.defaultFontPixelWidth

                        Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }

                        MouseArea {
                            id:             cardMouse
                            anchors.fill:   parent
                            hoverEnabled:   !ScreenTools.isMobile

                            onClicked: {
                                applyButton.primary = true
                                airframeCheckBox.checked = true
                            }
                        }

                        QGCLabel {
                            id:                 title
                            text:               modelData.name
                            color:              popupStyle.primaryTextColor
                            anchors.left:       parent.left
                            anchors.leftMargin: innerMargin
                            anchors.top:        parent.top
                            anchors.topMargin:  innerMargin * 0.5
                        }

                        Rectangle {
                            anchors.topMargin:  ScreenTools.defaultFontPixelHeight / 2
                            anchors.top:        title.bottom
                            anchors.bottom:     parent.bottom
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            color:              airframeCheckBox.checked
                                                    ? Qt.rgba(popupStyle.accentColor.r, popupStyle.accentColor.g, popupStyle.accentColor.b, 0.22)
                                                    : (cardMouse.pressed
                                                        ? popupStyle.pressedColor(popupStyle.inputBackground)
                                                        : (cardMouse.containsMouse ? popupStyle.hoverColor(popupStyle.inputBackground) : popupStyle.inputBackground))
                            radius:             popupStyle.cornerRadius
                            border.width:       1
                            border.color:       airframeCheckBox.checked ? popupStyle.accentColor : popupStyle.borderColor

                            Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
                            Behavior on border.color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }

                            Image {
                                id:                 image
                                anchors.margins:    innerMargin
                                anchors.top:        parent.top
                                anchors.bottom:     combo.top
                                anchors.left:       parent.left
                                anchors.right:      parent.right
                                fillMode:           Image.PreserveAspectFit
                                smooth:             true
                                mipmap:             true
                                source:             modelData.imageResource
                            }

                            QGCCheckBox {
                                id:             airframeCheckBox
                                checked:        modelData.name === controller.currentAirframeType
                                buttonGroup:    airframeTypeExclusive
                                visible:        false

                                onCheckedChanged: {
                                    if (checked && combo.currentIndex !== -1) {
                                        console.log("check box change", combo.currentIndex)
                                        controller.autostartId = modelData.airframes[combo.currentIndex].autostartId
                                    }
                                }
                            }

                            QGCComboBox {
                                id:                 combo
                                objectName:         modelData.airframeType + "ComboBox"
                                anchors.margins:    innerMargin
                                anchors.bottom:     parent.bottom
                                anchors.left:       parent.left
                                anchors.right:      parent.right
                                model:              modelData.airframes
                                textRole:           "text"
                                borderRadius:       popupStyle.cornerRadius
                                backgroundColor:    popupStyle.inputBackground
                                borderColor:        popupStyle.borderColor
                                focusBorderColor:   popupStyle.accentColor
                                showFocusBorder:    true
                                textColor:          popupStyle.primaryTextColor
                                popupBackgroundColor: popupStyle.popupBackground
                                popupBorderColor:   popupStyle.borderColor
                                delegateBackgroundColor: popupStyle.popupBackground
                                delegateSelectedBackgroundColor: popupStyle.hoverColor(popupStyle.panelBackground)
                                delegateTextColor:  popupStyle.primaryTextColor
                                delegateSelectedTextColor: popupStyle.primaryTextColor
                                stateAnimationDuration: popupStyle.stateAnimationDuration

                                Component.onCompleted: {
                                    if (airframeCheckBox.checked) {
                                        currentIndex = controller.currentVehicleIndex
                                    }
                                }

                                onActivated: (index) => {
                                    applyButton.primary = true
                                    airframeCheckBox.checked = true
                                    console.log("combo change", index)
                                    controller.autostartId = modelData.airframes[index].autostartId
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
