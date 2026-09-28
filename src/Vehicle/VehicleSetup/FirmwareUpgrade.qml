pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SetupPage {
    id:                 firmwarePage
    pageComponent:      firmwarePageComponent
    pageName:           qsTr("Firmware")
    showAdvanced:       globals.activeVehicle && globals.activeVehicle.apmFirmware
    centerPageLoader:   true

    property bool _qgcPopupChrome: true

    QGCPopupStyle { id: popupStyle }

    Component {
        id: firmwarePageComponent

        Item {
            id: firmwareContent
            readonly property real _outerMargin:       ScreenTools.defaultFontPixelHeight
            readonly property real _panelPadding:      ScreenTools.defaultFontPixelHeight * 1.1
            readonly property real _sectionSpacing:    ScreenTools.defaultFontPixelHeight * 0.8
            readonly property real _cardInnerMargin:   ScreenTools.defaultFontPixelHeight * 0.55
            readonly property real _pairedCardHeight:  Math.max(ScreenTools.defaultFontPixelHeight * 14.4, recommendationColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.1), checksColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.1))
            readonly property real _versionTileHeight: ScreenTools.defaultFontPixelHeight * 3.05
            readonly property real _contentMinWidth:   ScreenTools.defaultFontPixelWidth * 36
            readonly property real _contentMaxWidth:   ScreenTools.defaultFontPixelWidth * 86
            readonly property real _availableWidth:    Math.max(ScreenTools.defaultFontPixelWidth * 34, firmwarePage.availableWidth - (_outerMargin * 2))
            readonly property real _panelWidth:        Math.min(_contentMaxWidth, Math.max(_contentMinWidth, _availableWidth))
            readonly property real _logHeight:         Math.max(ScreenTools.defaultFontPixelHeight * 12, ScreenTools.defaultFontPixelHeight * 16)
            readonly property real _sectionTitlePointSize: ScreenTools.mediumFontPointSize * 0.92
            readonly property real _bodyPointSize:         ScreenTools.defaultFontPointSize * 0.90
            readonly property real _smallPointSize:        ScreenTools.defaultFontPointSize * ScreenTools.smallFontPointRatio * 0.95
            readonly property real _pageHeight:            Math.max(ScreenTools.defaultFontPixelHeight * 28, firmwarePage.availableHeight)
            readonly property int  _versionGridColumns:    firmwarePage.availableWidth < ScreenTools.defaultFontPixelWidth * 68 ? 2 : 3

            implicitWidth:  _panelWidth + (_outerMargin * 2)
            implicitHeight: _pageHeight
            width:          Math.max(implicitWidth, firmwarePage.availableWidth)
            height:         _pageHeight

            // Those user visible strings are hard to translate because we can't send the
            // HTML strings to translation as this can create a security risk. we need to find
            // a better way to highlight them, or use less highlights.

            // User visible strings
            readonly property string title:             qsTr("Firmware Setup") // Popup dialog title
            readonly property string highlightPrefix:   "<font color=\"" + qgcPal.warningText + "\">"
            readonly property string highlightSuffix:   "</font>"
            readonly property string welcomeText:       qsTr("%1 can upgrade the firmware on Pixhawk devices and SiK Radios.").arg("BTFW-GCS")
            readonly property string welcomeTextSingle: qsTr("Update the autopilot firmware to the latest version")
            readonly property string plugInText:        "<big>" + highlightPrefix + qsTr("Plug in your device") + highlightSuffix + qsTr(" via USB to ") + highlightPrefix + qsTr("start") + highlightSuffix + qsTr(" firmware upgrade.") + "</big>"
            readonly property string flashFailText:     qsTr("If upgrade failed, make sure to connect ") + highlightPrefix + qsTr("directly") + highlightSuffix + qsTr(" to a powered USB port on your computer, not through a USB hub. ") +
                                                        qsTr("Also make sure you are only powered via USB ") + highlightPrefix + qsTr("not battery") + highlightSuffix + "."
            readonly property string qgcUnplugText1:    qsTr("All %1 connections to vehicles must be ").arg(QGroundControl.appName) + highlightPrefix + qsTr(" disconnected ") + highlightSuffix + qsTr("prior to firmware upgrade.")
            readonly property string qgcUnplugText2:    highlightPrefix + "<big>" + qsTr("Please unplug your Pixhawk and/or Radio from USB.") + "</big>" + highlightSuffix

            readonly property int _defaultFimwareTypePX4:   12
            readonly property int _defaultFimwareTypeAPM:   3
            readonly property real _infoSpacing:            ScreenTools.defaultFontPixelHeight * 0.5
            readonly property real _infoLabelWidth:         ScreenTools.defaultFontPixelWidth * 18
            readonly property var  _activeVehicle:          globals.activeVehicle
            readonly property var  _cameraManager:          _activeVehicle ? _activeVehicle.cameraManager : null
            readonly property var  _currentCamera:          _cameraManager ? _cameraManager.currentCameraInstance : null
            readonly property var  _gimbalController:       _activeVehicle ? _activeVehicle.gimbalController : null
            readonly property var  _activeGimbal:           (_gimbalController && _gimbalController.gimbals.count > 0)
                                                            ? (_gimbalController.activeGimbal ? _gimbalController.activeGimbal : _gimbalController.gimbals.get(0))
                                                            : null
            readonly property var  _escs:                   _activeVehicle ? _activeVehicle.escs : null
            readonly property var  _primaryBattery:         (_activeVehicle && _activeVehicle.batteries && _activeVehicle.batteries.count > 0)
                                                            ? _activeVehicle.batteries.get(0)
                                                            : null
            readonly property bool _vehicleConnected:       !!(_activeVehicle && _activeVehicle.vehicleLinkManager && !_activeVehicle.vehicleLinkManager.communicationLost)

            property var    _firmwareUpgradeSettings:   QGroundControl.settingsManager.firmwareUpgradeSettings
            property var    _defaultFirmwareFact:       _firmwareUpgradeSettings.defaultFirmwareType
            property bool   _defaultFirmwareIsPX4:      true

            property string firmwareWarningMessage
            property bool   firmwareWarningMessageVisible:  false
            property bool   initialBoardSearch:             true
            property string firmwareName
            property string _upgradeNoticeText
            property string _upgradeNoticeLevel:             "info"
            property bool   _upgradeNoticeVisible:           false
            property bool   _flashInProgress:                false
            property bool   _flashCompleted:                 false
            property string _pendingFlashKind
            property string _pendingFlashDescription
            property string _pendingFlashUrl
            property int    _pendingFlashStack:              FirmwareUpgradeController.AutoPilotStackPX4
            property int    _pendingFlashBuildType:          FirmwareUpgradeController.StableFirmware
            property int    _pendingFlashVehicleType:        FirmwareUpgradeController.DefaultVehicleFirmware

            property bool _singleFirmwareMode:          QGroundControl.corePlugin.options.firmwareUpgradeSingleURL.length != 0   ///< true: running in special single firmware download mode

            function _setUpgradeNotice(level, text) {
                _upgradeNoticeLevel = level
                _upgradeNoticeText = text
                _upgradeNoticeVisible = text !== ""
            }

            function _upgradeNoticeColor() {
                switch (_upgradeNoticeLevel) {
                case "success":
                    return qgcPal.colorGreen
                case "warn":
                    return qgcPal.warningText
                case "error":
                    return qgcPal.colorRed
                default:
                    return popupStyle.accentColor
                }
            }

            function _requestFlashConfirmation(description, kind, url, stack, buildType, vehicleType) {
                _flashCompleted = false
                _pendingFlashDescription = description
                _pendingFlashKind = kind
                _pendingFlashUrl = url || ""
                _pendingFlashStack = stack !== undefined ? stack : FirmwareUpgradeController.AutoPilotStackPX4
                _pendingFlashBuildType = buildType !== undefined ? buildType : FirmwareUpgradeController.StableFirmware
                _pendingFlashVehicleType = vehicleType !== undefined ? vehicleType : FirmwareUpgradeController.DefaultVehicleFirmware
                flashConfirmDialogFactory.open()
            }

            function _beginConfirmedFlash() {
                _flashInProgress = true
                progressBar.value = 0
                statusTextArea.append(qsTr("已确认刷写，正在准备固件文件..."))
                _setUpgradeNotice("info", qsTr("正在准备固件文件，请保持 USB 与电源稳定。"))
                if (_pendingFlashKind === "single") {
                    controller.flashSingleFirmwareMode(_pendingFlashBuildType)
                } else if (_pendingFlashKind === "url") {
                    controller.flashFirmwareUrl(_pendingFlashUrl)
                } else if (_pendingFlashKind === "firmware") {
                    controller.flash(_pendingFlashStack, _pendingFlashBuildType, _pendingFlashVehicleType)
                } else {
                    _flashInProgress = false
                    _setUpgradeNotice("error", qsTr("未找到待刷写的固件请求，请重新选择固件。"))
                }
                _clearPendingFlash()
            }

            function _cancelPendingFlash() {
                _flashInProgress = false
                _clearPendingFlash()
                statusTextArea.append(highlightPrefix + qsTr("Upgrade cancelled") + highlightSuffix)
                statusTextArea.append("------------------------------------------")
                controller.cancel()
            }

            function _clearPendingFlash() {
                _pendingFlashKind = ""
                _pendingFlashDescription = ""
                _pendingFlashUrl = ""
                _pendingFlashStack = FirmwareUpgradeController.AutoPilotStackPX4
                _pendingFlashBuildType = FirmwareUpgradeController.StableFirmware
                _pendingFlashVehicleType = FirmwareUpgradeController.DefaultVehicleFirmware
            }

            function _flightControllerVersionText() {
                if (!_activeVehicle) {
                    return qsTr("Not detected")
                }
                if (_activeVehicle.firmwareMajorVersion < 0) {
                    return _vehicleConnected ? qsTr("Connected, version not reported") : qsTr("Not detected")
                }

                return _activeVehicle.firmwareMajorVersion + "."
                        + _activeVehicle.firmwareMinorVersion + "."
                        + _activeVehicle.firmwarePatchVersion
                        + _activeVehicle.firmwareVersionTypeString
            }

            function _flightControllerModelText() {
                if (!_activeVehicle) {
                    return qsTr("Not detected")
                }

                const firmwareType = _activeVehicle.firmwareTypeString !== "" ? _activeVehicle.firmwareTypeString : qsTr("Unknown firmware")
                const vehicleType = _activeVehicle.vehicleTypeString !== "" ? _activeVehicle.vehicleTypeString : qsTr("Unknown vehicle")
                return firmwareType + " / " + vehicleType
            }

            function _protocolVersionText() {
                if (!_vehicleConnected || !_activeVehicle.vehicleLinkManager) {
                    return qsTr("Not detected")
                }

                const mavlinkVersion = _activeVehicle.vehicleLinkManager.primaryMavlinkVersion
                return mavlinkVersion > 0 ? qsTr("MAVLink %1").arg(mavlinkVersion) : qsTr("Not reported")
            }

            function _deviceIdText() {
                if (!_activeVehicle) {
                    return qsTr("Not detected")
                }

                return _activeVehicle.vehicleUID > 0 ? _activeVehicle.vehicleUIDStr : qsTr("Not reported")
            }

            function _boardIdText(boardId) {
                if (!_activeVehicle) {
                    return qsTr("Not detected")
                }

                return boardId > 0 ? boardId.toString() : qsTr("Not reported")
            }

            function _gitHashText() {
                if (!_activeVehicle) {
                    return qsTr("Not detected")
                }

                return _activeVehicle.gitHash !== "" ? _activeVehicle.gitHash : qsTr("Not reported")
            }

            function _firmwareSupportText() {
                if (!_activeVehicle) {
                    return qsTr("Connect a vehicle to verify firmware compatibility.")
                }
                if (_activeVehicle.firmwareMajorVersion < 0) {
                    return qsTr("Firmware version not reported; compatibility cannot be verified.")
                }
                if (_activeVehicle.genericFirmware) {
                    return qsTr("Generic firmware detected; verify compatibility before flight.")
                }

                return qsTr("Known firmware family detected.")
            }

            function _telemetryVersionText() {
                if (controller.boardType !== "" && controller.boardType.toLowerCase().indexOf("radio") !== -1) {
                    return controller.boardType
                }

                return _vehicleConnected
                    ? qsTr("Connected, version not reported")
                    : qsTr("Not detected")
            }

            function _cameraVersionText() {
                if (!_currentCamera) {
                    return qsTr("Not detected")
                }

                const modelName = _currentCamera.modelName !== "" ? _currentCamera.modelName : qsTr("Camera")
                const firmwareVersion = _currentCamera.firmwareVersion !== "" ? _currentCamera.firmwareVersion : qsTr("Version not reported")
                return modelName + " / " + firmwareVersion
            }

            function _gimbalVersionText() {
                if (!_activeGimbal) {
                    return qsTr("Not detected")
                }

                return qsTr("Device %1, version not reported").arg(_activeGimbal.deviceId.rawValue)
            }

            function _escVersionText() {
                if (!_escs || _escs.count === 0) {
                    return qsTr("Not detected")
                }

                return qsTr("%1 ESCs detected, version not reported").arg(_escs.count)
            }

            function _batteryStateText() {
                if (!_primaryBattery) {
                    return qsTr("Verify USB power is stable and disconnect the main battery if the target hardware requires it.")
                }

                const percent = Number(_primaryBattery.percentRemaining.rawValue)
                if (!isNaN(percent) && percent >= 50) {
                    return qsTr("Battery reported at %1%.").arg(Math.round(percent))
                }
                if (!isNaN(percent) && percent >= 0) {
                    return qsTr("Battery reported at %1%. Charge or disconnect the battery before upgrade.").arg(Math.round(percent))
                }
                return qsTr("Battery state not reported. Confirm power stability before flashing.")
            }

            function _checkStateColor(state) {
                switch (state) {
                case "pass":
                    return qgcPal.colorGreen
                case "warn":
                    return qgcPal.warningText
                default:
                    return qgcPal.text
                }
            }

            readonly property var _versionItems: [
                { title: qsTr("Flight Controller"), value: _flightControllerModelText() },
                { title: qsTr("Firmware Version"),  value: _flightControllerVersionText() },
                { title: qsTr("MAVLink Protocol"),  value: _protocolVersionText() },
                { title: qsTr("Device ID"),         value: _deviceIdText() },
                { title: qsTr("Board Vendor ID"),   value: _boardIdText(_activeVehicle ? _activeVehicle.firmwareBoardVendorId : 0) },
                { title: qsTr("Board Product ID"),  value: _boardIdText(_activeVehicle ? _activeVehicle.firmwareBoardProductId : 0) },
                { title: qsTr("Git Hash"),          value: _gitHashText() },
                { title: qsTr("Compatibility"),     value: _firmwareSupportText() },
                { title: qsTr("Telemetry"),         value: _telemetryVersionText() },
                { title: qsTr("Camera"),            value: _cameraVersionText() },
                { title: qsTr("Gimbal"),            value: _gimbalVersionText() },
                { title: qsTr("ESC"),               value: _escVersionText() }
            ]

            readonly property var _recommendationItems: [
                _activeVehicle && _activeVehicle.px4Firmware && controller.px4StableVersion !== ""
                    ? qsTr("For routine operations, prefer the stable PX4 release (%1).").arg(controller.px4StableVersion)
                    : qsTr("For routine operations, prefer the stable firmware channel and avoid beta or developer builds."),
                qsTr("Upgrade telemetry, camera, gimbal and ESC firmware only when the vendor release notes require version matching."),
                qsTr("After flashing, verify parameters, recalibrate affected sensors and confirm failsafe behavior before the next flight.")
            ]

            readonly property var _preUpgradeChecks: [
                {
                    title: qsTr("Vehicle disarmed"),
                    detail: _activeVehicle
                        ? (_activeVehicle.armed
                            ? qsTr("Vehicle is armed. Disarm before flashing.")
                            : qsTr("Vehicle is disarmed."))
                        : qsTr("No active vehicle detected."),
                    state: (_activeVehicle && _activeVehicle.armed) ? "warn" : "pass"
                },
                {
                    title: qsTr("Upgrade target via USB"),
                    detail: controller.boardType !== ""
                        ? qsTr("Detected upgrade target: %1").arg(controller.boardType)
                        : qsTr("Plug the target hardware directly into a powered USB port."),
                    state: controller.boardType !== "" ? "pass" : "info"
                },
                {
                    title: qsTr("Battery / power state"),
                    detail: _batteryStateText(),
                    state: (_primaryBattery && !isNaN(Number(_primaryBattery.percentRemaining.rawValue))
                            && Number(_primaryBattery.percentRemaining.rawValue) < 50)
                           ? "warn"
                           : "info"
                },
                {
                    title: qsTr("Safety preparation"),
                    detail: qsTr("Remove propellers, secure payload power and back up parameters and mission files before upgrading."),
                    state: "info"
                }
            ]

            function setupPageCompleted() {
                controller.startBoardSearch()
                _defaultFirmwareIsPX4 = _defaultFirmwareFact.rawValue === _defaultFimwareTypePX4 // we don't want this to be bound and change as radios are selected
            }

            QGCFileDialog {
                id:                 customFirmwareDialog
                title:              qsTr("Select Firmware File")
                nameFilters:        [qsTr("Firmware Files (*.px4 *.apj *.bin *.ihx)"), qsTr("All Files (*)")]
                folder:             QGroundControl.settingsManager.appSettings.logSavePath
                onAcceptedForLoad: (file) => {
                    firmwareContent._requestFlashConfirmation(qsTr("自定义固件文件：%1").arg(file), "url", file)
                    close()
                }
            }

            FirmwareUpgradeController {
                id:             controller
                progressBar:    progressBar
                statusLog:      statusTextArea

                property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

                onActiveVehicleChanged: {
                    if (!globals.activeVehicle) {
                        statusTextArea.append(plugInText)
                    }
                }

                onNoBoardFound: {
                    initialBoardSearch = false
                    if (!QGroundControl.multiVehicleManager.activeVehicleAvailable) {
                        statusTextArea.append(plugInText)
                    }
                }

                onBoardGone: {
                    initialBoardSearch = false
                    if (progressBar.value > 0 && progressBar.value < 1) {
                        firmwareContent._setUpgradeNotice("warn", qsTr("刷写过程中设备断开。请保持 USB 连接，按日志提示重新连接或重新进入刷写流程。"))
                    } else if (firmwareContent._flashInProgress) {
                        firmwareContent._flashInProgress = false
                        firmwareContent._setUpgradeNotice("warn", qsTr("刷写尚未进入写入阶段设备已断开，请重新连接并重新选择固件。"))
                    }
                    if (!QGroundControl.multiVehicleManager.activeVehicleAvailable) {
                        statusTextArea.append(plugInText)
                    }
                }

                onBoardFound: {
                    if (initialBoardSearch) {
                        // Board was found right away, so something is already plugged in before we've started upgrade
                        statusTextArea.append(qgcUnplugText1)
                        statusTextArea.append(qgcUnplugText2)

                        var availableDevices = controller.availableBoardsName()
                        if (availableDevices.length > 1) {
                            statusTextArea.append(highlightPrefix + qsTr("Multiple devices detected! Remove all detected devices to perform the firmware upgrade."))
                            statusTextArea.append(qsTr("Detected [%1]: ").arg(availableDevices.length) + availableDevices.join(", "))
                        }
                        if (QGroundControl.multiVehicleManager.activeVehicle) {
                            QGroundControl.multiVehicleManager.activeVehicle.vehicleLinkManager.autoDisconnect = true
                        }
                    } else {
                        // We end up here when we detect a board plugged in after we've started upgrade
                        statusTextArea.append(highlightPrefix + qsTr("Found device") + highlightSuffix + ": " + controller.boardType)
                    }
                }

                onShowFirmwareSelectDlg: {
                    if (firmwareContent._flashCompleted) {
                        statusTextArea.append(qsTr("检测到刷写完成后的升级设备，已保持完成状态。如需再次刷写，请重新进入固件页面。"))
                        return
                    }
                    firmwareSelectDialogFactory.open()
                }
                onFlashComplete: {
                    firmwareContent._flashInProgress = false
                    firmwareContent._flashCompleted = true
                    progressBar.value = 1
                    controller.cancel()
                    firmwareContent._setUpgradeNotice("success", qsTr("固件刷写完成。请重新连接飞控，并在摘要或固件维护页面确认版本已更新。"))
                }
                onError: {
                    firmwareContent._flashInProgress = false
                    firmwareContent._flashCompleted = false
                    firmwareContent._setUpgradeNotice("error", qsTr("固件刷写失败或中断。请保持 USB 稳定，按日志提示恢复后重试。"))
                    statusTextArea.append(flashFailText)
                }
            }

            QGCPopupDialogFactory {
                id: firmwareSelectDialogFactory

                dialogComponent: firmwareSelectDialogComponent
            }

            QGCPopupDialogFactory {
                id: flashConfirmDialogFactory

                dialogComponent: flashConfirmDialogComponent
            }

            Component {
                id: flashConfirmDialogComponent

                QGCPopupDialog {
                    title:              qsTr("确认刷写固件")
                    buttons:            Dialog.Ok | Dialog.Cancel
                    acceptButtonText:   qsTr("确认刷写")
                    rejectButtonText:   qsTr("取消")

                    onAccepted: firmwareContent._beginConfirmedFlash()
                    onRejected: firmwareContent._cancelPendingFlash()

                    ColumnLayout {
                        width:      Math.min(ScreenTools.defaultFontPixelWidth * 72, Math.max(ScreenTools.defaultFontPixelWidth * 44, firmwarePage.availableWidth * 0.72))
                        spacing:    ScreenTools.defaultFontPixelHeight * 0.7

                        QGCLabel {
                            id:                 confirmText
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("即将刷写：%1").arg(firmwareContent._pendingFlashDescription)
                            font.bold:          true
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("确认设备身份、固件文件、USB 连接和供电均稳定；移除螺旋桨，按硬件要求断开主电池。刷写期间不要拔插设备。")
                        }
                    }
                }
            }

            Component {
                id: firmwareSelectDialogComponent

                QGCPopupDialog {
                    id:         firmwareSelectDialog
                    title:      qsTr("Firmware Setup")
                    buttons:    Dialog.Ok | Dialog.Cancel

                    property bool showFirmwareTypeSelection:    _advanced.checked

                    function firmwareVersionChanged(model) {
                        firmwareWarningMessageVisible = false
                        // All of this bizarre, setting model to null and index to 1 and then to 0 is to work around
                        // strangeness in the combo box implementation. This sequence of steps correctly changes the combo model
                        // without generating any warnings and correctly updates the combo text with the new selection.
                        firmwareBuildTypeCombo.model = null
                        firmwareBuildTypeCombo.model = model
                        firmwareBuildTypeCombo.currentIndex = 1
                        firmwareBuildTypeCombo.currentIndex = 0
                    }

                    function updatePX4VersionDisplay() {
                        var versionString = ""
                        if (_advanced.checked) {
                            switch (controller.selectedFirmwareBuildType) {
                            case FirmwareUpgradeController.StableFirmware:
                                versionString = controller.px4StableVersion
                                break
                            case FirmwareUpgradeController.BetaFirmware:
                                versionString = controller.px4BetaVersion
                                break
                            }
                        } else {
                            versionString = controller.px4StableVersion
                        }
                        px4FlightStackRadio.text = qsTr("PX4 Pro ") + versionString
                        //px4FlightStackRadio2.text = qsTr("PX4 Pro ") + versionString
                    }

                    Component.onCompleted: {
                        firmwarePage.advanced = false
                        firmwarePage.showAdvanced = false
                        updatePX4VersionDisplay()
                    }

                    Connections {
                        target:     controller
                        onError:    reject()
                    }

                    onAccepted: {
                        if (_singleFirmwareMode) {
                            firmwareContent._requestFlashConfirmation(qsTr("单固件模式"), "single", "", FirmwareUpgradeController.AutoPilotStackPX4, controller.selectedFirmwareBuildType, FirmwareUpgradeController.DefaultVehicleFirmware)
                        } else {
                            var firmwareBuildType = firmwareBuildTypeCombo.model.get(firmwareBuildTypeCombo.currentIndex).firmwareType
                            var vehicleType = FirmwareUpgradeController.DefaultVehicleFirmware

                            var stack = apmFlightStack.checked ? FirmwareUpgradeController.AutoPilotStackAPM : FirmwareUpgradeController.AutoPilotStackPX4
                            if (apmFlightStack.checked) {
                                if (firmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                    vehicleType = apmVehicleTypeCombo.currentIndex
                                } else {
                                    if (controller.apmFirmwareNames.length === 0) {
                                        // Not ready yet, or no firmware available
                                        QGroundControl.showMessageDialog(firmwarePage, firmwareSelectDialog.title, qsTr("Either firmware list is still downloading, or no firmware is available for current selection."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }
                                    if (ardupilotFirmwareSelectionCombo.currentIndex == -1) {
                                        QGroundControl.showMessageDialog(firmwarePage, firmwareSelectDialog.title, qsTr("You must choose a board type."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }

                                    var firmwareUrl = controller.apmFirmwareUrls[ardupilotFirmwareSelectionCombo.currentIndex]
                                    if (firmwareUrl == "") {
                                        QGroundControl.showMessageDialog(firmwarePage, firmwareSelectDialog.title, qsTr("No firmware was found for the current selection."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }
                                    firmwareContent._requestFlashConfirmation(qsTr("ArduPilot 固件：%1").arg(controller.apmFirmwareNames[ardupilotFirmwareSelectionCombo.currentIndex]), "url", firmwareUrl)
                                    return
                                }
                            }
                            //-- If custom, get file path
                            if (firmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                customFirmwareDialog.openForLoad()
                            } else {
                                var stackName = stack === FirmwareUpgradeController.AutoPilotStackAPM ? qsTr("ArduPilot") : qsTr("PX4")
                                var buildName = firmwareBuildTypeCombo.model.get(firmwareBuildTypeCombo.currentIndex).text
                                firmwareContent._requestFlashConfirmation(qsTr("%1 / %2").arg(stackName).arg(buildName), "firmware", "", stack, firmwareBuildType, vehicleType)
                            }
                        }
                    }

                    function reject() {
                        statusTextArea.append(highlightPrefix + qsTr("Upgrade cancelled") + highlightSuffix)
                        statusTextArea.append("------------------------------------------")
                        controller.cancel()
                        close()
                    }

                    ListModel {
                        id: firmwareBuildTypeList

                        ListElement {
                            text:           qsTr("Standard Version (stable)")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Beta Testing (beta)")
                            firmwareType:   FirmwareUpgradeController.BetaFirmware
                        }
                        ListElement {
                            text:           qsTr("Developer Build (master)")
                            firmwareType:   FirmwareUpgradeController.DeveloperFirmware
                        }
                        ListElement {
                            text:           qsTr("Custom firmware file...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ListModel {
                        id: singleFirmwareModeTypeList

                        ListElement {
                            text:           qsTr("Standard Version")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Custom firmware file...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ColumnLayout {
                        width:      Math.max(ScreenTools.defaultFontPixelWidth * 40, firmwareRadiosColumn.width)
                        spacing:    globals.defaultTextHeight / 2

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               (_singleFirmwareMode || !QGroundControl.apmFirmwareSupported) ? _singleFirmwareLabel : _pixhawkLabel

                            readonly property string _pixhawkLabel:          qsTr("Detected Pixhawk board. You can select from the following flight stacks:")
                            readonly property string _singleFirmwareLabel:   qsTr("Press Ok to upgrade your vehicle.")
                        }

                        Column {
                            id:         firmwareRadiosColumn
                            spacing:    0

                            visible: !_singleFirmwareMode && QGroundControl.apmFirmwareSupported

                            Component.onCompleted: {
                                if(!QGroundControl.apmFirmwareSupported) {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypePX4
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }

                            QGCRadioButton {
                                id:             px4FlightStackRadio
                                text:           qsTr("PX4 Pro ")
                                font.bold:      _defaultFirmwareIsPX4
                                checked:        _defaultFirmwareIsPX4

                                onClicked: {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypePX4
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }

                            QGCRadioButton {
                                id:             apmFlightStack
                                text:           qsTr("ArduPilot")
                                font.bold:      !_defaultFirmwareIsPX4
                                checked:        !_defaultFirmwareIsPX4

                                onClicked: {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypeAPM
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }
                        }

                        FactComboBox {
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked
                            fact:               _firmwareUpgradeSettings.apmChibiOS
                            indexModel:         false
                        }

                        FactComboBox {
                            id:                 apmVehicleTypeCombo
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked
                            fact:               _firmwareUpgradeSettings.apmVehicleType
                            indexModel:         false
                        }

                        QGCComboBox {
                            id:                 ardupilotFirmwareSelectionCombo
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked && !controller.downloadingFirmwareList && controller.apmFirmwareNames.length !== 0
                            model:              controller.apmFirmwareNames
                            onModelChanged:     currentIndex = controller.apmFirmwareNamesBestIndex
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("Downloading list of available firmwares...")
                            visible:            controller.downloadingFirmwareList
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("No Firmware Available")
                            visible:            !controller.downloadingFirmwareList && (QGroundControl.apmFirmwareSupported && controller.apmFirmwareNames.length === 0)
                        }

                        QGCCheckBox {
                            id:         _advanced
                            text:       qsTr("Advanced settings")
                            checked:    false

                            onClicked: {
                                firmwareBuildTypeCombo.currentIndex = 0
                                firmwareWarningMessageVisible = false
                                updatePX4VersionDisplay()
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            visible:            showFirmwareTypeSelection
                            text:               _singleFirmwareMode ?  qsTr("Select the standard version or one from the file system (previously downloaded):") :
                                                                      qsTr("Select which version of the above flight stack you would like to install:")
                        }

                        QGCComboBox {
                            id:                 firmwareBuildTypeCombo
                            Layout.fillWidth:   true
                            visible:            showFirmwareTypeSelection
                            textRole:           "text"
                            model:              _singleFirmwareMode ? singleFirmwareModeTypeList : firmwareBuildTypeList

                            onActivated: (index) => {
                                controller.selectedFirmwareBuildType = model.get(index).firmwareType
                                if (model.get(index).firmwareType === FirmwareUpgradeController.BetaFirmware) {
                                    firmwareWarningMessageVisible = true
                                    firmwareVersionWarningLabel.text = qsTr("WARNING: BETA FIRMWARE. ") +
                                            qsTr("This firmware version is ONLY intended for beta testers. ") +
                                            qsTr("Although it has received FLIGHT TESTING, it represents actively changed code. ") +
                                            qsTr("Do NOT use for normal operation.")
                                } else if (model.get(index).firmwareType === FirmwareUpgradeController.DeveloperFirmware) {
                                    firmwareWarningMessageVisible = true
                                    firmwareVersionWarningLabel.text = qsTr("WARNING: CONTINUOUS BUILD FIRMWARE. ") +
                                            qsTr("This firmware has NOT BEEN FLIGHT TESTED. ") +
                                            qsTr("It is only intended for DEVELOPERS. ") +
                                            qsTr("Run bench tests without props first. ") +
                                            qsTr("Do NOT fly this without additional safety precautions. ") +
                                            qsTr("Follow the forums actively when using it.")
                                } else {
                                    firmwareWarningMessageVisible = false
                                }
                                updatePX4VersionDisplay()
                            }
                        }

                        QGCLabel {
                            id:                 firmwareVersionWarningLabel
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            visible:            firmwareWarningMessageVisible
                        }
                    } // ColumnLayout
                } // QGCPopupDialog
            } // Component - firmwareSelectDialogComponent

            QGCFlickable {
                id:             contentFlickable
                anchors.fill:   parent
                contentWidth:   Math.max(width, panelFrame.width + (firmwareContent._outerMargin * 2))
                contentHeight:  panelFrame.height + (firmwareContent._outerMargin * 2)
                clip:           true

                Rectangle {
                    id: panelFrame
                    x: Math.max(firmwareContent._outerMargin, (contentFlickable.width - width) / 2)
                    y: firmwareContent._outerMargin
                    width: firmwareContent._panelWidth
                    height: contentColumn.implicitHeight + (firmwareContent._panelPadding * 2)
                    radius: popupStyle.cornerRadius
                    border.color: popupStyle.borderColor
                    border.width: 1
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: popupStyle.popupBackground }
                        GradientStop { position: 1.0; color: "#222222" }
                    }
                }

                ColumnLayout {
                    id: contentColumn
                    anchors.top: panelFrame.top
                    anchors.topMargin: firmwareContent._panelPadding
                    anchors.horizontalCenter: panelFrame.horizontalCenter
                    width: panelFrame.width - (firmwareContent._panelPadding * 2)
                    spacing: firmwareContent._sectionSpacing

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: headerColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                    radius: popupStyle.cornerRadius
                    color: popupStyle.panelBackground
                    border.color: popupStyle.borderColor
                    border.width: 1

                    ColumnLayout {
                        id: headerColumn
                        anchors.fill: parent
                        anchors.margins: firmwareContent._cardInnerMargin
                        spacing: ScreenTools.defaultFontPixelHeight * 0.3

                        QGCLabel {
                            Layout.fillWidth: true
                            text: firmwareContent.title
                            font.pointSize: firmwareContent._sectionTitlePointSize
                            font.bold: true
                            color: popupStyle.primaryTextColor
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: firmwareContent._singleFirmwareMode ? firmwareContent.welcomeTextSingle : firmwareContent.welcomeText
                            font.pointSize: firmwareContent._bodyPointSize
                            color: popupStyle.secondaryTextColor
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: versionCardColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                    radius: popupStyle.cornerRadius
                    color: popupStyle.panelBackground
                    border.color: popupStyle.borderColor
                    border.width: 1

                    ColumnLayout {
                        id: versionCardColumn
                        anchors.fill: parent
                        anchors.margins: firmwareContent._cardInnerMargin
                        spacing: firmwareContent._infoSpacing

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Installed Versions")
                            font.pointSize: firmwareContent._sectionTitlePointSize
                            font.bold: true
                            color: popupStyle.primaryTextColor
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: firmwareContent._versionGridColumns
                            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                            columnSpacing: ScreenTools.defaultFontPixelWidth * 0.6

                            Repeater {
                                model: firmwareContent._versionItems

                                Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: firmwareContent._versionTileHeight
                                    radius: popupStyle.cornerRadius
                                    color: popupStyle.inputBackground
                                    border.color: popupStyle.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: versionItemColumn
                                        anchors.fill: parent
                                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.35
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.15

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            font.pointSize: firmwareContent._smallPointSize
                                            color: popupStyle.secondaryTextColor
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                            text: modelData.value
                                            font.pointSize: firmwareContent._bodyPointSize
                                            color: popupStyle.primaryTextColor
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: firmwareContent._sectionSpacing

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredHeight: firmwareContent._pairedCardHeight
                        radius: popupStyle.cornerRadius
                        color: popupStyle.panelBackground
                        border.color: popupStyle.borderColor
                        border.width: 1

                        ColumnLayout {
                            id: recommendationColumn
                            anchors.fill: parent
                            anchors.margins: firmwareContent._cardInnerMargin
                            spacing: firmwareContent._infoSpacing

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("Upgrade Recommendations")
                                font.pointSize: firmwareContent._sectionTitlePointSize
                                font.bold: true
                                color: popupStyle.primaryTextColor
                            }

                            Repeater {
                                model: firmwareContent._recommendationItems

                                RowLayout {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.35

                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.35
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: Layout.preferredWidth / 2
                                        color: popupStyle.accentColor
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        text: modelData
                                        font.pointSize: firmwareContent._bodyPointSize
                                        color: popupStyle.secondaryTextColor
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredHeight: firmwareContent._pairedCardHeight
                        radius: popupStyle.cornerRadius
                        color: popupStyle.panelBackground
                        border.color: popupStyle.borderColor
                        border.width: 1

                        ColumnLayout {
                            id: checksColumn
                            anchors.fill: parent
                            anchors.margins: firmwareContent._cardInnerMargin
                            spacing: firmwareContent._infoSpacing

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("Pre-upgrade Checks")
                                font.pointSize: firmwareContent._sectionTitlePointSize
                                font.bold: true
                                color: popupStyle.primaryTextColor
                            }

                            Repeater {
                                model: firmwareContent._preUpgradeChecks

                                RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.35

                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.5
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: Layout.preferredWidth / 2
                                        color: firmwareContent._checkStateColor(modelData.state)
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.15

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            text: modelData.title
                                            font.pointSize: firmwareContent._bodyPointSize
                                            font.bold: true
                                            color: popupStyle.primaryTextColor
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            text: modelData.detail
                                            color: popupStyle.secondaryTextColor
                                            font.pointSize: firmwareContent._smallPointSize
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: actionColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                    radius: popupStyle.cornerRadius
                    color: popupStyle.panelBackground
                    border.color: popupStyle.borderColor
                    border.width: 1

                    ColumnLayout {
                        id: actionColumn
                        anchors.fill: parent
                        anchors.margins: firmwareContent._cardInnerMargin
                        spacing: ScreenTools.defaultFontPixelHeight * 0.55

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelHeight * 0.2

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: qsTr("Upgrade Status")
                                    font.pointSize: firmwareContent._sectionTitlePointSize
                                    font.bold: true
                                    color: popupStyle.primaryTextColor
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: qsTr("Connect the target device through USB. Upgrade progress and board detection messages will appear below.")
                                    font.pointSize: firmwareContent._bodyPointSize
                                    color: popupStyle.secondaryTextColor
                                }
                            }

                            QGCButton {
                                id:                 flashBootloaderButton
                                Layout.alignment:   Qt.AlignTop
                                text:               qsTr("Flash ChibiOS Bootloader")
                                visible:            firmwarePage.advanced
                                onClicked:          globals.activeVehicle.flashBootloader()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth:       true
                            Layout.preferredHeight: noticeLabel.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.8)
                            visible:                firmwareContent._upgradeNoticeVisible
                            radius:                 popupStyle.cornerRadius
                            color:                  Qt.rgba(firmwareContent._upgradeNoticeColor().r,
                                                            firmwareContent._upgradeNoticeColor().g,
                                                            firmwareContent._upgradeNoticeColor().b,
                                                            0.16)
                            border.color:           firmwareContent._upgradeNoticeColor()
                            border.width:           1

                            QGCLabel {
                                id:                 noticeLabel
                                anchors.fill:       parent
                                anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.4
                                wrapMode:           Text.WordWrap
                                text:               firmwareContent._upgradeNoticeText
                                color:              popupStyle.primaryTextColor
                                font.pointSize:     firmwareContent._bodyPointSize
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth:   true
                            visible:            !flashBootloaderButton.visible
                            spacing:            ScreenTools.defaultFontPixelHeight * 0.25

                            RowLayout {
                                Layout.fillWidth:   true
                                spacing:            ScreenTools.defaultFontPixelWidth

                                QGCLabel {
                                    Layout.fillWidth:   true
                                    text:               firmwareContent._flashInProgress
                                                            ? (progressBar.value > 0 ? qsTr("正在刷写") : qsTr("准备刷写"))
                                                            : (progressBar.value >= 1 ? qsTr("刷写完成") : qsTr("等待刷写"))
                                    font.bold:          true
                                    color:              popupStyle.primaryTextColor
                                }

                                QGCLabel {
                                    text:           qsTr("%1%").arg(Math.round(progressBar.value * 100))
                                    font.bold:      true
                                    color:          popupStyle.primaryTextColor
                                }
                            }

                            ProgressBar {
                                id:                     progressBar
                                Layout.fillWidth:       true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.55
                                from:                   0
                                to:                     1

                                background: Rectangle {
                                    implicitHeight: ScreenTools.defaultFontPixelHeight * 1.55
                                    radius: popupStyle.cornerRadius
                                    color: Qt.rgba(popupStyle.primaryButtonColor.r,
                                                   popupStyle.primaryButtonColor.g,
                                                   popupStyle.primaryButtonColor.b,
                                                   0.14)
                                    border.color: firmwareContent._flashInProgress || progressBar.value > 0
                                                    ? popupStyle.primaryButtonColor
                                                    : popupStyle.borderColor
                                    border.width: 1
                                }

                                contentItem: Item {
                                    Rectangle {
                                        width: Math.max(progressBar.visualPosition * parent.width,
                                                        progressBar.value > 0 ? ScreenTools.defaultFontPixelWidth * 2 : 0)
                                        height: parent.height
                                        radius: popupStyle.cornerRadius
                                        color: progressBar.indeterminate
                                                   ? popupStyle.hoverColor(popupStyle.primaryButtonColor)
                                                   : popupStyle.primaryButtonColor

                                        Behavior on width { NumberAnimation { duration: popupStyle.stateAnimationDuration } }
                                        Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
                                    }

                                    QGCLabel {
                                        anchors.centerIn: parent
                                        text: qsTr("%1%").arg(Math.round(progressBar.value * 100))
                                        font.bold: true
                                        color: popupStyle.primaryTextColor
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: logColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                    radius: popupStyle.cornerRadius
                    color: popupStyle.panelBackground
                    border.color: popupStyle.borderColor
                    border.width: 1

                    ColumnLayout {
                        id: logColumn
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Status Log")
                            font.pointSize: ScreenTools.mediumFontPointSize
                            font.bold: true
                            color: popupStyle.primaryTextColor
                        }

                        TextArea {
                            id:                     statusTextArea
                            Layout.fillWidth:       true
                            Layout.preferredHeight: firmwareContent._logHeight
                            readOnly:               true
                            selectByMouse:          true
                            wrapMode:               TextEdit.Wrap
                            font.pointSize:         ScreenTools.defaultFontPointSize
                            font.family:            ScreenTools.normalFontFamily
                            textFormat:             TextEdit.RichText
                            text:                   firmwareContent._singleFirmwareMode ? firmwareContent.welcomeTextSingle : firmwareContent.welcomeText
                            color:                  popupStyle.primaryTextColor
                            selectionColor:         popupStyle.accentColor
                            selectedTextColor:      popupStyle.primaryTextColor
                            leftPadding:            ScreenTools.defaultFontPixelHeight * 0.45
                            rightPadding:           leftPadding
                            topPadding:             leftPadding
                            bottomPadding:          leftPadding

                            background: Rectangle {
                                color: popupStyle.inputBackground
                                radius: popupStyle.cornerRadius
                                border.color: statusTextArea.activeFocus ? popupStyle.accentColor : popupStyle.borderColor
                                border.width: 1

                                Behavior on border.color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
                            }
                        }
                    }
                }
                }
            }

        } // Item
    } // Component
} // SetupPage
