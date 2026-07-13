import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

/// Page for sensor calibration. This control is used within the SensorsComponent control and can also be used
/// standalone for custom uis. When using standadalone you can use the various show* bools to show/hide what you want.
Item {
    id: _root
    property bool _qgcPopupChrome: useDarkStyle

    property bool   showSensorCalibrationCompass:   true    ///< true: Show this calibration button
    property bool   showSensorCalibrationGyro:      true    ///< true: Show this calibration button
    property bool   showSensorCalibrationAccel:     true    ///< true: Show this calibration button
    property bool   showSensorCalibrationLevel:     true    ///< true: Show this calibration button
    property bool   showSensorCalibrationAirspeed:  true    ///< true: Show this calibration button
    property bool   showSetOrientations:            true    ///< true: Show this calibration button
    property bool   showNextButton:                 false   ///< true: Show Next button which will signal nextButtonClicked
    property bool   useDarkStyle:                   false

    signal nextButtonClicked

    // Help text which is shown both in the status text area prior to pressing a cal button and in the
    // pre-calibration dialog.

    readonly property string boardRotationText: qsTr("如果朝向与飞行方向一致，请选择 ROTATION_NONE。")
    readonly property string compassRotationText: qsTr("如果朝向与飞行方向一致，请选择 ROTATION_NONE。")

    readonly property string compassHelp:   qsTr("磁力计校准时，需要将飞行器旋转到多个不同姿态。")
    readonly property string gyroHelp:      qsTr("陀螺仪校准时，需要将飞行器放置在平面上并保持静止。")
    readonly property string accelHelp:     qsTr("加速度计校准时，需要将飞行器依次放置在六个面上，确保每个朝向都位于绝对水平的平面上，并在每个姿态下保持静止几秒钟。")
    readonly property string levelHelp:     qsTr("地平线校准时，需要将飞行器放置在其平飞姿态并保持静止。")
    readonly property string airspeedHelp:  qsTr("空速校准时，需要让空速传感器避开一切气流，然后朝传感器吹气。校准过程中请勿触碰传感器，也不要堵住任何气孔。")

    readonly property string statusTextAreaDefaultText: qsTr("点击左侧任一按钮即可开始对应的校准步骤。")

    // Used to pass what type of calibration is being performed to the preCalibrationDialog
    property string preCalibrationDialogType

    // Used to pass help text to the preCalibrationDialog dialog
    property string preCalibrationDialogHelp

    property Fact cal_mag0_id:      controller.getParameterFact(-1, "CAL_MAG0_ID")
    property Fact cal_mag1_id:      controller.getParameterFact(-1, "CAL_MAG1_ID")
    property Fact cal_mag2_id:      controller.getParameterFact(-1, "CAL_MAG2_ID")
    property Fact cal_mag0_rot:     controller.getParameterFact(-1, "CAL_MAG0_ROT")
    property Fact cal_mag1_rot:     controller.getParameterFact(-1, "CAL_MAG1_ROT")
    property Fact cal_mag2_rot:     controller.getParameterFact(-1, "CAL_MAG2_ROT")

    property Fact cal_gyro0_id:     controller.getParameterFact(-1, "CAL_GYRO0_ID")
    property Fact cal_acc0_id:      controller.getParameterFact(-1, "CAL_ACC0_ID")

    property Fact sens_board_rot:   controller.getParameterFact(-1, "SENS_BOARD_ROT")
    property Fact sens_dpres_off:   controller.getParameterFact(-1, "SENS_DPRES_OFF")

    // Id > = signals compass available, rot < 0 signals internal compass
    property bool showCompass0Rot: cal_mag0_id.value > 0 && cal_mag0_rot.value >= 0
    property bool showCompass1Rot: cal_mag1_id.value > 0 && cal_mag1_rot.value >= 0
    property bool showCompass2Rot: cal_mag2_id.value > 0 && cal_mag2_rot.value >= 0

    property bool   _sensorsHaveFixedOrientation:       QGroundControl.corePlugin.options.sensorsHaveFixedOrientation
    property string _calMagIdParamFormat:               "CAL_MAG#_ID"
    property string _calMagRotParamFormat:              "CAL_MAG#_ROT"
    property bool 	_allMagsDisabled:                   controller.parameterExists(-1, "SYS_HAS_MAG") ? controller.getParameterFact(-1, "SYS_HAS_MAG").value === 0 : false
    property bool   _boardOrientationChangeAllowed:     !_sensorsHaveFixedOrientation && setOrientationsDialogShowBoardOrientation
    property bool   _compassOrientationChangeAllowed:   !_sensorsHaveFixedOrientation
    property int    _arbitrarilyLargeMaxMagIndex:       50

    function currentMagParamCount() {
        if (_allMagsDisabled) {
            return 0
        } else {
            for (var index=0; index<_arbitrarilyLargeMaxMagIndex; index++) {
                var magIdParam = _calMagIdParamFormat.replace("#", index)
                if (!controller.parameterExists(-1, magIdParam)) {
                    return index
                }
            }
            console.warn("SensorSetup.qml:currentMagParamCount internal error")
            return -1
        }
    }

    function currentExternalMagCount() {
        if (_allMagsDisabled) {
            return 0
        } else {
            var externalMagCount = 0
            for (var index=0; index<_arbitrarilyLargeMaxMagIndex; index++) {
                var magIdParam = _calMagIdParamFormat.replace("#", index)
                if (controller.parameterExists(-1, magIdParam)) {
                    var calMagIdFact = controller.getParameterFact(-1, magIdParam)
                    var calMagRotFact = controller.getParameterFact(-1, _calMagRotParamFormat.replace("#", index))
                    if (calMagIdFact.value > 0 && calMagRotFact.value >= 0) {
                        externalMagCount++
                    }
                } else {
                    return externalMagCount
                }
            }
            console.warn("SensorSetup.qml:currentExternalMagCount internal error")
            return 0
        }
    }

    function orientationsButtonVisible() {
        if (_sensorsHaveFixedOrientation || !showSetOrientations) {
            return false
        } else if (_boardOrientationChangeAllowed) {
            return true
        } else if (_compassOrientationChangeAllowed && !_allMagsDisabled) {
            for (var index=0; index<_arbitrarilyLargeMaxMagIndex; index++) {
                var magIdParam = _calMagIdParamFormat.replace("#", index)
                if (controller.parameterExists(-1, magIdParam)) {
                    var calMagIdFact = controller.parameterExists(-1, magIdParam)
                    var calMagRotFact = controller.parameterExists(-1, _calMagRotParamFormat.replace("#", index))
                    if (calMagIdFact.value > 0 && calMagRotFact.value >= 0) {
                        // Only external compasses can set orientation
                        return true
                    }
                }
            }
            return false
        } else {
            return false
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    SensorsComponentController {
        id:                         controller
        statusLog:                  statusTextArea
        progressBar:                progressBar
        orientationCalAreaHelpText: orientationCalAreaHelpText

        onResetStatusTextArea: statusLog.text = statusTextAreaDefaultText

        onMagCalComplete: {
            setOrientationsDialogShowBoardOrientation   = false
            setOrientationsDialogFactory.open({ title: qsTr("磁力计校准完成"), showRebootVehicleButton: true })
        }

        onWaitingForCancelChanged: {
            if (controller.waitingForCancel) {
                waitForCancelDialogFactory.open()
            }
        }

        onCalibrationActiveChanged: {
            if (controller.calibrationActive) {
                globals.navigationBlockedReason = qsTr("请先完成或取消当前校准")
            } else {
                globals.navigationBlockedReason = ""
            }
        }
    }

    Component.onDestruction: globals.navigationBlockedReason = ""

    QGCPopupDialogFactory {
        id: waitForCancelDialogFactory

        dialogComponent: waitForCancelDialogComponent
    }

    Component {
        id: waitForCancelDialogComponent

        QGCPopupDialog {
            title:      qsTr("取消校准")
            buttons:    0
            bottomActionButtons: _root.useDarkStyle
            useExplicitActionColors: _root.useDarkStyle
            actionPrimaryBackgroundColor: _accentColor

            ColumnLayout {
                width: ScreenTools.defaultFontPixelWidth * 50
                spacing: ScreenTools.defaultFontPixelHeight * 0.75

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: waitingCancelText.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.6)
                    color: Qt.rgba(0.08, 0.12, 0.16, 0.72)
                    radius: _cornerRadius
                    border.width: 1
                    border.color: _borderColor

                    QGCLabel {
                        id: waitingCancelText
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.8
                        wrapMode: Text.WordWrap
                        color: _secondaryTextColor
                        text: qsTr("正在等待飞行器响应取消操作，这可能需要几秒钟。")
                    }
                }
            }

            Connections {
                target: controller

                onWaitingForCancelChanged: {
                    if (!controller.waitingForCancel) {
                        close()
                    }
                }
            }
        }
    }

    QGCPopupDialogFactory {
        id: preCalibrationDialogFactory

        dialogComponent: preCalibrationDialogComponent
    }

    Component {
        id: preCalibrationDialogComponent

        QGCPopupDialog {
            buttons: Dialog.Cancel | Dialog.Ok
            acceptButtonText: qsTr("开始校准")
            rejectButtonText: qsTr("取消")
            bottomActionButtons: _root.useDarkStyle
            useExplicitActionColors: _root.useDarkStyle
            actionPrimaryBackgroundColor: _accentColor
            actionPrimaryBorderColor: _accentColor
            actionSecondaryBackgroundColor: _buttonColor
            actionSecondaryBorderColor: _dropdownBorderColor
            actionButtonRadius: _cornerRadius

            onAccepted: {
                if (preCalibrationDialogType == "gyro") {
                    controller.calibrateGyro()
                } else if (preCalibrationDialogType == "accel") {
                    controller.calibrateAccel()
                } else if (preCalibrationDialogType == "level") {
                    controller.calibrateLevel()
                } else if (preCalibrationDialogType == "compass") {
                    controller.calibrateCompass()
                } else if (preCalibrationDialogType == "airspeed") {
                    controller.calibrateAirspeed()
                }
            }

            ColumnLayout {
                width: ScreenTools.defaultFontPixelWidth * 52
                spacing: ScreenTools.defaultFontPixelHeight * 0.75

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: calibrationHelpText.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.5)
                    color: Qt.rgba(0.08, 0.12, 0.16, 0.72)
                    radius: _cornerRadius
                    border.width: 1
                    border.color: _borderColor

                    QGCLabel {
                        id: calibrationHelpText
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.75
                        wrapMode: Text.WordWrap
                        color: _primaryTextColor
                        text: preCalibrationDialogHelp
                    }
                }

                ColumnLayout {
                    id:         innerColumn
                    Layout.fillWidth: true
                    spacing:    ScreenTools.defaultFontPixelHeight * 0.65

                    QGCLabel {
                        id:         boardRotationHelp
                        Layout.fillWidth: true
                        wrapMode:   Text.WordWrap
                        color:      _secondaryTextColor
                        visible:    !_sensorsHaveFixedOrientation && (preCalibrationDialogType == "accel" || preCalibrationDialogType == "compass")
                        text:       qsTr("校准前请先设置飞控方向。")
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: boardRotationColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.1)
                        visible:    boardRotationHelp.visible
                        color: _inputColor
                        radius: _cornerRadius
                        border.width: 1
                        border.color: _borderColor

                        ColumnLayout {
                            id: boardRotationColumn
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.55
                            spacing: ScreenTools.defaultFontPixelHeight * 0.35

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("飞控方向")
                                color: _primaryTextColor
                                font.weight: Font.DemiBold
                            }

                            FactComboBox {
                                Layout.fillWidth: true
                                sizeToContents: true
                                fact:           sens_board_rot
                                useExplicitPopupColors: _root.useDarkStyle
                                backgroundColor:        _dropdownColor
                                borderColor:            _dropdownBorderColor
                                focusBorderColor:       _accentColor
                                textColor:              _primaryTextColor
                                popupBackgroundColor:   "#181A1D"
                                popupBorderColor:       _dropdownBorderColor
                                delegateBackgroundColor: "transparent"
                                delegateHoveredBackgroundColor: _dropdownHoverColor
                                delegateSelectedBackgroundColor: _dropdownSelectColor
                                delegateTextColor:      _secondaryTextColor
                                delegateSelectedTextColor: _primaryTextColor
                                showFocusBorder:        true
                                borderRadius:           _cornerRadius
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: _secondaryTextColor
                                text: qsTr("ROTATION_NONE 表示组件朝向与飞行方向一致。")
                            }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode:   Text.WordWrap
                        color:      _secondaryTextColor
                        text:       qsTr("确认环境与飞行器状态无误后开始校准。")
                    }
                }
            }
        }
    }

    property bool setOrientationsDialogShowBoardOrientation:    true

    QGCPopupDialogFactory {
        id: setOrientationsDialogFactory

        dialogComponent: setOrientationsDialogComponent
    }

    Component {
        id: setOrientationsDialogComponent

        QGCPopupDialog {
            buttons: Dialog.Ok
            acceptButtonText: qsTr("完成")
            bottomActionButtons: _root.useDarkStyle
            useExplicitActionColors: _root.useDarkStyle
            actionPrimaryBackgroundColor: _accentColor
            actionPrimaryBorderColor: _accentColor
            actionSecondaryBackgroundColor: _buttonColor
            actionSecondaryBorderColor: _dropdownBorderColor
            actionButtonRadius: _cornerRadius

            property bool showRebootVehicleButton: true

            ColumnLayout {
                width: ScreenTools.defaultFontPixelWidth * 54
                spacing: ScreenTools.defaultFontPixelHeight * 0.75

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: orientationIntro.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.5)
                    color: Qt.rgba(0.08, 0.12, 0.16, 0.72)
                    radius: _cornerRadius
                    border.width: 1
                    border.color: _borderColor
                    visible:    showRebootVehicleButton

                    QGCLabel {
                        id: orientationIntro
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.75
                        wrapMode: Text.WordWrap
                        color: _secondaryTextColor
                        text: qsTr("飞行前请重启飞行器，使方向设置生效。")
                    }
                }

                QGCButton {
                    text:       qsTr("重启飞行器")
                    visible:    showRebootVehicleButton
                    primary: true
                    useExplicitPopupColors: _root.useDarkStyle
                    backgroundColor: _root.useDarkStyle ? _accentColor : qgcPal.primaryButton
                    borderColor: _root.useDarkStyle ? _accentColor : qgcPal.buttonBorder
                    textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.primaryButtonText
                    overlayColor: "#FFFFFF"
                    hoverOverlayOpacity: 0.10
                    pressedOverlayOpacity: 0.18
                    backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                    showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                    Layout.alignment: Qt.AlignLeft
                    onClicked: { controller.vehicle.rebootVehicle(); close() }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text:       qsTr("请按需调整方向。\n\nROTATION_NONE 表示组件朝向与飞行方向一致。")
                    color:      _secondaryTextColor
                    wrapMode:   Text.WordWrap
                    visible:    _boardOrientationChangeAllowed || (_compassOrientationChangeAllowed && currentExternalMagCount() !== 0)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: boardOrientationColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.1)
                    visible: _boardOrientationChangeAllowed
                    color: _inputColor
                    radius: _cornerRadius
                    border.width: 1
                    border.color: _borderColor

                    ColumnLayout {
                        id: boardOrientationColumn
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.55
                        spacing: ScreenTools.defaultFontPixelHeight * 0.35

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("飞控方向")
                            color: _primaryTextColor
                            font.weight: Font.DemiBold
                        }

                        FactComboBox {
                            Layout.fillWidth: true
                            sizeToContents: true
                            fact:           sens_board_rot
                            useExplicitPopupColors: _root.useDarkStyle
                            backgroundColor:        _dropdownColor
                            borderColor:            _dropdownBorderColor
                            focusBorderColor:       _accentColor
                            textColor:              _primaryTextColor
                            popupBackgroundColor:   "#181A1D"
                            popupBorderColor:       _dropdownBorderColor
                            delegateBackgroundColor: "transparent"
                            delegateHoveredBackgroundColor: _dropdownHoverColor
                            delegateSelectedBackgroundColor: _dropdownSelectColor
                            delegateTextColor:      _secondaryTextColor
                            delegateSelectedTextColor: _primaryTextColor
                            showFocusBorder:        true
                            borderRadius:           _cornerRadius
                        }
                    }
                }

                Repeater {
                    model: _compassOrientationChangeAllowed ? currentMagParamCount() : 0

                    Rectangle {
                        // id > = signals compass available, rot < 0 signals internal compass
                        visible: calMagIdFact.value > 0 && calMagRotFact.value >= 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: magOrientationColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.1)
                        color: _inputColor
                        radius: _cornerRadius
                        border.width: 1
                        border.color: _borderColor

                        property Fact calMagIdFact:     controller.getParameterFact(-1, _calMagIdParamFormat.replace("#", index))
                        property Fact calMagRotFact:    controller.getParameterFact(-1, _calMagRotParamFormat.replace("#", index))

                        ColumnLayout {
                            id: magOrientationColumn
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.55
                            spacing: ScreenTools.defaultFontPixelHeight * 0.35

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("磁力计 %1 方向").arg(index)
                                color: _primaryTextColor
                                font.weight: Font.DemiBold
                            }

                            FactComboBox {
                                Layout.fillWidth: true
                                sizeToContents: true
                                fact:           magOrientationColumn.parent.calMagRotFact
                                useExplicitPopupColors: _root.useDarkStyle
                                backgroundColor:        _dropdownColor
                                borderColor:            _dropdownBorderColor
                                focusBorderColor:       _accentColor
                                textColor:              _primaryTextColor
                                popupBackgroundColor:   "#181A1D"
                                popupBorderColor:       _dropdownBorderColor
                                delegateBackgroundColor: "transparent"
                                delegateHoveredBackgroundColor: _dropdownHoverColor
                                delegateSelectedBackgroundColor: _dropdownSelectColor
                                delegateTextColor:      _secondaryTextColor
                                delegateSelectedTextColor: _primaryTextColor
                                showFocusBorder:        true
                                borderRadius:           _cornerRadius
                            }
                        }
                    }
                }
            } // Column
        } // QGCPopupDialog
    } // Component - setOrientationsDialogComponent

    property string sectionNameFilter: ""

    function sectionVisible(name) {
        if (name === qsTr("磁力计")) return !_allMagsDisabled && QGroundControl.corePlugin.options.showSensorCalibrationCompass && showSensorCalibrationCompass
        if (name === qsTr("陀螺仪")) return QGroundControl.corePlugin.options.showSensorCalibrationGyro && showSensorCalibrationGyro
        if (name === qsTr("加速度计")) return QGroundControl.corePlugin.options.showSensorCalibrationAccel && showSensorCalibrationAccel
        if (name === qsTr("地平线")) return QGroundControl.corePlugin.options.showSensorCalibrationLevel && showSensorCalibrationLevel
        if (name === qsTr("空速")) return vehicleComponent.airspeedCalSupported && QGroundControl.corePlugin.options.showSensorCalibrationAirspeed && showSensorCalibrationAirspeed
        if (name === qsTr("方向设置")) return orientationsButtonVisible()
        return true
    }

    function _startCalibration(type, help, title) {
        preCalibrationDialogType = type
        preCalibrationDialogHelp = help
        preCalibrationDialogFactory.open({ title: title })
    }

    function _sectionMatches(filterValue, sourceName) {
        const filterText = filterValue === undefined || filterValue === null ? "" : ("" + filterValue).trim()
        if (filterText === "") {
            return true
        }

        const translatedName = qsTr(sourceName)
        return filterText === sourceName || filterText === translatedName
    }

    readonly property bool _recognizedSectionFilter:
        _sectionMatches(sectionNameFilter, "Compass") || _sectionMatches(sectionNameFilter, "磁力计") ||
        _sectionMatches(sectionNameFilter, "Gyroscope") || _sectionMatches(sectionNameFilter, "陀螺仪") ||
        _sectionMatches(sectionNameFilter, "Accelerometer") || _sectionMatches(sectionNameFilter, "加速度计") ||
        _sectionMatches(sectionNameFilter, "Level Horizon") || _sectionMatches(sectionNameFilter, "地平线") ||
        _sectionMatches(sectionNameFilter, "Airspeed") || _sectionMatches(sectionNameFilter, "空速") ||
        _sectionMatches(sectionNameFilter, "Orientations") || _sectionMatches(sectionNameFilter, "方向设置")

    readonly property string _effectiveSectionFilter: _recognizedSectionFilter ? sectionNameFilter : ""

    property bool _showOrientationPreview: !controller.calibrationActive &&
        (_effectiveSectionFilter !== "") &&
        (_sectionMatches(_effectiveSectionFilter, "Accelerometer") || _sectionMatches(_effectiveSectionFilter, "加速度计") ||
         _sectionMatches(_effectiveSectionFilter, "Compass") || _sectionMatches(_effectiveSectionFilter, "磁力计") ||
         _sectionMatches(_effectiveSectionFilter, "Gyroscope") || _sectionMatches(_effectiveSectionFilter, "陀螺仪"))

    property bool _showAllSidesPreview: _showOrientationPreview &&
        (_sectionMatches(_effectiveSectionFilter, "Accelerometer") || _sectionMatches(_effectiveSectionFilter, "加速度计") ||
         _sectionMatches(_effectiveSectionFilter, "Compass") || _sectionMatches(_effectiveSectionFilter, "磁力计"))

    property bool _showDownOnlyPreview: _showOrientationPreview &&
        _sectionMatches(_effectiveSectionFilter, "Gyroscope") || _sectionMatches(_effectiveSectionFilter, "陀螺仪")

    property bool _showStatusPreview: !controller.calibrationActive &&
        (_effectiveSectionFilter !== "") &&
        (_sectionMatches(_effectiveSectionFilter, "Level Horizon") || _sectionMatches(_effectiveSectionFilter, "地平线") ||
         _sectionMatches(_effectiveSectionFilter, "Airspeed") || _sectionMatches(_effectiveSectionFilter, "空速"))

    readonly property color _panelColor:         "#2D2D2D"
    readonly property color _inputColor:         "#252525"
    readonly property color _borderColor:        "#333333"
    readonly property color _primaryTextColor:   "#FFFFFF"
    readonly property color _secondaryTextColor: "#B0B0B0"
    readonly property color _accentColor:        "#2563EB"
    readonly property color _buttonColor:        "#24272B"
    readonly property color _buttonHoverColor:   "#3A4452"
    readonly property color _dropdownColor:      "#202326"
    readonly property color _dropdownBorderColor:"#3A3F46"
    readonly property color _dropdownHoverColor: Qt.rgba(0.15, 0.39, 0.92, 0.14)
    readonly property color _dropdownSelectColor: Qt.rgba(0.15, 0.39, 0.92, 0.24)
    readonly property real _cornerRadius:        8
    readonly property real _buttonRowSpacing:    ScreenTools.defaultFontPixelWidth * 0.5
    readonly property real _buttonPointSize:     Math.max(10, ScreenTools.defaultFontPointSize - 2)
    readonly property real _buttonHeightFactor:  0.35
    readonly property real _buttonHPadding:      ScreenTools.defaultFontPixelWidth * 0.75

    readonly property int _visibleCalibrationButtonCount:
        (sectionVisible(qsTr("Compass")) ? 1 : 0) +
        (sectionVisible(qsTr("Gyroscope")) ? 1 : 0) +
        (sectionVisible(qsTr("Accelerometer")) ? 1 : 0) +
        (sectionVisible(qsTr("Level Horizon")) ? 1 : 0) +
        (sectionVisible(qsTr("Airspeed")) ? 1 : 0) +
        (sectionVisible(qsTr("Orientations")) ? 2 : 0) +
        (showNextButton ? 1 : 0)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Calibration trigger buttons — one per section, shown based on sectionNameFilter
        RowLayout {
            Layout.fillWidth: true
            spacing: _buttonRowSpacing
            visible: !controller.calibrationActive

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / Math.max(_visibleCalibrationButtonCount, 1)
                text:       qsTr("校准磁力计")
                visible:    sectionVisible(qsTr("磁力计"))
                pointSize:  _buttonPointSize
                heightFactor: _buttonHeightFactor
                _horizontalPadding: _buttonHPadding
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _buttonColor : qgcPal.button
                borderColor: _root.useDarkStyle ? _dropdownBorderColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.buttonText
                overlayColor: _buttonHoverColor
                hoverOverlayOpacity: 0.28
                pressedOverlayOpacity: 0.42
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked:  _startCalibration("compass", compassHelp, qsTr("校准磁力计"))
            }

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / Math.max(_visibleCalibrationButtonCount, 1)
                text:       qsTr("校准陀螺仪")
                visible:    sectionVisible(qsTr("陀螺仪"))
                pointSize:  _buttonPointSize
                heightFactor: _buttonHeightFactor
                _horizontalPadding: _buttonHPadding
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _buttonColor : qgcPal.button
                borderColor: _root.useDarkStyle ? _dropdownBorderColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.buttonText
                overlayColor: _buttonHoverColor
                hoverOverlayOpacity: 0.28
                pressedOverlayOpacity: 0.42
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked:  _startCalibration("gyro", gyroHelp, qsTr("校准陀螺仪"))
            }

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / Math.max(_visibleCalibrationButtonCount, 1)
                text:       qsTr("校准加速度计")
                visible:    sectionVisible(qsTr("加速度计"))
                pointSize:  _buttonPointSize
                heightFactor: _buttonHeightFactor
                _horizontalPadding: _buttonHPadding
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _buttonColor : qgcPal.button
                borderColor: _root.useDarkStyle ? _dropdownBorderColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.buttonText
                overlayColor: _buttonHoverColor
                hoverOverlayOpacity: 0.28
                pressedOverlayOpacity: 0.42
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked:  _startCalibration("accel", accelHelp, qsTr("校准加速度计"))
            }

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / Math.max(_visibleCalibrationButtonCount, 1)
                text:       qsTr("校平地平线")
                enabled:    cal_acc0_id.value !== 0 && cal_gyro0_id.value !== 0
                visible:    sectionVisible(qsTr("地平线"))
                pointSize:  _buttonPointSize
                heightFactor: _buttonHeightFactor
                _horizontalPadding: _buttonHPadding
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _buttonColor : qgcPal.button
                borderColor: _root.useDarkStyle ? _dropdownBorderColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.buttonText
                overlayColor: _buttonHoverColor
                hoverOverlayOpacity: 0.28
                pressedOverlayOpacity: 0.42
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked:  _startCalibration("level", levelHelp, qsTr("校平地平线"))
            }

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / Math.max(_visibleCalibrationButtonCount, 1)
                text:       qsTr("校准空速")
                visible:    sectionVisible(qsTr("空速"))
                pointSize:  _buttonPointSize
                heightFactor: _buttonHeightFactor
                _horizontalPadding: _buttonHPadding
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _buttonColor : qgcPal.button
                borderColor: _root.useDarkStyle ? _dropdownBorderColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.buttonText
                overlayColor: _buttonHoverColor
                hoverOverlayOpacity: 0.28
                pressedOverlayOpacity: 0.42
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked:  _startCalibration("airspeed", airspeedHelp, qsTr("校准空速"))
            }

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / Math.max(_visibleCalibrationButtonCount, 1)
                text:       qsTr("设置方向")
                visible:    sectionVisible(qsTr("方向设置"))
                pointSize:  _buttonPointSize
                heightFactor: _buttonHeightFactor
                _horizontalPadding: _buttonHPadding
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _buttonColor : qgcPal.button
                borderColor: _root.useDarkStyle ? _dropdownBorderColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.buttonText
                overlayColor: _buttonHoverColor
                hoverOverlayOpacity: 0.28
                pressedOverlayOpacity: 0.42
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked: {
                    setOrientationsDialogShowBoardOrientation = true
                    setOrientationsDialogFactory.open({ title: qsTr("Set Orientations"), showRebootVehicleButton: false })
                }
            }

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / Math.max(_visibleCalibrationButtonCount, 1)
                text:       qsTr("Factory Reset")
                visible:    sectionVisible(qsTr("Orientations"))
                pointSize:  _buttonPointSize
                heightFactor: _buttonHeightFactor
                _horizontalPadding: _buttonHPadding
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _buttonColor : qgcPal.button
                borderColor: _root.useDarkStyle ? _dropdownBorderColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.buttonText
                overlayColor: _buttonHoverColor
                hoverOverlayOpacity: 0.28
                pressedOverlayOpacity: 0.42
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked:  controller.resetFactoryParameters()
            }

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / Math.max(_visibleCalibrationButtonCount, 1)
                text:       qsTr("Next")
                visible:    showNextButton
                pointSize:  _buttonPointSize
                heightFactor: _buttonHeightFactor
                _horizontalPadding: _buttonHPadding
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _accentColor : qgcPal.primaryButton
                borderColor: _root.useDarkStyle ? _accentColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.primaryButtonText
                overlayColor: "#FFFFFF"
                hoverOverlayOpacity: 0.10
                pressedOverlayOpacity: 0.18
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked:  _root.nextButtonClicked()
            }
        }

        // Active calibration area — visible during calibration
        RowLayout {
            Layout.fillWidth:   true
            visible:            controller.calibrationActive
            spacing:            ScreenTools.defaultFontPixelWidth

            ProgressBar {
                id:                 progressBar
                Layout.fillWidth:   true
            }

            QGCButton {
                text:       qsTr("Cancel")
                useExplicitPopupColors: _root.useDarkStyle
                backgroundColor: _root.useDarkStyle ? _buttonColor : qgcPal.button
                borderColor: _root.useDarkStyle ? _dropdownBorderColor : qgcPal.buttonBorder
                textColor: _root.useDarkStyle ? _primaryTextColor : qgcPal.buttonText
                overlayColor: _buttonHoverColor
                hoverOverlayOpacity: 0.28
                pressedOverlayOpacity: 0.42
                backRadius: _root.useDarkStyle ? _cornerRadius : ScreenTools.defaultBorderRadius
                showBorder: _root.useDarkStyle ? true : (qgcPal.globalTheme === QGCPalette.Light)
                onClicked:  controller.cancelCalibration()
            }
        }

        Item {
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            visible:            controller.calibrationActive || _showOrientationPreview || _showStatusPreview

            TextArea {
                id:             statusTextArea
                anchors.fill:   parent
                readOnly:       true
                visible:        !orientationCalArea.visible
                text:           statusTextAreaDefaultText
                color:          _root.useDarkStyle ? _secondaryTextColor : qgcPal.text
                background: Rectangle {
                    color: _root.useDarkStyle ? _panelColor : qgcPal.windowShade
                    border.width: _root.useDarkStyle ? 1 : 0
                    border.color: _root.useDarkStyle ? _borderColor : "transparent"
                    radius: _root.useDarkStyle ? _cornerRadius : 0
                }
            }

            Rectangle {
                id:         orientationCalArea
                anchors.fill: parent
                visible:    controller.showOrientationCalArea || _showOrientationPreview
                color:      _root.useDarkStyle ? _panelColor : qgcPal.windowShade
                border.width: _root.useDarkStyle ? 1 : 0
                border.color: _root.useDarkStyle ? _borderColor : "transparent"
                radius: _root.useDarkStyle ? _cornerRadius : 0

                QGCLabel {
                    id:                 orientationCalAreaHelpText
                    anchors.margins:    ScreenTools.defaultFontPixelWidth
                    anchors.top:        orientationCalArea.top
                    anchors.left:       orientationCalArea.left
                    width:              parent.width
                    wrapMode:           Text.WordWrap
                    font.pointSize:     ScreenTools.mediumFontPointSize
                    visible:            text !== ""
                }

                Flow {
                    anchors.topMargin:  ScreenTools.defaultFontPixelWidth
                    anchors.top:        orientationCalAreaHelpText.bottom
                    anchors.bottom:     parent.bottom
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            ScreenTools.defaultFontPixelWidth / 2

                    property real indicatorWidth:   (width / 3) - (spacing * 2)
                    property real indicatorHeight:  (height / 2) - spacing

                    VehicleRotationCal {
                        width:              parent.indicatorWidth
                        height:             parent.indicatorHeight
                        visible:            controller.orientationCalDownSideVisible || _showAllSidesPreview || _showDownOnlyPreview
                        calValid:           controller.orientationCalDownSideDone && !_showOrientationPreview
                        calInProgress:      controller.orientationCalDownSideInProgress
                        calInProgressText:  controller.orientationCalDownSideRotate ? qsTr("Rotate") : qsTr("Hold Still")
                        imageSource:        controller.orientationCalDownSideRotate ? "qrc:///qmlimages/VehicleDownRotate.png" : "qrc:///qmlimages/VehicleDown.png"
                        modernStyle:        _root.useDarkStyle
                    }
                    VehicleRotationCal {
                        width:              parent.indicatorWidth
                        height:             parent.indicatorHeight
                        visible:            controller.orientationCalUpsideDownSideVisible || _showAllSidesPreview
                        calValid:           controller.orientationCalUpsideDownSideDone && !_showOrientationPreview
                        calInProgress:      controller.orientationCalUpsideDownSideInProgress
                        calInProgressText:  controller.orientationCalUpsideDownSideRotate ? qsTr("Rotate") : qsTr("Hold Still")
                        imageSource:        controller.orientationCalUpsideDownSideRotate ? "qrc:///qmlimages/VehicleUpsideDownRotate.png" : "qrc:///qmlimages/VehicleUpsideDown.png"
                        modernStyle:        _root.useDarkStyle
                    }
                    VehicleRotationCal {
                        width:              parent.indicatorWidth
                        height:             parent.indicatorHeight
                        visible:            controller.orientationCalNoseDownSideVisible || _showAllSidesPreview
                        calValid:           controller.orientationCalNoseDownSideDone && !_showOrientationPreview
                        calInProgress:      controller.orientationCalNoseDownSideInProgress
                        calInProgressText:  controller.orientationCalNoseDownSideRotate ? qsTr("Rotate") : qsTr("Hold Still")
                        imageSource:        controller.orientationCalNoseDownSideRotate ? "qrc:///qmlimages/VehicleNoseDownRotate.png" : "qrc:///qmlimages/VehicleNoseDown.png"
                        modernStyle:        _root.useDarkStyle
                    }
                    VehicleRotationCal {
                        width:              parent.indicatorWidth
                        height:             parent.indicatorHeight
                        visible:            controller.orientationCalTailDownSideVisible || _showAllSidesPreview
                        calValid:           controller.orientationCalTailDownSideDone && !_showOrientationPreview
                        calInProgress:      controller.orientationCalTailDownSideInProgress
                        calInProgressText:  controller.orientationCalTailDownSideRotate ? qsTr("Rotate") : qsTr("Hold Still")
                        imageSource:        controller.orientationCalTailDownSideRotate ? "qrc:///qmlimages/VehicleTailDownRotate.png" : "qrc:///qmlimages/VehicleTailDown.png"
                        modernStyle:        _root.useDarkStyle
                    }
                    VehicleRotationCal {
                        width:              parent.indicatorWidth
                        height:             parent.indicatorHeight
                        visible:            controller.orientationCalLeftSideVisible || _showAllSidesPreview
                        calValid:           controller.orientationCalLeftSideDone && !_showOrientationPreview
                        calInProgress:      controller.orientationCalLeftSideInProgress
                        calInProgressText:  controller.orientationCalLeftSideRotate ? qsTr("Rotate") : qsTr("Hold Still")
                        imageSource:        controller.orientationCalLeftSideRotate ? "qrc:///qmlimages/VehicleLeftRotate.png" : "qrc:///qmlimages/VehicleLeft.png"
                        modernStyle:        _root.useDarkStyle
                    }
                    VehicleRotationCal {
                        width:              parent.indicatorWidth
                        height:             parent.indicatorHeight
                        visible:            controller.orientationCalRightSideVisible || _showAllSidesPreview
                        calValid:           controller.orientationCalRightSideDone && !_showOrientationPreview
                        calInProgress:      controller.orientationCalRightSideInProgress
                        calInProgressText:  controller.orientationCalRightSideRotate ? qsTr("Rotate") : qsTr("Hold Still")
                        imageSource:        controller.orientationCalRightSideRotate ? "qrc:///qmlimages/VehicleRightRotate.png" : "qrc:///qmlimages/VehicleRight.png"
                        modernStyle:        _root.useDarkStyle
                    }
                }
            }
        }
    }
}
