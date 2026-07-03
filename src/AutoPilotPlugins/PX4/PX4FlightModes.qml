import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SetupPage {
    centerPageLoader: true
    centerDescriptionText: true
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
            readonly property var _modeDisplayMap: ({
                "Unassigned": qsTr("未分配"),
                "Position": qsTr("位置"),
                "Position Slow": qsTr("慢速位置"),
                "Mission": qsTr("任务"),
                "Stabilized": qsTr("增稳"),
                "Altitude": qsTr("高度"),
                "Manual": qsTr("手动"),
                "Acro": qsTr("特技"),
                "Offboard": qsTr("机外控制"),
                "Return": qsTr("返航"),
                "Hold": qsTr("悬停"),
                "Takeoff": qsTr("起飞"),
                "Land": qsTr("降落"),
                "Precision Land": qsTr("精准降落"),
                "Follow Me": qsTr("跟随"),
                "Orbit": qsTr("盘旋"),
                "External Mode 1": qsTr("外部模式 1"),
                "External Mode 2": qsTr("外部模式 2"),
                "External Mode 3": qsTr("外部模式 3"),
                "External Mode 4": qsTr("外部模式 4"),
                "External Mode 5": qsTr("外部模式 5"),
                "External Mode 6": qsTr("外部模式 6"),
                "External Mode 7": qsTr("外部模式 7"),
                "External Mode 8": qsTr("外部模式 8")
            })

            function _displayText(text) {
                if (text === undefined || text === null) {
                    return ""
                }

                const value = text.toString()
                if (_modeDisplayMap[value]) {
                    return _modeDisplayMap[value]
                }
                if (value.indexOf("Channel ") === 0) {
                    return qsTr("通道 %1").arg(value.substring("Channel ".length))
                }

                return value
            }

            function _displayModel(fact) {
                if (!fact || !fact.enumStrings) {
                    return []
                }

                const values = []
                for (let i = 0; i < fact.enumStrings.length; i++) {
                    values.push(_displayText(fact.enumStrings[i]))
                }
                return values
            }

            function _factCurrentIndex(fact, indexModel) {
                if (!fact) {
                    return 0
                }
                return indexModel ? fact.value : fact.enumIndex
            }

            function _setFactFromIndex(fact, index, indexModel) {
                if (!fact || index < 0) {
                    return
                }

                if (indexModel) {
                    fact.value = index
                } else if (fact.enumValues && index < fact.enumValues.length) {
                    fact.value = fact.enumValues[index]
                }
            }

            function _switchLabel(shortDescription) {
                switch (shortDescription) {
                case "Arm switch channel":
                    return qsTr("解锁开关通道")
                case "Emergency Kill switch channel":
                    return qsTr("紧急停止开关通道")
                case "Offboard switch channel":
                    return qsTr("机外控制开关通道")
                case "Landing gear switch channel":
                    return qsTr("起落架开关通道")
                case "Loiter switch channel":
                    return qsTr("盘旋开关通道")
                case "Return switch channel":
                    return qsTr("返航开关通道")
                default:
                    return shortDescription
                }
            }

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

                                    QGCComboBox {
                                        id: modeChannelCombo
                                        property Fact fact: controller.getParameterFact(-1, "RC_MAP_FLTMODE")
                                        property bool indexModel: fact ? fact.enumValues.length === 0 : true
                                        Layout.fillWidth:   true
                                        model:              root._displayModel(fact)
                                        currentIndex:       root._factCurrentIndex(fact, indexModel)
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
                                        onActivated: (index) => root._setFactFromIndex(fact, index, indexModel)

                                        Connections {
                                            target: fact
                                            function onValueChanged() {
                                                modeChannelCombo.currentIndex = root._factCurrentIndex(modeChannelCombo.fact, modeChannelCombo.indexModel)
                                            }
                                            function onEnumsChanged() {
                                                modeChannelCombo.model = root._displayModel(modeChannelCombo.fact)
                                                modeChannelCombo.currentIndex = root._factCurrentIndex(modeChannelCombo.fact, modeChannelCombo.indexModel)
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: 6

                                        QGCComboBox {
                                            id: flightModeCombo
                                            property Fact fact: controller.getParameterFact(-1, "COM_FLTMODE" + (modelData + 1))
                                            property bool indexModel: fact ? fact.enumValues.length === 0 : true
                                            Layout.fillWidth:   true
                                            model:              root._displayModel(fact)
                                            currentIndex:       root._factCurrentIndex(fact, indexModel)
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
                                            onActivated: (index) => root._setFactFromIndex(fact, index, indexModel)

                                            Connections {
                                                target: fact
                                                function onValueChanged() {
                                                    flightModeCombo.currentIndex = root._factCurrentIndex(flightModeCombo.fact, flightModeCombo.indexModel)
                                                }
                                                function onEnumsChanged() {
                                                    flightModeCombo.model = root._displayModel(flightModeCombo.fact)
                                                    flightModeCombo.currentIndex = root._factCurrentIndex(flightModeCombo.fact, flightModeCombo.indexModel)
                                                }
                                            }
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
                                                text:               root._switchLabel(swFact.shortDescription)
                                                Layout.fillWidth:   true
                                                color:              swActive ? _accentColor : _secondaryTextColor
                                            }

                                            QGCComboBox {
                                                id: switchChannelCombo
                                                property bool indexModel: swFact ? swFact.enumValues.length === 0 : true
                                                Layout.preferredWidth:  _channelComboWidth
                                                model:                  root._displayModel(swFact)
                                                currentIndex:           root._factCurrentIndex(swFact, indexModel)
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
                                                onActivated: (comboIndex) => root._setFactFromIndex(swFact, comboIndex, indexModel)

                                                Connections {
                                                    target: swFact
                                                    function onValueChanged() {
                                                        switchChannelCombo.currentIndex = root._factCurrentIndex(swFact, switchChannelCombo.indexModel)
                                                    }
                                                    function onEnumsChanged() {
                                                        switchChannelCombo.model = root._displayModel(swFact)
                                                        switchChannelCombo.currentIndex = root._factCurrentIndex(swFact, switchChannelCombo.indexModel)
                                                    }
                                                }
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
