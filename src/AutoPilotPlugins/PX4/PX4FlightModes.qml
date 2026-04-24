import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SetupPage {
    centerPageLoader: true
    pageComponent:  pageComponent
    Component {
        id: pageComponent

        Item {
            id:     root
            width:  availableWidth
            height: availableHeight
            property bool _qgcPopupChrome: true

            property string sectionNameFilter: ""

            property real _margins:         ScreenTools.defaultFontPixelHeight / 2
            property var  _switchNameList:  [ "RC_MAP_ARM_SW", "RC_MAP_GEAR_SW", "RC_MAP_KILL_SW", "RC_MAP_LOITER_SW", "RC_MAP_OFFB_SW", "RC_MAP_RETURN_SW" ]
            property var  _switchTHList:    [ "RC_ARMSWITCH_TH", "RC_GEAR_TH", "RC_KILLSWITCH_TH", "RC_LOITER_TH", "RC_OFFB_TH", "RC_RETURN_TH" ]
            readonly property color _panelColor: "#2D2D2D"
            readonly property color _inputColor: "#252525"
            readonly property color _borderColor: "#333333"
            readonly property color _primaryTextColor: "#FFFFFF"
            readonly property color _secondaryTextColor: "#B0B0B0"
            readonly property color _accentColor: "#2563EB"
            readonly property real _cornerRadius: 8

            readonly property real _channelComboWidth: ScreenTools.defaultFontPixelWidth * 13

            Component.onCompleted: {
                if (controller.vehicle.vtol) {
                    _switchNameList.push("RC_MAP_TRANS_SW")
                    _switchTHList.push("RC_TRANS_TH")
                }
                if (controller.vehicle.fixedWing) {
                    _switchNameList.push("RC_MAP_FLAPS")
                    _switchTHList.push("")
                }
                switchRepeater.model = _switchNameList
            }

            PX4SimpleFlightModesController {
                id: controller
            }

            Rectangle {
                anchors.fill: parent
                color: "#202020"
                border.width: 1
                border.color: _borderColor
                radius: _cornerRadius
            }

            QGCFlickable {
                id: pageFlickable
                anchors.fill:   parent
                anchors.margins: ScreenTools.defaultFontPixelHeight
                clip:           true
                contentWidth:   Math.max(width, mainColumn.width)
                contentHeight:  Math.max(height, mainColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 2)

                Column {
                    id:         mainColumn
                    width:      settingsRow.width
                    x:          Math.max(0, (pageFlickable.contentWidth - width) / 2)
                    y:          Math.max(0, (pageFlickable.contentHeight - implicitHeight) / 2)
                    spacing:    _margins

                    Row {
                        id:         settingsRow
                        spacing:    _margins

                        Column {
                            id:      flightModeSettingsColumn
                            spacing: _margins
                            visible: sectionNameFilter === "" || sectionNameFilter === qsTr("Flight Modes")

                            QGCLabel {
                                id:             flightModeLabel
                                text:           qsTr("Flight Mode Settings")
                                font.bold:      true
                                color:          _primaryTextColor
                            }

                            Rectangle {
                                id:                 flightModeSettings
                                width:              flightModeColumn.width + (_margins * 2)
                                height:             flightModeColumn.height + ScreenTools.defaultFontPixelHeight
                                color:              _panelColor
                                border.width:       1
                                border.color:       _borderColor
                                radius:             _cornerRadius

                                GridLayout {
                                    id:                 flightModeColumn
                                    anchors.margins:    ScreenTools.defaultFontPixelWidth
                                    anchors.left:       parent.left
                                    anchors.top:        parent.top
                                    rows:               7
                                    rowSpacing:         ScreenTools.defaultFontPixelWidth / 2
                                    columnSpacing:      rowSpacing
                                    flow:               GridLayout.TopToBottom

                                    QGCLabel {
                                        Layout.fillWidth:   true
                                        text:               qsTr("Mode Channel")
                                        color:              _secondaryTextColor
                                    }

                                    Repeater {
                                        model: 6

                                        QGCLabel {
                                            Layout.fillWidth:   true
                                            text:               qsTr("Flight Mode %1").arg(modelData + 1)
                                            color:              (controller.activeFlightMode - 1) == index ? _accentColor : _secondaryTextColor
                                        }
                                    }

                                    FactComboBox {
                                        Layout.fillWidth:   true
                                        fact:               controller.getParameterFact(-1, "RC_MAP_FLTMODE")
                                        indexModel:         false
                                        sizeToContents:     true
                                        backgroundColor:    _inputColor
                                        borderColor:        _borderColor
                                        focusBorderColor:   _accentColor
                                        textColor:          _primaryTextColor
                                        popupBackgroundColor: "#1A1A1A"
                                        popupBorderColor:   _borderColor
                                        delegateSelectedBackgroundColor: _accentColor
                                        delegateSelectedTextColor: _primaryTextColor
                                        showFocusBorder:    true
                                        borderRadius:       _cornerRadius
                                    }

                                    Repeater {
                                        model: 6

                                        FactComboBox {
                                            Layout.fillWidth:   true
                                            fact:               controller.getParameterFact(-1, "COM_FLTMODE" + (modelData + 1))
                                            indexModel:         false
                                            sizeToContents:     true
                                            backgroundColor:    _inputColor
                                            borderColor:        _borderColor
                                            focusBorderColor:   _accentColor
                                            textColor:          _primaryTextColor
                                            popupBackgroundColor: "#1A1A1A"
                                            popupBorderColor:   _borderColor
                                            delegateSelectedBackgroundColor: _accentColor
                                            delegateSelectedTextColor: _primaryTextColor
                                            showFocusBorder:    true
                                            borderRadius:       _cornerRadius
                                        }
                                    }
                                }
                            } // Rectangle - Flight Modes
                        } // Column - Flight mode settings

                        Column {
                            id:         column2
                            spacing:    _margins
                            visible:    sectionNameFilter === "" || sectionNameFilter === qsTr("Switch Settings")

                            QGCLabel {
                                text:           qsTr("Switch Settings")
                                font.bold:      true
                                color:          _primaryTextColor
                            }

                            Rectangle {
                                id:     switchSettingsRect
                                width:  switchSettingsGrid.width + (_margins * 2)
                                height: switchSettingsGrid.height + ScreenTools.defaultFontPixelHeight
                                color:  _panelColor
                                border.width: 1
                                border.color: _borderColor
                                radius: _cornerRadius

                                GridLayout {
                                    id:                 switchSettingsGrid
                                    anchors.margins:    ScreenTools.defaultFontPixelWidth
                                    anchors.left:       parent.left
                                    anchors.top:        parent.top
                                    columns:            2
                                    columnSpacing:      ScreenTools.defaultFontPixelWidth

                                    Repeater {
                                        id: switchRepeater

                                        RowLayout {
                                            spacing:            ScreenTools.defaultFontPixelWidth
                                            Layout.fillWidth:   true

                                            property string thFactName:     _switchTHList[index]
                                            property bool   thFactExists:   thFactName !== ""
                                            property Fact   swFact:         controller.getParameterFact(-1, modelData)
                                            property Fact   thFact:         thFactExists ? controller.getParameterFact(-1, thFactName) : null
                                            property real   thValue:        thFactExists ? thFact.rawValue : 0.5
                                            property real   thPWM:          1000 + (1000 * thValue)
                                            property int    swChannel:      swFact.rawValue - 1
                                            property bool   swActive:       swChannel < 0 ?
                                                                                false :
                                                                                (thValue >= 0 ?
                                                                                     (controller.rcChannelValues[swChannel] > thPWM) :
                                                                                     (controller.rcChannelValues[swChannel] <= thPWM))
                                            QGCLabel {
                                                text:               swFact.shortDescription
                                                Layout.fillWidth:   true
                                                color:              swActive ? _accentColor : _secondaryTextColor
                                            }

                                            FactComboBox {
                                                Layout.preferredWidth:  _channelComboWidth
                                                fact:                   swFact
                                                indexModel:             false
                                                backgroundColor:        _inputColor
                                                borderColor:            _borderColor
                                                focusBorderColor:       _accentColor
                                                textColor:              _primaryTextColor
                                                popupBackgroundColor:   "#1A1A1A"
                                                popupBorderColor:       _borderColor
                                                delegateSelectedBackgroundColor: _accentColor
                                                delegateSelectedTextColor: _primaryTextColor
                                                showFocusBorder:        true
                                                borderRadius:           _cornerRadius
                                            }
                                        }
                                    }
                                }
                            } // Rectangle

                            RCChannelMonitor {
                                width:      switchSettingsRect.width
                                twoColumn:  true
                            }
                        } // Column - Switch settings
                    } // Row - Settings
                }
            }
        }
    }
}
