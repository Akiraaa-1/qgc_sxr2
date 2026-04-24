import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.VehicleSetup

SetupPage {
    id: radioPage
    pageComponent: pageComponent
    centerPageLoader: true
    centerDescriptionText: true
    readonly property color _darkPageColor: "#1E1E1E"
    readonly property color _darkPanelColor: popupStyle.panelBackground
    readonly property color _darkInputColor: popupStyle.inputBackground
    readonly property color _darkBorderColor: popupStyle.borderColor
    readonly property color _darkPrimaryTextColor: popupStyle.primaryTextColor
    readonly property color _darkSecondaryTextColor: popupStyle.secondaryTextColor
    readonly property color _darkAccentColor: popupStyle.accentColor
    readonly property color _darkButtonColor: "#333333"
    readonly property color _darkPopupColor: popupStyle.popupBackground
    readonly property real _darkRadius: popupStyle.cornerRadius

    QGCPopupStyle { id: popupStyle }

    Component {
        id: pageComponent

        Item {
            property real _outerMargin: ScreenTools.defaultFontPixelHeight
            implicitWidth: Math.max(framedPanel.implicitWidth + (_outerMargin * 2), radioPage.availableWidth)
            implicitHeight: Math.max(framedPanel.implicitHeight + (_outerMargin * 2), radioPage.availableHeight)
            width: implicitWidth
            height: implicitHeight

            Rectangle {
                anchors.fill: parent
                radius: 0
                color: radioPage._darkPageColor
            }

            Rectangle {
                id: framedPanel
                property real _padding: ScreenTools.defaultFontPixelHeight * 0.8
                readonly property real _panelSideMargin: ScreenTools.defaultFontPixelWidth * 4
                readonly property real _minimumOuterWidth: ScreenTools.defaultFontPixelWidth * 56
                readonly property real _preferredOuterWidth: ScreenTools.defaultFontPixelWidth * 80
                readonly property real _availableOuterWidth: Math.max(ScreenTools.defaultFontPixelWidth * 36, radioPage.availableWidth - _panelSideMargin)
                readonly property real _targetOuterWidth: _availableOuterWidth < _minimumOuterWidth ? _availableOuterWidth : Math.min(_preferredOuterWidth, _availableOuterWidth)

                implicitWidth: _targetOuterWidth
                implicitHeight: remoteControlCalibration.implicitHeight + (_padding * 2)
                width: implicitWidth
                height: implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent._outerMargin
                radius: radioPage._darkRadius
                color: radioPage._darkPanelColor
                border.width: 1
                border.color: radioPage._darkBorderColor

                RemoteControlCalibration {
                    id: remoteControlCalibration
                    anchors.fill: parent
                    anchors.margins: framedPanel._padding

                    useDeadband: false
                    useDarkStyle: true

                    controller: RadioComponentController {
                        statusText: remoteControlCalibration.statusText
                        cancelButton: remoteControlCalibration.cancelButton
                        nextButton: remoteControlCalibration.nextButton
                        joystickMode: false

                        onThrottleReversedCalFailure: QGroundControl.showMessageDialog(radioPage, qsTr("Throttle channel reversed"), qsTr("Calibration failed. The throttle channel on your transmitter is reversed. You must correct this on your transmitter in order to complete calibration."))
                    }

                    Component.onCompleted: controller.start()

                    additionalSetupComponent: ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight / 2

                        ColumnLayout {
                            id: switchSettings
                            Layout.fillWidth: true

                            Repeater {
                                model: QGroundControl.multiVehicleManager.activeVehicle.px4Firmware ?
                                            (QGroundControl.multiVehicleManager.activeVehicle.multiRotor ?
                                                [ "RC_MAP_AUX1", "RC_MAP_AUX2", "RC_MAP_PARAM1", "RC_MAP_PARAM2", "RC_MAP_PARAM3", "RC_MAP_PAY_SW"] :
                                                [ "RC_MAP_FLAPS", "RC_MAP_AUX1", "RC_MAP_AUX2", "RC_MAP_PARAM1", "RC_MAP_PARAM2", "RC_MAP_PARAM3", "RC_MAP_PAY_SW"]) :
                                            0

                                LabelledFactComboBox {
                                    label: (fact && fact.shortDescription !== "") ? fact.shortDescription : modelData
                                    fact: controller.getParameterFact(-1, modelData)
                                    indexModel: false
                                    comboBoxPreferredWidth: ScreenTools.defaultFontPixelWidth * 18
                                    labelColor: radioPage._darkSecondaryTextColor
                                    comboBoxBackgroundColor: radioPage._darkInputColor
                                    comboBoxBorderColor: radioPage._darkBorderColor
                                    comboBoxFocusBorderColor: radioPage._darkAccentColor
                                    comboBoxTextColor: radioPage._darkPrimaryTextColor
                                    comboBoxPopupBackgroundColor: "#1A1A1A"
                                    comboBoxPopupBorderColor: radioPage._darkBorderColor
                                    comboBoxSelectedColor: radioPage._darkAccentColor
                                    comboBoxSelectedTextColor: radioPage._darkPrimaryTextColor
                                    comboBoxRadius: radioPage._darkRadius
                                    comboBoxShowFocusBorder: true
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: radioPage._darkBorderColor
                        }

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth

                            QGCButton {
                                id: bindButton
                                text: qsTr("Spektrum Bind")
                                backgroundColor: pressed ? popupStyle.pressedColor(radioPage._darkButtonColor) : (hovered ? popupStyle.hoverColor(radioPage._darkButtonColor) : radioPage._darkButtonColor)
                                borderColor: radioPage._darkBorderColor
                                textColor: radioPage._darkPrimaryTextColor
                                backRadius: radioPage._darkRadius
                                showBorder: true
                                overlayColor: "transparent"
                                onClicked: spektrumBindDialogFactory.open()
                            }

                            QGCButton {
                                text: qsTr("CRSF Bind")
                                backgroundColor: pressed ? popupStyle.pressedColor(radioPage._darkButtonColor) : (hovered ? popupStyle.hoverColor(radioPage._darkButtonColor) : radioPage._darkButtonColor)
                                borderColor: radioPage._darkBorderColor
                                textColor: radioPage._darkPrimaryTextColor
                                backRadius: radioPage._darkRadius
                                showBorder: true
                                overlayColor: "transparent"
                                onClicked: QGroundControl.showMessageDialog(radioPage, qsTr("CRSF Bind"),
                                                                        qsTr("Click Ok to place your CRSF receiver in the bind mode."),
                                                                        Dialog.Ok | Dialog.Cancel,
                                                                        function() { controller.crsfBindMode() })
                            }

                            QGCButton {
                                text: qsTr("Copy Trims")
                                backgroundColor: pressed ? popupStyle.pressedColor(radioPage._darkButtonColor) : (hovered ? popupStyle.hoverColor(radioPage._darkButtonColor) : radioPage._darkButtonColor)
                                borderColor: radioPage._darkBorderColor
                                textColor: radioPage._darkPrimaryTextColor
                                backRadius: radioPage._darkRadius
                                showBorder: true
                                overlayColor: "transparent"
                                onClicked: QGroundControl.showMessageDialog(radioPage, qsTr("Copy Trims"),
                                                                        qsTr("Center your sticks and move throttle all the way down, then press Ok to copy trims. After pressing Ok, reset the trims on your radio back to zero."),
                                                                        Dialog.Ok | Dialog.Cancel,
                                                                        function() { controller.copyTrims() })
                            }
                        }

                        QGCPopupDialogFactory {
                            id: spektrumBindDialogFactory

                            dialogComponent: spektrumBindDialogComponent
                        }

                        Component {
                            id: spektrumBindDialogComponent

                            QGCPopupDialog {
                                title: qsTr("Spektrum Bind")
                                buttons: Dialog.Ok | Dialog.Cancel

                                onAccepted: { controller.spektrumBindMode(radioGroup.checkedButton.bindMode) }

                                ButtonGroup { id: radioGroup }

                                ColumnLayout {
                                    spacing: ScreenTools.defaultFontPixelHeight / 2

                                    QGCLabel {
                                        wrapMode: Text.WordWrap
                                        color: radioPage._darkSecondaryTextColor
                                        text: qsTr("Click Ok to place your Spektrum receiver in the bind mode.")
                                    }

                                    QGCLabel {
                                        wrapMode: Text.WordWrap
                                        color: radioPage._darkSecondaryTextColor
                                        text: qsTr("Select the specific receiver type below:")
                                    }

                                    QGCRadioButton {
                                        text: qsTr("DSM2 Mode")
                                        ButtonGroup.group: radioGroup
                                        property int bindMode: RadioComponentController.DSM2
                                        textColor: radioPage._darkSecondaryTextColor
                                        indicatorBackgroundColor: radioPage._darkInputColor
                                        indicatorBorderColor: radioPage._darkBorderColor
                                        indicatorHoverColor: "#3A3A3A"
                                        indicatorDotColor: radioPage._darkAccentColor
                                    }

                                    QGCRadioButton {
                                        text: qsTr("DSMX (7 channels or less)")
                                        ButtonGroup.group: radioGroup
                                        property int bindMode: RadioComponentController.DSMX7
                                        textColor: radioPage._darkSecondaryTextColor
                                        indicatorBackgroundColor: radioPage._darkInputColor
                                        indicatorBorderColor: radioPage._darkBorderColor
                                        indicatorHoverColor: "#3A3A3A"
                                        indicatorDotColor: radioPage._darkAccentColor
                                    }

                                    QGCRadioButton {
                                        checked: true
                                        text: qsTr("DSMX (8 channels or more)")
                                        ButtonGroup.group: radioGroup
                                        property int bindMode: RadioComponentController.DSMX8
                                        textColor: radioPage._darkSecondaryTextColor
                                        indicatorBackgroundColor: radioPage._darkInputColor
                                        indicatorBorderColor: radioPage._darkBorderColor
                                        indicatorHoverColor: "#3A3A3A"
                                        indicatorDotColor: radioPage._darkAccentColor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
