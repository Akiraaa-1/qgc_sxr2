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
    property Fact sens_board_x_off: controller.getParameterFact(-1, "SENS_BOARD_X_OFF")
    property Fact sens_board_y_off: controller.getParameterFact(-1, "SENS_BOARD_Y_OFF")
    property Fact sens_board_z_off: controller.getParameterFact(-1, "SENS_BOARD_Z_OFF")
    property Fact sens_dpres_off:   controller.getParameterFact(-1, "SENS_DPRES_OFF")

    // Id > = signals compass available, rot < 0 signals internal compass
    property bool showCompass0Rot: cal_mag0_id.value > 0 && cal_mag0_rot.value >= 0
    property bool showCompass1Rot: cal_mag1_id.value > 0 && cal_mag1_rot.value >= 0
    property bool showCompass2Rot: cal_mag2_id.value > 0 && cal_mag2_rot.value >= 0

    property bool   _sensorsHaveFixedOrientation:       QGroundControl.corePlugin.options.sensorsHaveFixedOrientation
    property string _calMagIdParamFormat:               "CAL_MAG#_ID"
    property string _calMagRotParamFormat:              "CAL_MAG#_ROT"
    property int    _expectedMagCount:                   controller.parameterExists(-1, "SYS_HAS_MAG") ? Number(controller.getParameterFact(-1, "SYS_HAS_MAG").value) : 1
    property bool 	_allMagsDisabled:                   _expectedMagCount <= 0
    property bool   _magCalibrationAvailable:            !_allMagsDisabled && (cal_mag0_id.value > 0 || cal_mag1_id.value > 0 || cal_mag2_id.value > 0)
    property bool   _boardOrientationChangeAllowed:     !_sensorsHaveFixedOrientation && setOrientationsDialogShowBoardOrientation
    property bool   _compassOrientationChangeAllowed:   !_sensorsHaveFixedOrientation && _magCalibrationAvailable
    property int    _arbitrarilyLargeMaxMagIndex:       50
    property string _selectedCalibrationType:            "accel"
    property var    _activeVehicle:                      QGroundControl.multiVehicleManager.activeVehicle
    property bool   _calibrationCommandPending:          false
    property string _pendingCalibrationType:             ""
    property string _pendingCalibrationStatusText:       ""
    property string _activeCalibrationType:              ""
    property var    _calibrationResultByType:            ({})
    property bool   _factoryResetPending:                false
    property bool   _factoryResetForcesUncalibrated:     false
    property int    _lastVehicleMessagesReceived:        _activeVehicle ? _activeVehicle.messagesReceived : 0
    property double _lastVehicleMessageMSecs:            Date.now()
    property string _lastAttitudeSample:                 ""
    property double _lastAttitudeSampleMSecs:            Date.now()
    property bool   _vehicleTelemetryLive:               !!_activeVehicle
    property bool   _attitudeTelemetryLive:              !!_activeVehicle
    property bool   _vehicleConnected:                   !!(QGroundControl.multiVehicleManager.activeVehicleAvailable && _activeVehicle && !_activeVehicle.isOfflineEditingVehicle && _activeVehicle.vehicleLinkManager && !_activeVehicle.vehicleLinkManager.communicationLost && _vehicleTelemetryLive && _attitudeTelemetryLive)

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
                    var calMagIdFact = controller.getParameterFact(-1, magIdParam)
                    var calMagRotFact = controller.getParameterFact(-1, _calMagRotParamFormat.replace("#", index))
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
                _calibrationCommandPending = false
                calibrationCommandResponseTimer.stop()
                globals.navigationBlockedReason = qsTr("请先完成或取消当前校准")
            } else {
                globals.navigationBlockedReason = ""
            }
        }
    }

    Component.onDestruction: globals.navigationBlockedReason = ""

    Component.onCompleted: {
        _applySectionFilterSelection()
        _ensureSelectedCalibrationVisible()
    }

    on_MagCalibrationAvailableChanged: _ensureSelectedCalibrationVisible()

    on_ActiveVehicleChanged: {
        _calibrationResultByType = ({})
        _factoryResetPending = false
        _factoryResetForcesUncalibrated = false
        _lastVehicleMessagesReceived = _activeVehicle ? _activeVehicle.messagesReceived : 0
        _lastVehicleMessageMSecs = Date.now()
        _lastAttitudeSample = _attitudeSample()
        _lastAttitudeSampleMSecs = Date.now()
        _vehicleTelemetryLive = !!_activeVehicle
        _attitudeTelemetryLive = !!_activeVehicle
        factoryResetRefreshTimer.stop()
    }

    Connections {
        target: _activeVehicle

        function onMessagesReceivedChanged() {
            _lastVehicleMessagesReceived = _activeVehicle ? _activeVehicle.messagesReceived : 0
            _lastVehicleMessageMSecs = Date.now()
            _vehicleTelemetryLive = true
        }
    }

    Connections {
        target: _activeVehicle && _activeVehicle.vehicleLinkManager ? _activeVehicle.vehicleLinkManager : null

        function onCommunicationLostChanged(communicationLost) {
            if (communicationLost) {
                _calibrationResultByType = ({})
                _factoryResetPending = false
                _factoryResetForcesUncalibrated = false
                factoryResetRefreshTimer.stop()
            }
        }
    }

    Timer {
        id: vehicleTelemetryWatchdogTimer
        interval: 500
        repeat: true
        running: true

        onTriggered: {
            if (!_activeVehicle) {
                _vehicleTelemetryLive = false
                _attitudeTelemetryLive = false
                return
            }

            const messagesReceived = _activeVehicle.messagesReceived
            if (messagesReceived !== _lastVehicleMessagesReceived) {
                _lastVehicleMessagesReceived = messagesReceived
                _lastVehicleMessageMSecs = Date.now()
                _vehicleTelemetryLive = true
            } else if (Date.now() - _lastVehicleMessageMSecs > 2500) {
                _vehicleTelemetryLive = false
            }

            const attitudeSample = _attitudeSample()
            if (attitudeSample !== _lastAttitudeSample) {
                _lastAttitudeSample = attitudeSample
                _lastAttitudeSampleMSecs = Date.now()
                _attitudeTelemetryLive = true
            } else if (Date.now() - _lastAttitudeSampleMSecs > 5000) {
                _attitudeTelemetryLive = false
            }
        }
    }

    onSectionNameFilterChanged: _applySectionFilterSelection()

    Timer {
        id: calibrationCommandResponseTimer
        interval: 7000
        repeat: false

        onTriggered: {
            if (_calibrationCommandPending && !controller.calibrationActive) {
                _calibrationCommandPending = false
                _pendingCalibrationStatusText = qsTr("飞控未响应%1命令，请检查飞控连接、飞控状态和传感器校准条件。").arg(_calibrationTitleForType(_pendingCalibrationType))
                statusTextArea.append(_pendingCalibrationStatusText)
            }
        }
    }

    Timer {
        id: factoryResetRefreshTimer
        interval: 3000
        repeat: false

        onTriggered: _factoryResetPending = false
    }

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
                _sendCalibrationCommand(preCalibrationDialogType)
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
        if (_sectionMatches(name, "Compass") || _sectionMatches(name, "磁力计")) {
            return _magCalibrationAvailable && QGroundControl.corePlugin.options.showSensorCalibrationCompass && showSensorCalibrationCompass
        }
        if (_sectionMatches(name, "Gyroscope") || _sectionMatches(name, "陀螺仪")) {
            return QGroundControl.corePlugin.options.showSensorCalibrationGyro && showSensorCalibrationGyro
        }
        if (_sectionMatches(name, "Accelerometer") || _sectionMatches(name, "加速度计")) {
            return QGroundControl.corePlugin.options.showSensorCalibrationAccel && showSensorCalibrationAccel
        }
        if (_sectionMatches(name, "Level Horizon") || _sectionMatches(name, "地平线")) {
            return QGroundControl.corePlugin.options.showSensorCalibrationLevel && showSensorCalibrationLevel
        }
        if (_sectionMatches(name, "Airspeed") || _sectionMatches(name, "空速")) {
            return vehicleComponent.airspeedCalSupported && QGroundControl.corePlugin.options.showSensorCalibrationAirspeed && showSensorCalibrationAirspeed
        }
        if (_sectionMatches(name, "Orientations") || _sectionMatches(name, "方向设置")) {
            return orientationsButtonVisible()
        }
        return true
    }

    function _startCalibration(type, help, title) {
        preCalibrationDialogType = type
        preCalibrationDialogHelp = help
        preCalibrationDialogFactory.open({ title: title })
    }

    function _sendCalibrationCommand(type) {
        _pendingCalibrationType = type
        _activeCalibrationType = type
        _setCalibrationResult(type, "")
        _calibrationCommandPending = true
        _pendingCalibrationStatusText = qsTr("已发送%1命令，等待飞控响应...").arg(_calibrationTitleForType(type))
        statusTextArea.text = _pendingCalibrationStatusText
        calibrationCommandResponseTimer.restart()

        if (type == "gyro") {
            controller.calibrateGyro()
        } else if (type == "accel") {
            controller.calibrateAccel()
        } else if (type == "level") {
            controller.calibrateLevel()
        } else if (type == "compass") {
            controller.calibrateCompass()
        } else if (type == "airspeed") {
            controller.calibrateAirspeed()
        } else {
            _calibrationCommandPending = false
            calibrationCommandResponseTimer.stop()
        }
    }

    function _factNumber(fact) {
        if (!fact) {
            return NaN
        }
        const value = Number(fact.value)
        return isNaN(value) ? Number(fact.rawValue) : value
    }

    function _formatTelemetryValue(fact, decimals, suffix) {
        const value = _factNumber(fact)
        if (isNaN(value)) {
            return "--"
        }
        return value.toFixed(decimals) + (suffix || "")
    }

    function _factNumberOrZero(fact) {
        const value = _factNumber(fact)
        return isNaN(value) ? 0 : value
    }

    function _attitudeSample() {
        if (!_activeVehicle) {
            return ""
        }

        return "%1,%2,%3,%4".arg(_formatTelemetryValue(_activeVehicle.roll, 2, ""))
                            .arg(_formatTelemetryValue(_activeVehicle.pitch, 2, ""))
                            .arg(_formatTelemetryValue(_activeVehicle.yawRate, 3, ""))
                            .arg(_formatTelemetryValue(_activeVehicle.heading, 1, ""))
    }

    function _attitudeRateMagnitude() {
        const rollRate = _factNumberOrZero(_activeVehicle ? _activeVehicle.rollRate : null)
        const pitchRate = _factNumberOrZero(_activeVehicle ? _activeVehicle.pitchRate : null)
        const yawRate = _factNumberOrZero(_activeVehicle ? _activeVehicle.yawRate : null)
        return Math.max(Math.abs(rollRate), Math.abs(pitchRate), Math.abs(yawRate))
    }

    function _attitudeStable() {
        return _vehicleConnected && _attitudeRateMagnitude() < 0.15
    }

    function _telemetryHealthText() {
        return _vehicleConnected ? qsTr("数据通信正常") : qsTr("等待飞控连接")
    }

    function _selectCalibrationPage(type) {
        _selectedCalibrationType = type
    }

    function _ensureSelectedCalibrationVisible() {
        if (_calibrationVisible(_selectedCalibrationType)) {
            return
        }

        const fallbackTypes = [ "accel", "gyro", "level", "airspeed", "compass" ]
        for (let i = 0; i < fallbackTypes.length; i++) {
            if (_calibrationVisible(fallbackTypes[i])) {
                _selectedCalibrationType = fallbackTypes[i]
                return
            }
        }
    }

    function _applySectionFilterSelection() {
        if (_sectionMatches(sectionNameFilter, "Compass") || _sectionMatches(sectionNameFilter, "磁力计")) {
            _selectedCalibrationType = "compass"
        } else if (_sectionMatches(sectionNameFilter, "Gyroscope") || _sectionMatches(sectionNameFilter, "陀螺仪")) {
            _selectedCalibrationType = "gyro"
        } else if (_sectionMatches(sectionNameFilter, "Accelerometer") || _sectionMatches(sectionNameFilter, "加速度计")) {
            _selectedCalibrationType = "accel"
        } else if (_sectionMatches(sectionNameFilter, "Level Horizon") || _sectionMatches(sectionNameFilter, "地平线")) {
            _selectedCalibrationType = "level"
        } else if (_sectionMatches(sectionNameFilter, "Airspeed") || _sectionMatches(sectionNameFilter, "空速")) {
            _selectedCalibrationType = "airspeed"
        }
        _ensureSelectedCalibrationVisible()
    }

    function _calibrationVisible(type) {
        if (type === "compass") return sectionVisible(qsTr("磁力计"))
        if (type === "gyro") return sectionVisible(qsTr("陀螺仪"))
        if (type === "accel") return sectionVisible(qsTr("加速度计"))
        if (type === "level") return sectionVisible(qsTr("地平线"))
        if (type === "airspeed") return sectionVisible(qsTr("空速"))
        return false
    }

    function _calibrationReady(type) {
        if (!_vehicleConnected) return false
        if (type === "compass") return !_allMagsDisabled
        if (type === "gyro") return controller.parameterExists(-1, "CAL_GYRO0_ID")
        if (type === "accel") return controller.parameterExists(-1, "CAL_ACC0_ID")
        if (type === "level") return controller.parameterExists(-1, "CAL_ACC0_ID") && controller.parameterExists(-1, "CAL_GYRO0_ID")
        if (type === "airspeed") return vehicleComponent.airspeedCalSupported
        return false
    }

    function _calibrationStateText(type) {
        if (!_calibrationReady(type)) {
            return qsTr("不可用")
        }
        if (_factoryResetPending) {
            return qsTr("刷新中")
        }
        if (_calibrationComplete(type)) {
            return qsTr("已完成")
        }
        if (_calibrationValid(type)) {
            return qsTr("已校准")
        }
        if (type === "airspeed" && vehicleComponent.airspeedCalRequired) {
            return qsTr("需校准")
        }
        return qsTr("待校准")
    }

    function _calibrationAccent(type) {
        if (!_calibrationReady(type)) {
            return "#FF5A5F"
        }
        if (_factoryResetPending) {
            return "#F59E0B"
        }
        if (_calibrationComplete(type)) {
            return "#22C55E"
        }
        if (_calibrationValid(type)) {
            return "#22C55E"
        }
        if (type === "airspeed" && vehicleComponent.airspeedCalRequired) {
            return "#F59E0B"
        }
        return "#60A5FA"
    }

    function _calibrationTitleForType(type) {
        if (type === "compass") return qsTr("磁力计校准")
        if (type === "gyro") return qsTr("陀螺仪校准")
        if (type === "accel") return qsTr("加速度计校准")
        if (type === "level") return qsTr("地平线校准")
        if (type === "airspeed") return qsTr("空速校准")
        return qsTr("传感器校准")
    }

    function _calibrationHelpForType(type) {
        if (type === "compass") return compassHelp
        if (type === "gyro") return gyroHelp
        if (type === "accel") return accelHelp
        if (type === "level") return levelHelp
        if (type === "airspeed") return airspeedHelp
        return statusTextAreaDefaultText
    }

    function _calibrationActionTitle(type) {
        if (type === "compass") return qsTr("开始磁力计校准")
        if (type === "gyro") return qsTr("开始陀螺仪校准")
        if (type === "accel") return qsTr("开始加速度计校准")
        if (type === "level") return qsTr("开始地平线校准")
        if (type === "airspeed") return qsTr("开始空速校准")
        return qsTr("开始校准")
    }

    function _calibrationSteps(type) {
        if (type === "accel") {
            return [
                qsTr("水平放置"),
                qsTr("倒置"),
                qsTr("机头朝下"),
                qsTr("机头朝上"),
                qsTr("左侧朝下"),
                qsTr("右侧朝下")
            ]
        }
        if (type === "compass") {
            return [
                qsTr("水平放置"),
                qsTr("倒置"),
                qsTr("机头向下"),
                qsTr("机头向上"),
                qsTr("左侧朝下"),
                qsTr("右侧朝下")
            ]
        }
        if (type === "gyro") {
            return [
                qsTr("静止放置")
            ]
        }
        if (type === "level") {
            return [
                qsTr("水平放置")
            ]
        }
        if (type === "airspeed") {
            return [
                qsTr("避开气流"),
                qsTr("采集零点"),
                qsTr("吹气验证")
            ]
        }
        return []
    }

    function _selectedCalibrationStepText() {
        const steps = _calibrationSteps(_selectedCalibrationType)
        return steps.length > 0 ? steps[0] : qsTr("准备校准")
    }

    function _calibrationPreviewImage(type) {
        if (type === "gyro" || type === "level") return "qrc:///qmlimages/VehicleDown.png"
        if (type === "airspeed") return "qrc:///qmlimages/VehicleNoseDown.png"
        if (type === "compass") return "qrc:///qmlimages/VehicleLeftRotate.png"
        return "qrc:///qmlimages/VehicleLeft.png"
    }

    function _calibrationStepImage(type, stepIndex) {
        if (type === "accel" || type === "compass") {
            const images = [
                "qrc:///qmlimages/VehicleDown.png",
                "qrc:///qmlimages/VehicleUpsideDown.png",
                "qrc:///qmlimages/VehicleNoseDown.png",
                "qrc:///qmlimages/VehicleTailDown.png",
                "qrc:///qmlimages/VehicleLeft.png",
                "qrc:///qmlimages/VehicleRight.png"
            ]
            return images[Math.max(0, Math.min(stepIndex, images.length - 1))]
        }
        return _calibrationPreviewImage(type)
    }

    function _orientationCalStepState(index) {
        const states = [
            {
                text: qsTr("水平放置"),
                visible: controller.orientationCalDownSideVisible,
                done: controller.orientationCalDownSideDone,
                inProgress: controller.orientationCalDownSideInProgress,
                rotate: controller.orientationCalDownSideRotate,
                stillImage: "qrc:///qmlimages/VehicleDown.png",
                rotateImage: "qrc:///qmlimages/VehicleDownRotate.png"
            },
            {
                text: qsTr("倒置"),
                visible: controller.orientationCalUpsideDownSideVisible,
                done: controller.orientationCalUpsideDownSideDone,
                inProgress: controller.orientationCalUpsideDownSideInProgress,
                rotate: controller.orientationCalUpsideDownSideRotate,
                stillImage: "qrc:///qmlimages/VehicleUpsideDown.png",
                rotateImage: "qrc:///qmlimages/VehicleUpsideDownRotate.png"
            },
            {
                text: qsTr("机头朝下"),
                visible: controller.orientationCalNoseDownSideVisible,
                done: controller.orientationCalNoseDownSideDone,
                inProgress: controller.orientationCalNoseDownSideInProgress,
                rotate: controller.orientationCalNoseDownSideRotate,
                stillImage: "qrc:///qmlimages/VehicleNoseDown.png",
                rotateImage: "qrc:///qmlimages/VehicleNoseDownRotate.png"
            },
            {
                text: qsTr("机头朝上"),
                visible: controller.orientationCalTailDownSideVisible,
                done: controller.orientationCalTailDownSideDone,
                inProgress: controller.orientationCalTailDownSideInProgress,
                rotate: controller.orientationCalTailDownSideRotate,
                stillImage: "qrc:///qmlimages/VehicleTailDown.png",
                rotateImage: "qrc:///qmlimages/VehicleTailDownRotate.png"
            },
            {
                text: qsTr("左侧朝下"),
                visible: controller.orientationCalLeftSideVisible,
                done: controller.orientationCalLeftSideDone,
                inProgress: controller.orientationCalLeftSideInProgress,
                rotate: controller.orientationCalLeftSideRotate,
                stillImage: "qrc:///qmlimages/VehicleLeft.png",
                rotateImage: "qrc:///qmlimages/VehicleLeftRotate.png"
            },
            {
                text: qsTr("右侧朝下"),
                visible: controller.orientationCalRightSideVisible,
                done: controller.orientationCalRightSideDone,
                inProgress: controller.orientationCalRightSideInProgress,
                rotate: controller.orientationCalRightSideRotate,
                stillImage: "qrc:///qmlimages/VehicleRight.png",
                rotateImage: "qrc:///qmlimages/VehicleRightRotate.png"
            }
        ]
        return states[Math.max(0, Math.min(index, states.length - 1))]
    }

    function _orientationCalVisibleSteps() {
        const visibleSteps = []
        for (let i = 0; i < 6; i++) {
            const state = _orientationCalStepState(i)
            if (state.visible) {
                state.rawIndex = i
                visibleSteps.push(state)
            }
        }
        return visibleSteps
    }

    function _displaySteps() {
        if (controller.calibrationActive && controller.showOrientationCalArea) {
            const visibleSteps = _orientationCalVisibleSteps()
            return visibleSteps.length > 0 ? visibleSteps : _calibrationSteps(_selectedCalibrationType)
        }
        return _calibrationSteps(_selectedCalibrationType)
    }

    function _activeOrientationRawIndex() {
        if (!controller.calibrationActive || !controller.showOrientationCalArea) {
            return 0
        }
        for (let i = 0; i < 6; i++) {
            const state = _orientationCalStepState(i)
            if (state.visible && state.inProgress) {
                return i
            }
        }
        for (let j = 0; j < 6; j++) {
            const orderedState = _orientationCalStepState(j)
            if (orderedState.visible && !orderedState.done) {
                return j
            }
        }
        const visibleSteps = _orientationCalVisibleSteps()
        if (visibleSteps.length > 0) {
            return visibleSteps[visibleSteps.length - 1].rawIndex
        }
        return 0
    }

    function _completedOrientationCount() {
        let completeCount = 0
        for (let i = 0; i < 6; i++) {
            const state = _orientationCalStepState(i)
            if (state.visible && state.done) {
                completeCount++
            }
        }
        return completeCount
    }

    function _completedDisplayStepCount() {
        if (controller.calibrationActive && controller.showOrientationCalArea) {
            return _completedOrientationCount()
        }
        return _calibrationDoneForDisplay(_selectedCalibrationType) ? _displayStepCount() : 0
    }

    function _stepStatusText(modelData) {
        if (controller.calibrationActive && controller.showOrientationCalArea && modelData && modelData.rawIndex !== undefined) {
            if (modelData.done) {
                return qsTr("已校准")
            }
            if (modelData.rawIndex === _activeOrientationRawIndex()) {
                return modelData.rotate ? qsTr("旋转中") : qsTr("校准中")
            }
            return qsTr("待校准")
        }
        if (_calibrationDoneForDisplay(_selectedCalibrationType)) {
            return qsTr("已校准")
        }
        return qsTr("待校准")
    }

    function _stepStatusColor(modelData) {
        const status = _stepStatusText(modelData)
        if (status === qsTr("已校准")) {
            return "#22C55E"
        }
        if (status === qsTr("校准中") || status === qsTr("旋转中")) {
            return "#60A5FA"
        }
        return _secondaryTextColor
    }

    function _activeOrientationStepIndex() {
        const rawIndex = _activeOrientationRawIndex()
        const visibleSteps = _orientationCalVisibleSteps()
        for (let i = 0; i < visibleSteps.length; i++) {
            if (visibleSteps[i].rawIndex === rawIndex) {
                return i
            }
        }
        return 0
    }

    function _orientationHasActiveDetection() {
        if (!controller.calibrationActive || !controller.showOrientationCalArea) {
            return false
        }
        for (let i = 0; i < 6; i++) {
            const state = _orientationCalStepState(i)
            if (state.visible && state.inProgress) {
                return true
            }
        }
        return false
    }

    function _displayStepCount() {
        return _displaySteps().length
    }

    function _statusTextHasCalibrationComplete(statusText) {
        const statusTextLower = statusText.toLowerCase()
        return statusText.indexOf("校准完成") !== -1 ||
                statusTextLower.indexOf("calibration done") !== -1 ||
                statusTextLower.indexOf("calibration complete") !== -1
    }

    function _statusTextHasCalibrationFailed(statusText) {
        const statusTextLower = statusText.toLowerCase()
        return statusText.indexOf("校准失败") !== -1 ||
                statusTextLower.indexOf("calibration failed") !== -1
    }

    function _statusTextHasCalibrationCancelled(statusText) {
        const statusTextLower = statusText.toLowerCase()
        return statusText.indexOf("取消") !== -1 ||
                statusTextLower.indexOf("calibration cancelled") !== -1
    }

    function _setCalibrationResult(type, result) {
        if (!type) {
            return
        }
        const results = Object.assign({}, _calibrationResultByType)
        if (result === "") {
            delete results[type]
        } else {
            results[type] = result
        }
        _calibrationResultByType = results
    }

    function _calibrationResult(type) {
        const calibrationType = type || _selectedCalibrationType
        return _calibrationResultByType[calibrationType] || ""
    }

    function _calibrationComplete(type) {
        return _calibrationResult(type) === "complete"
    }

    function _calibrationValid(type) {
        if (!_vehicleConnected || _factoryResetPending || _factoryResetForcesUncalibrated) {
            return false
        }
        if (type === "compass") {
            return _allMagsDisabled || cal_mag0_id.value !== 0
        }
        if (type === "gyro") {
            return cal_gyro0_id.value !== 0
        }
        if (type === "accel") {
            return cal_acc0_id.value !== 0
        }
        if (type === "level") {
            return cal_acc0_id.value !== 0 && cal_gyro0_id.value !== 0
        }
        if (type === "airspeed") {
            return vehicleComponent.airspeedCalSupported && !vehicleComponent.airspeedCalRequired
        }
        return false
    }

    function _calibrationDoneForDisplay(type) {
        return _calibrationComplete(type) || _calibrationValid(type)
    }

    function _calibrationFailed(type) {
        return _calibrationResult(type) === "failed"
    }

    function _calibrationCancelled(type) {
        return _calibrationResult(type) === "cancelled"
    }

    function _displayStepIndex() {
        if (_calibrationDoneForDisplay(_selectedCalibrationType)) {
            return Math.max(0, _displayStepCount() - 1)
        }
        return controller.calibrationActive && controller.showOrientationCalArea ? _activeOrientationStepIndex() : 0
    }

    function _displayStepImage() {
        if (controller.calibrationActive && controller.showOrientationCalArea) {
            const state = _orientationCalStepState(_activeOrientationRawIndex())
            if (!_orientationHasActiveDetection()) {
                return state.stillImage
            }
            return state.rotate ? state.rotateImage : state.stillImage
        }
        return _calibrationStepImage(_selectedCalibrationType, 0)
    }

    function _displayStepText() {
        const steps = _displaySteps()
        const step = steps[Math.max(0, Math.min(_displayStepIndex(), steps.length - 1))]
        return step && step.text !== undefined ? step.text : step
    }

    function _orientationInstructionText(index, rotate) {
        const instructions = [
            rotate ? qsTr("按箭头方向水平顺时针旋转") : qsTr("水平放置并保持静止"),
            rotate ? qsTr("按箭头方向倒置逆时针旋转") : qsTr("倒置放置并保持静止"),
            rotate ? qsTr("机头朝下，按箭头方向俯仰旋转") : qsTr("机头朝下并保持静止"),
            rotate ? qsTr("机头朝上，按箭头方向俯仰旋转") : qsTr("机头朝上并保持静止"),
            rotate ? qsTr("左侧朝下，按箭头方向滚转") : qsTr("左侧朝下并保持静止"),
            rotate ? qsTr("右侧朝下，按箭头方向滚转") : qsTr("右侧朝下并保持静止")
        ]
        return instructions[Math.max(0, Math.min(index, instructions.length - 1))]
    }

    function _rotationGuideText() {
        const guideText = [
            qsTr("顺时针"),
            qsTr("逆时针"),
            qsTr("向前俯仰"),
            qsTr("向后俯仰"),
            qsTr("向左滚转"),
            qsTr("向右滚转")
        ]
        return guideText[Math.max(0, Math.min(_activeOrientationRawIndex(), guideText.length - 1))]
    }

    function _showRotationGuide() {
        return controller.calibrationActive &&
                controller.showOrientationCalArea &&
                _orientationCalStepState(_activeOrientationRawIndex()).rotate
    }

    function _displayProgressValue() {
        if (_calibrationDoneForDisplay(_selectedCalibrationType)) {
            return 1.0
        }
        if (controller.calibrationActive) {
            return Math.max(0.03, Math.min(1.0, progressBar.value))
        }
        return 1.0 / Math.max(_displayStepCount(), 1)
    }

    function _latestStatusLine() {
        const text = statusTextArea.text === undefined || statusTextArea.text === null ? "" : ("" + statusTextArea.text).trim()
        if (text === "" || text === statusTextAreaDefaultText) {
            if (controller.calibrationActive && controller.showOrientationCalArea) {
                if (!_orientationHasActiveDetection()) {
                    return _orientationWaitDiagnosticText()
                }
                const state = _orientationCalStepState(_activeOrientationRawIndex())
                return _orientationInstructionText(_activeOrientationRawIndex(), state.rotate)
            }
            if (_calibrationCommandPending) {
                return _pendingCalibrationStatusText !== "" ? _pendingCalibrationStatusText : qsTr("校准命令已发送，等待飞控响应...")
            }
            return controller.calibrationActive ? qsTr("正在校准...") : (_vehicleConnected ? qsTr("已检测到飞控数据，等待开始校准。") : qsTr("正在等待飞控数据..."))
        }
        if (controller.calibrationActive && controller.showOrientationCalArea) {
            if (!_orientationHasActiveDetection()) {
                return _orientationWaitDiagnosticText()
            }
            const activeState = _orientationCalStepState(_activeOrientationRawIndex())
            return _orientationInstructionText(_activeOrientationRawIndex(), activeState.rotate)
        }
        const lines = text.split(/\r?\n/)
        return lines[Math.max(0, lines.length - 1)]
    }

    function _shortCalibrationStateText() {
        if (_calibrationFailed(_selectedCalibrationType)) {
            return qsTr("校准失败")
        }
        if (_calibrationComplete(_selectedCalibrationType)) {
            return qsTr("已完成")
        }
        if (_calibrationValid(_selectedCalibrationType)) {
            return qsTr("已校准")
        }
        if (_calibrationCancelled(_selectedCalibrationType)) {
            return qsTr("已取消")
        }
        if (_calibrationCommandPending && !controller.calibrationActive) {
            return qsTr("等待响应")
        }
        if (!controller.calibrationActive) {
            return qsTr("等待开始")
        }
        if (controller.showOrientationCalArea) {
            if (!_orientationHasActiveDetection()) {
                return qsTr("等待识别")
            }
            const state = _orientationCalStepState(_activeOrientationRawIndex())
            if (state.done) {
                return qsTr("已完成")
            }
            if (state.rotate) {
                return _rotationGuideText()
            }
            if (state.inProgress) {
                return qsTr("保持静止")
            }
        }
        return qsTr("正在校准")
    }

    function _orientationWaitDiagnosticText() {
        const rollText = _formatTelemetryValue(_activeVehicle ? _activeVehicle.roll : null, 1, "°")
        const pitchText = _formatTelemetryValue(_activeVehicle ? _activeVehicle.pitch : null, 1, "°")
        const completedText = _completedOrientationCount() > 0
            ? qsTr(" 已完成的姿态会保留为“已校准”，后续按顺序校准时会自动跳过。")
            : ""
        if (_selectedCalibrationType === "accel") {
            const boardX = _factNumber(sens_board_x_off)
            const boardY = _factNumber(sens_board_y_off)
            if (controller.calibrationActive && !isNaN(boardX) && !isNaN(boardY) && (Math.abs(boardX) > 1.0 || Math.abs(boardY) > 1.0)) {
                return qsTr("当前水平偏置较大，建议先点击“清除水平偏置”并重启飞控。当前 Roll %1 / Pitch %2，Board X/Y %3 / %4").arg(rollText).arg(pitchText).arg(_formatTelemetryValue(sens_board_x_off, 1, "°")).arg(_formatTelemetryValue(sens_board_y_off, 1, "°"))
            }
            return qsTr("请按当前高亮步骤放置飞机并保持静止。若已放平但仍不识别，请检查飞控方向 SENS_BOARD_ROT。当前 Roll %1 / Pitch %2").arg(rollText).arg(pitchText) + completedText
        }
        return qsTr("请按当前高亮步骤放置飞机，放稳后保持静止，等待飞控识别") + completedText
    }

    function _calibrationImageScale(type, stepIndex) {
        return 1.0
    }

    function _startSelectedCalibration() {
        if (_selectedCalibrationType === "gyro") {
            _sendCalibrationCommand(_selectedCalibrationType)
        } else {
            _startCalibration(_selectedCalibrationType,
                              _calibrationHelpForType(_selectedCalibrationType),
                              _calibrationTitleForType(_selectedCalibrationType))
        }
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
        (_sectionMatches(_effectiveSectionFilter, "Gyroscope") || _sectionMatches(_effectiveSectionFilter, "陀螺仪"))

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
    readonly property bool _compactCalibrationLayout: width < ScreenTools.defaultFontPixelWidth * 122 || height < ScreenTools.defaultFontPixelHeight * 42
    readonly property real _adaptiveContentMargin: ScreenTools.defaultFontPixelHeight * (_compactCalibrationLayout ? 0.28 : 0.45)
    readonly property real _adaptiveContentGap: ScreenTools.defaultFontPixelWidth * (_compactCalibrationLayout ? 0.55 : 1.0)

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

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: true
            color: _root.useDarkStyle ? "#07111D" : qgcPal.windowShade
            radius: _root.useDarkStyle ? _cornerRadius : 0
            border.width: _root.useDarkStyle ? 1 : 0
            border.color: _root.useDarkStyle ? _borderColor : "transparent"

            Rectangle {
                id: calibrationTopBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: ScreenTools.defaultFontPixelHeight * 2.55
                color: Qt.rgba(0.03, 0.07, 0.11, 0.82)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.2
                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.0
                    spacing: ScreenTools.defaultFontPixelWidth

                    Rectangle {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.55
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: width / 2
                        color: Qt.rgba(0.15, 0.39, 0.92, 0.18)
                        border.width: 2
                        border.color: _accentColor

                        QGCLabel {
                            anchors.centerIn: parent
                            text: "C"
                            color: "#60A5FA"
                            font.bold: true
                        }
                    }

                    QGCLabel {
                        text: qsTr("传感器校准")
                        color: _primaryTextColor
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.98
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 2.2
                        spacing: ScreenTools.defaultFontPixelWidth * 0.35

                        Repeater {
                            model: [
                                { "type": "accel", "title": qsTr("加速度计") },
                                { "type": "gyro", "title": qsTr("陀螺仪") },
                                { "type": "compass", "title": qsTr("磁力计") },
                                { "type": "level", "title": qsTr("地平线") },
                                { "type": "airspeed", "title": qsTr("空速") }
                            ]

                            Rectangle {
                                required property var modelData
                                readonly property bool selected: _selectedCalibrationType === modelData.type

                                visible: _calibrationVisible(modelData.type)
                                Layout.preferredWidth: navText.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.0
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.05
                                radius: _cornerRadius * 0.8
                                color: selected ? Qt.rgba(0.15, 0.39, 0.92, 0.18) : "transparent"
                                border.width: selected ? 1 : 0
                                border.color: selected ? Qt.rgba(0.15, 0.39, 0.92, 0.7) : "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: _selectCalibrationPage(modelData.type)
                                }

                                QGCLabel {
                                    id: navText
                                    anchors.centerIn: parent
                                    text: modelData.title
                                    color: selected ? "#60A5FA" : _secondaryTextColor
                                    font.bold: selected
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: ScreenTools.defaultFontPixelWidth * 0.35

                            QGCLabel {
                                text: _vehicleConnected ? qsTr("已连接") : qsTr("未连接")
                                color: _vehicleConnected ? "#22C55E" : "#FF5A5F"
                                font.bold: true
                            }

                            Rectangle {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.45
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: width / 2
                                color: _vehicleConnected ? "#22C55E" : "#FF5A5F"
                            }
                        }

                        QGCLabel {
                            text: _telemetryHealthText()
                            color: Qt.rgba(1, 1, 1, 0.58)
                            font.pointSize: Math.max(8, ScreenTools.defaultFontPointSize * 0.78)
                        }
                    }

                    QGCButton {
                        text: "×"
                        width: ScreenTools.defaultFontPixelHeight * 2.0
                        height: width
                        useExplicitPopupColors: _root.useDarkStyle
                        backgroundColor: "transparent"
                        borderColor: "transparent"
                        textColor: _primaryTextColor
                        overlayColor: "#FFFFFF"
                        hoverOverlayOpacity: 0.10
                        pressedOverlayOpacity: 0.18
                        backRadius: width / 2
                        showBorder: false
                    }
                }
            }

            Rectangle {
                id: calibrationBottomBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: ScreenTools.defaultFontPixelHeight * 3.25
                color: Qt.rgba(0.03, 0.07, 0.11, 0.72)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
                z: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.4
                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.0
                    spacing: ScreenTools.defaultFontPixelWidth * 1.4

                    ColumnLayout {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22
                        Layout.minimumWidth: Layout.preferredWidth
                        Layout.maximumWidth: Layout.preferredWidth
                        spacing: ScreenTools.defaultFontPixelHeight * 0.18

                        RowLayout {
                            Layout.fillWidth: true

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("总体进度")
                                color: _secondaryTextColor
                                font.pointSize: Math.max(8, ScreenTools.defaultFontPointSize * 0.82)
                            }

                            QGCLabel {
                                text: qsTr("%1/%2").arg(_displayStepIndex() + 1).arg(_displayStepCount())
                                color: _primaryTextColor
                                font.bold: true
                                font.pointSize: Math.max(8, ScreenTools.defaultFontPointSize * 0.82)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.38
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.12)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * _displayProgressValue()
                                radius: height / 2
                                color: _accentColor
                            }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text: _latestStatusLine()
                        color: _secondaryTextColor
                        wrapMode: Text.WordWrap
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    QGCButton {
                        text: qsTr("设置方向")
                        visible: orientationsButtonVisible()
                        useExplicitPopupColors: _root.useDarkStyle
                        backgroundColor: _buttonColor
                        borderColor: _dropdownBorderColor
                        textColor: _primaryTextColor
                        overlayColor: _buttonHoverColor
                        hoverOverlayOpacity: 0.28
                        pressedOverlayOpacity: 0.42
                        backRadius: _cornerRadius
                        showBorder: true
                        onClicked: {
                            setOrientationsDialogShowBoardOrientation = true
                            setOrientationsDialogFactory.open({ title: qsTr("Set Orientations"), showRebootVehicleButton: false })
                        }
                    }

                    QGCButton {
                        text: qsTr("恢复出厂校准参数")
                        visible: sectionVisible(qsTr("方向设置"))
                        useExplicitPopupColors: _root.useDarkStyle
                        backgroundColor: _buttonColor
                        borderColor: _dropdownBorderColor
                        textColor: _primaryTextColor
                        overlayColor: _buttonHoverColor
                        hoverOverlayOpacity: 0.28
                        pressedOverlayOpacity: 0.42
                        backRadius: _cornerRadius
                        showBorder: true
                        onClicked: {
                            _calibrationResultByType = ({})
                            _factoryResetForcesUncalibrated = true
                            _factoryResetPending = true
                            factoryResetRefreshTimer.restart()
                            controller.resetFactoryParameters()
                        }
                    }

                    QGCButton {
                        text: qsTr("清除水平偏置")
                        useExplicitPopupColors: _root.useDarkStyle
                        backgroundColor: _buttonColor
                        borderColor: _dropdownBorderColor
                        textColor: _primaryTextColor
                        overlayColor: _buttonHoverColor
                        hoverOverlayOpacity: 0.28
                        pressedOverlayOpacity: 0.42
                        backRadius: _cornerRadius
                        showBorder: true
                        onClicked: controller.clearBoardLevelOffsets()
                    }

                    QGCButton {
                        text: qsTr("取消校准")
                        enabled: controller.calibrationActive
                        useExplicitPopupColors: _root.useDarkStyle
                        backgroundColor: _buttonColor
                        borderColor: _dropdownBorderColor
                        textColor: _primaryTextColor
                        overlayColor: _buttonHoverColor
                        hoverOverlayOpacity: 0.28
                        pressedOverlayOpacity: 0.42
                        backRadius: _cornerRadius
                        showBorder: true
                        onClicked: controller.cancelCalibration()
                    }

                    QGCButton {
                        text: controller.calibrationActive ? qsTr("校准中") : (_calibrationCommandPending ? qsTr("等待响应") : qsTr("开始校准"))
                        enabled: !controller.calibrationActive && !_calibrationCommandPending && _calibrationReady(_selectedCalibrationType)
                        primary: true
                        useExplicitPopupColors: _root.useDarkStyle
                        backgroundColor: _accentColor
                        borderColor: _accentColor
                        textColor: _primaryTextColor
                        overlayColor: "#FFFFFF"
                        hoverOverlayOpacity: 0.10
                        pressedOverlayOpacity: 0.18
                        backRadius: _cornerRadius
                        showBorder: true
                        onClicked: {
                            if (!controller.calibrationActive) {
                                _startSelectedCalibration()
                            }
                        }
                    }
                }
            }

            RowLayout {
                id: calibrationContentLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: calibrationTopBar.bottom
                anchors.bottom: calibrationBottomBar.top
                anchors.margins: _adaptiveContentMargin
                anchors.bottomMargin: _adaptiveContentMargin
                spacing: _adaptiveContentGap
                clip: true
                z: 1

                    ColumnLayout {
                        Layout.preferredWidth: Math.min(ScreenTools.defaultFontPixelWidth * 24,
                                                        Math.max(ScreenTools.defaultFontPixelWidth * 16,
                                                                 calibrationContentLayout.width * 0.20))
                        Layout.minimumWidth: Math.min(ScreenTools.defaultFontPixelWidth * 14,
                                                      Math.max(0, calibrationContentLayout.width * 0.16))
                        Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 25
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    spacing: ScreenTools.defaultFontPixelHeight * 0.75

                    QGCLabel {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.55
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight
                        text: _calibrationTitleForType(_selectedCalibrationType)
                        color: _root.useDarkStyle ? _primaryTextColor : qgcPal.text
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                    }

                    Item {
                        id: stepListArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 16.0
                        Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 10.0

                        QGCLabel {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: qsTr("步骤 %1/%2").arg(_displayStepIndex() + 1).arg(_displayStepCount())
                            color: _secondaryTextColor
                            font.bold: true
                            font.pointSize: Math.max(8, ScreenTools.defaultFontPointSize * 0.86)
                        }

                        Repeater {
                            model: _displaySteps()

                            RowLayout {
                                id: stepRow
                                required property var modelData
                                required property int index
                                readonly property bool stepDone: controller.calibrationActive && controller.showOrientationCalArea && modelData && modelData.rawIndex !== undefined
                                    ? (modelData.done !== undefined ? modelData.done : false)
                                    : _calibrationDoneForDisplay(_selectedCalibrationType)
                                readonly property bool stepActive: controller.calibrationActive &&
                                    controller.showOrientationCalArea &&
                                    modelData &&
                                    modelData.rawIndex !== undefined &&
                                    modelData.rawIndex === _activeOrientationRawIndex()
                                readonly property string stepText: modelData && modelData.text !== undefined ? modelData.text : modelData
                                readonly property real rowPitch: Math.min(ScreenTools.defaultFontPixelHeight * 2.35,
                                                                          Math.max(ScreenTools.defaultFontPixelHeight * 1.85,
                                                                                   (stepListArea.height - ScreenTools.defaultFontPixelHeight * 2.4) / Math.max(_displayStepCount(), 1)))
                                x: 0
                                y: ScreenTools.defaultFontPixelHeight * 2.1 + (index * rowPitch)
                                width: stepListArea.width
                                height: Math.min(ScreenTools.defaultFontPixelHeight * 2.1, rowPitch)
                                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.72
                                    Layout.preferredHeight: Layout.preferredWidth
                                    radius: width / 2
                                    color: stepRow.stepActive ? _accentColor : (stepRow.stepDone ? "#22C55E" : "transparent")
                                    border.width: 1
                                    border.color: stepRow.stepActive ? _accentColor : (stepRow.stepDone ? "#22C55E" : Qt.rgba(1, 1, 1, 0.24))

                                    QGCLabel {
                                        anchors.centerIn: parent
                                        text: index + 1
                                        color: _primaryTextColor
                                        font.bold: true
                                        font.pointSize: Math.max(8, ScreenTools.defaultFontPointSize * 0.86)
                                    }
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: stepRow.stepText
                                    color: stepRow.stepActive || stepRow.stepDone ? _primaryTextColor : _secondaryTextColor
                                    font.bold: stepRow.stepActive
                                    font.pointSize: Math.max(8, ScreenTools.defaultFontPointSize * 0.86)
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.preferredWidth: stepStatusLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.2
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.35
                                    radius: height / 2
                                    color: Qt.rgba(0, 0, 0, 0.18)
                                    border.width: 1
                                    border.color: _stepStatusColor(modelData)

                                    QGCLabel {
                                        id: stepStatusLabel
                                        anchors.centerIn: parent
                                        text: _stepStatusText(modelData)
                                        color: _stepStatusColor(modelData)
                                        font.bold: stepRow.stepDone || stepRow.stepActive
                                        font.pointSize: Math.max(7, ScreenTools.defaultFontPointSize * 0.72)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.1
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.9
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight
                        radius: _cornerRadius
                        color: Qt.rgba(0.15, 0.39, 0.92, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(0.15, 0.39, 0.92, 0.28)

                        ColumnLayout {
                            id: leftProgressColumn
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                            spacing: ScreenTools.defaultFontPixelHeight * 0.35

                            RowLayout {
                                Layout.fillWidth: true

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: qsTr("当前状态")
                                    color: _secondaryTextColor
                                }

                                QGCLabel {
                                    text: _shortCalibrationStateText()
                                    color: controller.calibrationActive ? "#22C55E" : (_calibrationCommandPending ? "#3B82F6" : "#F59E0B")
                                    font.bold: true
                                }
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                text: controller.calibrationActive && controller.showOrientationCalArea
                                      ? qsTr("已完成 %1/%2").arg(_completedDisplayStepCount()).arg(_displayStepCount())
                                      : qsTr("校准进度 %1/%2").arg(_displayStepIndex() + 1).arg(_displayStepCount())
                                color: _primaryTextColor
                                font.bold: true
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.fillHeight: true
                    radius: _cornerRadius
                    color: _root.useDarkStyle ? "#111820" : qgcPal.window
                    border.width: 1
                    border.color: _root.useDarkStyle ? _borderColor : qgcPal.buttonBorder
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.32
                        spacing: ScreenTools.defaultFontPixelHeight * 0.06

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.05
                            Layout.minimumHeight: Layout.preferredHeight
                            Layout.maximumHeight: Layout.preferredHeight

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelHeight * 0.18

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: _calibrationTitleForType(_selectedCalibrationType)
                                    color: _root.useDarkStyle ? _primaryTextColor : qgcPal.text
                                    font.bold: true
                                    font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: _calibrationHelpForType(_selectedCalibrationType)
                                    color: _root.useDarkStyle ? _secondaryTextColor : qgcPal.text
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    font.pointSize: Math.max(8, ScreenTools.defaultFontPointSize * 0.86)
                                }
                            }

                            Rectangle {
                                radius: height / 2
                                implicitHeight: ScreenTools.defaultFontPixelHeight * 1.35
                                implicitWidth: detailStateText.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.8
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: _calibrationAccent(_selectedCalibrationType)

                                QGCLabel {
                                    id: detailStateText
                                    anchors.centerIn: parent
                                    text: _calibrationStateText(_selectedCalibrationType)
                                    color: _calibrationAccent(_selectedCalibrationType)
                                    font.bold: true
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: _root.useDarkStyle ? _borderColor : qgcPal.buttonBorder
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 14.0, parent.height * 0.72)
                            Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 12.0
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 0
                            spacing: _adaptiveContentGap

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.fillHeight: true
                                Layout.preferredHeight: parent.height
                                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 12.0
                                Layout.alignment: Qt.AlignTop
                                radius: _cornerRadius
                                color: Qt.rgba(0.02, 0.08, 0.14, _root.useDarkStyle ? 0.86 : 0.08)
                                border.width: 1
                                border.color: Qt.rgba(0.15, 0.39, 0.92, _root.useDarkStyle ? 0.55 : 0.25)
                                clip: true

                                Item {
                                    id: aircraftDisplayBox
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -Math.min(ScreenTools.defaultFontPixelHeight * 0.8, parent.height * 0.06)
                                    width: Math.min(parent.width * 0.90, ScreenTools.defaultFontPixelWidth * 47)
                                    height: Math.min(parent.height * 0.76, ScreenTools.defaultFontPixelHeight * 12.8)

                                    Image {
                                        anchors.centerIn: parent
                                        width: aircraftDisplayBox.width
                                        height: aircraftDisplayBox.height
                                        source: _displayStepImage()
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        opacity: 0.92
                                    }

                                    Canvas {
                                        id: rotationGuideCanvas
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: ScreenTools.defaultFontPixelHeight * 0.18
                                        width: aircraftDisplayBox.width * 0.68
                                        height: aircraftDisplayBox.height * 0.88
                                        visible: _showRotationGuide()
                                        opacity: 0.95

                                        property int guideIndex: _activeOrientationRawIndex()
                                        onGuideIndexChanged: requestPaint()
                                        onVisibleChanged: requestPaint()
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()

                                        onPaint: {
                                            const ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            if (!visible) {
                                                return
                                            }

                                            const cx = width / 2
                                            const cy = height / 2
                                            const rx = width * 0.42
                                            const ryByStep = [0.26, 0.26, 0.52, 0.52, 0.36, 0.36]
                                            const tiltByStep = [-0.28, -0.28, 1.08, 1.08, 0.18, 0.18]
                                            const clockwiseByStep = [true, false, true, false, true, false]
                                            const ry = height * ryByStep[Math.max(0, Math.min(guideIndex, ryByStep.length - 1))]
                                            const tilt = tiltByStep[Math.max(0, Math.min(guideIndex, tiltByStep.length - 1))]
                                            const clockwise = clockwiseByStep[Math.max(0, Math.min(guideIndex, clockwiseByStep.length - 1))]
                                            const start = clockwise ? -0.88 * Math.PI : 0.12 * Math.PI
                                            const end = clockwise ? 0.82 * Math.PI : -1.58 * Math.PI

                                            function point(angle) {
                                                const x = Math.cos(angle) * rx
                                                const y = Math.sin(angle) * ry
                                                return {
                                                    x: cx + x * Math.cos(tilt) - y * Math.sin(tilt),
                                                    y: cy + x * Math.sin(tilt) + y * Math.cos(tilt)
                                                }
                                            }

                                            function tangent(angle) {
                                                const dir = clockwise ? 1 : -1
                                                const dx = -Math.sin(angle) * rx * dir
                                                const dy = Math.cos(angle) * ry * dir
                                                return Math.atan2(dx * Math.sin(tilt) + dy * Math.cos(tilt),
                                                                  dx * Math.cos(tilt) - dy * Math.sin(tilt))
                                            }

                                            ctx.save()
                                            ctx.lineCap = "round"
                                            ctx.shadowColor = "rgba(37, 99, 235, 0.9)"
                                            ctx.shadowBlur = 14

                                            for (let pass = 0; pass < 2; pass++) {
                                                ctx.beginPath()
                                                const steps = 72
                                                for (let i = 0; i <= steps; i++) {
                                                    const t = i / steps
                                                    const angle = start + (end - start) * t
                                                    const p = point(angle)
                                                    if (i === 0) {
                                                        ctx.moveTo(p.x, p.y)
                                                    } else {
                                                        ctx.lineTo(p.x, p.y)
                                                    }
                                                }
                                                ctx.strokeStyle = pass === 0 ? "rgba(96, 165, 250, 0.24)" : "#60A5FA"
                                                ctx.lineWidth = pass === 0 ? Math.max(9, width * 0.036) : Math.max(4, width * 0.017)
                                                ctx.stroke()
                                            }

                                            const tip = point(end)
                                            const heading = tangent(end)
                                            const size = Math.max(14, width * 0.052)
                                            ctx.fillStyle = "#93C5FD"
                                            ctx.beginPath()
                                            ctx.moveTo(tip.x, tip.y)
                                            ctx.lineTo(tip.x - Math.cos(heading - 0.52) * size, tip.y - Math.sin(heading - 0.52) * size)
                                            ctx.lineTo(tip.x - Math.cos(heading + 0.52) * size, tip.y - Math.sin(heading + 0.52) * size)
                                            ctx.closePath()
                                            ctx.fill()
                                            ctx.restore()
                                        }
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: -ScreenTools.defaultFontPixelHeight * 0.35
                                        visible: _showRotationGuide()
                                        width: rotationGuideLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.0
                                        height: ScreenTools.defaultFontPixelHeight * 1.65
                                        radius: height / 2
                                        color: Qt.rgba(0.15, 0.39, 0.92, 0.22)
                                        border.width: 1
                                        border.color: "#60A5FA"

                                        QGCLabel {
                                            id: rotationGuideLabel
                                            anchors.centerIn: parent
                                            text: _rotationGuideText()
                                            color: "#E0F2FE"
                                            font.bold: true
                                        }
                                    }
                                }

                                QGCLabel {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.45
                                    text: controller.calibrationActive && controller.showOrientationCalArea
                                          ? qsTr("步骤 %1/%2  已完成 %3/%4  %5").arg(_displayStepIndex() + 1).arg(_displayStepCount()).arg(_completedDisplayStepCount()).arg(_displayStepCount()).arg(_displayStepText())
                                          : qsTr("步骤 %1/%2  %3").arg(_displayStepIndex() + 1).arg(_displayStepCount()).arg(_displayStepText())
                                    color: _root.useDarkStyle ? _primaryTextColor : qgcPal.text
                                    font.bold: true
                                    font.pointSize: ScreenTools.defaultFontPointSize * 1.05
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: aircraftDisplayBox.top
                                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.35
                                    visible: !_showRotationGuide()
                                    width: detectingLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.2
                                    height: ScreenTools.defaultFontPixelHeight * 1.65
                                    radius: _cornerRadius
                                    color: Qt.rgba(0.15, 0.39, 0.92, 0.14)
                                    border.width: 1
                                    border.color: Qt.rgba(0.15, 0.39, 0.92, 0.62)

                                    QGCLabel {
                                        id: detectingLabel
                                        anchors.centerIn: parent
                                        text: _shortCalibrationStateText()
                                        color: "#60A5FA"
                                        font.bold: true
                                    }
                                }

                            }

                            ColumnLayout {
                                Layout.preferredWidth: Math.min(ScreenTools.defaultFontPixelWidth * 31,
                                                                Math.max(ScreenTools.defaultFontPixelWidth * 22, parent.width * 0.30))
                                Layout.minimumWidth: Math.min(ScreenTools.defaultFontPixelWidth * 20, parent.width * 0.24)
                                Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 36
                                Layout.alignment: Qt.AlignTop
                                spacing: ScreenTools.defaultFontPixelHeight * (_compactCalibrationLayout ? 0.32 : 0.5)

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 6.8, parent.height * 0.30)
                                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 6.4
                                    Layout.maximumHeight: ScreenTools.defaultFontPixelHeight * 8.0
                                    radius: _cornerRadius
                                    color: _root.useDarkStyle ? _inputColor : qgcPal.windowShade
                                    border.width: 1
                                    border.color: _root.useDarkStyle ? _borderColor : qgcPal.buttonBorder

                                    ColumnLayout {
                                        id: statusPanelColumn
                                        anchors.fill: parent
                                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.38
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.18

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: qsTr("设备状态")
                                            color: _root.useDarkStyle ? _primaryTextColor : qgcPal.text
                                            font.bold: true
                                        }

                                        Repeater {
                                            model: [
                                                { "name": qsTr("加速度计"), "type": "accel" },
                                                { "name": qsTr("陀螺仪"), "type": "gyro" },
                                                { "name": qsTr("磁力计"), "type": "compass" },
                                                { "name": qsTr("地平线"), "type": "level" },
                                                { "name": qsTr("空速"), "type": "airspeed" }
                                            ]

                                            RowLayout {
                                                required property var modelData
                                                visible: _calibrationVisible(modelData.type)
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.05
                                                Layout.minimumHeight: Layout.preferredHeight
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.35

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    text: modelData.name
                                                    color: _root.useDarkStyle ? _secondaryTextColor : qgcPal.text
                                                    elide: Text.ElideRight
                                                }

                                                QGCLabel {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7.2
                                                    Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 7.2
                                                    text: _calibrationStateText(modelData.type)
                                                    color: _calibrationAccent(modelData.type)
                                                    font.bold: true
                                                    horizontalAlignment: Text.AlignRight
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 10.0, parent.height * 0.47)
                                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 9.0
                                    Layout.maximumHeight: ScreenTools.defaultFontPixelHeight * 14.0
                                    radius: _cornerRadius
                                    color: _root.useDarkStyle ? _inputColor : qgcPal.windowShade
                                    border.width: 1
                                    border.color: _root.useDarkStyle ? _borderColor : qgcPal.buttonBorder

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.38
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.18

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: qsTr("实时数据")
                                            color: _root.useDarkStyle ? _primaryTextColor : qgcPal.text
                                            font.bold: true
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: "Roll"
                                                color: "#FF5A5F"
                                                font.bold: true
                                            }

                                            QGCLabel {
                                                text: _formatTelemetryValue(_activeVehicle ? _activeVehicle.roll : null, 1, "°")
                                                color: _primaryTextColor
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: "Pitch"
                                                color: "#22C55E"
                                                font.bold: true
                                            }

                                            QGCLabel {
                                                text: _formatTelemetryValue(_activeVehicle ? _activeVehicle.pitch : null, 1, "°")
                                                color: _primaryTextColor
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: "Yaw Rate"
                                                color: "#3B82F6"
                                                font.bold: true
                                            }

                                            QGCLabel {
                                                text: _formatTelemetryValue(_activeVehicle ? _activeVehicle.yawRate : null, 2, "°/s")
                                                color: _primaryTextColor
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: "Heading"
                                                color: "#A78BFA"
                                                font.bold: true
                                            }

                                            QGCLabel {
                                                text: _formatTelemetryValue(_activeVehicle ? _activeVehicle.heading : null, 0, "°")
                                                color: _primaryTextColor
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: "Board Rot"
                                                color: _secondaryTextColor
                                                font.bold: true
                                            }

                                            QGCLabel {
                                                text: sens_board_rot ? sens_board_rot.valueString : "--"
                                                color: _primaryTextColor
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: "Board X/Y"
                                                color: _secondaryTextColor
                                                font.bold: true
                                            }

                                            QGCLabel {
                                                text: "%1 / %2".arg(_formatTelemetryValue(sens_board_x_off, 1, "°")).arg(_formatTelemetryValue(sens_board_y_off, 1, "°"))
                                                color: _primaryTextColor
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: "Board Z"
                                                color: _secondaryTextColor
                                                font.bold: true
                                            }

                                            QGCLabel {
                                                text: _formatTelemetryValue(sens_board_z_off, 1, "°")
                                                color: _primaryTextColor
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 1
                                            color: _root.useDarkStyle ? _borderColor : qgcPal.buttonBorder
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: qsTr("稳定性")
                                                color: _root.useDarkStyle ? _primaryTextColor : qgcPal.text
                                                font.bold: true
                                            }

                                            QGCLabel {
                                                text: _attitudeStable() ? qsTr("稳定") : (_vehicleConnected ? qsTr("姿态变化中") : qsTr("等待数据"))
                                                color: _attitudeStable() ? "#22C55E" : "#F59E0B"
                                                font.bold: true
                                            }
                                        }

                                        Canvas {
                                            id: stabilityCanvas
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 1.5, parent.height * 0.18)
                                            Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 1.25
                                            Layout.maximumHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                            opacity: 0.9

                                            property real sampleSeed: _factNumberOrZero(_activeVehicle ? _activeVehicle.rollRate : null) +
                                                                      _factNumberOrZero(_activeVehicle ? _activeVehicle.pitchRate : null) +
                                                                      _factNumberOrZero(_activeVehicle ? _activeVehicle.yawRate : null)
                                            onSampleSeedChanged: requestPaint()
                                            onWidthChanged: requestPaint()
                                            onHeightChanged: requestPaint()

                                            onPaint: {
                                                const ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                ctx.strokeStyle = "#22C55E"
                                                ctx.lineWidth = 2
                                                ctx.beginPath()
                                                const mid = height * 0.48
                                                const amp = Math.max(2, height * 0.18)
                                                for (let x = 0; x < width; x += 8) {
                                                    const y = mid + Math.sin((x * 0.08) + sampleSeed) * amp * 0.35 +
                                                        Math.sin((x * 0.22) + sampleSeed * 0.4) * amp * 0.18
                                                    if (x === 0) {
                                                        ctx.moveTo(x, y)
                                                    } else {
                                                        ctx.lineTo(x, y)
                                                    }
                                                }
                                                ctx.stroke()
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

        // Active calibration area — visible during calibration
        RowLayout {
            Layout.fillWidth:   true
            visible:            false
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
            visible:            false

            TextArea {
                id:             statusTextArea
                anchors.fill:   parent
                readOnly:       true
                visible:        !orientationCalArea.visible
                text:           statusTextAreaDefaultText
                color:          _root.useDarkStyle ? _secondaryTextColor : qgcPal.text
                onTextChanged: {
                    const rawStatusText = text === undefined || text === null ? "" : "" + text
                    const statusText = rawStatusText.toLowerCase()
                    const resolvedCalibrationType = _activeCalibrationType !== "" ? _activeCalibrationType : _selectedCalibrationType
                    if (_statusTextHasCalibrationComplete(rawStatusText)) {
                        _setCalibrationResult(resolvedCalibrationType, "complete")
                    } else if (_statusTextHasCalibrationFailed(rawStatusText)) {
                        _setCalibrationResult(resolvedCalibrationType, "failed")
                    } else if (_statusTextHasCalibrationCancelled(rawStatusText)) {
                        _setCalibrationResult(resolvedCalibrationType, "cancelled")
                    }
                    if (_calibrationCommandPending &&
                            (statusText.indexOf("calibration started") !== -1 ||
                             statusText.indexOf("calibration failed") !== -1 ||
                             statusText.indexOf("calibration cancelled") !== -1 ||
                             statusText.indexOf("校准失败") !== -1 ||
                             statusText.indexOf("取消") !== -1 ||
                             statusText.indexOf("校准完成") !== -1)) {
                        _calibrationCommandPending = false
                        calibrationCommandResponseTimer.stop()
                    }
                }
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
