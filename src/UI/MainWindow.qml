import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.AnalyzeView
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.PlanView
import QGroundControl.Toolbar

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:         mainWindow
    visible:    true
    // The special casing for android prevents white bars from showing up on the edges of the screen with newer android versions
    flags:      Qt.Window | (ScreenTools.isAndroid ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)

    Component.onCompleted: {
        // Start the sequence of first run prompt(s)
        firstRunPromptManager.nextPrompt()
    }

    /// Saves main window position and size and re-opens it in the same position and size next time
    MainWindowSavedState {
        window: mainWindow
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real      _leftPanelWidth:            ScreenTools.defaultFontPixelWidth * 32
    readonly property real      _panelMargin:               ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real      _panelRadius:               ScreenTools.defaultFontPixelHeight * 0.5
    readonly property int       _planTabIndex:              0
    readonly property int       _flyTabIndex:               1
    readonly property int       _summaryTabIndex:           2
    readonly property int       _configureTabIndex:         3
    readonly property int       _analyzeTabIndex:           4
    readonly property int       _mavlinkConsoleTabIndex:    5
    readonly property bool      _analyzeEnabled:            false
    property bool               _showStartPage:             true
    property bool               _startPageEntryGranted:     false
    property bool               _offlineWorkspaceMode:      false
    property bool               _configureReadOnlyMode:     false
    property int                _lastVisitedWorkspaceTab:   _planTabIndex
    property bool               _hadConnectedVehicleSession:false
    property bool               _vehicleDisconnectNoticeShown:false
    property string             _pendingDisconnectedVehicleId:""

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    mainWindow._flyPageItem() ? mainWindow._flyPageItem().planController : null
        readonly property var       guidedControllerFlyView:        mainWindow._flyPageItem() ? mainWindow._flyPageItem().guidedController : null

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int                validationErrorCount:           0

        // Set to a non-empty string to block navigation with a custom reason (e.g. during calibration)
        property string             navigationBlockedReason:        ""

        // Property to manage RemoteID quick access to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Timer {
        id: vehicleDisconnectNoticeTimer
        interval: 900
        repeat: false

        onTriggered: mainWindow._showVehicleDisconnectedIfStillOffline()
    }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0, showErrorOnDisallow = true) {
        // Check for explicit navigation block (e.g. calibration in progress)
        if (globals.navigationBlockedReason !== "") {
            if (showErrorOnDisallow) {
                validationErrorToast.text = globals.navigationBlockedReason
                if (validationErrorToast.visible) {
                    validationErrorToast.close()
                }
                validationErrorToast.open()
            }
            return false
        }
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        var allowed = globals.validationErrorCount <= previousValidationErrorCount
        if (!allowed && showErrorOnDisallow) {
            validationErrorToast.text = qsTr("Please correct the invalid value before continuing")
            if (validationErrorToast.visible) {
                validationErrorToast.close()
            }
            validationErrorToast.open()
        }
        return allowed
    }

    function showPlanView() {
        _ensureMainInterfaceAccess(_planTabIndex)
    }

    function showFlyView() {
        _ensureMainInterfaceAccess(_flyTabIndex)
    }

    function showTool(toolTitle, toolSource, toolIcon, compactHeader = false) {
        toolDrawer.backIcon     = !mainViewTabBar ? "/qmlimages/Plan.svg"
            : ((mainWindow._analyzeEnabled && mainViewTabBar.currentIndex === _analyzeTabIndex) ? "/qmlimages/Analyze.svg"
                : (mainViewTabBar.currentIndex === _mavlinkConsoleTabIndex ? "/qmlimages/MAVLinkConsoleIcon.svg"
                    : (mainViewTabBar.currentIndex === _flyTabIndex ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg")))
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        toolDrawer.toolIcon     = toolIcon
        toolDrawer.compactHeader = compactHeader
        toolDrawer.visible      = true
    }

    function showAnalyzeTool() {
        if (!mainWindow._analyzeEnabled) {
            showFlyView()
            return
        }
        _ensureMainInterfaceAccess(_analyzeTabIndex)
    }

    function showMAVLinkConsoleView() {
        _ensureMainInterfaceAccess(_mavlinkConsoleTabIndex)
    }

    function _vehicleConfigViewItem() {
        if (configureViewContent && configureViewContent.item) {
            return configureViewContent.item
        }
        if (toolDrawerLoader.item && toolDrawer.toolSource === "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml") {
            return toolDrawerLoader.item
        }
        return null
    }

    function showVehicleConfig() {
        if (!_ensureMainInterfaceAccess(_configureTabIndex, true)) {
            return false
        }

        const configItem = _vehicleConfigViewItem()
        if (configItem && typeof configItem.showMenuPanel === "function") {
            configItem.showMenuPanel()
        }

        return true
    }

    function _openVehicleConfigWorkspace() {
        return _ensureMainInterfaceAccess(_configureTabIndex, true)
    }

    function _findVehicleConfigComponentByKeywords(keywords) {
        const vehicle = QGroundControl.multiVehicleManager.activeVehicle
        const autopilotPlugin = vehicle ? vehicle.autopilotPlugin : null
        if (!autopilotPlugin || !keywords || keywords.length === 0) {
            return null
        }

        const components = autopilotPlugin.vehicleComponents
        for (let i = 0; i < components.length; i++) {
            const component = components[i]
            if (!component) {
                continue
            }

            const name = component.name ? ("" + component.name).toLowerCase() : ""
            const setupSource = component.setupSource ? component.setupSource.toString().toLowerCase() : ""
            for (let j = 0; j < keywords.length; j++) {
                const keyword = ("" + keywords[j]).toLowerCase().trim()
                if (keyword !== "" && (name.indexOf(keyword) !== -1 || setupSource.indexOf(keyword) !== -1)) {
                    return component
                }
            }
        }

        return null
    }

    function showVehicleConfigTuningPage() {
        if (!_openVehicleConfigWorkspace()) {
            return
        }
        const tuningComponent = _findVehicleConfigComponentByKeywords(["tuning", "pid"])
        const configItem = _vehicleConfigViewItem()
        if (tuningComponent && configItem && typeof configItem.showVehicleComponentPanel === "function") {
            configItem.showVehicleComponentPanel(tuningComponent)
        }
    }

    function showVehicleConfigSensorsPage() {
        if (!_openVehicleConfigWorkspace()) {
            return
        }
        const sensorComponent = _findVehicleConfigComponentByKeywords(["sensor", "calibration"])
        const configItem = _vehicleConfigViewItem()
        if (sensorComponent && configItem && typeof configItem.showVehicleComponentPanel === "function") {
            configItem.showVehicleComponentPanel(sensorComponent)
        }
    }

    function showVehicleConfigFirmwarePage() {
        if (!_openVehicleConfigWorkspace()) {
            return
        }
        const configItem = _vehicleConfigViewItem()
        if (configItem && typeof configItem.showPanel === "function") {
            configItem.showPanel("firmware", "qrc:/qml/QGroundControl/VehicleSetup/FirmwareUpgrade.qml")
        }
    }

    function showVehicleConfigParametersPage() {
        if (!_openVehicleConfigWorkspace()) {
            return
        }
        const configItem = _vehicleConfigViewItem()
        if (configItem && typeof configItem.showParametersPanel === "function") {
            configItem.showParametersPanel()
        }
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        if (!_openVehicleConfigWorkspace()) {
            return
        }
        let vehicleComponent = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(knownVehicleComponent)
        const configItem = _vehicleConfigViewItem()
        if (vehicleComponent && configItem && typeof configItem.showVehicleComponentPanel === "function") {
            configItem.showVehicleComponentPanel(vehicleComponent)
        }
    }

    function showVehicleConfigComponentPanel(vehicleComponent) {
        if (!_openVehicleConfigWorkspace()) {
            return
        }
        const configItem = _vehicleConfigViewItem()
        if (vehicleComponent && configItem && typeof configItem.showVehicleComponentPanel === "function") {
            configItem.showVehicleComponentPanel(vehicleComponent)
        }
    }

    function showSwarmView() {
        if (!_ensureMainInterfaceAccess(_flyTabIndex, true)) {
            return
        }

        const flyPage = _flyPageItem()
        if (flyPage && typeof flyPage._openClusterWorkspaceWindow === "function") {
            flyPage._openClusterWorkspaceWindow()
            return
        }

        console.warn("Swarm workspace is unavailable because the Fly page instance is not ready.")
        if (mainWindow.showMessageDialog) {
            mainWindow.showMessageDialog(qsTr("Swarm"), qsTr("The swarm workspace is not ready yet. Open Fly view and try again."))
        }
    }

    function showClusterView() {
        showSwarmView()
    }

    function showSettingsTool(settingsPage = "") {
        showTool(qsTr("Application Settings"), "qrc:/qml/QGroundControl/Controls/AppSettings.qml", "/InstrumentValueIcons/menu.svg", true)
        if (settingsPage !== "") {
            toolDrawerLoader.item.showSettingsPage(settingsPage)
        }
    }

    function _setCurrentTab(index) {
        if (mainViewTabBar) {
            if (!mainWindow._analyzeEnabled && index === _analyzeTabIndex) {
                index = _flyTabIndex
            }
            mainViewTabBar.currentIndex = index
            _lastVisitedWorkspaceTab = index
        }
    }

    function _canAccessTabOffline(tabIndex) {
        return tabIndex === _planTabIndex
            || tabIndex === _summaryTabIndex
            || tabIndex === _configureTabIndex
    }

    function _canAccessTabInCurrentState(tabIndex) {
        return _hasAnyConnectedVehicle() || _canAccessTabOffline(tabIndex)
    }

    function _returnToStartPage() {
        _startPageEntryGranted = false
        _offlineWorkspaceMode = false
        _configureReadOnlyMode = false
        _showStartPage = true
        toolDrawer.visible = false
        _updateEmbeddedPageState()
    }

    function _clearVehicleDisconnectNotice() {
        _pendingDisconnectedVehicleId = ""
        vehicleDisconnectNoticeTimer.stop()
        _vehicleDisconnectNoticeShown = false
    }

    function _handleVehicleDisconnected(vehicleId) {
        if (_showStartPage) {
            return
        }

        if (_vehicleDisconnectNoticeShown || (!_hadConnectedVehicleSession && _hasAnyConnectedVehicle())) {
            return
        }

        _pendingDisconnectedVehicleId = vehicleId !== undefined && vehicleId !== null ? ("" + vehicleId) : ""
        vehicleDisconnectNoticeTimer.restart()
    }

    function _showVehicleDisconnectedIfStillOffline() {
        if (_vehicleDisconnectNoticeShown || _hasAnyConnectedVehicle()) {
            _pendingDisconnectedVehicleId = ""
            return
        }

        _vehicleDisconnectNoticeShown = true
        _returnToStartPage()

        const vehicleIdText = _pendingDisconnectedVehicleId
        _pendingDisconnectedVehicleId = ""
        const message = vehicleIdText === ""
            ? qsTr("飞行器连接已断开。")
            : qsTr("飞行器 %1 连接已断开。").arg(vehicleIdText)
        QGroundControl.showMessageDialog(mainWindow, qsTr("连接断开"), message)
    }

    function _updateEmbeddedPageState() {
        if (summaryViewContent && summaryViewContent.item) {
            if (typeof summaryViewContent.item.useOfflineVehicleFallback !== "undefined") {
                summaryViewContent.item.useOfflineVehicleFallback = _offlineWorkspaceMode
            }
        }

        if (configureViewContent && configureViewContent.item) {
            if (typeof configureViewContent.item.useOfflineVehicleFallback !== "undefined") {
                configureViewContent.item.useOfflineVehicleFallback = _offlineWorkspaceMode
            }
            if (typeof configureViewContent.item.readOnlyMode !== "undefined") {
                configureViewContent.item.readOnlyMode = _configureReadOnlyMode
            }
        }
    }

    function _connectedVehicleCount() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles
        let connectedCount = 0

        if (!vehicles) {
            return 0
        }

        for (let i = 0; i < vehicles.count; i++) {
            const vehicle = vehicles.get(i)
            const vehicleLinkManager = vehicle ? vehicle.vehicleLinkManager : null
            if (vehicleLinkManager && !vehicleLinkManager.communicationLost) {
                connectedCount++
            }
        }

        return connectedCount
    }

    function _trackedVehicleCount() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles
        return vehicles ? vehicles.count : 0
    }

    function _hasAnyConnectedVehicle() {
        return _connectedVehicleCount() > 0
    }

    function _hasAnyTrackedVehicle() {
        return _trackedVehicleCount() > 0
    }

    function _syncStartPageVisibility() {
        const hasConnectedVehicle = _hasAnyTrackedVehicle()

        if (!hasConnectedVehicle) {
            if (_offlineWorkspaceMode) {
                _showStartPage = false
                toolDrawer.visible = false
                _updateEmbeddedPageState()
                return false
            }
            _startPageEntryGranted = false
            _configureReadOnlyMode = false
            if (_hadConnectedVehicleSession) {
                _showStartPage = true
            }
            toolDrawer.visible = false
            _updateEmbeddedPageState()
            return false
        }

        _hadConnectedVehicleSession = true
        _offlineWorkspaceMode = false
        _showStartPage = !_startPageEntryGranted
        if (_showStartPage) {
            toolDrawer.visible = false
        }
        _updateEmbeddedPageState()

        return true
    }

    function _ensureMainInterfaceAccess(tabIndex, grantEntry = false) {
        if (!_hasAnyTrackedVehicle()) {
            if (_canAccessTabOffline(tabIndex)) {
                _offlineWorkspaceMode = true
                _configureReadOnlyMode = tabIndex === _configureTabIndex
                _startPageEntryGranted = true
                _showStartPage = false
                _setCurrentTab(tabIndex)
                toolDrawer.visible = false
                _updateEmbeddedPageState()
                return true
            }

            _syncStartPageVisibility()
            return false
        }

        _offlineWorkspaceMode = false
        _configureReadOnlyMode = false

        if (grantEntry) {
            _startPageEntryGranted = true
        }

        if (!_startPageEntryGranted) {
            _showStartPage = true
            toolDrawer.visible = false
            return false
        }

        _showStartPage = false
        _setCurrentTab(tabIndex)
        toolDrawer.visible = false
        _updateEmbeddedPageState()
        return true
    }

    function _planViewItem() {
        return planViewContent
    }

    function _flyPageItem() {
        return flyPageContent
    }

    function _activeBatteryForVehicle(vehicle) {
        return (vehicle && (vehicle.batteries.count > 0)) ? vehicle.batteries.get(0) : null
    }

    function _hasFactValue(fact) {
        return fact && !isNaN(Number(fact.rawValue))
    }

    function _formatFactValue(fact, includeUnits = true, unavailableText = "--") {
        if (!_hasFactValue(fact)) {
            return unavailableText
        }

        const units = includeUnits && (fact.units !== "") ? (" " + fact.units) : ""
        return fact.valueString + units
    }

    function _formatElapsedTime(fact) {
        if (!_hasFactValue(fact)) {
            return "--"
        }

        const totalSeconds = Math.max(0, Math.round(Number(fact.rawValue)))
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60

        function pad(value) {
            return value < 10 ? ("0" + value) : ("" + value)
        }

        return hours > 0 ? (hours + ":" + pad(minutes) + ":" + pad(seconds)) : (minutes + ":" + pad(seconds))
    }

    function _flightModeDisplayName(flightMode) {
        const rawMode = flightMode === undefined || flightMode === null ? "" : ("" + flightMode)
        const mode = rawMode.trim()
        const normalizedMode = mode.toLowerCase()

        if (normalizedMode.indexOf("precision lan") === 0 || normalizedMode === "precland") {
            return qsTr("精准降落")
        }
        if (normalizedMode.indexOf("safe recovery") === 0) {
            return qsTr("安全恢复")
        }
        if (normalizedMode.indexOf("position slow") === 0) {
            return qsTr("慢速位置")
        }
        if (normalizedMode.indexOf("follow target") === 0) {
            return qsTr("跟随目标")
        }
        if (normalizedMode.indexOf("vtol takeoff") === 0) {
            return qsTr("VTOL 起飞")
        }
        if (normalizedMode.indexOf("manual") >= 0) {
            return qsTr("手动")
        }
        if (normalizedMode.indexOf("stabilized") >= 0) {
            return qsTr("自稳")
        }
        if (normalizedMode.indexOf("acro") >= 0) {
            return qsTr("特技")
        }
        if (normalizedMode.indexOf("rattitude") >= 0) {
            return qsTr("半自稳")
        }
        if (normalizedMode.indexOf("offboard") >= 0) {
            return qsTr("板外控制")
        }
        if (normalizedMode.indexOf("position") >= 0) {
            return qsTr("定点")
        }
        if (normalizedMode.indexOf("return") >= 0 || normalizedMode.indexOf("rtl") >= 0) {
            return qsTr("返航")
        }

        switch (mode) {
        case "":                return qsTr("自动")
        case "Hold":            return qsTr("保持")
        case "Mission":         return qsTr("任务")
        case "Return":
        case "RTL":             return qsTr("返航")
        case "Land":            return qsTr("降落")
        case "Takeoff":         return qsTr("起飞")
        case "Manual":          return qsTr("手动")
        case "Position":
        case "Position Hold":   return qsTr("定点")
        case "Altitude":
        case "Altitude Hold":   return qsTr("定高")
        case "Stabilized":      return qsTr("自稳")
        case "Acro":            return qsTr("特技")
        case "Rattitude":       return qsTr("半自稳")
        case "Offboard":        return qsTr("板外控制")
        case "Orbit":           return qsTr("环绕")
        case "Descend":         return qsTr("下降")
        case "Unknown":         return qsTr("未知")
        default:                return mode
        }
    }

    function _requestMapFlightModeChange(vehicle, flightMode) {
        if (!vehicle || !vehicle.flightModeSetAvailable) {
            return
        }

        const targetMode = flightMode === undefined || flightMode === null ? "" : ("" + flightMode)
        const currentMode = vehicle.flightMode === undefined || vehicle.flightMode === null ? "" : ("" + vehicle.flightMode)
        if (targetMode === "" || targetMode === currentMode) {
            return
        }

        QGroundControl.showMessageDialog(
            mainWindow,
            qsTr("切换飞行模式"),
            qsTr("将飞行模式切换为 %1？").arg(_flightModeDisplayName(targetMode)),
            Dialog.Yes | Dialog.Cancel,
            function() {
                if (vehicle) {
                    vehicle.flightMode = targetMode
                }
            })
    }

    function _formatSignedValue(value, precision = 0, suffix = "") {
        if (isNaN(Number(value))) {
            return "--"
        }

        const numericValue = Number(value)
        const prefix = numericValue > 0 ? "+" : ""
        return prefix + numericValue.toFixed(precision) + suffix
    }

    function _clamp(value, minimumValue, maximumValue) {
        return Math.max(minimumValue, Math.min(value, maximumValue))
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function _showMessageDialogWorker(owner, dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null) {
        let dialog = simpleMessageDialogComponent.createObject(owner, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction, closeFunction: closeFunction })
        dialog.open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle, dialogText)
    }

    Connections {
        target: QGroundControl

        function onShowMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction) {
            _showMessageDialogWorker(owner, title, text, buttons, acceptFunction, closeFunction)
        }
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    property bool _forceClose: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property int _skipPendingParameterWritesCheckMask: 0x02
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    property int _closeChecksToSkip: 0
    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false
        }
        finishCloseProcess()
        return true
    }

    property string closeDialogTitle: qsTr("关闭 %1").arg(QGroundControl.appName)

    function checkForUnsavedMission() {
        const planViewItem = _planViewItem()
        if (planViewItem && (planViewItem._planMasterController.dirtyForSave || planViewItem._planMasterController.dirtyForUpload)) {
            QGroundControl.showMessageDialog(mainWindow, closeDialogTitle,
                              qsTr("当前有未保存或未上传的任务编辑。关闭后将丢失这些更改，确定要关闭吗？"),
                              Dialog.Yes | Dialog.No,
                              function() { _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                QGroundControl.showMessageDialog(mainWindow, closeDialogTitle,
                    qsTr("当前有尚未写入飞行器的参数更新。关闭后将丢失这些更改，确定要关闭吗？"),
                    Dialog.Yes | Dialog.No,
                    function() { _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() })
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            QGroundControl.showMessageDialog(mainWindow, closeDialogTitle,
                qsTr("当前仍有飞行器处于活动连接状态。确定要退出吗？"),
                Dialog.Yes | Dialog.No,
                function() { _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
        if (!_forceClose) {
            _closeChecksToSkip = 0
            close.accepted = performCloseChecks()
        }
    }

    background: Rectangle {
        anchors.fill:   parent
        color:          QGroundControl.globalPalette.window
    }

    Item {
        id:             integratedMainView
        anchors.fill:   parent
        readonly property real _headerHeight: ScreenTools.toolbarHeight
        readonly property color _navBarBgColor: "#1E1E1E"
        readonly property color _navTextColor: "#FFFFFF"
        readonly property color _tabSelectedBg: Qt.rgba(1, 1, 1, 0.07)
        readonly property color _tabSelectedBorder: Qt.rgba(1, 1, 1, 0.24)
        readonly property real _leftNavClusterOffset: Math.round(ScreenTools.realPixelDensity * 1.5)
        readonly property real _rightNavAvatarOffset: Math.round(ScreenTools.realPixelDensity * 1.5)

        Component {
            id: planViewPageComponent

            Item {
                anchors.fill: parent

                PlanView {
                    anchors.fill: parent
                    embeddedView: true
                }
            }
        }

        Component {
            id: flyViewPageComponent

            Item {
                anchors.fill: parent

                FlyIntegratedPage {
                    anchors.fill: parent
                }
            }
        }

        Component {
            id: analyzeViewPageComponent

            Item {
                anchors.fill: parent

                AnalyzeView {
                    anchors.fill: parent
                }
            }
        }

        Rectangle {
            id:                     topNavigationBar
            anchors.top:            parent.top
            anchors.left:           parent.left
            anchors.right:          parent.right
            anchors.margins:        0
            height:                 mainWindow._showStartPage ? 0 : (integratedMainView._headerHeight * 0.85)
            visible:                !mainWindow._showStartPage
            color:                  integratedMainView._navBarBgColor
            radius:                 0
            border.color:           "transparent"
            border.width:           0
            readonly property real _availableWidth: Math.max(1, width - (ScreenTools.defaultFontPixelHeight * 0.4))
            readonly property bool _compactNavigation: _availableWidth < ScreenTools.defaultFontPixelWidth * 122
            readonly property real _navScale: _compactNavigation ? 0.82 : 1.0
            readonly property real _outerSpacing: ScreenTools.defaultFontPixelWidth * (_compactNavigation ? 0.35 : 0.75)
            readonly property real _utilityButtonWidth: ScreenTools.defaultFontPixelWidth * (_compactNavigation ? 6.2 : 8.0)
            readonly property real _utilityTextSize: Math.max(11, Math.min(ScreenTools.defaultFontPixelHeight * 0.82, _utilityButtonWidth * 0.25))
            readonly property real _returnButtonWidth: ScreenTools.defaultFontPixelWidth * (_compactNavigation ? 9.8 : 12.8)
            readonly property real _returnTextSize: Math.max(11, Math.min(ScreenTools.defaultFontPixelHeight * 0.84, _returnButtonWidth * 0.2))
            readonly property real _navButtonHeight: ScreenTools.defaultFontPixelHeight * (_compactNavigation ? 2.0 : 2.2)
            readonly property real _navIconSize: ScreenTools.defaultFontPixelHeight * (_compactNavigation ? 0.78 : 0.85)
            readonly property real _navTextSize: Math.max(11, Math.min(ScreenTools.defaultFontPixelHeight * 0.84, _navButtonHeight * 0.52))

            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.2
                spacing:            topNavigationBar._outerSpacing

                Item {
                    Layout.alignment:       Qt.AlignVCenter
                    Layout.preferredWidth:  leftNavCluster.implicitWidth
                    Layout.preferredHeight: leftNavCluster.implicitHeight

                    RowLayout {
                        id: leftNavCluster
                        width: implicitWidth
                        height: implicitHeight
                        x: integratedMainView._leftNavClusterOffset
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5

                        Rectangle {
                            width: ScreenTools.defaultFontPixelHeight * 1.7
                            height:     width
                            radius:     width / 2
                            color:      qgcPal.colorBlue
                            border.color: "transparent"
                            border.width: 0

                            QGCLabel {
                                anchors.centerIn:   parent
                                text:               "A"
                                color:              qgcPal.buttonHighlightText
                                font.weight:        Font.DemiBold
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth:  topNavigationBar._utilityButtonWidth
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
                            radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                            color:                  "transparent"

                            QGCLabel {
                                anchors.centerIn:   parent
                                width:              parent.width - (ScreenTools.defaultFontPixelWidth * 0.5)
                                text:               qsTr("设置")
                                color:              integratedMainView._navTextColor
                                opacity:            0.78
                                font.pixelSize:     topNavigationBar._utilityTextSize
                                horizontalAlignment: Text.AlignHCenter
                                elide:              Text.ElideRight
                            }

                            QGCMouseArea {
                                anchors.fill: parent
                                onClicked: mainWindow.showSettingsTool()
                            }
                        }
                    }
                }

                Item {
                    Layout.alignment:       Qt.AlignHCenter
                    Layout.fillWidth:       true
                    Layout.minimumWidth:    ScreenTools.defaultFontPixelWidth * 22
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 102
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    readonly property int _tabCount: mainWindow._analyzeEnabled ? 6 : 5
                    readonly property real _tabSpacing: ScreenTools.defaultFontPixelWidth * (topNavigationBar._compactNavigation ? 0.32 : 0.95)
                    readonly property real _availableTabWidth: Math.max(1, width - ((_tabCount - 1) * _tabSpacing))
                    readonly property real _tabWidth: Math.max(ScreenTools.defaultFontPixelWidth * 10.5, Math.min(ScreenTools.defaultFontPixelWidth * 24, _availableTabWidth / _tabCount))

                    TabBar {
                        id:             mainViewTabBar
                        visible:        false
                        currentIndex:   _flyTabIndex

                        TabButton { text: qsTr("Plan") }
                        TabButton { text: qsTr("Fly") }
                        TabButton { text: qsTr("Summary") }
                        TabButton { text: qsTr("Configure") }
                        TabButton { text: qsTr("Analyze"); visible: mainWindow._analyzeEnabled }
                        TabButton { text: qsTr("Console") }
                    }

                    Row {
                        id:                 navigationTabRow
                        anchors.centerIn:   parent
                        width:              Math.min(implicitWidth, parent.width)
                        spacing:            parent._tabSpacing

                        Repeater {
                            model: {
                                const tabs = [
                                    { label: qsTr("Plan"), icon: "/qmlimages/Plan.svg", tabIndex: _planTabIndex, offlineAvailable: true },
                                    { label: qsTr("Fly"), icon: "/qmlimages/PaperPlane.svg", tabIndex: _flyTabIndex, offlineAvailable: false },
                                    { label: qsTr("Summary"), icon: "/qmlimages/VehicleSummaryIcon.png", tabIndex: _summaryTabIndex, offlineAvailable: true },
                                    { label: qsTr("Configure"), icon: "/InstrumentValueIcons/cog.svg", tabIndex: _configureTabIndex, offlineAvailable: true }
                                ]
                                if (mainWindow._analyzeEnabled) {
                                    tabs.push({ label: qsTr("Analyze"), icon: "/qmlimages/Analyze.svg", tabIndex: _analyzeTabIndex, offlineAvailable: false })
                                }
                                tabs.push({ label: qsTr("Console"), icon: "/qmlimages/MAVLinkConsoleIcon.svg", tabIndex: _mavlinkConsoleTabIndex, offlineAvailable: false })
                                return tabs
                            }

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected: mainViewTabBar.currentIndex === modelData.tabIndex
                                readonly property bool enabledForState: mainWindow._hasAnyConnectedVehicle() || !!modelData.offlineAvailable

                                width:          navigationTabRow.parent._tabWidth
                                height:         topNavigationBar._navButtonHeight
                                radius:         ScreenTools.defaultFontPixelHeight * 0.22
                                color:          selected ? integratedMainView._tabSelectedBg : "transparent"
                                border.color:   selected ? integratedMainView._tabSelectedBorder : "transparent"
                                border.width:   selected ? 1 : 0

                                RowLayout {
                                    id:                 navigationTabContent
                                    anchors.centerIn:   parent
                                    width:              Math.min(implicitWidth, parent.width - (ScreenTools.defaultFontPixelWidth * (topNavigationBar._compactNavigation ? 0.7 : 1.5)))
                                    height:             parent.height
                                    spacing:            ScreenTools.defaultFontPixelWidth * (topNavigationBar._compactNavigation ? 0.22 : 0.35)

                                    Item {
                                        Layout.alignment:       Qt.AlignVCenter
                                        Layout.preferredWidth:  topNavigationBar._navIconSize
                                        Layout.preferredHeight: topNavigationBar._navIconSize

                                        QGCColoredImage {
                                            anchors.fill:       parent
                                            source:             modelData.icon
                                            fillMode:           Image.PreserveAspectFit
                                            color:              integratedMainView._navTextColor
                                            opacity:            !enabledForState ? 0.28 : (selected ? 1 : 0.72)
                                        }
                                    }

                                    QGCLabel {
                                        Layout.alignment:       Qt.AlignVCenter
                                        Layout.preferredWidth:  Math.min(
                                                                    implicitWidth,
                                                                    Math.max(0, navigationTabContent.width - topNavigationBar._navIconSize - navigationTabContent.spacing)
                                                                )
                                        Layout.maximumWidth:    Layout.preferredWidth
                                        text:               modelData.label
                                        color:              integratedMainView._navTextColor
                                        opacity:            !enabledForState ? 0.32 : (selected ? 1 : 0.72)
                                        font.pixelSize:     topNavigationBar._navTextSize
                                        font.weight:        selected ? Font.DemiBold : Font.Normal
                                        horizontalAlignment: Text.AlignLeft
                                        verticalAlignment:  Text.AlignVCenter
                                        elide:              Text.ElideRight
                                    }
                                }

                                QGCMouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (enabledForState && mainWindow.allowViewSwitch()) {
                                            mainWindow._ensureMainInterfaceAccess(modelData.tabIndex)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.alignment:       Qt.AlignVCenter
                    Layout.preferredWidth:  rightNavCluster.implicitWidth
                    Layout.preferredHeight: rightNavCluster.implicitHeight

                    RowLayout {
                        id: rightNavCluster
                        width: implicitWidth
                        height: implicitHeight
                        x: -integratedMainView._rightNavAvatarOffset
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5

                        Rectangle {
                            id: returnToStartButton
                            visible: !mainWindow._showStartPage
                            width: visible ? topNavigationBar._returnButtonWidth : 0
                            height: ScreenTools.defaultFontPixelHeight * 2.1
                            radius: ScreenTools.defaultFontPixelHeight * 0.3
                            color: returnToStartMouseArea.pressed
                                        ? Qt.rgba(1, 1, 1, 0.10)
                                        : (returnToStartMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelWidth * 0.35

                                QGCColoredImage {
                                    width: ScreenTools.defaultFontPixelHeight * 0.78
                                    height: width
                                    source: "/InstrumentValueIcons/home.svg"
                                    fillMode: Image.PreserveAspectFit
                                    color: integratedMainView._navTextColor
                                }

                                QGCLabel {
                                    text: qsTr("开始")
                                    color: integratedMainView._navTextColor
                                    font.pixelSize: topNavigationBar._returnTextSize
                                    font.weight: Font.DemiBold
                                }
                            }

                            QGCMouseArea {
                                id: returnToStartMouseArea
                                anchors.fill: parent
                                hoverEnabled: !ScreenTools.isMobile
                                onClicked: mainWindow._returnToStartPage()
                            }
                        }
                    }
                }
            }

        }

        Item {
            anchors.top:        mainWindow._showStartPage ? parent.top : topNavigationBar.bottom
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            anchors.margins:    0

            Rectangle {
                id:                     leftPanel
                visible:                false
                Layout.preferredWidth:  0
                Layout.minimumWidth:    0
                Layout.maximumWidth:    0
                Layout.fillHeight:      true
                color:                  qgcPal.windowShadeDark
                radius:                 _panelRadius
                border.color:           qgcPal.windowShadeLight
                border.width:           0
                clip:                   true

                ColumnLayout {
                    anchors.fill:       parent
                    anchors.margins:    _panelMargin
                    spacing:            _panelMargin

                    Rectangle {
                        id:                     vehicleSection
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 15
                        color:                  qgcPal.windowShade
                        radius:                 _panelRadius * 0.75
                        border.color:           qgcPal.windowShadeLight
                        border.width:           1

                        ColumnLayout {
                            anchors.fill:       parent
                            anchors.margins:    _panelMargin
                            spacing:            _panelMargin

                            QGCLabel {
                                text:           qsTr("已连接飞行器")
                                font.pointSize: ScreenTools.mediumFontPointSize
                                font.weight:    Font.DemiBold
                            }

                            QGCLabel {
                                Layout.fillWidth:       true
                                horizontalAlignment:    Text.AlignHCenter
                                text:                   qsTr("暂无已连接飞行器")
                                visible:                QGroundControl.multiVehicleManager.vehicles.count === 0
                                color:                  qgcPal.text
                                opacity:                0.7
                            }

                            QGCListView {
                                id:                 vehicleList
                                Layout.fillWidth:   true
                                Layout.fillHeight:  true
                                visible:            QGroundControl.multiVehicleManager.vehicles.count > 0
                                model:              QGroundControl.multiVehicleManager.vehicles
                                spacing:            ScreenTools.defaultFontPixelHeight * 0.25
                                clip:               true

                                delegate: Rectangle {
                                    width:          vehicleList.width
                                    height:         vehicleRow.implicitHeight + ScreenTools.defaultFontPixelHeight
                                    radius:         _panelRadius * 0.65
                                    color:          vehicleObject === globals.activeVehicle ? qgcPal.buttonHighlight : qgcPal.window
                                    border.color:   vehicleObject === globals.activeVehicle ? qgcPal.buttonHighlightText : qgcPal.windowShadeLight
                                    border.width:   vehicleObject === globals.activeVehicle ? 1 : 0

                                    property var vehicleObject: object

                                    QGCMouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (vehicleObject) {
                                                QGroundControl.multiVehicleManager.activeVehicle = vehicleObject
                                            }
                                        }
                                    }

                                    RowLayout {
                                        id:                 vehicleRow
                                        anchors.fill:       parent
                                        anchors.margins:    _panelMargin
                                        spacing:            _panelMargin

                                        IntegratedCompassAttitude {
                                            compassRadius:              ScreenTools.defaultFontPixelHeight * 1.4
                                            compassBorder:              0
                                            attitudeSize:               ScreenTools.defaultFontPixelWidth / 2
                                            attitudeSpacing:            attitudeSize / 2
                                            usedByMultipleVehicleList:  true
                                            vehicle:                    vehicleObject
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing:          ScreenTools.defaultFontPixelHeight * 0.1

                                            QGCLabel {
                                                text:           vehicleObject ? qsTr("Vehicle %1").arg(vehicleObject.id) : ""
                                                font.weight:    vehicleObject === globals.activeVehicle ? Font.DemiBold : Font.Normal
                                                color:          vehicleObject === globals.activeVehicle ? qgcPal.buttonHighlightText : qgcPal.text
                                            }

                                            QGCLabel {
                                                text:       vehicleObject ? vehicleObject.flightMode : ""
                                                color:      vehicleObject === globals.activeVehicle ? qgcPal.buttonHighlightText : qgcPal.text
                                                opacity:    0.7
                                            }
                                        }

                                        QGCLabel {
                                            text:       vehicleObject && vehicleObject.armed ? qsTr("Armed") : qsTr("Standby")
                                            color:      vehicleObject && vehicleObject.armed ? qgcPal.colorOrange : (vehicleObject === globals.activeVehicle ? qgcPal.buttonHighlightText : qgcPal.text)
                                            opacity:    vehicleObject && vehicleObject.armed ? 1 : 0.75
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id:                 instrumentSection
                        Layout.fillWidth:   true
                        Layout.fillHeight:  true
                        color:              qgcPal.windowShade
                        radius:             _panelRadius * 0.75
                        border.color:       qgcPal.windowShadeLight
                        border.width:       1

                        property var activeVehicle:  globals.activeVehicle
                        property var activeBattery:  mainWindow._activeBatteryForVehicle(activeVehicle)
                        property var flightTimeFact: activeVehicle ? activeVehicle.getFact("flightTime") : null
                        property var batteryFact:    activeBattery ? activeBattery.percentRemaining : null
                        property var altitudeFact:   activeVehicle ? activeVehicle.altitudeRelative : null
                        property var headingFact:    activeVehicle ? activeVehicle.heading : null
                        property var airSpeedFact:   activeVehicle ? activeVehicle.airSpeed : null

                        ColumnLayout {
                            anchors.fill:       parent
                            anchors.margins:    _panelMargin
                            spacing:            _panelMargin

                            RowLayout {
                                Layout.fillWidth: true

                                QGCLabel {
                                    text:           qsTr("Instruments")
                                    font.pointSize: ScreenTools.mediumFontPointSize
                                    font.weight:    Font.DemiBold
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                QGCLabel {
                                    text:       instrumentSection.activeVehicle ? qsTr("Vehicle %1").arg(instrumentSection.activeVehicle.id) : qsTr("No Active Vehicle")
                                    color:      qgcPal.text
                                    opacity:    0.7
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing:          _panelMargin

                                Rectangle {
                                    Layout.fillWidth:       true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.75
                                    color:                  qgcPal.window
                                    radius:                 _panelRadius * 0.65
                                    border.color:           qgcPal.windowShadeLight
                                    border.width:           1

                                    ColumnLayout {
                                        anchors.fill:       parent
                                        anchors.margins:    _panelMargin
                                        spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                                        QGCLabel {
                                            text:       qsTr("Flight Time")
                                            color:      qgcPal.text
                                            opacity:    0.7
                                        }

                                        QGCLabel {
                                            text:           mainWindow._formatElapsedTime(instrumentSection.flightTimeFact)
                                            font.pointSize: ScreenTools.largeFontPointSize
                                            font.weight:    Font.DemiBold
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth:       true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.75
                                    color:                  qgcPal.window
                                    radius:                 _panelRadius * 0.65
                                    border.color:           qgcPal.windowShadeLight
                                    border.width:           1

                                    ColumnLayout {
                                        anchors.fill:       parent
                                        anchors.margins:    _panelMargin
                                        spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                                        QGCLabel {
                                            text:       qsTr("Battery")
                                            color:      qgcPal.text
                                            opacity:    0.7
                                        }

                                        QGCLabel {
                                            text: mainWindow._formatFactValue(instrumentSection.batteryFact)
                                            color: !mainWindow._hasFactValue(instrumentSection.batteryFact)
                                                ? qgcPal.text
                                                : (Number(instrumentSection.batteryFact.rawValue) <= 20
                                                    ? qgcPal.colorRed
                                                    : (Number(instrumentSection.batteryFact.rawValue) <= 40 ? qgcPal.colorOrange : qgcPal.colorGreen))
                                            font.pointSize: ScreenTools.largeFontPointSize
                                            font.weight:    Font.DemiBold
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing:          _panelMargin

                                Rectangle {
                                    Layout.fillWidth:       true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.75
                                    color:                  qgcPal.window
                                    radius:                 _panelRadius * 0.65
                                    border.color:           qgcPal.windowShadeLight
                                    border.width:           1

                                    ColumnLayout {
                                        anchors.fill:       parent
                                        anchors.margins:    _panelMargin
                                        spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                                        QGCLabel {
                                            text:       qsTr("Altitude")
                                            color:      qgcPal.text
                                            opacity:    0.7
                                        }

                                        QGCLabel {
                                            text:           mainWindow._formatFactValue(instrumentSection.altitudeFact)
                                            font.pointSize: ScreenTools.largeFontPointSize
                                            font.weight:    Font.DemiBold
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth:       true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.75
                                    color:                  qgcPal.window
                                    radius:                 _panelRadius * 0.65
                                    border.color:           qgcPal.windowShadeLight
                                    border.width:           1

                                    ColumnLayout {
                                        anchors.fill:       parent
                                        anchors.margins:    _panelMargin
                                        spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                                        QGCLabel {
                                            text:       qsTr("Air Speed")
                                            color:      qgcPal.text
                                            opacity:    0.7
                                        }

                                        QGCLabel {
                                            text:           mainWindow._formatFactValue(instrumentSection.airSpeedFact)
                                            font.pointSize: ScreenTools.largeFontPointSize
                                            font.weight:    Font.DemiBold
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth:   true
                                Layout.fillHeight:  true
                                color:              qgcPal.window
                                radius:             _panelRadius * 0.65
                                border.color:       qgcPal.windowShadeLight
                                border.width:       1

                                ColumnLayout {
                                    anchors.fill:       parent
                                    anchors.margins:    _panelMargin
                                    spacing:            _panelMargin

                                    RowLayout {
                                        Layout.fillWidth: true

                                        QGCLabel {
                                            text:       qsTr("Heading")
                                            color:      qgcPal.text
                                            opacity:    0.7
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        QGCLabel {
                                            text:       mainWindow._formatFactValue(instrumentSection.headingFact)
                                            color:      qgcPal.text
                                            opacity:    0.8
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth:   true
                                        Layout.fillHeight:  true

                                        QGCCompassWidget {
                                            anchors.centerIn:   parent
                                            size:               Math.min(parent.width, parent.height) * 0.85
                                            vehicle:            instrumentSection.activeVehicle
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 12
                        spacing:                _panelMargin

                        Rectangle {
                            id:                 gpsStatusCard
                            Layout.fillWidth:   true
                            Layout.fillHeight:  true
                            color:              qgcPal.windowShade
                            radius:             _panelRadius * 0.75
                            border.color:       qgcPal.windowShadeLight
                            border.width:       1

                            property var gpsFactGroup: globals.activeVehicle ? globals.activeVehicle.gps : null
                            property var satelliteFact: gpsFactGroup ? gpsFactGroup.count : null
                            property var hdopFact: gpsFactGroup ? gpsFactGroup.hdop : null
                            property var vdopFact: gpsFactGroup ? gpsFactGroup.vdop : null

                            ColumnLayout {
                                anchors.fill:       parent
                                anchors.margins:    _panelMargin
                                spacing:            _panelMargin

                                QGCLabel {
                                    text:       qsTr("GPS")
                                    color:      qgcPal.text
                                    opacity:    0.7
                                }

                                ColumnLayout {
                                    Layout.fillWidth:   true
                                    Layout.fillHeight:  true
                                    spacing:            _panelMargin

                                    RowLayout {
                                        Layout.alignment:           Qt.AlignHCenter
                                        Layout.fillHeight:          true
                                        spacing:                    ScreenTools.defaultFontPixelWidth

                                        QGCLabel {
                                            text:                       mainWindow._formatFactValue(gpsStatusCard.satelliteFact, false)
                                            color:                      qgcPal.text
                                            font.pointSize:             ScreenTools.largeFontPointSize * 1.7
                                            font.weight:                Font.DemiBold
                                            verticalAlignment:          Text.AlignVCenter
                                        }

                                        QGCLabel {
                                            text:                       qsTr("Satellites")
                                            color:                      qgcPal.text
                                            opacity:                    0.7
                                            verticalAlignment:          Text.AlignVCenter
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth:       true
                                        columns:                2
                                        columnSpacing:          ScreenTools.defaultFontPixelWidth
                                        rowSpacing:             ScreenTools.defaultFontPixelHeight / 3

                                        QGCLabel {
                                            text:       qsTr("HDOP")
                                            color:      qgcPal.text
                                            opacity:    0.7
                                        }

                                        QGCLabel {
                                            Layout.alignment:   Qt.AlignRight
                                            text:               mainWindow._formatFactValue(gpsStatusCard.hdopFact, false)
                                            color:              qgcPal.text
                                            font.weight:        Font.DemiBold
                                        }

                                        QGCLabel {
                                            text:       qsTr("VDOP")
                                            color:      qgcPal.text
                                            opacity:    0.7
                                        }

                                        QGCLabel {
                                            Layout.alignment:   Qt.AlignRight
                                            text:               mainWindow._formatFactValue(gpsStatusCard.vdopFact, false)
                                            color:              qgcPal.text
                                            font.weight:        Font.DemiBold
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id:                 verticalSpeedCard
                            Layout.fillWidth:   true
                            Layout.fillHeight:  true
                            color:              qgcPal.windowShade
                            radius:             _panelRadius * 0.75
                            border.color:       qgcPal.windowShadeLight
                            border.width:       1

                            property var climbRateFact: globals.activeVehicle ? globals.activeVehicle.climbRate : null
                            property bool hasClimbRate: mainWindow._hasFactValue(climbRateFact)
                            property real climbRate: hasClimbRate ? Number(climbRateFact.rawValue) : 0
                            property real needleRotation: mainWindow._clamp(climbRate * 35, -120, 120)

                            ColumnLayout {
                                anchors.fill:       parent
                                anchors.margins:    _panelMargin
                                spacing:            _panelMargin

                                QGCLabel {
                                    text:       qsTr("Vertical Speed")
                                    color:      qgcPal.text
                                    opacity:    0.7
                                }

                                Item {
                                    Layout.fillWidth:   true
                                    Layout.fillHeight:  true

                                    Rectangle {
                                        id:                 verticalSpeedDial
                                        width:              Math.min(parent.width, parent.height) * 0.8
                                        height:             width
                                        radius:             width / 2
                                        color:              qgcPal.window
                                        border.color:       qgcPal.windowShadeLight
                                        border.width:       1
                                        anchors.centerIn:   parent
                                    }

                                    Rectangle {
                                        width:                  verticalSpeedDial.width * 0.34
                                        height:                 Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                                        radius:                 height / 2
                                        x:                      verticalSpeedDial.x + (verticalSpeedDial.width / 2)
                                        y:                      verticalSpeedDial.y + ((verticalSpeedDial.height - height) / 2)
                                        transformOrigin:        Item.Left
                                        rotation:               verticalSpeedCard.needleRotation
                                        color:                  qgcPal.colorGreen
                                    }

                                    Rectangle {
                                        width:                  ScreenTools.defaultFontPixelWidth
                                        height:                 width
                                        radius:                 width / 2
                                        color:                  qgcPal.colorGreen
                                        anchors.centerIn:       verticalSpeedDial
                                    }

                                    QGCLabel {
                                        anchors.horizontalCenter:   verticalSpeedDial.horizontalCenter
                                        anchors.bottom:             parent.bottom
                                        text:                       mainWindow._formatFactValue(verticalSpeedCard.climbRateFact)
                                        font.pointSize:             ScreenTools.largeFontPointSize
                                        font.weight:                Font.DemiBold
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id:                 rightPanel
                anchors.fill:       parent
                color:              qgcPal.windowShadeDark
                radius:             _panelRadius
                border.color:       qgcPal.windowShadeLight
                border.width:       0
                clip:               true

                ColumnLayout {
                    anchors.fill:       parent
                    anchors.margins:    _panelMargin
                    spacing:            _panelMargin

                    Item {
                        Layout.fillWidth:   true
                        Layout.fillHeight:  true

                        PlanView {
                            id:             planViewContent
                            x:              0
                            y:              0
                            width:          parent ? parent.width : 0
                            height:         parent ? parent.height : 0
                            embeddedView:   true
                            visible:        mainViewTabBar.currentIndex === _planTabIndex
                        }

                        FlyIntegratedPage {
                            id:             flyPageContent
                            x:              0
                            y:              0
                            width:          parent ? parent.width : 0
                            height:         parent ? parent.height : 0
                            _useExternalStartMissionUi: true
                            visible:        mainViewTabBar.currentIndex === _flyTabIndex
                        }

                        Loader {
                            id:             summaryViewContent
                            x:              0
                            y:              0
                            width:          parent ? parent.width : 0
                            height:         parent ? parent.height : 0
                            source:         "qrc:/qml/QGroundControl/VehicleSetup/VehicleSummary.qml"
                            active:         mainViewTabBar.currentIndex === _summaryTabIndex
                            visible:        mainViewTabBar.currentIndex === _summaryTabIndex
                            onLoaded:       mainWindow._updateEmbeddedPageState()
                        }

                        Loader {
                            id:             configureViewContent
                            x:              0
                            y:              0
                            width:          parent ? parent.width : 0
                            height:         parent ? parent.height : 0
                            source:         "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml"
                            visible:        mainViewTabBar.currentIndex === _configureTabIndex
                            onLoaded:       mainWindow._updateEmbeddedPageState()
                        }

                        AnalyzeView {
                            id:             analyzeViewContent
                            x:              0
                            y:              0
                            width:          parent ? parent.width : 0
                            height:         parent ? parent.height : 0
                            visible:        mainWindow._analyzeEnabled && (mainViewTabBar.currentIndex === _analyzeTabIndex)
                        }

                        MAVLinkConsolePage {
                            id:             mavlinkConsoleViewContent
                            x:              0
                            y:              0
                            width:          parent ? parent.width : 0
                            height:         parent ? parent.height : 0
                            visible:        mainViewTabBar.currentIndex === _mavlinkConsoleTabIndex
                        }
                    }
                }

                Rectangle {
                    id: fallbackFlyMapHost
                    visible: !mainWindow._showStartPage &&
                             (mainViewTabBar.currentIndex === _flyTabIndex)
                    x: flyPageContent ? (flyPageContent._leftPaneWidth + flyPageContent._margin) : Math.max(ScreenTools.defaultFontPixelWidth * 24, width * 0.25)
                    y: 0
                    width: Math.max(0, parent.width - x)
                    height: Math.max(0, fallbackProfileHost.y - y)
                    color: "transparent"
                    z: 20

                    property var _activeVehicle: globals.activeVehicle
                    property bool _trafficViewVisible: false
                    property bool _instrumentPanelVisible: false
                    property bool _videoOverlayExpanded: false
                    property bool _mapStripExpanded: true
                    property string _mapNavigationSelection: ""
                    readonly property real _margin: flyPageContent ? flyPageContent._margin : ScreenTools.defaultFontPixelHeight * 0.45

                    function _compactVideoOverlayWidth(availableWidth) {
                        return flyPageContent
                            ? flyPageContent._compactVideoOverlayWidth(availableWidth)
                            : Math.min(availableWidth * 0.25, ScreenTools.defaultFontPixelWidth * 24)
                    }

                    function _expandedVideoOverlayWidth(availableWidth) {
                        return flyPageContent
                            ? flyPageContent._expandedVideoOverlayWidth(availableWidth)
                            : Math.min(availableWidth * 0.38, ScreenTools.defaultFontPixelWidth * 34)
                    }

                    function _vehicleHasPosition(vehicle) {
                        return !!(vehicle && vehicle.coordinate && vehicle.coordinate.isValid &&
                                  vehicle.coordinate.latitude !== 0 && vehicle.coordinate.longitude !== 0)
                    }

                    function _trafficRangeStep(distanceMeters) {
                        const steps = [500, 1000, 2000, 3000, 5000, 10000, 20000]
                        for (let i = 0; i < steps.length; i++) {
                            if (distanceMeters <= steps[i]) {
                                return steps[i]
                            }
                        }
                        return Math.ceil(distanceMeters / 5000) * 5000
                    }

                    function _isMapFollowMode() {
                        return !!(_activeVehicle &&
                                  fallbackFlyMap &&
                                  fallbackFlyMap._activeVehicleCoordinate &&
                                  fallbackFlyMap._activeVehicleCoordinate.isValid &&
                                  fallbackFlyMap._flyViewSettings.keepMapCenteredOnVehicle.rawValue &&
                                  !fallbackFlyMap._disableVehicleTracking)
                    }

                    function _isMapPanMode() {
                        return !!fallbackFlyMap && !_isMapFollowMode()
                    }

                    function _isMapStripActionEnabled(key, requiresVehicle) {
                        if (key === "oneKeyRTL") {
                            return !!(globals.guidedControllerFlyView && globals.guidedControllerFlyView.showRTL)
                        }
                        if (key === "flightMode") {
                            return !!(_activeVehicle && _activeVehicle.flightModeSetAvailable)
                        }
                        if (key === "land") {
                            return !!(globals.guidedControllerFlyView && globals.guidedControllerFlyView.showLand)
                        }
                        if (key === "emergencyStop") {
                            return !!(globals.guidedControllerFlyView && globals.guidedControllerFlyView.showEmergenyStop)
                        }
                        if (key === "locate") {
                            return _vehicleHasPosition(_activeVehicle)
                        }
                        return !requiresVehicle || !!_activeVehicle
                    }

                    function _isMapStripSelected(key) {
                        if (key === "traffic") {
                            return _trafficViewVisible
                        }
                        if (key === "showPath") {
                            return flyPageContent ? flyPageContent._showFlightPath : true
                        }
                        if (key === "list") {
                            return flyPageContent ? flyPageContent._instrumentPanelVisible : _instrumentPanelVisible
                        }
                        if (key === "armDisarm") {
                            return !!(_activeVehicle && _activeVehicle.armed)
                        }
                        if (key === "pan" || key === "locate") {
                            return _mapNavigationSelection === key
                        }
                        return false
                    }

                    function _mapStripFlightModeText() {
                        const text = _activeVehicle && _activeVehicle.flightMode
                            ? mainWindow._flightModeDisplayName(_activeVehicle.flightMode)
                            : qsTr("模式")
                        const compactText = ("" + text).replace(/\s+/g, "")
                        if (compactText.length <= 3) {
                            return compactText
                        }
                        if (compactText.length === 4) {
                            return compactText.slice(0, 2) + "\n" + compactText.slice(2)
                        }
                        const splitIndex = Math.ceil(compactText.length / 2)
                        return compactText.slice(0, splitIndex) + "\n" + compactText.slice(splitIndex)
                    }

                    function _flightModeMenuMinimumWidth() {
                        const modes = _activeVehicle && _activeVehicle.flightModeSetAvailable ? _activeVehicle.flightModes : []
                        let widestText = 0
                        for (let i = 0; i < modes.length; i++) {
                            fallbackFlightModeMenuTextMetrics.text = mainWindow._flightModeDisplayName(modes[i])
                            widestText = Math.max(widestText, fallbackFlightModeMenuTextMetrics.advanceWidth)
                        }

                        return widestText + (ScreenTools.defaultFontPixelWidth * 5.5)
                    }

                    function _mapStripActionTitle(key) {
                        switch (key) {
                        case "traffic":
                            return qsTr("态势")
                        case "showPath":
                            return qsTr("显示航迹")
                        case "list":
                            return qsTr("仪表")
                        case "checklist":
                            return qsTr("飞行前检查单")
                        case "armDisarm":
                            return _activeVehicle && _activeVehicle.armed ? qsTr("上锁") : qsTr("解锁")
                        case "play":
                            return qsTr("继续任务")
                        case "pause":
                            return qsTr("暂停")
                        case "rtl":
                            return qsTr("返航")
                        case "oneKeyRTL":
                            return qsTr("一键返航")
                        case "land":
                            return qsTr("降落")
                        case "emergencyStop":
                            return qsTr("紧急停止")
                        case "flightMode":
                            return qsTr("飞行模式")
                        case "up":
                            return qsTr("上升")
                        case "down":
                            return qsTr("下降")
                        case "orbit":
                            return qsTr("旋转地图")
                        case "lockOrbit":
                            return qsTr("锁定朝向")
                        case "pan":
                            return qsTr("平移")
                        case "locate":
                            return qsTr("定位")
                        default:
                            return qsTr("操作不可用")
                        }
                    }

                    function _mapStripUnavailableMessage(key, requiresVehicle) {
                        if (requiresVehicle && !_activeVehicle) {
                            return qsTr("当前没有连接飞行器。")
                        }
                        switch (key) {
                        case "locate":
                            return qsTr("当前飞行器还没有有效定位。")
                        case "flightMode":
                            return qsTr("当前飞控不支持从地面站切换飞行模式。")
                        case "land":
                            return qsTr("当前状态不允许降落。")
                        case "emergencyStop":
                            return qsTr("当前状态不允许紧急停止。")
                        case "play":
                            return qsTr("当前没有可继续的任务。")
                        case "pause":
                            return qsTr("当前飞行模式不允许暂停。")
                        case "up":
                        case "down":
                            return qsTr("当前飞行模式不允许直接调整高度。")
                        default:
                            return qsTr("当前状态下无法执行此操作。")
                        }
                    }

                    function _showMapStripUnavailable(key, requiresVehicle) {
                        QGroundControl.showMessageDialog(
                            mainWindow,
                            _mapStripActionTitle(key),
                            _mapStripUnavailableMessage(key, requiresVehicle))
                    }

                    function _triggerMapStripAction(command, sourceItem) {
                        const guidedController = globals.guidedControllerFlyView
                        switch (command) {
                        case "traffic":
                            _trafficViewVisible = !_trafficViewVisible
                            if (_trafficViewVisible) {
                                if (flyPageContent) {
                                    flyPageContent._instrumentPanelVisible = false
                                } else {
                                    _instrumentPanelVisible = false
                                }
                                fallbackTrafficViewPanel.refresh()
                            }
                            break
                        case "list":
                            _trafficViewVisible = false
                            if (flyPageContent) {
                                flyPageContent._instrumentPanelVisible = !flyPageContent._instrumentPanelVisible
                            } else {
                                _instrumentPanelVisible = !_instrumentPanelVisible
                            }
                            break
                        case "orbit":
                            if (typeof fallbackFlyMap.bearing !== "undefined") {
                                fallbackFlyMap.bearing = (fallbackFlyMap.bearing + 20) % 360
                            }
                            break
                        case "lockOrbit":
                            if (typeof fallbackFlyMap.bearing !== "undefined") {
                                fallbackFlyMap.bearing = 0
                            }
                            break
                        case "up":
                            if (_activeVehicle) {
                                _activeVehicle.guidedModeChangeAltitude(2, false)
                            }
                            break
                        case "down":
                            if (_activeVehicle) {
                                _activeVehicle.guidedModeChangeAltitude(-2, false)
                            }
                            break
                        case "rtl":
                            if (guidedController) {
                                guidedController.confirmAction(guidedController.actionRTL)
                            }
                            break
                        case "oneKeyRTL":
                            fallbackFlyMapHost._confirmOneKeyRTL()
                            break
                        case "land":
                            if (guidedController) {
                                guidedController.confirmAction(guidedController.actionLand)
                            }
                            break
                        case "emergencyStop":
                            if (guidedController) {
                                guidedController.confirmAction(guidedController.actionEmergencyStop)
                            }
                            break
                        case "checklist":
                            if (flyPageContent && flyPageContent.preFlightChecklistPopupItem) {
                                flyPageContent.preFlightChecklistPopupItem.open()
                            }
                            break
                        case "armDisarm":
                            if (_activeVehicle) {
                                const arm = !_activeVehicle.armed
                                QGroundControl.showMessageDialog(
                                    mainWindow,
                                    arm ? qsTr("解锁") : qsTr("上锁"),
                                    arm ? qsTr("确认解锁飞行器？") : qsTr("确认上锁飞行器？"),
                                    Dialog.Yes | Dialog.Cancel,
                                    function() {
                                        if (fallbackFlyMapHost._activeVehicle) {
                                            fallbackFlyMapHost._activeVehicle.armed = arm
                                        }
                                    })
                            }
                            break
                        case "play":
                            if (!guidedController) {
                                break
                            }
                            if (guidedController.showContinueMission) {
                                guidedController.confirmAction(guidedController.actionContinueMission)
                            } else if (flyPageContent && flyPageContent._startMissionEntryVisible) {
                                flyPageContent._triggerMapPrimaryAction()
                            }
                            break
                        case "pause":
                            if (guidedController) {
                                guidedController.confirmAction(guidedController.actionPause)
                            }
                            break
                        case "flightMode":
                            if (_activeVehicle && _activeVehicle.flightModeSetAvailable && sourceItem) {
                                fallbackMapFlightModeMenu.width = Math.max(fallbackMapFlightModeMenu.implicitWidth,
                                                                           fallbackFlyMapHost._flightModeMenuMinimumWidth())
                                fallbackMapFlightModeMenu.popup(fallbackFloatingMapStrip.x + fallbackFloatingMapStrip.width,
                                                                fallbackFloatingMapStrip.y + sourceItem.y)
                            }
                            break
                        case "showPath":
                            if (flyPageContent) {
                                flyPageContent._showFlightPath = !flyPageContent._showFlightPath
                            }
                            break
                        case "pan":
                            if (_mapNavigationSelection === "pan") {
                                _mapNavigationSelection = ""
                                break
                            }
                            fallbackFlyMap._flyViewSettings.keepMapCenteredOnVehicle.rawValue = false
                            fallbackFlyMap._disableVehicleTracking = true
                            _mapNavigationSelection = "pan"
                            break
                        case "locate":
                            if (_activeVehicle && fallbackFlyMap._activeVehicleCoordinate.isValid) {
                                if (_mapNavigationSelection === "locate") {
                                    fallbackFlyMap._flyViewSettings.keepMapCenteredOnVehicle.rawValue = false
                                    fallbackFlyMap._disableVehicleTracking = true
                                    _mapNavigationSelection = ""
                                    break
                                }
                                fallbackFlyMap._flyViewSettings.keepMapCenteredOnVehicle.rawValue = true
                                fallbackFlyMap._disableVehicleTracking = false
                                fallbackFlyMap.center = fallbackFlyMap._activeVehicleCoordinate
                                _mapNavigationSelection = "locate"
                            }
                            break
                        }
                    }

                    function _confirmOneKeyRTL() {
                        const guidedController = globals.guidedControllerFlyView
                        if (!guidedController || !guidedController.showRTL) {
                            _showMapStripUnavailable("oneKeyRTL", true)
                            return
                        }

                        QGroundControl.showMessageDialog(
                            mainWindow,
                            qsTr("一键返航"),
                            qsTr("确认执行一键返航？"),
                            Dialog.Yes | Dialog.Cancel,
                            function() {
                                if (fallbackFlyMapHost._activeVehicle) {
                                    fallbackFlyMapHost._activeVehicle.guidedModeRTL(false)
                                    QGroundControl.showMessageDialog(mainWindow, qsTr("一键返航"), qsTr("返航指令已发送。"))
                                }
                            })
                    }

                    function _formatVehicleAlertMessage(message) {
                        const messageText = message && message.text !== undefined ? message.text : message
                        const messageLevel = message && message.level !== undefined ? Number(message.level) : 0
                        let text = (messageText || "").toString()
                        text = text.replace(/&/g, "&amp;")
                        text = text.replace(/</g, "&lt;")
                        text = text.replace(/>/g, "&gt;")
                        const criticalText = /\b(Emergency|Alert|Critical|Error)\b/i.test(messageText || "")
                        const warningText = /\bWarning\b/i.test(messageText || "")
                        if (messageLevel >= 3 || criticalText) {
                            if (!criticalText) {
                                text = qsTr("错误：") + text
                            }
                            text = "<span style=\"color:#FF5A5F; font-weight:600\">" + text + "</span>"
                        } else if (messageLevel === 2 || warningText) {
                            if (!warningText) {
                                text = qsTr("警告：") + text
                            }
                            text = "<span style=\"color:#FF5A5F; font-weight:600\">" + text + "</span>"
                        }
                        return text
                    }

                    PlanMasterController {
                        id: fallbackPlanController
                        flyView: true

                        Component.onCompleted: {
                            if (!flyPageContent) {
                                start()
                            }
                        }
                    }

                    QGCToolInsets {
                        id: fallbackToolInsets
                        leftEdgeCenterInset: fallbackFloatingMapStrip.width + (fallbackFlyMapHost._margin * 2)
                        leftEdgeTopInset: fallbackFlyMapHost._margin
                        leftEdgeBottomInset: fallbackFlyMapHost._margin
                        rightEdgeTopInset: fallbackVideoOverlay.width + (fallbackFlyMapHost._margin * 2)
                        rightEdgeCenterInset: fallbackFlyMapHost._margin
                        rightEdgeBottomInset: fallbackFlyMapHost._margin
                        topEdgeLeftInset: fallbackFlyMapHost._margin
                        topEdgeCenterInset: fallbackFlyMapHost._margin
                        topEdgeRightInset: fallbackFlyMapHost._margin
                        bottomEdgeLeftInset: fallbackFlyMapHost._margin
                        bottomEdgeCenterInset: fallbackFlyMapHost._margin
                        bottomEdgeRightInset: fallbackFlyMapHost._margin
                    }

                    Connections {
                        target: fallbackFlyMap

                        function onMapPanStart() {
                            fallbackFlyMapHost._mapNavigationSelection = "pan"
                        }
                    }

                    FlyViewMap {
                        id: fallbackFlyMap
                        anchors.fill: parent
                        mapName: "FlyFallbackMap"
                        pipMode: false
                        showMissionPaths: flyPageContent ? flyPageContent._showFlightPath : true
                        planMasterController: flyPageContent ? flyPageContent.planController : fallbackPlanController
                        rightPanelWidth: 0
                        toolInsets: fallbackToolInsets
                    }

                    Rectangle {
                        id: fallbackVehicleAlertStack
                        anchors.top: fallbackVideoOverlay.bottom
                        anchors.right: parent.right
                        anchors.topMargin: fallbackFlyMapHost._margin * 0.85
                        anchors.rightMargin: fallbackFlyMapHost._margin
                        width: fallbackVideoOverlay.width
                        height: Math.min(
                            ScreenTools.defaultFontPixelHeight * 10.5,
                            alertStackColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.72)
                        )
                        visible: fallbackFlyMapHost.visible &&
                                 !!flyPageContent &&
                                 flyPageContent._vehicleAlertMessagesForDisplay(8, false).length > 0
                        color: flyPageContent &&
                               flyPageContent._vehicleAlertDisplayHasUrgentMessage() &&
                               !flyPageContent._vehicleAlertUrgentAcknowledged
                               ? Qt.rgba(0.42, 0.04, 0.05, 0.96)
                               : Qt.rgba(0.07, 0.08, 0.09, 0.94)
                        border.color: flyPageContent &&
                                      flyPageContent._vehicleAlertDisplayHasUrgentMessage() &&
                                      !flyPageContent._vehicleAlertUrgentAcknowledged
                                      ? Qt.rgba(1.0, 0.26, 0.28, 0.38)
                                      : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.18
                        clip: true
                        z: QGroundControl.zOrderWidgets + 30

                        SequentialAnimation on opacity {
                            running: fallbackVehicleAlertStack.visible &&
                                     !!flyPageContent &&
                                     flyPageContent._vehicleAlertFlashActive
                            loops: Animation.Infinite

                            NumberAnimation {
                                from: 1.0
                                to: 0.9
                                duration: 520
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                from: 0.9
                                to: 1.0
                                duration: 520
                                easing.type: Easing.InOutQuad
                            }
                        }

                        onVisibleChanged: {
                            if (!visible) {
                                opacity = 1.0
                                if (flyPageContent) {
                                    flyPageContent._acknowledgeVehicleAlertMessages()
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: ScreenTools.defaultFontPixelWidth * 0.2
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, 0.42)
                            opacity: 0.9
                        }

                        Flickable {
                            id: alertStackFlickable
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.75
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.68
                            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.34
                            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.34
                            clip: true
                            contentWidth: width
                            contentHeight: alertStackColumn.implicitHeight
                            interactive: contentHeight > height

                            Column {
                                id: alertStackColumn
                                width: alertStackFlickable.width
                                spacing: ScreenTools.defaultFontPixelHeight * 0.22

                                Repeater {
                                    model: flyPageContent ? flyPageContent._vehicleAlertMessagesForDisplay(8, false) : []

                                    delegate: RowLayout {
                                        required property var modelData

                                        width: alertStackColumn.width
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.42

                                        QGCColoredImage {
                                            Layout.alignment: Qt.AlignTop
                                            Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.1
                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.62
                                            Layout.preferredHeight: Layout.preferredWidth
                                            source: "/res/VehicleMessages.png"
                                            sourceSize.width: width
                                            fillMode: Image.PreserveAspectFit
                                            color: Qt.rgba(1, 1, 1, 0.9)
                                            opacity: 0.95
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            color: Number(modelData.level) >= 2 ? "#FF5A5F" : Qt.rgba(1, 1, 1, 0.9)
                                            text: fallbackFlyMapHost._formatVehicleAlertMessage(modelData)
                                            textFormat: Text.RichText
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                            verticalAlignment: Text.AlignVCenter
                                            lineHeight: 0.95
                                            lineHeightMode: Text.ProportionalHeight
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                            font.weight: Number(modelData.level) >= 2 ? Font.DemiBold : Font.Normal
                                        }
                                    }
                                }
                            }
                        }

                        QGCMouseArea {
                            cursorShape: Qt.PointingHandCursor
                            fillItem: parent

                            onClicked: {
                                if (flyPageContent) {
                                    flyPageContent._acknowledgeVehicleAlertMessages()
                                    flyPageContent._openVehicleMessages(fallbackVehicleAlertStack)
                                }
                            }
                        }
                    }

                    QGCMenu {
                        id: fallbackMapFlightModeMenu
                        width: Math.max(implicitWidth, fallbackFlyMapHost._flightModeMenuMinimumWidth())

                        Instantiator {
                            model: fallbackFlyMapHost._activeVehicle && fallbackFlyMapHost._activeVehicle.flightModeSetAvailable
                                ? fallbackFlyMapHost._activeVehicle.flightModes
                                : []
                            delegate: QGCMenuItem {
                                required property var modelData
                                text: mainWindow._flightModeDisplayName(modelData)
                                onTriggered: mainWindow._requestMapFlightModeChange(fallbackFlyMapHost._activeVehicle, modelData)
                            }
                            onObjectAdded: (index, object) => fallbackMapFlightModeMenu.insertItem(index, object)
                            onObjectRemoved: (index, object) => fallbackMapFlightModeMenu.removeItem(object)
                        }
                    }

                    TextMetrics {
                        id: fallbackFlightModeMenuTextMetrics
                    }

                    Rectangle {
                        id: fallbackFloatingMapStrip
                        anchors.left: parent.left
                        anchors.leftMargin: fallbackFlyMapHost._margin
                        y: Math.max(fallbackFlyMapHost._margin, (parent.height - height) * 0.5)
                        readonly property real _buttonHeight: ScreenTools.defaultFontPixelHeight * 2.18
                        readonly property real _innerMargin: ScreenTools.defaultFontPixelHeight * 0.16
                        readonly property real _iconRailWidth: ScreenTools.defaultFontPixelHeight * 2.75
                        readonly property real _expandedWidth: _iconRailWidth
                        readonly property real _collapsedWidth: 0
                        readonly property real _buttonSpacing: ScreenTools.defaultFontPixelHeight * 0.12
                        readonly property real _expandedHeight: fallbackStripButtonColumn.implicitHeight + (_innerMargin * 2)
                        readonly property real _collapsedHeight: 0
                        width: fallbackFlyMapHost._mapStripExpanded ? _expandedWidth : _collapsedWidth
                        height: fallbackFlyMapHost._mapStripExpanded
                            ? Math.min(_expandedHeight, Math.max(0, parent.height - (fallbackFlyMapHost._margin * 2)))
                            : _collapsedHeight
                        color: Qt.rgba(0.06, 0.06, 0.07, 0.9)
                        radius: ScreenTools.defaultFontPixelHeight * 0.18
                        clip: true
                        z: QGroundControl.zOrderWidgets

                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.InOutCubic }
                        }
                        Behavior on height {
                            NumberAnimation { duration: 180; easing.type: Easing.InOutCubic }
                        }

                        Flickable {
                            id: fallbackStripFlickable
                            anchors.fill: parent
                            anchors.margins: fallbackFloatingMapStrip._innerMargin
                            contentWidth: width
                            contentHeight: fallbackStripButtonColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            interactive: fallbackFlyMapHost._mapStripExpanded && contentHeight > height

                            ScrollBar.vertical: ScrollBar {
                                policy: fallbackStripFlickable.contentHeight > fallbackStripFlickable.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                width: ScreenTools.defaultFontPixelWidth * 0.35
                            }

                            ColumnLayout {
                                id: fallbackStripButtonColumn
                                width: fallbackStripFlickable.width
                                spacing: fallbackFloatingMapStrip._buttonSpacing

                                Repeater {
                                    model: [
                                    { "key": "traffic",   "icon": "/InstrumentValueIcons/border-outer.svg",    "requiresVehicle": false, "slashed": false },
                                    { "key": "showPath",  "icon": "/InstrumentValueIcons/view-show.svg",       "requiresVehicle": false, "slashed": false },
                                    { "key": "armDisarm", "icon": fallbackFlyMapHost._activeVehicle && fallbackFlyMapHost._activeVehicle.armed ? "/res/LockClosed.svg" : "/res/LockOpen.svg", "requiresVehicle": true, "slashed": false },
                                    { "key": "play",      "icon": "/InstrumentValueIcons/play-outline.svg",    "requiresVehicle": true,  "slashed": false },
                                    { "key": "pause",     "icon": "/InstrumentValueIcons/pause-outline.svg",   "requiresVehicle": true,  "slashed": false },
                                    { "key": "oneKeyRTL", "label": qsTr("一键\n返航"),                          "requiresVehicle": true,  "slashed": false },
                                    { "key": "land",      "icon": "/res/land.svg",                             "requiresVehicle": true,  "slashed": false },
                                    { "key": "emergencyStop", "icon": "/res/Stop.svg",                         "requiresVehicle": true,  "slashed": false },
                                    { "key": "flightMode","icon": "",                                          "requiresVehicle": true,  "slashed": false },
                                    { "key": "up",        "icon": "/InstrumentValueIcons/arrow-base-up.svg",   "requiresVehicle": true,  "slashed": false },
                                    { "key": "down",      "icon": "/InstrumentValueIcons/arrow-base-down.svg", "requiresVehicle": true,  "slashed": false },
                                    { "key": "locate",    "icon": "/InstrumentValueIcons/map-follow.svg",      "requiresVehicle": true,  "slashed": false }
                                    ]

                                    delegate: Rectangle {
                                    required property var modelData

                                    readonly property bool _isSeparator: modelData.separator === true
                                    readonly property bool _isFlightMode: modelData.key === "flightMode"
                                    readonly property bool _enabled: !_isSeparator && fallbackFlyMapHost._isMapStripActionEnabled(modelData.key, modelData.requiresVehicle)
                                    readonly property bool _selected: !_isSeparator && fallbackFlyMapHost._isMapStripSelected(modelData.key)

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: _isSeparator ? ScreenTools.defaultFontPixelHeight * 0.42 : fallbackFloatingMapStrip._buttonHeight
                                    color: _isSeparator
                                        ? "transparent"
                                        : (_selected
                                            ? "#2F6FC7"
                                            : (_isFlightMode
                                                ? (fallbackStripMouseArea.pressed ? "#1A1C1F" : "#121315")
                                                : (fallbackStripMouseArea.pressed ? "#1A1C1F" : "#121315")))
                                    opacity: fallbackFlyMapHost._mapStripExpanded ? (_isSeparator ? 1 : (_enabled ? 1 : 0.42)) : 0
                                    radius: ScreenTools.defaultFontPixelHeight * 0.18
                                    border.width: 0
                                    border.color: "transparent"

                                    Rectangle {
                                        visible: parent._isSeparator
                                        anchors.centerIn: parent
                                        width: parent.width * 0.58
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.18)
                                    }

                                    Item {
                                        visible: !parent._isSeparator
                                        anchors.fill: parent

                                        Rectangle {
                                            visible: parent.parent._isFlightMode
                                            anchors.left: parent.left
                                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.14
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: ScreenTools.defaultFontPixelWidth * 0.22
                                            height: parent.height * 0.62
                                            radius: width / 2
                                            color: "#7FD0FF"
                                            opacity: 0.8
                                        }

                                        QGCColoredImage {
                                            visible: !parent.parent._isFlightMode && !modelData.label
                                            anchors.centerIn: parent
                                            width: parent.height * 0.42
                                            height: width
                                            color: "#FFFFFF"
                                            fillMode: Image.PreserveAspectFit
                                            source: modelData.icon || ""
                                        }

                                        QGCLabel {
                                            visible: !parent.parent._isFlightMode && !!modelData.label
                                            anchors.centerIn: parent
                                            width: parent.width - (ScreenTools.defaultFontPixelWidth * 0.4)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.label || ""
                                            color: "#FFFFFF"
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            lineHeightMode: Text.FixedHeight
                                            lineHeight: ScreenTools.defaultFontPixelHeight * 0.58
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                            font.bold: true
                                        }

                                        QGCLabel {
                                            visible: parent.parent._isFlightMode
                                            anchors.centerIn: parent
                                            width: parent.width - (ScreenTools.defaultFontPixelWidth * 0.7)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: fallbackFlyMapHost._mapStripFlightModeText()
                                            color: "#FFFFFF"
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            lineHeightMode: Text.FixedHeight
                                            lineHeight: ScreenTools.defaultFontPixelHeight * 0.62
                                            font.pixelSize: Math.max(ScreenTools.defaultFontPixelHeight * 0.36,
                                                                     Math.min(ScreenTools.defaultFontPixelHeight * 0.54,
                                                                              parent.width / Math.max(2.2, text.replace(/\n/g, "").length * 0.56)))
                                            font.bold: true
                                        }

                                        Rectangle {
                                            visible: modelData.slashed
                                            anchors.centerIn: parent
                                            width: parent.height * 0.52
                                            height: ScreenTools.defaultFontPixelHeight * 0.1
                                            radius: height / 2
                                            color: "#FFFFFF"
                                            rotation: -32
                                        }
                                    }

                                    QGCMouseArea {
                                        id: fallbackStripMouseArea
                                        anchors.fill: parent
                                        enabled: fallbackFlyMapHost._mapStripExpanded && !parent._isSeparator
                                        onClicked: {
                                            if (parent._enabled) {
                                                fallbackFlyMapHost._triggerMapStripAction(modelData.key, parent)
                                            } else {
                                                fallbackFlyMapHost._showMapStripUnavailable(modelData.key, modelData.requiresVehicle)
                                            }
                                        }
                                    }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: fallbackMapStripToggleHandle
                        anchors.left: fallbackFloatingMapStrip.right
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.15
                        anchors.verticalCenter: fallbackFloatingMapStrip.verticalCenter
                        width: ScreenTools.defaultFontPixelHeight * 1.05
                        height: ScreenTools.defaultFontPixelHeight * 1.9
                        color: Qt.rgba(0.08, 0.08, 0.09, 0.95)
                        radius: width * 0.45
                        border.color: Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1
                        z: QGroundControl.zOrderWidgets + 1

                        Text {
                            anchors.centerIn: parent
                            text: fallbackFlyMapHost._mapStripExpanded ? "<" : ">"
                            color: "#FFFFFF"
                            font.pixelSize: parent.width * 0.78
                            font.bold: true
                            renderType: Text.NativeRendering
                        }

                        QGCMouseArea {
                            anchors.fill: parent
                            onClicked: fallbackFlyMapHost._mapStripExpanded = !fallbackFlyMapHost._mapStripExpanded
                        }
                    }

                    Rectangle {
                        id: fallbackTrafficViewPanel
                        anchors.left: fallbackFloatingMapStrip.right
                        anchors.leftMargin: fallbackFlyMapHost._margin * 0.9
                        anchors.top: fallbackFloatingMapStrip.top
                        width: fallbackFlyMapHost._compactVideoOverlayWidth(parent.width)
                        height: width * 0.75
                        visible: fallbackFlyMapHost._trafficViewVisible
                        color: Qt.rgba(0.07, 0.07, 0.08, 0.95)
                        border.color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.18
                        clip: true
                        z: QGroundControl.zOrderWidgets + 2

                        property var _adsbModel: QGroundControl.adsbVehicleManager ? QGroundControl.adsbVehicleManager.adsbVehicles : null
                        property var _referenceCoordinate: null
                        property int trafficCount: 0
                        property real displayRangeMeters: 2000
                        readonly property real _headerHeight: ScreenTools.defaultFontPixelHeight * 1.42
                        readonly property real _plotLeft: ScreenTools.defaultFontPixelWidth * 1.2
                        readonly property real _plotRight: ScreenTools.defaultFontPixelWidth * 0.75
                        readonly property real _plotTop: _headerHeight + (ScreenTools.defaultFontPixelHeight * 0.14)
                        readonly property real _plotBottom: ScreenTools.defaultFontPixelHeight * 0.72
                        readonly property real _plotWidth: Math.max(width - _plotLeft - _plotRight, 1)
                        readonly property real _plotHeight: Math.max(height - _plotTop - _plotBottom, 1)

                        function refresh() {
                            const adsbModel = _adsbModel
                            const referenceCoordinate = fallbackFlyMapHost._vehicleHasPosition(fallbackFlyMapHost._activeVehicle) ? fallbackFlyMapHost._activeVehicle.coordinate : null
                            let farthestDistance = 0
                            let validTrafficCount = 0

                            _referenceCoordinate = referenceCoordinate

                            if (adsbModel) {
                                for (let i = 0; i < adsbModel.count; i++) {
                                    const trafficVehicle = adsbModel.get(i)
                                    if (!trafficVehicle || !trafficVehicle.coordinate || !trafficVehicle.coordinate.isValid) {
                                        continue
                                    }
                                    validTrafficCount++
                                    if (referenceCoordinate) {
                                        farthestDistance = Math.max(farthestDistance, referenceCoordinate.distanceTo(trafficVehicle.coordinate))
                                    }
                                }
                            }

                            trafficCount = validTrafficCount
                            displayRangeMeters = fallbackFlyMapHost._trafficRangeStep(Math.max(farthestDistance * 1.15, 800))
                            fallbackTrafficGrid.requestPaint()
                        }

                        function relativeTrafficPoint(trafficVehicle) {
                            if (!_referenceCoordinate || !trafficVehicle || !trafficVehicle.coordinate || !trafficVehicle.coordinate.isValid) {
                                return { "valid": false, "x": 0, "y": 0, "distance": NaN }
                            }

                            const distance = _referenceCoordinate.distanceTo(trafficVehicle.coordinate)
                            const azimuthRadians = _referenceCoordinate.azimuthTo(trafficVehicle.coordinate) * Math.PI / 180
                            const eastOffset = Math.sin(azimuthRadians) * distance
                            const northOffset = Math.cos(azimuthRadians) * distance
                            const xRatio = Math.max(-1, Math.min(1, eastOffset / Math.max(displayRangeMeters, 1)))
                            const yRatio = Math.max(-1, Math.min(1, northOffset / Math.max(displayRangeMeters, 1)))

                            return {
                                "valid": true,
                                "x": _plotLeft + (_plotWidth * 0.5) + (xRatio * _plotWidth * 0.5),
                                "y": _plotTop + (_plotHeight * 0.5) - (yRatio * _plotHeight * 0.5),
                                "distance": distance
                            }
                        }

                        function trafficColor(trafficVehicle, trafficPoint) {
                            if (trafficVehicle && trafficVehicle.alert) {
                                return "#FF6B55"
                            }
                            if (trafficPoint.valid && trafficPoint.distance <= Math.max(displayRangeMeters * 0.35, 450)) {
                                return "#D98C4D"
                            }
                            return "#89E0B5"
                        }

                        onVisibleChanged: {
                            if (visible) {
                                refresh()
                            }
                        }
                        onDisplayRangeMetersChanged: fallbackTrafficGrid.requestPaint()
                        onWidthChanged: fallbackTrafficGrid.requestPaint()
                        onHeightChanged: fallbackTrafficGrid.requestPaint()

                        Timer {
                            interval: 700
                            repeat: true
                            running: fallbackTrafficViewPanel.visible
                            triggeredOnStart: true
                            onTriggered: fallbackTrafficViewPanel.refresh()
                        }

                        Connections {
                            target: fallbackTrafficViewPanel._adsbModel
                            ignoreUnknownSignals: true
                            function onCountChanged() { fallbackTrafficViewPanel.refresh() }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: fallbackTrafficViewPanel._headerHeight
                            color: Qt.rgba(0.10, 0.10, 0.11, 0.98)

                            QGCLabel {
                                anchors.left: parent.left
                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.72
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#E8E8E8"
                                font.weight: Font.DemiBold
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                text: qsTr("交通视图")
                            }

                            QGCLabel {
                                anchors.right: parent.right
                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.68
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#5FB5FF"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                text: fallbackTrafficViewPanel.trafficCount > 0
                                    ? qsTr("实时 %1").arg(fallbackTrafficViewPanel.trafficCount)
                                    : qsTr("实时")
                            }
                        }

                        Canvas {
                            id: fallbackTrafficGrid
                            anchors.fill: parent

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                const left = fallbackTrafficViewPanel._plotLeft
                                const top = fallbackTrafficViewPanel._plotTop
                                const plotWidth = fallbackTrafficViewPanel._plotWidth
                                const plotHeight = fallbackTrafficViewPanel._plotHeight

                                ctx.strokeStyle = "rgba(255,255,255,0.05)"
                                ctx.lineWidth = 1

                                for (let i = 0; i <= 5; i++) {
                                    const x = left + ((plotWidth * i) / 5)
                                    ctx.beginPath()
                                    ctx.moveTo(x, top)
                                    ctx.lineTo(x, top + plotHeight)
                                    ctx.stroke()
                                }

                                for (let i = 0; i <= 4; i++) {
                                    const y = top + ((plotHeight * i) / 4)
                                    ctx.beginPath()
                                    ctx.moveTo(left, y)
                                    ctx.lineTo(left + plotWidth, y)
                                    ctx.stroke()
                                }
                            }
                        }

                        Rectangle {
                            width: ScreenTools.defaultFontPixelHeight * 0.36
                            height: width
                            radius: width / 2
                            color: "#49A7FF"
                            opacity: fallbackTrafficViewPanel._referenceCoordinate ? 0.85 : 0
                            x: fallbackTrafficViewPanel._plotLeft + (fallbackTrafficViewPanel._plotWidth * 0.5) - (width * 0.5)
                            y: fallbackTrafficViewPanel._plotTop + (fallbackTrafficViewPanel._plotHeight * 0.5) - (height * 0.5)
                        }

                        Repeater {
                            model: fallbackTrafficViewPanel._adsbModel

                            delegate: Item {
                                required property var object

                                readonly property var trafficPoint: fallbackTrafficViewPanel.relativeTrafficPoint(object)
                                readonly property color pointColor: fallbackTrafficViewPanel.trafficColor(object, trafficPoint)

                                visible: trafficPoint.valid
                                width: ScreenTools.defaultFontPixelHeight * 0.56
                                height: width
                                x: trafficPoint.x - (width * 0.5)
                                y: trafficPoint.y - (height * 0.5)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: pointColor
                                    border.width: 1
                                    border.color: Qt.lighter(pointColor, 1.25)
                                }
                            }
                        }

                        QGCLabel {
                            anchors.left: parent.left
                            anchors.leftMargin: fallbackTrafficViewPanel._plotLeft
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                            color: "#7C8794"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.46
                            text: qsTr("范围 %1 km").arg((fallbackTrafficViewPanel.displayRangeMeters / 1000).toFixed(1))
                        }

                        QGCLabel {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: ScreenTools.defaultFontPixelHeight * 0.18
                            visible: fallbackTrafficViewPanel.trafficCount === 0 || !fallbackTrafficViewPanel._referenceCoordinate
                            width: fallbackTrafficViewPanel.width * 0.68
                            color: "#9CA3AF"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.64
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: fallbackTrafficViewPanel.trafficCount === 0
                                ? qsTr("等待实时交通数据")
                                : qsTr("已检测到交通目标，等待飞行器位置")
                        }
                    }

                    Rectangle {
                        id: fallbackInstrumentPanel
                        anchors.left: fallbackFloatingMapStrip.right
                        anchors.leftMargin: fallbackFlyMapHost._margin * 0.9
                        anchors.top: fallbackFloatingMapStrip.top
                        width: Math.min(
                            Math.max(ScreenTools.defaultFontPixelWidth * 26, parent.width * 0.34),
                            Math.max(ScreenTools.defaultFontPixelWidth * 22, parent.width - fallbackFloatingMapStrip.width - (fallbackFlyMapHost._margin * 2.4))
                        )
                        height: Math.min(parent.height - (fallbackFlyMapHost._margin * 2), ScreenTools.defaultFontPixelHeight * 24)
                        visible: flyPageContent ? flyPageContent._instrumentPanelVisible : fallbackFlyMapHost._instrumentPanelVisible
                        color: Qt.rgba(0.10, 0.10, 0.11, 0.96)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.18
                        clip: true
                        z: QGroundControl.zOrderWidgets + 2

                        property var _vehicle: fallbackFlyMapHost._activeVehicle
                        property var _battery: _vehicle && _vehicle.batteries && _vehicle.batteries.count > 0 ? _vehicle.batteries.get(0) : null
                        readonly property real _panelMargin: ScreenTools.defaultFontPixelHeight * 0.64
                        readonly property real _rowHeight: ScreenTools.defaultFontPixelHeight * 1.72

                        function _factText(fact, precision = 0) {
                            if (!fact || fact.rawValue === undefined || isNaN(Number(fact.rawValue))) {
                                return "--"
                            }

                            const units = fact.units === undefined || fact.units === null ? "" : fact.units
                            return Number(fact.rawValue).toFixed(precision) + units
                        }

                        function _flightTimeText() {
                            if (!_vehicle) {
                                return "--"
                            }
                            const fact = _vehicle.getFact("flightTime")
                            if (!fact || fact.rawValue === undefined || isNaN(Number(fact.rawValue))) {
                                return "--"
                            }
                            const totalSeconds = Math.max(0, Math.round(Number(fact.rawValue)))
                            const minutes = Math.floor(totalSeconds / 60)
                            const seconds = totalSeconds % 60
                            return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: fallbackInstrumentPanel._panelMargin
                            spacing: ScreenTools.defaultFontPixelHeight * 0.42

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.2
                                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: qsTr("仪表")
                                    color: "#E8E8E8"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.82
                                    elide: Text.ElideRight
                                }

                                QGCLabel {
                                    text: fallbackInstrumentPanel._vehicle ? mainWindow._flightModeDisplayName(fallbackInstrumentPanel._vehicle.flightMode) : qsTr("未连接")
                                    color: "#7FD0FF"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                    elide: Text.ElideRight
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.36
                                columnSpacing: ScreenTools.defaultFontPixelWidth * 0.5

                                Repeater {
                                    model: [
                                        { "label": qsTr("飞行时间"), "value": fallbackInstrumentPanel._flightTimeText() },
                                        { "label": qsTr("电量"), "value": fallbackInstrumentPanel._battery ? fallbackInstrumentPanel._factText(fallbackInstrumentPanel._battery.percentRemaining, 0) : "--" },
                                        { "label": qsTr("高度"), "value": fallbackInstrumentPanel._vehicle ? fallbackInstrumentPanel._factText(fallbackInstrumentPanel._vehicle.altitudeRelative, 1) : "--" },
                                        { "label": qsTr("航向"), "value": fallbackInstrumentPanel._vehicle ? fallbackInstrumentPanel._factText(fallbackInstrumentPanel._vehicle.heading, 0) : "--" },
                                        { "label": qsTr("空速"), "value": fallbackInstrumentPanel._vehicle ? fallbackInstrumentPanel._factText(fallbackInstrumentPanel._vehicle.airSpeed, 1) : "--" },
                                        { "label": qsTr("垂直速度"), "value": fallbackInstrumentPanel._vehicle ? fallbackInstrumentPanel._factText(fallbackInstrumentPanel._vehicle.climbRate, 1) : "--" }
                                    ]

                                    delegate: Rectangle {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: fallbackInstrumentPanel._rowHeight
                                        color: Qt.rgba(1, 1, 1, 0.035)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.14
                                        border.color: Qt.rgba(1, 1, 1, 0.055)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                                            spacing: 0

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: modelData.label
                                                color: "#8F9BA8"
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                elide: Text.ElideRight
                                            }

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: modelData.value
                                                color: "#F6F8FB"
                                                font.weight: Font.DemiBold
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }

                    Rectangle {
                        id: fallbackVideoOverlay
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: fallbackFlyMapHost._margin
                        anchors.rightMargin: fallbackFlyMapHost._margin
                        width: fallbackFlyMapHost._videoOverlayExpanded
                            ? fallbackFlyMapHost._expandedVideoOverlayWidth(parent.width)
                            : fallbackFlyMapHost._compactVideoOverlayWidth(parent.width)
                        height: width * 0.75
                        color: qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelHeight * 0.1
                        clip: true
                        z: QGroundControl.zOrderWidgets

                        Behavior on width {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.InOutQuad
                            }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.InOutQuad
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: QGroundControl.videoManager.hasVideo ? fallbackVideoComponent : fallbackVideoPlaceholderComponent
                        }

                        Component {
                            id: fallbackVideoComponent

                            FlyViewVideo {
                                pipView: null
                            }
                        }

                        Component {
                            id: fallbackVideoPlaceholderComponent

                            Rectangle {
                                color: qgcPal.window

                                QGCColoredImage {
                                    anchors.centerIn: parent
                                    width: ScreenTools.defaultFontPixelHeight * 2.4
                                    height: width
                                    color: "#FFFFFF"
                                    fillMode: Image.PreserveAspectFit
                                    source: "/InstrumentValueIcons/drone.svg"
                                }
                            }
                        }

                        Repeater {
                            model: [
                                { "left": true,  "top": true,  "source": "/InstrumentValueIcons/window.svg" },
                                { "left": false, "top": true,  "source": "/InstrumentValueIcons/cheveron-outline-right.svg" },
                                { "left": true,  "top": false, "source": "/InstrumentValueIcons/view-tile.svg" },
                                { "left": false, "top": false, "source": "/InstrumentValueIcons/screen-full.svg", "toggleExpand": true }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: ScreenTools.defaultFontPixelHeight * 1.16
                                height: width
                                radius: ScreenTools.defaultFontPixelHeight * 0.08
                                color: Qt.rgba(0.1, 0.1, 0.1, 0.92)
                                anchors.left: modelData.left ? parent.left : undefined
                                anchors.right: modelData.left ? undefined : parent.right
                                anchors.top: modelData.top ? parent.top : undefined
                                anchors.bottom: modelData.top ? undefined : parent.bottom
                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                anchors.topMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                anchors.bottomMargin: ScreenTools.defaultFontPixelWidth * 0.18

                                QGCColoredImage {
                                    anchors.centerIn: parent
                                    width: parent.height * 0.48
                                    height: width
                                    color: "#FFFFFF"
                                    fillMode: Image.PreserveAspectFit
                                    source: modelData.toggleExpand && fallbackFlyMapHost._videoOverlayExpanded
                                        ? "/InstrumentValueIcons/window-open.svg"
                                        : modelData.source
                                }

                                QGCMouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (modelData.toggleExpand) {
                                            fallbackFlyMapHost._videoOverlayExpanded = !fallbackFlyMapHost._videoOverlayExpanded
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: fallbackStartMissionLauncherCard
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: fallbackFlyMapHost._margin
                        anchors.bottomMargin: fallbackFlyMapHost._margin
                        width: Math.min(ScreenTools.defaultFontPixelWidth * 22, parent.width - (fallbackFlyMapHost._margin * 2))
                        height: fallbackStartMissionLauncherContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                        visible: fallbackFlyMapHost.visible &&
                                 !!flyPageContent &&
                                 !!flyPageContent.guidedController &&
                                 flyPageContent._startMissionEntryVisible &&
                                 !flyPageContent._startMissionVehicleInAir &&
                                 !flyPageContent._startMissionSliderVisible &&
                                 !flyPageContent._startMissionFeedbackVisible &&
                                 !flyPageContent._startMissionUnavailableDialogVisible
                        color: Qt.rgba(0.10, 0.10, 0.11, 0.96)
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.28
                        z: QGroundControl.zOrderWidgets + 20

                        ColumnLayout {
                            id: fallbackStartMissionLauncherContent
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.42
                            spacing: ScreenTools.defaultFontPixelHeight * 0.3

                            QGCLabel {
                                Layout.fillWidth: true
                                text: flyPageContent ? flyPageContent._mapPrimaryActionDialogTitle() : qsTr("开始任务")
                                color: "#F8FAFC"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                text: flyPageContent ? flyPageContent._mapPrimaryActionMessage() : qsTr("开始任务")
                                color: "#E5E7EB"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            QGCButton {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("开始")
                                primary: true
                                onClicked: flyPageContent._triggerMapPrimaryAction()
                            }
                        }
                    }

                    Rectangle {
                        id: fallbackStartMissionFeedbackPanel
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: fallbackFlyMapHost._margin
                        anchors.bottomMargin: fallbackFlyMapHost._margin
                        width: Math.min(
                            ScreenTools.defaultFontPixelWidth * 32,
                            Math.max(ScreenTools.defaultFontPixelWidth * 20, fallbackFlyMapHost.width - (fallbackFlyMapHost._margin * 2))
                        )
                        height: fallbackStartMissionFeedbackContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                        visible: fallbackFlyMapHost.visible &&
                                 !!flyPageContent &&
                                 flyPageContent._startMissionFeedbackVisible &&
                                 !flyPageContent._startMissionSliderVisible &&
                                 !flyPageContent._startMissionUnavailableDialogVisible
                        color: flyPageContent && flyPageContent._startMissionFeedbackIsError
                            ? Qt.rgba(0.28, 0.11, 0.11, 0.96)
                            : Qt.rgba(0.08, 0.19, 0.30, 0.96)
                        border.color: flyPageContent && flyPageContent._startMissionFeedbackIsError
                            ? Qt.rgba(1.0, 0.52, 0.52, 0.35)
                            : Qt.rgba(0.60, 0.84, 1.0, 0.28)
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.28
                        z: QGroundControl.zOrderWidgets + 20

                        ColumnLayout {
                            id: fallbackStartMissionFeedbackContent
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.38
                            spacing: ScreenTools.defaultFontPixelHeight * 0.18

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.4

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: qsTr("开始任务")
                                    color: "#F8FAFC"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74
                                    font.bold: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.15
                                    Layout.preferredHeight: Layout.preferredWidth
                                    radius: width / 2
                                    color: Qt.rgba(1, 1, 1, 0.14)

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.4
                                        height: width
                                        source: "/res/XDelete.svg"
                                        color: "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    QGCMouseArea {
                                        anchors.fill: parent
                                        onClicked: flyPageContent._hideStartMissionFeedback()
                                    }
                                }
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                text: flyPageContent ? flyPageContent._startMissionFeedbackText : ""
                                color: "#E5E7EB"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        id: fallbackStartMissionMapSliderPanel
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: fallbackFlyMapHost._margin
                        anchors.bottomMargin: fallbackFlyMapHost._margin
                        width: Math.min(
                            ScreenTools.defaultFontPixelWidth * 34,
                            Math.max(ScreenTools.defaultFontPixelWidth * 22, fallbackFlyMapHost.width - (fallbackFlyMapHost._margin * 2))
                        )
                        height: fallbackStartMissionMapConfirmContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.58)
                        visible: fallbackFlyMapHost.visible &&
                                 !!flyPageContent &&
                                 flyPageContent._startMissionSliderVisible &&
                                 !flyPageContent._startMissionAlreadyStarted &&
                                 !flyPageContent._startMissionVehicleInAir &&
                                 flyPageContent._mapPrimaryActionAvailable()
                        color: Qt.rgba(0.07, 0.10, 0.12, 0.96)
                        border.color: Qt.rgba(0.45, 0.74, 0.78, 0.20)
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.22
                        z: QGroundControl.zOrderWidgets + 20

                        onVisibleChanged: {
                            if (!visible) {
                                fallbackStartMissionHoldAnimation.stop()
                                fallbackStartMissionHoldButton.holding = false
                                fallbackStartMissionHoldButton.holdProgress = 0
                            }
                        }

                        ColumnLayout {
                            id: fallbackStartMissionMapConfirmContent
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.30
                            spacing: ScreenTools.defaultFontPixelHeight * 0.22

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.32

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: qsTr("开始任务")
                                        color: "#F5FBFC"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: qsTr("确认航线状态后长按执行")
                                        color: "#8FB0B8"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.96
                                    Layout.preferredHeight: Layout.preferredWidth
                                    radius: width / 2
                                    color: Qt.rgba(1, 1, 1, 0.09)

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.42
                                        height: width
                                        source: "/res/XDelete.svg"
                                        color: "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    QGCMouseArea {
                                        anchors.fill: parent
                                        onClicked: flyPageContent._hideStartMissionSlider()
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.35

                                Repeater {
                                    model: [
                                        { "label": qsTr("航点"), "value": flyPageContent ? flyPageContent._startMissionItemCountText() : "--" },
                                        { "label": qsTr("首点"), "value": flyPageContent ? flyPageContent._startMissionFirstSequenceText() : "--" },
                                        { "label": qsTr("状态"), "value": flyPageContent ? flyPageContent._startMissionSyncStateText() : "--" }
                                    ]

                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.48
                                        color: Qt.rgba(0.09, 0.15, 0.18, 0.92)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.12
                                        border.width: 1
                                        border.color: Qt.rgba(0.45, 0.74, 0.78, 0.12)

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.14
                                            spacing: 0

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: modelData.label
                                                color: "#7E9AA4"
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.40
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: modelData.value
                                                color: "#E7F7F9"
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.32

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: qsTr("距离 %1").arg(flyPageContent ? flyPageContent._startMissionDistanceText() : "--")
                                    color: "#8FB0B8"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                                    elide: Text.ElideRight
                                }

                                QGCLabel {
                                    text: flyPageContent && flyPageContent.guidedController ? flyPageContent.guidedController.startMissionMessage : qsTr("开始任务")
                                    color: "#CBE5EA"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                id: fallbackStartMissionHoldButton
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.02
                                property real holdProgress: 0
                                property bool holding: false
                                clip: true
                                radius: ScreenTools.defaultFontPixelHeight * 0.16
                                color: fallbackStartMissionHoldMouseArea.pressed ? "#0F5F58" : (fallbackStartMissionHoldMouseArea.containsMouse ? "#199688" : "#147C72")
                                border.width: 1
                                border.color: Qt.rgba(0.82, 1, 0.96, 0.24)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * fallbackStartMissionHoldButton.holdProgress
                                    color: Qt.rgba(1, 1, 1, 0.14)
                                }

                                QGCLabel {
                                    anchors.centerIn: parent
                                    text: fallbackStartMissionHoldButton.holding
                                          ? qsTr("保持按住 %1%").arg(Math.round(fallbackStartMissionHoldButton.holdProgress * 100))
                                          : qsTr("长按开始任务")
                                    color: "#EFFFFC"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                NumberAnimation {
                                    id: fallbackStartMissionHoldAnimation
                                    target: fallbackStartMissionHoldButton
                                    property: "holdProgress"
                                    from: 0
                                    to: 1
                                    duration: 1250
                                    easing.type: Easing.InOutQuad
                                    onStopped: {
                                        if (fallbackStartMissionHoldButton.holding && fallbackStartMissionHoldButton.holdProgress >= 0.999 && flyPageContent) {
                                            fallbackStartMissionHoldButton.holding = false
                                            flyPageContent._confirmStartMissionSlider()
                                        }
                                    }
                                }

                                QGCMouseArea {
                                    id: fallbackStartMissionHoldMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onPressed: {
                                        if (!flyPageContent || !flyPageContent._mapPrimaryActionAvailable()) {
                                            if (flyPageContent) {
                                                flyPageContent._confirmStartMissionSlider()
                                            }
                                            return
                                        }
                                        fallbackStartMissionHoldAnimation.stop()
                                        fallbackStartMissionHoldButton.holdProgress = 0
                                        fallbackStartMissionHoldButton.holding = true
                                        fallbackStartMissionHoldAnimation.restart()
                                    }
                                    onReleased: {
                                        if (fallbackStartMissionHoldButton.holding && fallbackStartMissionHoldButton.holdProgress < 0.999) {
                                            fallbackStartMissionHoldAnimation.stop()
                                            fallbackStartMissionHoldButton.holding = false
                                            fallbackStartMissionHoldButton.holdProgress = 0
                                        }
                                    }
                                    onCanceled: {
                                        fallbackStartMissionHoldAnimation.stop()
                                        fallbackStartMissionHoldButton.holding = false
                                        fallbackStartMissionHoldButton.holdProgress = 0
                                    }
                                    onExited: {
                                        if (pressed && fallbackStartMissionHoldButton.holding) {
                                            fallbackStartMissionHoldAnimation.stop()
                                            fallbackStartMissionHoldButton.holding = false
                                            fallbackStartMissionHoldButton.holdProgress = 0
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: fallbackStartMissionUnavailablePanel
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: fallbackFlyMapHost._margin
                        anchors.bottomMargin: fallbackFlyMapHost._margin
                        width: Math.max(ScreenTools.defaultFontPixelWidth * 26, Math.min(ScreenTools.defaultFontPixelWidth * 42, parent.width * 0.38))
                        height: fallbackStartMissionUnavailableContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.2)
                        visible: fallbackFlyMapHost.visible && !!flyPageContent && flyPageContent._startMissionUnavailableDialogVisible
                        color: Qt.rgba(0.12, 0.12, 0.13, 0.985)
                        border.color: Qt.rgba(1.0, 0.52, 0.52, 0.34)
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.34
                        z: QGroundControl.zOrderWidgets + 21

                        ColumnLayout {
                            id: fallbackStartMissionUnavailableContent
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.48
                            spacing: ScreenTools.defaultFontPixelHeight * 0.34

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.38

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: qsTr("开始任务")
                                    color: "#F8FAFC"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.78
                                    font.bold: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.12
                                    Layout.preferredHeight: Layout.preferredWidth
                                    radius: width / 2
                                    color: Qt.rgba(1, 1, 1, 0.10)

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.42
                                        height: width
                                        source: "/res/XDelete.svg"
                                        color: "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    QGCMouseArea {
                                        anchors.fill: parent
                                        onClicked: flyPageContent._hideStartMissionUnavailableDialog()
                                    }
                                }
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                text: flyPageContent ? flyPageContent._startMissionUnavailableDialogText : ""
                                color: "#E5E7EB"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.12

                                Item { Layout.fillWidth: true }

                                QGCButton {
                                    text: qsTr("OK")
                                    primary: true
                                    onClicked: flyPageContent._hideStartMissionUnavailableDialog()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: fallbackProfileHost
                    visible: !mainWindow._showStartPage &&
                             (mainViewTabBar.currentIndex === _flyTabIndex)
                    x: fallbackFlyMapHost.x
                    y: parent.height - height
                    width: fallbackFlyMapHost.width
                    height: fallbackProfileHost._clampExpandedHeight(
                        flyPageContent ? flyPageContent._profilePanelExpandedHeight : fallbackProfileHost._localExpandedHeight)
                    color: qgcPal.windowShadeDark
                    radius: _panelRadius * 0.6
                    border.color: qgcPal.windowShadeLight
                    border.width: 1
                    z: 21

                    readonly property real _minExpandedHeight: flyPageContent
                        ? flyPageContent._profilePanelMinExpandedHeight
                        : Math.max(ScreenTools.defaultFontPixelHeight * 10.5, parent.height * 0.22)
                    readonly property real _maxExpandedHeight: flyPageContent
                        ? flyPageContent._profilePanelMaxExpandedHeight
                        : Math.max(ScreenTools.defaultFontPixelHeight * 17, parent.height * 0.48)
                    property real _localExpandedHeight: Math.max(ScreenTools.defaultFontPixelHeight * 12.8, parent.height * 0.29)
                    readonly property var _profilePoints: flyPageContent ? flyPageContent._profileMissionPoints : []
                    readonly property var _siteGroups: flyPageContent ? flyPageContent._profileSiteGroups : []
                    readonly property var _stats: flyPageContent ? flyPageContent._profileStats(_profilePoints) : ({ "minAlt": 0, "maxAlt": 40, "totalDistance": 1 })
                    readonly property real _progress: flyPageContent ? flyPageContent._profileProgress : 0
                    readonly property real _totalDuration: flyPageContent ? flyPageContent._profileTotalDurationSeconds(_profilePoints) : 0
                    readonly property real _treeWidth: Math.max(ScreenTools.defaultFontPixelWidth * 18, width * 0.24)

                    function _clampExpandedHeight(value) {
                        return Math.max(_minExpandedHeight, Math.min(_maxExpandedHeight, value))
                    }

                    function _setExpandedHeight(value) {
                        const nextHeight = _clampExpandedHeight(value)
                        if (flyPageContent) {
                            flyPageContent._profilePanelExpandedHeight = nextHeight
                        } else {
                            _localExpandedHeight = nextHeight
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.18
                        spacing: 0

                        Rectangle {
                            id: fallbackProfileResizeHandle
                            width: parent.width
                            height: ScreenTools.defaultFontPixelHeight * 0.42
                            color: Qt.rgba(1, 1, 1, 0.05)

                            Rectangle {
                                anchors.centerIn: parent
                                width: ScreenTools.defaultFontPixelWidth * 6
                                height: ScreenTools.defaultFontPixelHeight * 0.12
                                radius: height / 2
                                color: Qt.rgba(1, 1, 1, 0.28)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.SizeVerCursor

                                property real _startMouseY: 0
                                property real _startHeight: 0

                                onPressed: (mouse) => {
                                    _startMouseY = fallbackProfileResizeHandle.mapToItem(fallbackProfileHost, mouse.x, mouse.y).y
                                    _startHeight = fallbackProfileHost.height
                                }

                                onPositionChanged: (mouse) => {
                                    if (!pressed) {
                                        return
                                    }
                                    const currentMouseY = fallbackProfileResizeHandle.mapToItem(fallbackProfileHost, mouse.x, mouse.y).y
                                    const deltaY = currentMouseY - _startMouseY
                                    fallbackProfileHost._setExpandedHeight(_startHeight - deltaY)
                                }
                            }
                        }

                        Rectangle {
                            id: fallbackProfileToolbar
                            width: parent.width
                            height: ScreenTools.defaultFontPixelHeight * 2.15
                            color: "#2A2A2B"
                            radius: ScreenTools.defaultFontPixelHeight * 0.08

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                Item {
                                    Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 18, fallbackProfileHost._treeWidth)
                                    Layout.maximumWidth: Layout.preferredWidth
                                    Layout.fillHeight: true

                                    RowLayout {
                                        id: fallbackPlaybackButtonStrip
                                        anchors.fill: parent
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.28
                                        readonly property real buttonWidth: Math.max(
                                            ScreenTools.defaultFontPixelHeight * 1.92,
                                            (width - (spacing * 4)) / 5
                                        )

                                        Repeater {
                                            model: [
                                                { "key": "toStart", "icon": "/InstrumentValueIcons/fast-rewind.svg" },
                                                { "key": "stepBack", "icon": "/InstrumentValueIcons/step-backward.svg" },
                                                { "key": "toggle", "icon": "" },
                                                { "key": "stepForward", "icon": "/InstrumentValueIcons/step-forward.svg" },
                                                { "key": "toEnd", "icon": "/InstrumentValueIcons/fast-forward.svg" }
                                            ]

                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.preferredWidth: fallbackPlaybackButtonStrip.buttonWidth
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.92
                                                radius: ScreenTools.defaultFontPixelHeight * 0.06
                                                color: "#202020"
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.06)

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    width: parent.height * 0.5
                                                    height: width
                                                    color: "#FFFFFF"
                                                    fillMode: Image.PreserveAspectFit
                                                    source: modelData.key === "toggle"
                                                        ? ((flyPageContent && flyPageContent._profilePlaybackActive) ? "/InstrumentValueIcons/pause-outline.svg" : "/InstrumentValueIcons/play-outline.svg")
                                                        : modelData.icon
                                                }

                                                QGCMouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (!flyPageContent) {
                                                            return
                                                        }
                                                        switch (modelData.key) {
                                                        case "toStart":
                                                            flyPageContent._profilePlaybackActive = false
                                                            flyPageContent._profileProgress = 0
                                                            break
                                                        case "stepBack":
                                                            flyPageContent._profilePlaybackActive = false
                                                            flyPageContent._profileProgress = Math.max(0, flyPageContent._profileProgress - 0.05)
                                                            break
                                                        case "toggle":
                                                            flyPageContent._profilePlaybackActive = !flyPageContent._profilePlaybackActive
                                                            break
                                                        case "stepForward":
                                                            flyPageContent._profilePlaybackActive = false
                                                            flyPageContent._profileProgress = Math.min(1, flyPageContent._profileProgress + 0.05)
                                                            break
                                                        case "toEnd":
                                                            flyPageContent._profilePlaybackActive = false
                                                            flyPageContent._profileProgress = 1
                                                            break
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Repeater {
                                    model: [
                                        {
                                            "icon": "/InstrumentValueIcons/time.svg",
                                            "text": flyPageContent ? flyPageContent._formatReplayTime(fallbackProfileHost._totalDuration * fallbackProfileHost._progress) : "00:00"
                                        },
                                        {
                                            "icon": "/InstrumentValueIcons/navigation-more.svg",
                                            "text": globals.activeVehicle ? mainWindow._formatFactValue(globals.activeVehicle.heading, false, "--") + "\u00B0" : "--"
                                        },
                                        {
                                            "icon": "/InstrumentValueIcons/airplane.svg",
                                            "text": globals.activeVehicle ? mainWindow._formatFactValue(globals.activeVehicle.groundSpeed, true, "--") : "--"
                                        },
                                        {
                                            "icon": "/InstrumentValueIcons/arrow-thin-up.svg",
                                            "text": globals.activeVehicle ? mainWindow._formatFactValue(globals.activeVehicle.altitudeRelative, true, "--") : "--"
                                        },
                                        {
                                            "icon": "/InstrumentValueIcons/arrow-simple-up.svg",
                                            "text": globals.activeVehicle ? mainWindow._formatFactValue(globals.activeVehicle.climbRate, true, "--") : "--"
                                        }
                                    ]

                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.1
                                        Layout.preferredWidth: metricRow.implicitWidth + (ScreenTools.defaultFontPixelWidth * 0.65)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08
                                        color: "#202020"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.08)

                                        RowLayout {
                                            id: metricRow
                                            anchors.centerIn: parent
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.14

                                            QGCColoredImage {
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.54
                                                Layout.preferredHeight: Layout.preferredWidth
                                                color: "#B7BCC7"
                                                fillMode: Image.PreserveAspectFit
                                                source: modelData.icon
                                            }

                                            QGCLabel {
                                                color: "#E6E6E6"
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.54
                                                text: modelData.text
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6.4
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.2
                                    radius: ScreenTools.defaultFontPixelHeight * 0.08
                                    color: "#202020"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.08)

                                    QGCLabel {
                                        anchors.centerIn: parent
                                        color: "#D9D9D9"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                        text: flyPageContent ? flyPageContent._formatReplayTime(fallbackProfileHost._totalDuration) : "00:00"
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: parent.height - y

                            Rectangle {
                                id: fallbackProfileTree
                                x: 0
                                y: 0
                                width: fallbackProfileHost._treeWidth
                                height: parent.height
                                color: "#191A1C"
                                radius: ScreenTools.defaultFontPixelHeight * 0.08
                                clip: true

                                Flickable {
                                    id: fallbackProfileTreeFlickable
                                    anchors.fill: parent
                                    contentWidth: width
                                    contentHeight: fallbackProfileTreeColumn.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    flickableDirection: Flickable.VerticalFlick
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                    WheelHandler {
                                        target: null
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onWheel: (event) => {
                                            const step = ScreenTools.defaultFontPixelHeight * 2.2
                                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : (event.pixelDelta ? event.pixelDelta.y : 0)
                                            if (delta === 0) {
                                                return
                                            }
                                            fallbackProfileTreeFlickable.contentY = Math.max(
                                                0,
                                                Math.min(
                                                    fallbackProfileTreeFlickable.contentHeight - fallbackProfileTreeFlickable.height,
                                                    fallbackProfileTreeFlickable.contentY - ((delta / 120) * step)
                                                )
                                            )
                                        }
                                    }

                                    Column {
                                        id: fallbackProfileTreeColumn
                                        width: fallbackProfileTree.width
                                        spacing: 0

                                        Rectangle {
                                            width: parent.width
                                            height: ScreenTools.defaultFontPixelHeight * 2.05
                                            color: "#4A89D8"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                Item {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.82
                                                    Layout.fillHeight: true

                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        text: flyPageContent && flyPageContent._profileVehicleTreeExpanded ? "\u25BE" : "\u25B8"
                                                        color: "#D7E6FF"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                                    }

                                                    QGCMouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            if (flyPageContent) {
                                                                flyPageContent._profileVehicleTreeExpanded = !flyPageContent._profileVehicleTreeExpanded
                                                            }
                                                        }
                                                    }
                                                }

                                                QGCColoredImage {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.8
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.8
                                                    color: "#DCEBFF"
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/drone.svg"
                                                }

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: "#F4F9FF"
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                    elide: Text.ElideRight
                                                    text: flyPageContent ? flyPageContent._vehicleTitle(globals.activeVehicle) : qsTr("Vehicle --")
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: flyPageContent && flyPageContent._profileVehicleTreeExpanded ? ScreenTools.defaultFontPixelHeight * 2.0 : 0
                                            visible: height > 0
                                            color: "#1F2022"
                                            clip: true

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.28
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                Item {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.74
                                                    Layout.fillHeight: true

                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        text: flyPageContent && flyPageContent._profileMissionTreeExpanded ? "\u25BE" : "\u25B8"
                                                        color: "#D4D4D4"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                    }

                                                    QGCMouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            if (flyPageContent) {
                                                                flyPageContent._profileMissionTreeExpanded = !flyPageContent._profileMissionTreeExpanded
                                                            }
                                                        }
                                                    }
                                                }

                                                QGCColoredImage {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.72
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.72
                                                    color: "#61C3B1"
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/map.svg"
                                                }

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: "#E1E1E1"
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                                    elide: Text.ElideRight
                                                    text: flyPageContent ? flyPageContent._missionTitle() : qsTr("Mission")
                                                }
                                            }

                                            Rectangle {
                                                x: ScreenTools.defaultFontPixelWidth * 0.82
                                                y: 0
                                                width: 1
                                                height: parent.height
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                            }
                                        }

                                        Repeater {
                                            model: fallbackProfileHost._siteGroups

                                            delegate: Rectangle {
                                                required property var modelData
                                                required property int index

                                                readonly property bool current: fallbackProfileChart.currentPointIndex >= modelData.startIndex && fallbackProfileChart.currentPointIndex <= modelData.endIndex

                                                width: parent.width
                                                height: (flyPageContent && flyPageContent._profileVehicleTreeExpanded && flyPageContent._profileMissionTreeExpanded)
                                                    ? (ScreenTools.defaultFontPixelHeight * 1.82)
                                                    : 0
                                                visible: height > 0
                                                color: current ? Qt.rgba(0.29, 0.54, 0.85, 0.18) : "transparent"
                                                clip: true

                                                Rectangle {
                                                    x: ScreenTools.defaultFontPixelWidth * 0.82
                                                    y: 0
                                                    width: 1
                                                    height: parent.height
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                }

                                                Rectangle {
                                                    x: ScreenTools.defaultFontPixelWidth * 1.92
                                                    y: 0
                                                    width: 1
                                                    height: parent.height
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2.18
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                    QGCLabel {
                                                        text: "\u25B8"
                                                        color: "#B7B7B7"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                                    }

                                                    QGCColoredImage {
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.66
                                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.66
                                                        color: current ? "#7FD0FF" : "#7AA0C8"
                                                        fillMode: Image.PreserveAspectFit
                                                        source: "/InstrumentValueIcons/drone.svg"
                                                    }

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: current ? "#F6F8FB" : "#D1D5DB"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.64
                                                        elide: Text.ElideRight
                                                        text: modelData.label
                                                    }

                                                    QGCLabel {
                                                        color: "#8F98A3"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                        text: flyPageContent ? flyPageContent._formatProfileAltitude(modelData.altitude) : "--"
                                                    }
                                                }

                                                QGCMouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (!flyPageContent) {
                                                            return
                                                        }
                                                        const totalDistance = Math.max(Number(fallbackProfileHost._stats.totalDistance), 1)
                                                        flyPageContent._profilePlaybackActive = false
                                                        flyPageContent._profileProgress = Math.max(0, Math.min(1, Number(modelData.startDistance) / totalDistance))
                                                        if (modelData.coordinate && modelData.coordinate.isValid) {
                                                            fallbackFlyMap.center = modelData.coordinate
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: fallbackProfileChart
                                x: fallbackProfileTree.width + ScreenTools.defaultFontPixelWidth * 0.35
                                y: 0
                                width: parent.width - x
                                height: parent.height
                                color: "#202123"
                                radius: ScreenTools.defaultFontPixelHeight * 0.08
                                clip: true

                                property var points: fallbackProfileHost._profilePoints
                                readonly property var stats: fallbackProfileHost._stats
                                readonly property real currentDistance: Math.max(Number(stats.totalDistance), 1) * fallbackProfileHost._progress
                                readonly property int currentPointIndex: flyPageContent ? flyPageContent._profilePointIndexAtProgress(points, fallbackProfileHost._progress) : -1
                                readonly property real elapsedSeconds: flyPageContent ? flyPageContent._profileElapsedSeconds(points, fallbackProfileHost._progress) : 0
                                readonly property real plotLeft: ScreenTools.defaultFontPixelWidth * 2.8
                                readonly property real plotRight: ScreenTools.defaultFontPixelWidth * 1.2
                                readonly property real plotTop: ScreenTools.defaultFontPixelHeight * 1.6
                                readonly property real plotBottom: ScreenTools.defaultFontPixelHeight * 1.45
                                readonly property real plotWidth: Math.max(width - plotLeft - plotRight, 1)
                                readonly property real plotHeight: Math.max(height - plotTop - plotBottom, 1)

                                function xForDistance(distance) {
                                    return plotLeft + (Math.max(0, Number(distance)) / Math.max(Number(stats.totalDistance), 1)) * plotWidth
                                }

                                function yForAltitude(altitude) {
                                    const maxAlt = Number(stats.maxAlt)
                                    const minAlt = Number(stats.minAlt)
                                    const ratio = (Math.max(minAlt, Math.min(maxAlt, Number(altitude))) - minAlt) / Math.max(maxAlt - minAlt, 1)
                                    return plotTop + (1 - ratio) * plotHeight
                                }

                                function altitudeAtProgress(progress) {
                                    if (!points || points.length === 0) {
                                        return Number(stats.minAlt)
                                    }
                                    const targetDistance = Math.max(Number(stats.totalDistance), 1) * Math.max(0, Math.min(1, progress))
                                    for (let i = 1; i < points.length; i++) {
                                        const prevPoint = points[i - 1]
                                        const nextPoint = points[i]
                                        if (targetDistance <= nextPoint.distance) {
                                            const span = Math.max(Number(nextPoint.distance) - Number(prevPoint.distance), 1)
                                            const t = (targetDistance - Number(prevPoint.distance)) / span
                                            return Number(prevPoint.altitude) + ((Number(nextPoint.altitude) - Number(prevPoint.altitude)) * t)
                                        }
                                    }
                                    return Number(points[points.length - 1].altitude)
                                }

                                Canvas {
                                    id: fallbackProfileCanvas
                                    anchors.fill: parent

                                    onPaint: {
                                        const ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)

                                        const left = fallbackProfileChart.plotLeft
                                        const top = fallbackProfileChart.plotTop
                                        const plotWidth = fallbackProfileChart.plotWidth
                                        const plotHeight = fallbackProfileChart.plotHeight

                                        ctx.fillStyle = "#262729"
                                        ctx.fillRect(left, top, plotWidth, plotHeight)
                                        ctx.strokeStyle = "rgba(255,255,255,0.10)"
                                        ctx.lineWidth = 1

                                        for (let i = 0; i <= 8; i++) {
                                            const x = left + (plotWidth * i / 8)
                                            ctx.beginPath()
                                            ctx.moveTo(x, top)
                                            ctx.lineTo(x, top + plotHeight)
                                            ctx.stroke()
                                        }

                                        for (let i = 0; i <= 5; i++) {
                                            const y = top + (plotHeight * i / 5)
                                            ctx.beginPath()
                                            ctx.moveTo(left, y)
                                            ctx.lineTo(left + plotWidth, y)
                                            ctx.stroke()
                                        }

                                        const points = fallbackProfileChart.points
                                        if (!points || points.length < 2) {
                                            return
                                        }

                                        const drawSeries = (color, lineWidth) => {
                                            ctx.lineCap = "round"
                                            ctx.lineJoin = "round"
                                            ctx.strokeStyle = color
                                            ctx.lineWidth = lineWidth
                                            ctx.beginPath()
                                            for (let i = 0; i < points.length; i++) {
                                                const point = points[i]
                                                const x = fallbackProfileChart.xForDistance(point.distance)
                                                const y = fallbackProfileChart.yForAltitude(point.altitude)
                                                if (i === 0) {
                                                    ctx.moveTo(x, y)
                                                } else {
                                                    ctx.lineTo(x, y)
                                                }
                                            }
                                            ctx.stroke()
                                        }

                                        drawSeries("rgba(250, 146, 75, 0.28)", ScreenTools.defaultFontPixelHeight * 0.82)
                                        drawSeries("rgba(171, 138, 255, 0.58)", ScreenTools.defaultFontPixelHeight * 0.5)
                                        drawSeries("#E8893D", ScreenTools.defaultFontPixelHeight * 0.16)
                                    }
                                }

                                onPointsChanged: fallbackProfileCanvas.requestPaint()
                                onWidthChanged: fallbackProfileCanvas.requestPaint()
                                onHeightChanged: fallbackProfileCanvas.requestPaint()
                                onStatsChanged: fallbackProfileCanvas.requestPaint()

                                Rectangle {
                                    width: 1
                                    height: fallbackProfileChart.plotHeight + (ScreenTools.defaultFontPixelHeight * 0.55)
                                    x: fallbackProfileChart.xForDistance(fallbackProfileChart.currentDistance)
                                    y: fallbackProfileChart.plotTop - (ScreenTools.defaultFontPixelHeight * 0.52)
                                    color: "#3D9BFF"
                                    opacity: 0.8
                                }

                                Rectangle {
                                    width: ScreenTools.defaultFontPixelHeight * 0.52
                                    height: width
                                    radius: width / 2
                                    x: fallbackProfileChart.xForDistance(fallbackProfileChart.currentDistance) - (width * 0.5)
                                    y: fallbackProfileChart.plotTop - (height * 0.8)
                                    color: "#56A7FF"
                                }

                                QGCLabel {
                                    x: Math.max(
                                        fallbackProfileChart.plotLeft,
                                        Math.min(
                                            fallbackProfileChart.width - width - fallbackProfileChart.plotRight,
                                            fallbackProfileChart.xForDistance(fallbackProfileChart.currentDistance) - (width * 0.5)
                                        )
                                    )
                                    y: ScreenTools.defaultFontPixelHeight * 0.12
                                    color: "#71757B"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                    text: flyPageContent ? flyPageContent._formatReplayTime(fallbackProfileChart.elapsedSeconds) : "--"
                                }

                                Repeater {
                                    model: 4
                                    delegate: QGCLabel {
                                        required property int index
                                        color: "#696E74"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                        text: flyPageContent ? flyPageContent._formatReplayTime(fallbackProfileHost._totalDuration * (index + 1) / 4) : "--"
                                        y: ScreenTools.defaultFontPixelHeight * 0.12
                                        x: fallbackProfileChart.plotLeft + ((fallbackProfileChart.plotWidth - width) * (index + 1) / 4)
                                    }
                                }

                                Repeater {
                                    model: 4
                                    delegate: QGCLabel {
                                        required property int index
                                        readonly property real altitudeValue: Number(fallbackProfileChart.stats.maxAlt)
                                            - ((Number(fallbackProfileChart.stats.maxAlt) - Number(fallbackProfileChart.stats.minAlt)) * index / 3)
                                        x: ScreenTools.defaultFontPixelWidth * 0.2
                                        y: fallbackProfileChart.plotTop + ((fallbackProfileChart.plotHeight - height) * index / 3)
                                        color: "#A5A7AA"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.54
                                        text: flyPageContent ? flyPageContent._formatProfileAltitude(altitudeValue) : "--"
                                    }
                                }

                                Repeater {
                                    model: fallbackProfileChart.points
                                    delegate: Item {
                                        required property var modelData
                                        required property int index
                                        readonly property bool current: fallbackProfileChart.currentPointIndex === index
                                        width: ScreenTools.defaultFontPixelHeight * 1.22
                                        height: width
                                        x: fallbackProfileChart.xForDistance(modelData.distance) - (width * 0.5)
                                        y: fallbackProfileChart.yForAltitude(modelData.altitude) - (height * 0.5)

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: current ? "#53B84F" : "#9E5B2E"
                                            border.width: current ? 2 : 1
                                            border.color: current ? "#E9F7E8" : "#F2A462"
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width + (ScreenTools.defaultFontPixelHeight * 0.75)
                                            height: width
                                            radius: width / 2
                                            visible: current
                                            color: "transparent"
                                            border.width: 2
                                            border.color: Qt.rgba(1, 1, 1, 0.7)
                                        }

                                        QGCLabel {
                                            anchors.centerIn: parent
                                            color: "#FFFFFF"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                            text: modelData.label
                                        }

                                        QGCMouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (!flyPageContent) {
                                                    return
                                                }
                                                const totalDistance = Math.max(Number(fallbackProfileChart.stats.totalDistance), 1)
                                                flyPageContent._profilePlaybackActive = false
                                                flyPageContent._profileProgress = Math.max(0, Math.min(1, Number(modelData.distance) / totalDistance))
                                                if (modelData.coordinate && modelData.coordinate.isValid) {
                                                    fallbackFlyMap.center = modelData.coordinate
                                                }
                                            }
                                        }
                                    }
                                }

                                QGCColoredImage {
                                    width: ScreenTools.defaultFontPixelHeight * 1.55
                                    height: width
                                    color: "#55C2F8"
                                    fillMode: Image.PreserveAspectFit
                                    source: "/InstrumentValueIcons/drone.svg"
                                    x: fallbackProfileChart.xForDistance(Number(fallbackProfileChart.stats.totalDistance) * fallbackProfileHost._progress) - (width * 0.5)

                                    y: fallbackProfileChart.yForAltitude(
                                           flyPageContent
                                               && flyPageContent._activeVehicle
                                               && flyPageContent._hasFactValue
                                               && flyPageContent._hasFactValue(flyPageContent._activeVehicle.altitudeRelative)
                                               ? Number(flyPageContent._activeVehicle.altitudeRelative.rawValue)
                                               : fallbackProfileChart.altitudeAtProgress(fallbackProfileHost._progress)
                                       ) - (height * 0.5)

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    function updateProgress(mouseX) {
                                        if (!flyPageContent) {
                                            return
                                        }
                                        const ratio = (mouseX - fallbackProfileChart.plotLeft) / Math.max(fallbackProfileChart.plotWidth, 1)
                                        flyPageContent._profilePlaybackActive = false
                                        flyPageContent._profileProgress = Math.max(0, Math.min(1, ratio))
                                    }

                                    onPressed: (mouse) => updateProgress(mouse.x)
                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            updateProgress(mouse.x)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: startPageOverlay
                    anchors.fill: parent
                    visible: mainWindow._showStartPage
                    z: QGroundControl.zOrderTopMost + 100
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1E1E1E" }
                        GradientStop { position: 1.0; color: "#222222" }
                    }
                    readonly property color _cardBg: "#2D2D2D"
                    readonly property color _inputBg: "#252525"
                    readonly property color _borderColor: "#333333"
                    readonly property color _focusColor: "#2563EB"
                    readonly property color _primaryText: "#FFFFFF"
                    readonly property color _secondaryText: "#B0B0B0"
                    readonly property color _disabledText: "#666666"
                    readonly property color _primaryBtn: "#2563EB"
                    readonly property color _primaryBtnHover: "#1D4ED8"
                    readonly property color _primaryBtnPressed: "#1E40AF"
                    readonly property color _secondaryBtn: "#333333"
                    readonly property color _secondaryBtnHover: "#3B3B3B"
                    readonly property color _secondaryBtnPressed: "#292929"
                    readonly property real _uiRadius: 8
                    readonly property int _uiAnimMs: 200
                    readonly property real _fontTitle: 2.05
                    readonly property real _fontSubtitle: 1.12
                    readonly property real _fontSectionTitle: 1.28
                    readonly property real _fontFieldLabel: 0.74
                    readonly property real _fontMeta: 0.84
                    readonly property real _fontLogTime: 0.82
                    readonly property real _fontLogMessage: 0.90
                    readonly property real _fontControlScale: 0.90
                    readonly property real _leftFieldLabelWidth: 28.0
                    readonly property real _fontRightTitle: 1.24
                    readonly property real _fontRightLogTime: 0.74
                    readonly property real _fontRightLogMessage: 0.82
                    readonly property real _fontRightButtonScale: 0.82
                    readonly property var _linkManager: QGroundControl.linkManager
                    readonly property var _autoConnectSettings: QGroundControl.settingsManager.autoConnectSettings
                    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
                    readonly property string _startPageAutoConnectConfigName: "Start Page Auto Connect"
                    property bool _serialPortAvailable: false
                    readonly property bool _udpConnectAvailable: !!(_autoConnectSettings
                                                                    && _autoConnectSettings.autoConnectUDP
                                                                    && _autoConnectSettings.autoConnectUDP.rawValue)
                    readonly property bool _canConnect: !_connectionInProgress
                                                           && (_isConnected
                                                               || (_availableLinkNames.length > 0)
                                                               || _udpConnectAvailable
                                                               || (_serialPortAvailable
                                                                   && _selectedSerialPortIndex >= 0
                                                                   && _selectedSerialPortIndex < _serialPortNames.length))
                    property var _availableLinkConfigs: []
                    property var _availableLinkNames: []
                    property var _serialPortNames: []
                    property var _serialPortDisplayNames: []
                    property var _vehicleConnectionStateMap: ({})
                    property string _lastDetectedFlightControllerPortName: ""
                    property var _temporaryStartSerialConfig: null
                    property var _temporaryStartUdpConfig: null
                    property var _connectingConfig: null
                    property var _cleanupStartSerialConfig: null
                    property var _cleanupStartUdpConfig: null
                    property var _cleanupActiveConfig: null
                    property int _selectedLinkIndex: -1
                    property int _selectedSerialPortIndex: -1
                    property int _selectedBaudRate: 57600
                    property bool _selectedFlowControlEnabled: false
                    property int _selectedDataBits: 8
                    property int _selectedStopBits: 1
                    property int _selectedParity: 0
                    property bool _autoConnectOnBoot: false
                    property bool _linkSelectionLocked: false
                    property bool _serialPortSelectionLocked: false
                    property bool _pendingReconnectAfterCleanup: false
                    property bool _lastConnectionWasUdp: false
                    property bool _startPageDisconnectPending: false
                    property string _startPageDisconnectVehicleId: ""
                    property int _cleanupElapsedMs: 0
                    property int _connectedVehicleCount: 0
                    property bool _isConnected: false
                    readonly property string _connectionStateIdle: "idle"
                    readonly property string _connectionStateConnecting: "connecting"
                    readonly property string _connectionStateFinishing: "finishing"
                    property string _manualConnectionState: _connectionStateIdle
                    readonly property bool _connectionInProgress: _manualConnectionState === _connectionStateConnecting || _manualConnectionState === _connectionStateFinishing
                    property real _connectionProgress: 0
                    property int _connectionElapsedMs: 0
                    readonly property int _connectionTimeoutMs: 15000
                    readonly property int _cleanupMinimumWaitMs: 900
                    readonly property int _cleanupTimeoutMs: 5000
                    readonly property int _startPageInitialMavlinkVersion: 2
                    property bool _pendingWorkspaceEntry: false
                    property bool _manualConnectionArmed: false
                    property string _statusText: qsTr("请选择链路并连接飞行器")
                    property string _recentConnectionText: qsTr("暂无成功连接记录")

                    function _openWorkspaceTab(tabIndex) {
                        if (_hasAnyConnectedVehicle()) {
                            return mainWindow._ensureMainInterfaceAccess(tabIndex, true)
                        }
                        return mainWindow._ensureMainInterfaceAccess(tabIndex)
                    }

                    function _appendEvent(message) {
                        const now = new Date()
                        const hh = now.getHours().toString().padStart(2, "0")
                        const mm = now.getMinutes().toString().padStart(2, "0")
                        const ss = now.getSeconds().toString().padStart(2, "0")
                        startEventLogModel.insert(0, { timestamp: hh + ":" + mm + ":" + ss, message: message })
                        while (startEventLogModel.count > 120) {
                            startEventLogModel.remove(startEventLogModel.count - 1)
                        }
                    }

                    function _setStartPageAutoConnectPaused(paused) {
                        if (_linkManager && _linkManager.autoConnectPaused !== undefined) {
                            _linkManager.autoConnectPaused = false
                        }
                    }

                    function _beginConnectionProgress(config) {
                        if (_linkManager) {
                            _linkManager.clearDeferredCommunicationError()
                            _linkManager.communicationErrorDisplayPaused = true
                        }
                        _connectionElapsedMs = 0
                        _connectionProgress = 0.08
                        _manualConnectionState = _connectionStateConnecting
                        _pendingWorkspaceEntry = false
                        _manualConnectionArmed = true
                        _connectingConfig = config
                        _lastConnectionWasUdp = !!(config && config.linkType === LinkConfiguration.TypeUdp)
                        startConnectionCompleteTimer.stop()
                        _statusText = !config
                            ? qsTr("正在等待地面站自动识别飞控并接收 MAVLink 心跳...")
                            : _lastConnectionWasUdp
                            ? qsTr("正在打开 UDP 并等待 MAVLink 心跳...")
                            : qsTr("正在打开串口并等待 MAVLink 心跳...")
                        _recentConnectionText = _statusText
                    }

                    function _activeVehicleParametersReady() {
                        const parameterManager = _activeVehicle ? _activeVehicle.parameterManager : null
                        return !!(parameterManager && parameterManager.parametersReady && !parameterManager.missingParameters)
                    }

                    function _activeVehicleHasMissingParameters() {
                        const parameterManager = _activeVehicle ? _activeVehicle.parameterManager : null
                        return !!(parameterManager && parameterManager.parametersReady && parameterManager.missingParameters)
                    }

                    function _showConnectionFailure(reasonText, titleText = qsTr("连接失败")) {
                        const portText = _selectedSerialPortDisplayName() !== "" ? _selectedSerialPortDisplayName() : qsTr("未选择")
                        const message = reasonText + "\n\n"
                            + qsTr("当前选择：协议自动识别，端口：%1，波特率：%2。\n请检查串口、波特率和飞控供电后重新连接。")
                                .arg(portText)
                                .arg(_selectedBaudRate)
                        QGroundControl.showMessageDialog(mainWindow, titleText, message)
                    }

                    function _tryFinishAfterParametersReady() {
                        if (!_isConnected || !(_connectionInProgress || _manualConnectionArmed)) {
                            return false
                        }

                        if (_activeVehicleParametersReady()) {
                            _finishConnectionProgress(true)
                            if (mainWindow._showStartPage) {
                                _appendEvent(qsTr("已收到心跳，进入工作区；参数/任务将在后台同步"))
                            }
                            return true
                        }

                        if (_activeVehicleHasMissingParameters()) {
                            _finishConnectionProgress(true)
                            if (mainWindow._showStartPage) {
                                _appendEvent(qsTr("已收到心跳，进入工作区；参数/任务将在后台同步"))
                            }
                            return true
                        }

                        _finishConnectionProgress(true)
                        if (mainWindow._showStartPage) {
                            _appendEvent(qsTr("已收到心跳，进入工作区；参数/任务将在后台同步"))
                        }
                        return true
                    }

                    function _enterWorkspaceFromActiveLink(enterWorkspace = true) {
                        _syncConnectionState(false)
                        mainWindow._hadConnectedVehicleSession = true
                        _manualConnectionState = _connectionStateIdle
                        _manualConnectionArmed = false
                        _connectionProgress = 0
                        _connectionElapsedMs = 0
                        _connectingConfig = null
                        if (_linkManager) {
                            _linkManager.communicationErrorDisplayPaused = false
                            _linkManager.showDeferredCommunicationError()
                        }
                        if (enterWorkspace) {
                            _appendEvent(qsTr("进入工作区"))
                            mainWindow._ensureMainInterfaceAccess(mainWindow._flyTabIndex, true)
                        } else {
                            _appendEvent(qsTr("飞行器链路已连接"))
                        }
                    }

                    function _cancelConnectionAttempt() {
                        const config = _connectingConfig
                        _connectingConfig = null

                        if (!config) {
                            return
                        }

                        if (config.link) {
                            config.link.disconnect()
                        }
                        if (config === _temporaryStartSerialConfig) {
                            _temporaryStartSerialConfig = null
                        }
                        if (config === _temporaryStartUdpConfig) {
                            _temporaryStartUdpConfig = null
                        }
                    }

                    function _closePendingStartPageVehicle() {
                        if (!mainWindow._showStartPage || !_activeVehicle || _activeVehicleParametersReady()) {
                            return false
                        }

                        if (_activeVehicle.closeVehicle) {
                            _activeVehicle.closeVehicle()
                            return true
                        }

                        return false
                    }

                    function _resetStartPageConnectionAttempt(disconnectLink = true) {
                        const serialConfig = _temporaryStartSerialConfig
                        const udpConfig = _temporaryStartUdpConfig
                        const activeConfig = _connectingConfig
                        const closedVehicle = disconnectLink ? _closePendingStartPageVehicle() : false

                        if (disconnectLink) {
                            _cleanupStartSerialConfig = serialConfig
                            _cleanupStartUdpConfig = udpConfig
                            _cleanupActiveConfig = activeConfig
                            if (activeConfig && activeConfig.link) {
                                activeConfig.link.disconnect()
                            }
                            if (serialConfig && serialConfig !== activeConfig && serialConfig.link) {
                                serialConfig.link.disconnect()
                            }
                            if (udpConfig && udpConfig !== activeConfig && udpConfig.link) {
                                udpConfig.link.disconnect()
                            }
                        }

                        _manualConnectionState = _connectionStateIdle
                        _pendingWorkspaceEntry = false
                        _manualConnectionArmed = false
                        _connectionProgress = 0
                        _connectionElapsedMs = 0
                        _connectingConfig = null
                        _temporaryStartSerialConfig = null
                        _temporaryStartUdpConfig = null
                        startConnectionCompleteTimer.stop()
                        if (_linkManager) {
                            _linkManager.communicationErrorDisplayPaused = false
                            _linkManager.clearDeferredCommunicationError()
                        }
                        return closedVehicle
                    }

                    function _cleanupLinksReleased() {
                        const activeReleased = !_cleanupActiveConfig || !_cleanupActiveConfig.link
                        const serialReleased = !_cleanupStartSerialConfig || !_cleanupStartSerialConfig.link
                        const udpReleased = !_cleanupStartUdpConfig || !_cleanupStartUdpConfig.link
                        return activeReleased && serialReleased && udpReleased
                    }

                    function _clearCleanupLinkRefs() {
                        _cleanupStartSerialConfig = null
                        _cleanupStartUdpConfig = null
                        _cleanupActiveConfig = null
                    }

                    function _requestReconnectAfterCleanup(message = "") {
                        _pendingReconnectAfterCleanup = true
                        _cleanupElapsedMs = 0
                        _statusText = message !== "" ? message : qsTr("正在关闭上一次连接，随后将按当前设置重新连接...")
                        _recentConnectionText = _statusText
                        _appendEvent(_statusText)
                        if (_resetStartPageConnectionAttempt(true)) {
                            _appendEvent(qsTr("已关闭上一次未完成的飞控连接"))
                        }
                        startReconnectCleanupTimer.restart()
                    }

                    function _connectionSettingChanged(message = "") {
                        const connectedButNotReady = _isConnected && !_activeVehicleParametersReady()
                        if (_connectionInProgress || _manualConnectionArmed || connectedButNotReady) {
                            _requestReconnectAfterCleanup(qsTr("连接设置已更新，将按当前设置重新连接..."))
                        }
                    }

                    function _finishConnectionProgress(success) {
                        if (success) {
                            mainWindow._clearVehicleDisconnectNotice()
                            mainWindow._hadConnectedVehicleSession = true
                            _connectionProgress = 1.0
                            _pendingWorkspaceEntry = true
                            _manualConnectionState = _connectionStateFinishing
                            startConnectionCompleteTimer.restart()
                            return
                        }
                        _cancelConnectionAttempt()
                        _manualConnectionState = _connectionStateIdle
                        _pendingWorkspaceEntry = false
                        _manualConnectionArmed = false
                        startConnectionCompleteTimer.stop()
                        if (_linkManager) {
                            _linkManager.communicationErrorDisplayPaused = false
                        }
                    }

                    function _timeoutConnectionProgress() {
                        _cancelConnectionAttempt()
                        _manualConnectionState = _connectionStateIdle
                        _pendingWorkspaceEntry = false
                        _manualConnectionArmed = false
                        _connectionProgress = 0
                        _connectionElapsedMs = 0
                        _connectingConfig = null
                        startConnectionCompleteTimer.stop()
                    }

                    function _resetConnectionUiState(clearDeferredErrors = true) {
                        startConnectionCompleteTimer.stop()
                        startPageDisconnectConfirmTimer.stop()
                        _manualConnectionState = _connectionStateIdle
                        _pendingWorkspaceEntry = false
                        _manualConnectionArmed = false
                        _startPageDisconnectPending = false
                        _startPageDisconnectVehicleId = ""
                        _connectionProgress = 0
                        _connectionElapsedMs = 0
                        _connectingConfig = null
                        _temporaryStartSerialConfig = null
                        _temporaryStartUdpConfig = null
                        _clearCleanupLinkRefs()
                        if (_linkManager) {
                            _linkManager.communicationErrorDisplayPaused = false
                            if (clearDeferredErrors) {
                                _linkManager.clearDeferredCommunicationError()
                            }
                        }
                    }

                    function _handleDisconnectDuringManualConnection(vehicleId) {
                        if (_manualConnectionState === _connectionStateConnecting) {
                            _beginStartPageDisconnectConfirm(vehicleId)
                            return true
                        }

                        if (_manualConnectionState !== _connectionStateFinishing) {
                            return false
                        }

                        _resetConnectionUiState()
                        _syncConnectionState(false)
                        mainWindow._handleVehicleDisconnected(vehicleId)
                        return true
                    }

                    function _beginStartPageDisconnectConfirm(vehicleId) {
                        _startPageDisconnectVehicleId = vehicleId !== undefined && vehicleId !== null ? ("" + vehicleId) : ""
                        if (!_startPageDisconnectPending) {
                            _startPageDisconnectPending = true
                            const confirmText = qsTr("MAVLink 心跳暂时中断，正在确认连接状态...")
                            _statusText = confirmText
                            _recentConnectionText = confirmText
                            _appendEvent(confirmText)
                        }
                        startPageDisconnectConfirmTimer.restart()
                    }

                    function _activeVehicleCommunicationLost() {
                        const vehicle = _activeVehicle
                        const vehicleLinkManager = vehicle ? vehicle.vehicleLinkManager : null
                        return !!(vehicleLinkManager && vehicleLinkManager.communicationLost)
                    }

                    function _serialPortStillPresent() {
                        const selectedPortName = _selectedSerialPortName()
                        if (selectedPortName === "") {
                            return false
                        }

                        _refreshSerialSelection(true, selectedPortName, _selectedSerialPortDisplayName())
                        return _serialPortNames.indexOf(selectedPortName) >= 0
                    }

                    function _finishStartPageDisconnectConfirm() {
                        if (!_startPageDisconnectPending) {
                            return
                        }

                        _startPageDisconnectPending = false
                        if (_isConnected && !_activeVehicleCommunicationLost()) {
                            const recoveredText = qsTr("MAVLink 通信已恢复")
                            _statusText = recoveredText
                            _recentConnectionText = recoveredText
                            _appendEvent(recoveredText)
                            return
                        }

                        const portLabel = _selectedSerialPortDisplayName()
                        const portStillPresent = _serialPortStillPresent()
                        const failureText = portStillPresent && portLabel !== ""
                            ? qsTr("串口 %1 仍存在，但 MAVLink 心跳已中断，请检查飞控是否重启、波特率或 USB 线是否稳定").arg(portLabel)
                            : qsTr("飞行器连接已断开，请检查飞控供电、USB 连接或仿真数据发送")
                        _resetConnectionUiState()
                        _statusText = failureText
                        _recentConnectionText = failureText
                        _appendEvent(failureText)
                    }

                    function _refreshLinks() {
                        const configs = []
                        const names = []
                        const model = _linkManager ? _linkManager.linkConfigurations : null
                        if (model) {
                            for (let i = 0; i < model.count; i++) {
                                const cfg = model.get(i)
                                if (!cfg || cfg.dynamic) {
                                    continue
                                }
                                configs.push(cfg)
                                names.push(cfg.name && cfg.name !== "" ? cfg.name : qsTr("Link %1").arg(i + 1))
                            }
                        }
                        _availableLinkConfigs = configs
                        _availableLinkNames = names
                        _selectedLinkIndex = configs.length > 0 ? Math.max(0, Math.min(_selectedLinkIndex, configs.length - 1)) : -1
                        _syncSelectedLinkSettings()
                        _refreshSerialSelection()
                    }

                    function _syncSelectedLinkSettings() {
                        if (_selectedLinkIndex < 0 || _selectedLinkIndex >= _availableLinkConfigs.length) {
                            _selectedBaudRate = 57600
                            _selectedFlowControlEnabled = false
                            _selectedDataBits = 8
                            _selectedStopBits = 1
                            _selectedParity = 0
                            return
                        }

                        const cfg = _availableLinkConfigs[_selectedLinkIndex]
                        if (cfg && cfg.linkType === LinkConfiguration.TypeSerial) {
                            const baud = Number(cfg.baud)
                            const dataBits = Number(cfg.dataBits)
                            const stopBits = Number(cfg.stopBits)
                            const parity = Number(cfg.parity)
                            const flowControl = Number(cfg.flowControl)

                            _selectedBaudRate = isNaN(baud) || baud <= 0 ? 57600 : baud
                            _selectedFlowControlEnabled = !isNaN(flowControl) && flowControl !== 0
                            _selectedDataBits = isNaN(dataBits) || dataBits < 5 || dataBits > 8 ? 8 : dataBits
                            _selectedStopBits = isNaN(stopBits) || stopBits < 1 || stopBits > 2 ? 1 : stopBits
                            _selectedParity = isNaN(parity) ? 0 : parity
                        } else {
                            _selectedBaudRate = 57600
                            _selectedFlowControlEnabled = false
                            _selectedDataBits = 8
                            _selectedStopBits = 1
                            _selectedParity = 0
                        }

                    }

                    function _selectLinkConfigByName(name) {
                        if (!name) {
                            return
                        }

                        for (let i = 0; i < _availableLinkConfigs.length; i++) {
                            const cfg = _availableLinkConfigs[i]
                            if (cfg && cfg.name === name) {
                                _selectedLinkIndex = i
                                _syncSelectedLinkSettings()
                                return
                            }
                        }
                    }

                    function _openAddLinkDialog() {
                        if (!_linkManager) {
                            _appendEvent(qsTr("链路管理器不可用"))
                            return
                        }

                        const editingConfig = _linkManager.createConfiguration(ScreenTools.isSerialAvailable ? LinkConfiguration.TypeSerial : LinkConfiguration.TypeUdp, "")
                        if (!editingConfig) {
                            _appendEvent(qsTr("无法创建链路配置"))
                            return
                        }

                        startPageLinkDialogFactory.open({ editingConfig: editingConfig, originalConfig: null })
                    }

                    function _serialPortScore(portName, displayName) {
                        const portText = (portName + " " + displayName).toLowerCase()

                        if (portText.indexOf("ttyacm") !== -1 || portText.indexOf("usbmodem") !== -1) {
                            return 100
                        }
                        if (portText.indexOf("ttyusb") !== -1 || portText.indexOf("usbserial") !== -1) {
                            return 90
                        }
                        if (portText.indexOf("com") === 0 || portText.indexOf(" com") !== -1) {
                            return 80
                        }
                        if (portText.indexOf("ttys") !== -1) {
                            return 10
                        }

                        return 50
                    }

                    function _defaultBaudRateForSerialPort(portName, displayName) {
                        const portText = (portName + " " + displayName).toLowerCase()
                        if (portText.indexOf("sik") !== -1 || portText.indexOf("radio") !== -1 || portText.indexOf("telemetry") !== -1) {
                            return 57600
                        }

                        return 57600
                    }

                    function _bestSerialPortIndex(minimumScore = -1) {
                        let bestIndex = -1
                        let bestScore = -1

                        for (let i = 0; i < _serialPortNames.length; i++) {
                            const score = _serialPortScore(_serialPortNames[i], i < _serialPortDisplayNames.length ? _serialPortDisplayNames[i] : "")
                            if (score > bestScore) {
                                bestIndex = i
                                bestScore = score
                            }
                        }

                        return bestScore >= minimumScore ? bestIndex : -1
                    }

                    function _refreshSerialSelection(forceRefresh = false, preferredPortName = "", preferredDisplayName = "", chooseBestAvailable = false) {
                        if (forceRefresh && _linkManager && ScreenTools.isSerialAvailable) {
                            _linkManager.refreshSerialPorts()
                        }

                        const serialPorts = (_linkManager && ScreenTools.isSerialAvailable) ? _linkManager.serialPorts : []
                        const serialPortStrings = (_linkManager && ScreenTools.isSerialAvailable) ? _linkManager.serialPortStrings : []

                        _serialPortNames = serialPorts ? serialPorts.slice() : []
                        _serialPortDisplayNames = serialPortStrings ? serialPortStrings.slice() : []
                        _serialPortAvailable = _serialPortNames.length > 0

                        if (!serialPorts || serialPorts.length === 0) {
                            _selectedSerialPortIndex = -1
                            return
                        }

                        const preferredPortIndex = preferredPortName !== "" ? _serialPortNames.indexOf(preferredPortName) : -1
                        const preferredDisplayIndex = preferredDisplayName !== "" ? _serialPortDisplayNames.indexOf(preferredDisplayName) : -1
                        if (preferredPortIndex >= 0) {
                            _selectedSerialPortIndex = preferredPortIndex
                        } else if (preferredDisplayIndex >= 0) {
                            _selectedSerialPortIndex = preferredDisplayIndex
                        } else if (chooseBestAvailable) {
                            _selectedSerialPortIndex = _bestSerialPortIndex()
                        } else {
                            _selectedSerialPortIndex = Math.max(0, Math.min(_selectedSerialPortIndex, serialPorts.length - 1))
                        }
                    }

                    function _selectBestDetectedSerialPort() {
                        const bestIndex = _bestSerialPortIndex(80)
                        if (bestIndex < 0) {
                            return false
                        }

                        const currentScore = _selectedSerialPortIndex >= 0 && _selectedSerialPortIndex < _serialPortNames.length
                            ? _serialPortScore(_serialPortNames[_selectedSerialPortIndex], _selectedSerialPortIndex < _serialPortDisplayNames.length ? _serialPortDisplayNames[_selectedSerialPortIndex] : "")
                            : -1
                        const bestScore = _serialPortScore(_serialPortNames[bestIndex], bestIndex < _serialPortDisplayNames.length ? _serialPortDisplayNames[bestIndex] : "")
                        if (bestIndex === _selectedSerialPortIndex || (currentScore >= 0 && bestScore <= currentScore)) {
                            return false
                        }

                        _selectedSerialPortIndex = bestIndex
                        return true
                    }

                    function _detectedSerialPortLabel(portName, displayName) {
                        return displayName !== "" ? displayName : portName
                    }

                    function _logDetectedFlightControllerPort(previousPorts) {
                        const previousMap = {}
                        for (let i = 0; i < previousPorts.length; i++) {
                            previousMap[previousPorts[i]] = true
                        }

                        let bestNewIndex = -1
                        let bestNewScore = -1
                        for (let j = 0; j < _serialPortNames.length; j++) {
                            const portName = _serialPortNames[j]
                            if (previousMap[portName]) {
                                continue
                            }

                            const displayName = j < _serialPortDisplayNames.length ? _serialPortDisplayNames[j] : ""
                            const score = _serialPortScore(portName, displayName)
                            if (score > bestNewScore) {
                                bestNewIndex = j
                                bestNewScore = score
                            }
                        }

                        if (bestNewIndex >= 0 && bestNewScore >= 80) {
                            const bestPortName = _serialPortNames[bestNewIndex]
                            if (bestPortName === _lastDetectedFlightControllerPortName) {
                                return
                            }
                            _lastDetectedFlightControllerPortName = bestPortName
                            const bestDisplayName = bestNewIndex < _serialPortDisplayNames.length ? _serialPortDisplayNames[bestNewIndex] : ""
                            _appendEvent(qsTr("检测到飞控串口：%1").arg(_detectedSerialPortLabel(bestPortName, bestDisplayName)))
                        }
                    }

                    function _refreshSerialSelectionAfterConnectionFailure() {
                        const previousPortName = _selectedSerialPortName()
                        const previousDisplayName = _selectedSerialPortDisplayName()
                        _refreshSerialSelection(true, previousPortName, previousDisplayName)
                        if (_selectedSerialPortName() === "" || previousPortName === "") {
                            _selectBestDetectedSerialPort()
                        }

                        const currentPortName = _selectedSerialPortName()
                        const currentDisplayName = _selectedSerialPortDisplayName()
                        if (currentPortName === "") {
                            _appendEvent(qsTr("刷新后未检测到串口"))
                            return false
                        }

                        if (currentPortName !== previousPortName || currentDisplayName !== previousDisplayName) {
                            _appendEvent(qsTr("串口已刷新：%1").arg(currentDisplayName))
                            _statusText = qsTr("串口已切换为 %1，请重新点击连接飞行器").arg(currentDisplayName)
                            _recentConnectionText = _statusText
                            return true
                        } else {
                            _appendEvent(qsTr("串口列表已刷新"))
                        }

                        return false
                    }

                    function _refreshSerialSelectionFromDetection(logChanges = false, forceRefresh = true) {
                        if (_connectionInProgress || _isConnected) {
                            return false
                        }

                        const previousPorts = _serialPortNames.slice()
                        const previousPortName = _selectedSerialPortName()
                        const previousDisplayName = _selectedSerialPortDisplayName()
                        _refreshSerialSelection(forceRefresh)

                        if (logChanges) {
                            _logDetectedFlightControllerPort(previousPorts)
                        }

                        if (_serialPortSelectionLocked && previousPortName !== "") {
                            const lockedPortIndex = _serialPortNames.indexOf(previousPortName)
                            const lockedDisplayIndex = previousDisplayName !== "" ? _serialPortDisplayNames.indexOf(previousDisplayName) : -1
                            if (lockedPortIndex >= 0) {
                                _selectedSerialPortIndex = lockedPortIndex
                            } else if (lockedDisplayIndex >= 0) {
                                _selectedSerialPortIndex = lockedDisplayIndex
                            } else {
                                _serialPortSelectionLocked = false
                                _selectBestDetectedSerialPort()
                                if (logChanges && _selectedSerialPortName() !== "") {
                                    _appendEvent(qsTr("当前锁定串口已断开，已选择 %1").arg(_selectedSerialPortDisplayName()))
                                }
                            }
                        } else {
                            _selectBestDetectedSerialPort()
                        }

                        const currentPortName = _selectedSerialPortName()
                        const currentDisplayName = _selectedSerialPortDisplayName()
                        if (currentPortName === "") {
                            if (_udpConnectAvailable && logChanges) {
                                _statusText = qsTr("未检测到飞控串口，准备使用 UDP 连接")
                                _recentConnectionText = _statusText
                            }
                            return false
                        }

                        const changed = currentPortName !== previousPortName || currentDisplayName !== previousDisplayName
                        if (changed && logChanges) {
                            if (_selectedSerialPortScore() >= 80) {
                                _linkSelectionLocked = false
                                _lastConnectionWasUdp = false
                            }
                            if (!_serialPortSelectionLocked) {
                                _selectedBaudRate = _defaultBaudRateForSerialPort(currentPortName, currentDisplayName)
                            }
                            _statusText = qsTr("检测到串口 %1，可以连接").arg(currentDisplayName)
                            _recentConnectionText = _statusText
                        } else if (!changed && logChanges && _serialPortSelectionLocked && previousPortName !== "" && _serialPortNames.length > previousPorts.length) {
                            _statusText = qsTr("检测到新串口，当前保持 %1").arg(currentDisplayName)
                            _recentConnectionText = _statusText
                        }

                        return changed
                    }

                    function _selectedSerialPortName() {
                        if (_selectedSerialPortIndex < 0 || _selectedSerialPortIndex >= _serialPortNames.length) {
                            return ""
                        }

                        return _serialPortNames[_selectedSerialPortIndex]
                    }

                    function _selectedSerialPortDisplayName() {
                        if (_selectedSerialPortIndex < 0 || _selectedSerialPortIndex >= _serialPortDisplayNames.length) {
                            return _selectedSerialPortName()
                        }

                        return _serialPortDisplayNames[_selectedSerialPortIndex]
                    }

                    function _selectedSerialPortScore() {
                        if (_selectedSerialPortIndex < 0 || _selectedSerialPortIndex >= _serialPortNames.length) {
                            return -1
                        }

                        return _serialPortScore(_serialPortNames[_selectedSerialPortIndex], _selectedSerialPortIndex < _serialPortDisplayNames.length ? _serialPortDisplayNames[_selectedSerialPortIndex] : "")
                    }

                    function _udpListenPort() {
                        const port = _autoConnectSettings && _autoConnectSettings.udpListenPort
                            ? Number(_autoConnectSettings.udpListenPort.rawValue)
                            : 14550
                        return isNaN(port) || port <= 0 ? 14550 : port
                    }

                    function _findSavedConfigByName(name) {
                        const model = _linkManager ? _linkManager.linkConfigurations : null
                        if (!model || name === "") {
                            return null
                        }

                        for (let i = 0; i < model.count; i++) {
                            const cfg = model.get(i)
                            if (cfg && !cfg.dynamic && cfg.name === name) {
                                return cfg
                            }
                        }

                        return null
                    }

                    function _removeStartPageAutoConnectConfig() {
                        const existing = _findSavedConfigByName(_startPageAutoConnectConfigName)
                        if (existing && !existing.link) {
                            _linkManager.removeConfiguration(existing)
                            _refreshLinks()
                        }
                    }

                    function _persistStartPageAutoConnectConfig(connectionConfig) {
                        if (!_linkManager || !connectionConfig) {
                            return false
                        }

                        const existing = _findSavedConfigByName(_startPageAutoConnectConfigName)
                        if (existing && existing.link) {
                            return true
                        }
                        if (existing) {
                            _linkManager.removeConfiguration(existing)
                        }

                        let config = null
                        if (!connectionConfig.dynamic) {
                            config = _linkManager.startConfigurationEditing(connectionConfig)
                            if (!config) {
                                return false
                            }
                            config.name = _startPageAutoConnectConfigName
                            config.dynamic = false
                            config.autoConnect = true
                            _linkManager.endCreateConfiguration(config)
                            _refreshLinks()
                            return true
                        }

                        if (connectionConfig.linkType !== LinkConfiguration.TypeSerial) {
                            return false
                        }

                        config = _linkManager.createConfiguration(LinkConfiguration.TypeSerial, _startPageAutoConnectConfigName)
                        if (!config) {
                            return false
                        }

                        config.dynamic = false
                        config.name = _startPageAutoConnectConfigName
                        config.portName = _selectedSerialPortName()
                        config.baud = _selectedBaudRate
                        config.flowControl = _selectedFlowControlEnabled ? 1 : 0
                        config.dataBits = _selectedDataBits
                        config.stopBits = _selectedStopBits
                        config.parity = _selectedParity
                        config.mavlinkVersion = _startPageInitialMavlinkVersion
                        config.autoConnect = true
                        _linkManager.endCreateConfiguration(config)
                        _refreshLinks()
                        return true
                    }

                    function _applyStartPagePersistentSettings(connectionConfig) {
                        _autoConnectOnBoot = false
                        _removeStartPageAutoConnectConfig()
                    }

                    function _temporarySerialConfig() {
                        if (!_linkManager || !_serialPortAvailable) {
                            return null
                        }

                        _refreshSerialSelectionFromDetection(false)

                        const previousPortName = _selectedSerialPortName()
                        const previousDisplayName = _selectedSerialPortDisplayName()
                        _refreshSerialSelection(true, previousPortName, previousDisplayName)

                        const portName = _selectedSerialPortName()
                        if (portName === "") {
                            return null
                        }

                        let config = _temporaryStartSerialConfig
                        if (config && config.link) {
                            _statusText = qsTr("上一次串口链路正在关闭，请稍后重试")
                            _recentConnectionText = _statusText
                            config.link.disconnect()
                            return null
                        }

                        if (!config) {
                            config = _linkManager.createConfiguration(LinkConfiguration.TypeSerial, qsTr("Start Page Serial Link"))
                        }
                        if (!config) {
                            return null
                        }

                        config.dynamic = true
                        config.name = qsTr("Start Page Serial (%1)").arg(_selectedSerialPortDisplayName())
                        config.portName = portName
                        if (!_serialPortSelectionLocked) {
                            _selectedBaudRate = _defaultBaudRateForSerialPort(portName, _selectedSerialPortDisplayName())
                        }
                        config.baud = _selectedBaudRate
                        config.flowControl = _selectedFlowControlEnabled ? 1 : 0
                        config.dataBits = _selectedDataBits
                        config.stopBits = _selectedStopBits
                        config.parity = _selectedParity
                        config.mavlinkVersion = _startPageInitialMavlinkVersion
                        config.autoConnect = _autoConnectOnBoot
                        if (!_temporaryStartSerialConfig) {
                            _linkManager.endCreateConfiguration(config)
                            _temporaryStartSerialConfig = config
                        }

                        return config
                    }

                    function _temporaryUdpConfig() {
                        if (!_linkManager || !_udpConnectAvailable) {
                            return null
                        }

                        let config = _temporaryStartUdpConfig
                        if (config && config.link) {
                            _statusText = qsTr("上一次 UDP 链路正在关闭，请稍后重试")
                            _recentConnectionText = _statusText
                            config.link.disconnect()
                            return null
                        }

                        if (!config) {
                            config = _linkManager.createConfiguration(LinkConfiguration.TypeUdp, qsTr("Start Page UDP Link"))
                        }
                        if (!config) {
                            return null
                        }

                        config.dynamic = true
                        config.name = qsTr("Start Page UDP (%1)").arg(_udpListenPort())
                        config.autoConnect = false
                        config.localPort = _udpListenPort()
                        config.mavlinkVersion = _startPageInitialMavlinkVersion
                        if (!_temporaryStartUdpConfig) {
                            _linkManager.endCreateConfiguration(config)
                            _temporaryStartUdpConfig = config
                        }

                        return config
                    }

                    function _hasActiveTemporaryLink() {
                        return !!((_temporaryStartSerialConfig && _temporaryStartSerialConfig.link)
                                  || (_temporaryStartUdpConfig && _temporaryStartUdpConfig.link)
                                  || (_connectingConfig && _connectingConfig.link))
                    }

                    function _selectedSavedLinkConfig() {
                        if (_selectedLinkIndex >= 0 && _selectedLinkIndex < _availableLinkConfigs.length) {
                            return _availableLinkConfigs[_selectedLinkIndex]
                        }

                        return null
                    }

                    function _shouldWaitForSerialAutoConnect() {
                        const pixhawkAutoConnectEnabled = !!(_autoConnectSettings
                                                             && _autoConnectSettings.autoConnectPixhawk
                                                             && _autoConnectSettings.autoConnectPixhawk.rawValue)
                        return _serialPortAvailable
                            && pixhawkAutoConnectEnabled
                            && !_linkSelectionLocked
                            && !_serialPortSelectionLocked
                            && _selectedSerialPortIndex >= 0
                            && _selectedSerialPortIndex < _serialPortNames.length
                            && _selectedSerialPortScore() >= 80
                    }

                    function _chooseConnectionConfig() {
                        const selectedLinkConfig = _selectedSavedLinkConfig()
                        const highConfidenceSerialSelected = _serialPortAvailable
                            && _selectedSerialPortIndex >= 0
                            && _selectedSerialPortIndex < _serialPortNames.length
                            && _selectedSerialPortScore() >= 80

                        if (highConfidenceSerialSelected && !_linkSelectionLocked) {
                            return _temporarySerialConfig()
                        }

                        if (selectedLinkConfig && selectedLinkConfig.linkType === LinkConfiguration.TypeUdp && (_linkSelectionLocked || !highConfidenceSerialSelected)) {
                            return _temporaryUdpConfig()
                        }

                        if (selectedLinkConfig && selectedLinkConfig.linkType !== LinkConfiguration.TypeSerial) {
                            return selectedLinkConfig
                        }

                        const preferUdp = _udpConnectAvailable && _selectedSerialPortScore() < 80
                        if (_serialPortAvailable && !preferUdp) {
                            const serialConfig = _temporarySerialConfig()
                            if (serialConfig) {
                                return serialConfig
                            }
                        }

                        if (_udpConnectAvailable) {
                            const udpConfig = _temporaryUdpConfig()
                            if (udpConfig) {
                                return udpConfig
                            }
                        }

                        if (!_serialPortAvailable) {
                            return selectedLinkConfig
                        }

                        return null
                    }

                    function _vehicleKey(vehicle) {
                        return vehicle && vehicle.id !== undefined && vehicle.id !== null ? ("" + vehicle.id) : ""
                    }

                    function _vehicleLabel(vehicleIdText) {
                        return qsTr("飞行器 %1").arg(vehicleIdText)
                    }

                    function _syncConnectionState(logChanges = true) {
                        const vehicles = QGroundControl.multiVehicleManager.vehicles
                        const nextStates = {}
                        let connectedCount = 0

                        if (vehicles) {
                            for (let i = 0; i < vehicles.count; i++) {
                                const vehicle = vehicles.get(i)
                                const vehicleIdText = _vehicleKey(vehicle)
                                if (vehicleIdText === "") {
                                    continue
                                }

                                const vehicleLinkManager = vehicle ? vehicle.vehicleLinkManager : null
                                const isConnected = !!(vehicleLinkManager && !vehicleLinkManager.communicationLost)
                                const previousState = _vehicleConnectionStateMap[vehicleIdText]

                                nextStates[vehicleIdText] = isConnected

                                if (isConnected) {
                                    connectedCount++
                                }

                                if (!logChanges) {
                                    continue
                                }

                                if (previousState === undefined) {
                                    if (isConnected) {
                                        _appendEvent(qsTr("%1 已连接").arg(_vehicleLabel(vehicleIdText)))
                                    }
                                } else if (previousState !== isConnected && (isConnected || (!_connectionInProgress && !_pendingWorkspaceEntry))) {
                                    _appendEvent(
                                        isConnected
                                            ? qsTr("%1 已连接").arg(_vehicleLabel(vehicleIdText))
                                            : qsTr("%1 已断开").arg(_vehicleLabel(vehicleIdText))
                                    )
                                }
                            }
                        }

                        if (logChanges) {
                            for (const vehicleIdText in _vehicleConnectionStateMap) {
                                if (_vehicleConnectionStateMap[vehicleIdText] && nextStates[vehicleIdText] === undefined && !_connectionInProgress && !_pendingWorkspaceEntry) {
                                    _appendEvent(qsTr("%1 已断开").arg(_vehicleLabel(vehicleIdText)))
                                }
                            }
                        }

                        _vehicleConnectionStateMap = nextStates
                        _connectedVehicleCount = connectedCount
                        _isConnected = connectedCount > 0

                        if (_isConnected) {
                            mainWindow._hadConnectedVehicleSession = true
                            mainWindow._clearVehicleDisconnectNotice()
                            if (_activeVehicle && _activeVehicle.id !== undefined && _activeVehicle.id !== null) {
                                _statusText = qsTr("飞行器 %1 已连接。请检查设置，然后点击“连接飞行器”进入").arg(_activeVehicle.id)
                                _recentConnectionText = qsTr("最近连接：飞行器 %1 已连接").arg(_activeVehicle.id)
                            } else if (_connectedVehicleCount === 1) {
                                _statusText = qsTr("已连接 1 架飞行器。请检查设置，然后点击“连接飞行器”进入")
                                _recentConnectionText = qsTr("最近连接：1 架飞行器已连接")
                            } else {
                                _statusText = qsTr("已连接 %1 架飞行器。请检查设置，然后点击“连接飞行器”进入").arg(_connectedVehicleCount)
                                _recentConnectionText = qsTr("最近连接：%1 架飞行器已连接").arg(_connectedVehicleCount)
                            }
                        } else {
                            _statusText = qsTr("请选择链路并连接飞行器")
                            if (!_connectionInProgress && !_pendingWorkspaceEntry) {
                                _recentConnectionText = qsTr("暂无已连接飞行器")
                                _pendingWorkspaceEntry = false
                                startConnectionCompleteTimer.stop()
                            }
                        }

                        if (_isConnected && (_connectionInProgress || _manualConnectionArmed)) {
                            if (_tryFinishAfterParametersReady()) {
                                return
                            }
                        }

                        if (_isConnected && _activeVehicleHasMissingParameters()) {
                            _statusText = qsTr("飞控参数读取不完整，请检查连接设置")
                            _recentConnectionText = _statusText
                        }

                        const wasShowingStartPage = mainWindow._showStartPage

                        // The hidden start page overlay should not seize global navigation
                        // when vehicle state momentarily fluctuates while the user is working
                        // in another workspace (for example opening Parameters).
                        if (wasShowingStartPage) {
                            mainWindow._syncStartPageVisibility()
                        } else if (!_isConnected) {
                            _appendEvent(qsTr("当前没有可用的已连接飞行器，保持在当前工作区"))
                        }
                    }

                    function _connectSelected(enterWorkspace = true) {
                        if (!_linkManager) {
                            _appendEvent(qsTr("链路管理器不可用"))
                            return
                        }

                        if (_pendingReconnectAfterCleanup) {
                            _appendEvent(qsTr("正在等待上一次连接释放"))
                            return
                        }

                        if (_isConnected && !_activeVehicleParametersReady()) {
                            _appendEvent(qsTr("参数仍在读取，保持当前连接并进入工作区"))
                            _enterWorkspaceFromActiveLink(enterWorkspace)
                            return
                        }

                        _syncConnectionState(false)

                        if (_isConnected) {
                            mainWindow._hadConnectedVehicleSession = true
                            if (enterWorkspace) {
                                _appendEvent(qsTr("进入工作区"))
                                mainWindow._ensureMainInterfaceAccess(mainWindow._flyTabIndex, true)
                            } else {
                                _appendEvent(qsTr("飞行器链路已连接"))
                            }
                            return
                        }

                        if (_manualConnectionArmed && _connectingConfig && _connectingConfig.link) {
                            _beginConnectionProgress(_connectingConfig)
                            _appendEvent(qsTr("正在等待当前连接尝试完成..."))
                            return
                        }

                        if (_hasActiveTemporaryLink()) {
                            _requestReconnectAfterCleanup(qsTr("正在关闭上一次临时链路，随后将按当前设置重新连接..."))
                            return
                        }

                        if (_shouldWaitForSerialAutoConnect()) {
                            _beginConnectionProgress(null)
                            _appendEvent(qsTr("检测到飞控串口，等待地面站自动连接..."))
                            return
                        }

                        const cfg = _chooseConnectionConfig()

                        if (!cfg) {
                            _refreshSerialSelectionAfterConnectionFailure()
                            _appendEvent(qsTr("没有可用的链路或串口"))
                            return
                        }

                        if (cfg.mavlinkVersion !== undefined && cfg.mavlinkVersion !== null) {
                            cfg.mavlinkVersion = _startPageInitialMavlinkVersion
                        }
                        _applyStartPagePersistentSettings(cfg)
                        _beginConnectionProgress(cfg)
                        _appendEvent((enterWorkspace ? qsTr("正在使用 %1 连接...") : qsTr("正在测试 %1 ...")).arg(cfg.name))
                        _linkManager.createConnectedLink(cfg)
                    }

                    function _startDemo() {
                        QGroundControl.startPX4MockLink(false, false, false)
                        _appendEvent(qsTr("正在启动演示飞行器..."))
                    }

                    ListModel {
                        id: startEventLogModel
                    }

                    Timer {
                        id: startSerialDetectionTimer
                        interval: 1200
                        repeat: true
                        running: startPageOverlay.visible
                                 && !startPageOverlay._connectionInProgress
                                 && !startPageOverlay._isConnected

                        onTriggered: startPageOverlay._refreshSerialSelectionFromDetection(true)
                    }

                    Timer {
                        id: startConnectionProgressTimer
                        interval: 250
                        repeat: true
                        running: startPageOverlay._connectionInProgress

                        onTriggered: {
                            if (startPageOverlay._pendingWorkspaceEntry) {
                                return
                            }

                            startPageOverlay._connectionElapsedMs += interval
                            if (startPageOverlay._connectionElapsedMs >= startPageOverlay._connectionTimeoutMs) {
                                const wasUdpConnection = startPageOverlay._connectingConfig
                                    && startPageOverlay._connectingConfig.linkType === LinkConfiguration.TypeUdp
                                const waitingForAutoConnect = !startPageOverlay._connectingConfig
                                startPageOverlay._timeoutConnectionProgress()
                                if (waitingForAutoConnect) {
                                    startPageOverlay._refreshSerialSelectionAfterConnectionFailure()
                                    if (startPageOverlay._linkManager) {
                                        startPageOverlay._linkManager.clearDeferredCommunicationError()
                                    }
                                    startPageOverlay._statusText = qsTr("仍在等待地面站自动连接飞控，请确认飞控已启动并正在发送 MAVLink 心跳")
                                    startPageOverlay._recentConnectionText = startPageOverlay._statusText
                                    startPageOverlay._appendEvent(qsTr("尚未收到 MAVLink 心跳，继续等待自动连接"))
                                    return
                                }
                                const failureText = wasUdpConnection
                                    ? qsTr("连接失败：UDP 未收到 MAVLink 心跳，请确认仿真或飞控正在发送数据。")
                                    : qsTr("连接失败：未收到 MAVLink 心跳，可能是飞控仍在重启、波特率不匹配或飞控暂未发送数据。")
                                startPageOverlay._appendEvent(failureText)
                                const portChanged = wasUdpConnection ? false : startPageOverlay._refreshSerialSelectionAfterConnectionFailure()
                                const serialPortMissing = !wasUdpConnection && startPageOverlay._selectedSerialPortName() === ""
                                startPageOverlay._statusText = failureText
                                startPageOverlay._recentConnectionText = failureText
                                if (startPageOverlay._linkManager) {
                                    if (portChanged || serialPortMissing) {
                                        startPageOverlay._linkManager.clearDeferredCommunicationError()
                                    } else {
                                        startPageOverlay._linkManager.showDeferredCommunicationError()
                                    }
                                }
                                if (!serialPortMissing) {
                                    startPageOverlay._showConnectionFailure(failureText)
                                } else {
                                    startPageOverlay._appendEvent(qsTr("飞控串口暂未重新枚举，保持开始页等待检测"))
                                    startPageOverlay._statusText = qsTr("飞控重启中或 USB 暂未枚举，检测到串口后请重新连接")
                                    startPageOverlay._recentConnectionText = startPageOverlay._statusText
                                }
                                return
                            }

                            const progressRange = 0.84
                            startPageOverlay._connectionProgress = Math.min(0.92, 0.08 + (startPageOverlay._connectionElapsedMs / startPageOverlay._connectionTimeoutMs) * progressRange)
                        }
                    }

                    Timer {
                        id: startReconnectCleanupTimer
                        interval: 250
                        repeat: true

                        onTriggered: {
                            startPageOverlay._cleanupElapsedMs += interval
                            startPageOverlay._syncConnectionState(false)

                            if (!startPageOverlay._isConnected
                                    && startPageOverlay._cleanupLinksReleased()
                                    && startPageOverlay._cleanupElapsedMs >= startPageOverlay._cleanupMinimumWaitMs) {
                                stop()
                                startPageOverlay._pendingReconnectAfterCleanup = false
                                startPageOverlay._cleanupElapsedMs = 0
                                startPageOverlay._clearCleanupLinkRefs()
                                startPageOverlay._appendEvent(qsTr("上一次连接已关闭，使用当前设置重新连接"))
                                startPageOverlay._connectSelected()
                                return
                            }

                            if (startPageOverlay._cleanupElapsedMs >= startPageOverlay._cleanupTimeoutMs) {
                                stop()
                                startPageOverlay._pendingReconnectAfterCleanup = false
                                startPageOverlay._cleanupElapsedMs = 0
                                startPageOverlay._clearCleanupLinkRefs()
                                startPageOverlay._statusText = qsTr("上一次连接仍在释放中，请稍后重新连接")
                                startPageOverlay._recentConnectionText = startPageOverlay._statusText
                                startPageOverlay._appendEvent(startPageOverlay._statusText)
                            }
                        }
                    }

                    Timer {
                        id: startPageDisconnectConfirmTimer
                        interval: 8000
                        repeat: false

                        onTriggered: startPageOverlay._finishStartPageDisconnectConfirm()
                    }

                    Timer {
                        id: startConnectionCompleteTimer
                        interval: 450
                        repeat: false

                        onTriggered: {
                            if (!startPageOverlay._pendingWorkspaceEntry) {
                                return
                            }

                            if (!mainWindow._hasAnyConnectedVehicle()) {
                                startPageOverlay._resetConnectionUiState()
                                mainWindow._handleVehicleDisconnected("")
                                return
                            }

                            startPageOverlay._manualConnectionState = startPageOverlay._connectionStateIdle
                            startPageOverlay._manualConnectionArmed = false
                            startPageOverlay._connectingConfig = null
                            if (mainWindow._showStartPage) {
                                startPageOverlay._appendEvent(qsTr("进入工作区"))
                                mainWindow._ensureMainInterfaceAccess(mainWindow._flyTabIndex, true)
                            }
                            if (startPageOverlay._linkManager) {
                                startPageOverlay._linkManager.communicationErrorDisplayPaused = false
                                startPageOverlay._linkManager.showDeferredCommunicationError()
                            }
                            startPageOverlay._pendingWorkspaceEntry = false
                        }
                    }

                    Component.onCompleted: {
                        _setStartPageAutoConnectPaused(visible)
                        _refreshLinks()
                        _autoConnectOnBoot = false
                        _removeStartPageAutoConnectConfig()
                        _appendEvent(qsTr("开始页已初始化"))
                        _refreshSerialSelectionFromDetection(false)
                        _syncConnectionState(false)
                    }

                    onVisibleChanged: {
                        _setStartPageAutoConnectPaused(visible)
                        if (visible) {
                            _refreshLinks()
                            _autoConnectOnBoot = false
                            _removeStartPageAutoConnectConfig()
                            _refreshSerialSelectionFromDetection(false)
                            _syncConnectionState(false)
                        } else if (_linkManager && !_pendingWorkspaceEntry) {
                            _linkManager.clearDeferredCommunicationError()
                            _linkManager.communicationErrorDisplayPaused = false
                        }
                    }

                    Connections {
                        target: startPageOverlay._linkManager
                        ignoreUnknownSignals: true

                        function onCommPortsChanged() {
                            startPageOverlay._refreshSerialSelectionFromDetection(true, false)
                        }

                        function onCommPortStringsChanged() {
                            startPageOverlay._refreshSerialSelectionFromDetection(true, false)
                        }
                    }

                    Connections {
                        target: QGroundControl.multiVehicleManager
                        ignoreUnknownSignals: true
                        function onActiveVehicleChanged(activeVehicle) {
                            if (!activeVehicle && startPageOverlay._manualConnectionState === startPageOverlay._connectionStateConnecting) {
                                return
                            }
                            if (activeVehicle) {
                                criticalVehicleMessageModel.clear()
                                activeVehicle.resetErrorLevelMessages()
                            }
                            startPageOverlay._syncConnectionState()
                        }
                        function onVehicleAdded(vehicle) {
                            mainWindow._clearVehicleDisconnectNotice()
                            criticalVehicleMessageModel.clear()
                            if (vehicle) {
                                vehicle.resetErrorLevelMessages()
                            }
                            startPageOverlay._syncConnectionState()
                        }
                        function onVehicleRemoved(vehicle) {
                            const vehicleId = vehicle && vehicle.id !== undefined && vehicle.id !== null ? vehicle.id : ""
                            if (startPageOverlay._handleDisconnectDuringManualConnection(vehicleId)) {
                                return
                            }
                            startPageOverlay._resetConnectionUiState()
                            startPageOverlay._syncConnectionState()
                            if (!mainWindow._showStartPage) {
                                mainWindow._handleVehicleDisconnected(vehicleId)
                            }
                        }
                    }

                    Connections {
                        target: startPageOverlay._activeVehicle ? startPageOverlay._activeVehicle.parameterManager : null
                        ignoreUnknownSignals: true

                        function onParametersReadyChanged(parametersReady) {
                            if (parametersReady) {
                                startPageOverlay._tryFinishAfterParametersReady()
                            }
                        }

                        function onMissingParametersChanged(missingParameters) {
                            startPageOverlay._tryFinishAfterParametersReady()
                        }
                    }

                    Instantiator {
                        model: QGroundControl.multiVehicleManager.vehicles

                        delegate: Connections {
                            required property var object

                            target: object && object.vehicleLinkManager ? object.vehicleLinkManager : null
                            ignoreUnknownSignals: true

                            function onCommunicationLostChanged(communicationLost) {
                                if (communicationLost) {
                                    const vehicleId = object && object.id !== undefined && object.id !== null ? object.id : ""
                                    if (startPageOverlay._handleDisconnectDuringManualConnection(vehicleId)) {
                                        return
                                    }
                                }

                                startPageOverlay._syncConnectionState()
                                if (communicationLost) {
                                    const vehicleId = object && object.id !== undefined && object.id !== null ? object.id : ""
                                    if (mainWindow._showStartPage) {
                                        startPageOverlay._beginStartPageDisconnectConfirm(vehicleId)
                                        return
                                    }
                                    startPageOverlay._resetConnectionUiState()
                                    if (!mainWindow._showStartPage) {
                                        mainWindow._handleVehicleDisconnected(vehicleId)
                                    }
                                } else {
                                    if (startPageOverlay._startPageDisconnectPending) {
                                        startPageDisconnectConfirmTimer.stop()
                                        startPageOverlay._finishStartPageDisconnectConfirm()
                                    }
                                    mainWindow._clearVehicleDisconnectNotice()
                                }
                            }
                        }
                    }

                    QGCPopupDialogFactory {
                        id: startPageLinkDialogFactory

                        dialogComponent: startPageLinkDialogComponent
                    }

                    Component {
                        id: startPageLinkDialogComponent

                        QGCPopupDialog {
                            id: startPageLinkDialog
                            title:                  ""
                            buttons:                0
                            maxContentAvailableWidth: Math.min(mainWindow.width - (ScreenTools.defaultFontPixelWidth * 8), ScreenTools.defaultFontPixelWidth * 64)
                            maxContentAvailableHeight: mainWindow.height - (ScreenTools.defaultFontPixelHeight * 8)

                            property var originalConfig
                            property var editingConfig
                            readonly property real _dialogContentWidth: ScreenTools.defaultFontPixelWidth * 46
                            readonly property real _fieldLabelWidth: ScreenTools.defaultFontPixelWidth * 15
                            readonly property real _sectionSpacing: ScreenTools.defaultFontPixelHeight * 0.8
                            readonly property real _cardPadding: ScreenTools.defaultFontPixelHeight * 0.9
                            readonly property real _buttonHeight: ScreenTools.defaultFontPixelHeight * 1.8
                            readonly property bool _canSave: nameField.text.trim() !== ""
                            readonly property bool _showLinkParameters: editingConfig
                                                                       && editingConfig.linkType !== LinkConfiguration.TypeSerial
                                                                       && _settingsSource(editingConfig) !== ""

                            QGCPopupStyle { id: popupStyle }

                            function _settingsSource(config) {
                                if (!config || !config.settingsURL) {
                                    return ""
                                }

                                return Qt.resolvedUrl("AppSettings/" + config.settingsURL)
                            }

                            function _saveDialog() {
                                if (!_canSave) {
                                    return
                                }

                                if (linkSettingsLoader.item && typeof linkSettingsLoader.item.saveSettings === "function") {
                                    linkSettingsLoader.item.saveSettings()
                                }
                                editingConfig.name = nameField.text
                                const savedConfigName = editingConfig.name
                                if (originalConfig) {
                                    startPageOverlay._linkManager.endConfigurationEditing(originalConfig, editingConfig)
                                } else {
                                    editingConfig.dynamic = false
                                    startPageOverlay._linkManager.endCreateConfiguration(editingConfig)
                                }
                                startPageOverlay._refreshLinks()
                                startPageOverlay._selectLinkConfigByName(savedConfigName)
                                startPageOverlay._appendEvent(qsTr("已添加链路配置“%1”").arg(savedConfigName))
                                close()
                            }

                            function _cancelDialog() {
                                startPageOverlay._linkManager.cancelConfigurationEditing(editingConfig)
                                close()
                            }

                            ColumnLayout {
                                width: startPageLinkDialog._dialogContentWidth
                                spacing: startPageLinkDialog._sectionSpacing

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: headerLayout.implicitHeight + (startPageLinkDialog._cardPadding * 2)
                                    color: popupStyle.popupBackground
                                    radius: popupStyle.cornerRadius
                                    border.width: 1
                                    border.color: popupStyle.borderColor

                                    ColumnLayout {
                                        id: headerLayout
                                        anchors.fill: parent
                                        anchors.margins: startPageLinkDialog._cardPadding
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.35

                                        QGCLabel {
                                            Layout.fillWidth: true
                                    text: originalConfig ? qsTr("编辑链路") : qsTr("新增链路")
                                            color: popupStyle.primaryTextColor
                                            font.pointSize: ScreenTools.defaultFontPointSize + 2
                                            font.bold: true
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                    text: qsTr("创建并配置通信链路配置。")
                                            color: popupStyle.secondaryTextColor
                                            font.pointSize: ScreenTools.defaultFontPointSize - 1
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth:   true
                                    implicitHeight:     dialogForm.implicitHeight + (startPageLinkDialog._cardPadding * 2)
                                    color:              popupStyle.panelBackground
                                    radius:             popupStyle.cornerRadius
                                    border.width:       1
                                    border.color:       popupStyle.borderColor

                                    ColumnLayout {
                                        id: dialogForm
                                        anchors.fill: parent
                                        anchors.margins: startPageLinkDialog._cardPadding
                                        spacing: startPageLinkDialog._sectionSpacing

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: ScreenTools.defaultFontPixelWidth

                                            QGCLabel {
                                                Layout.preferredWidth: startPageLinkDialog._fieldLabelWidth
                                text: qsTr("名称")
                                                color: popupStyle.primaryTextColor
                                                font.pointSize: ScreenTools.defaultFontPointSize
                                            }

                                            QGCTextField {
                                                id:                 nameField
                                                Layout.fillWidth:   true
                                                text:               editingConfig.name
                                placeholderText:    qsTr("输入名称")
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
                            text:               qsTr("启动时自动连接")
                                            checked:            editingConfig.autoConnect
                                            onCheckedChanged:   editingConfig.autoConnect = checked
                                            textColor:          popupStyle.primaryTextColor
                                            trackColor:         popupStyle.secondaryButtonColor
                                            trackOnColor:       popupStyle.accentColor
                                            trackBorderColor:   popupStyle.borderColor
                                            handleColor:        popupStyle.primaryTextColor
                                        }

                                        QGCCheckBoxSlider {
                                            Layout.fillWidth:   true
                            text:               qsTr("高延迟")
                                            checked:            editingConfig.highLatency
                                            onCheckedChanged:   editingConfig.highLatency = checked
                                            textColor:          popupStyle.primaryTextColor
                                            trackColor:         popupStyle.secondaryButtonColor
                                            trackOnColor:       popupStyle.accentColor
                                            trackBorderColor:   popupStyle.borderColor
                                            handleColor:        popupStyle.primaryTextColor
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 1
                                            color: popupStyle.borderColor
                                            opacity: 0.8
                                        }

                                        LabelledComboBox {
                                            Layout.fillWidth:       true
                            label:                  qsTr("类型")
                                            comboBoxPreferredWidth: ScreenTools.defaultFontPixelWidth * 18
                                            enabled:                originalConfig == null
                                            model:                  startPageOverlay._linkManager.linkTypeStrings
                                            Component.onCompleted:  comboBox.currentIndex = editingConfig.linkType

                                            onActivated: (index) => {
                                                if (index !== editingConfig.linkType) {
                                                    const name = nameField.text
                                                    editingConfig = startPageOverlay._linkManager.createConfiguration(index, name)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            visible: startPageLinkDialog._showLinkParameters
                                            implicitHeight: linkSettingsLayout.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.4)
                                            color: popupStyle.inputBackground
                                            radius: popupStyle.cornerRadius
                                            border.width: 1
                                            border.color: popupStyle.borderColor

                                            ColumnLayout {
                                                id: linkSettingsLayout
                                                anchors.fill: parent
                                                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.7
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.55

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    text: qsTr("链路参数")
                                                    color: popupStyle.secondaryTextColor
                                                    font.pointSize: ScreenTools.defaultFontPointSize - 1
                                                    font.bold: true
                                                }

                                                Loader {
                                                    id:     linkSettingsLoader
                                                    Layout.fillWidth: true
                                                    source: startPageLinkDialog._settingsSource(editingConfig)
                                                    asynchronous: true

                                                    property var subEditConfig:         editingConfig
                                                    property int _firstColumnWidth:     startPageLinkDialog._fieldLabelWidth
                                                    property int _secondColumnWidth:    ScreenTools.defaultFontPixelWidth * 24
                                                    property int _rowSpacing:           ScreenTools.defaultFontPixelHeight / 2
                                                    property int _colSpacing:           ScreenTools.defaultFontPixelWidth / 2

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

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: footerLayout.implicitHeight + (startPageLinkDialog._cardPadding * 2)
                                    color: popupStyle.popupBackground
                                    radius: popupStyle.cornerRadius
                                    border.width: 1
                                    border.color: popupStyle.borderColor

                                    ColumnLayout {
                                        id: footerLayout
                                        anchors.fill: parent
                                        anchors.margins: startPageLinkDialog._cardPadding
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.5

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: qsTr("当内容高于屏幕时，对话框会保持居中并自动变为可滚动。")
                                            color: popupStyle.secondaryTextColor
                                            font.pointSize: ScreenTools.defaultFontPointSize - 2
                                            wrapMode: Text.WordWrap
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.75

                                            Item { Layout.fillWidth: true }

                                            QGCButton {
                                                text: qsTr("取消")
                                                Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 9, implicitWidth + (ScreenTools.defaultFontPixelWidth * 2))
                                                Layout.minimumWidth: Layout.preferredWidth
                                                Layout.preferredHeight: startPageLinkDialog._buttonHeight
                                                onClicked: startPageLinkDialog._cancelDialog()
                                            }

                                            QGCButton {
                                                text: qsTr("保存")
                                                primary: true
                                                enabled: startPageLinkDialog._canSave
                                                Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 9, implicitWidth + (ScreenTools.defaultFontPixelWidth * 2))
                                                Layout.minimumWidth: Layout.preferredWidth
                                                Layout.preferredHeight: startPageLinkDialog._buttonHeight
                                                onClicked: startPageLinkDialog._saveDialog()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width * 0.90, ScreenTools.defaultFontPixelWidth * 144)
                        height: Math.min(parent.height * 0.88, ScreenTools.defaultFontPixelHeight * 53)
                        radius: startPageOverlay._uiRadius
                        color: "transparent"
                        border.color: startPageOverlay._borderColor
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.85
                            spacing: ScreenTools.defaultFontPixelHeight * 0.7

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 7
                                radius: startPageOverlay._uiRadius
                                color: startPageOverlay._cardBg
                                border.color: startPageOverlay._borderColor
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.9

                                    QGCColoredImage {
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.0
                                        Layout.preferredHeight: Layout.preferredWidth
                                        source: "/qmlimages/PaperPlane.svg"
                                        color: "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.2
                                        QGCLabel { text: "BTFW-GCS"; color: startPageOverlay._primaryText; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontTitle; font.weight: Font.DemiBold }
                                        QGCLabel { text: qsTr("开始 - 专业连接与遥测工作区"); color: startPageOverlay._secondaryText; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontSubtitle }
                                    }

                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.7

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: parent.width * 0.66
                                    radius: startPageOverlay._uiRadius
                                    color: startPageOverlay._cardBg
                                    border.color: startPageOverlay._borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.9
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.62
                                        QGCLabel { text: qsTr("连接设置"); color: startPageOverlay._primaryText; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontSectionTitle; font.weight: Font.DemiBold }
                                        Item { Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1 }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.6
                                            QGCLabel { text: qsTr("链路"); color: startPageOverlay._primaryText; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * startPageOverlay._leftFieldLabelWidth; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontFieldLabel }
                                            QGCComboBox {
                                                Layout.fillWidth: true
                                                sizeToContents: true
                                                model: startPageOverlay._availableLinkNames.length > 0 ? startPageOverlay._availableLinkNames : [qsTr("无可用链路")]
                                                currentIndex: startPageOverlay._selectedLinkIndex >= 0 ? startPageOverlay._selectedLinkIndex : 0
                                                enabled: startPageOverlay._availableLinkNames.length > 0
                                                font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                backgroundColor: startPageOverlay._inputBg
                                                borderColor: startPageOverlay._borderColor
                                                focusBorderColor: startPageOverlay._focusColor
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                showFocusBorder: true
                                                borderRadius: startPageOverlay._uiRadius
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onActivated: {
                                                    startPageOverlay._selectedLinkIndex = index
                                                    startPageOverlay._linkSelectionLocked = true
                                                    startPageOverlay._syncSelectedLinkSettings()
                                                    startPageOverlay._connectionSettingChanged(qsTr("链路设置已更新，请重新连接"))
                                                }
                                            }
                                            QGCButton {
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6.0
                                                text: qsTr("新增")
                                                horizontalAlignment: Text.AlignHCenter
                                                pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                showBorder: true
                                                backRadius: startPageOverlay._uiRadius
                                                borderColor: startPageOverlay._borderColor
                                                backgroundColor: pressed ? startPageOverlay._secondaryBtnPressed : (hovered ? startPageOverlay._secondaryBtnHover : startPageOverlay._secondaryBtn)
                                                textColor: startPageOverlay._primaryText
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onClicked: startPageOverlay._openAddLinkDialog()
                                            }
                                            QGCButton {
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 9.5
                                                text: qsTr("刷新")
                                                horizontalAlignment: Text.AlignHCenter
                                                pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                showBorder: true
                                                backRadius: startPageOverlay._uiRadius
                                                borderColor: startPageOverlay._borderColor
                                                backgroundColor: !enabled ? startPageOverlay._secondaryBtn : (pressed ? startPageOverlay._secondaryBtnPressed : (hovered ? startPageOverlay._secondaryBtnHover : startPageOverlay._secondaryBtn))
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onClicked: startPageOverlay._refreshLinks()
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.6
                                            QGCLabel { text: qsTr("端口"); color: startPageOverlay._primaryText; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * startPageOverlay._leftFieldLabelWidth; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontFieldLabel }
                                            QGCComboBox {
                                                id: serialPortCombo
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16
                                                sizeToContents: true
                                                model: startPageOverlay._serialPortDisplayNames.length > 0 ? startPageOverlay._serialPortDisplayNames : ["COM4"]
                                                currentIndex: startPageOverlay._selectedSerialPortIndex >= 0 ? startPageOverlay._selectedSerialPortIndex : 0
                                                enabled: startPageOverlay._serialPortAvailable
                                                font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                backgroundColor: startPageOverlay._inputBg
                                                borderColor: startPageOverlay._borderColor
                                                focusBorderColor: startPageOverlay._focusColor
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                showFocusBorder: true
                                                borderRadius: startPageOverlay._uiRadius
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onActivated: {
                                                    startPageOverlay._selectedSerialPortIndex = index
                                                    startPageOverlay._linkSelectionLocked = false
                                                    startPageOverlay._serialPortSelectionLocked = true
                                                    startPageOverlay._connectionSettingChanged(qsTr("串口已更新，请重新连接"))
                                                }
                                            }
                                            QGCButton {
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8.4
                                                text: qsTr("刷新")
                                                horizontalAlignment: Text.AlignHCenter
                                                pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                showBorder: true
                                                backRadius: startPageOverlay._uiRadius
                                                borderColor: startPageOverlay._borderColor
                                                backgroundColor: !enabled ? startPageOverlay._secondaryBtn : (pressed ? startPageOverlay._secondaryBtnPressed : (hovered ? startPageOverlay._secondaryBtnHover : startPageOverlay._secondaryBtn))
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onClicked: {
                                                    const previousPortName = startPageOverlay._selectedSerialPortName()
                                                    const previousDisplayName = startPageOverlay._selectedSerialPortDisplayName()
                                                    startPageOverlay._refreshSerialSelection(true, previousPortName, previousDisplayName)
                                                    if (previousPortName !== "" && startPageOverlay._selectedSerialPortName() === previousPortName) {
                                                        startPageOverlay._serialPortSelectionLocked = true
                                                    }
                                                    if (serialPortCombo.enabled) {
                                                        startPageOverlay._appendEvent(qsTr("串口列表已刷新"))
                                                    } else {
                                                        startPageOverlay._appendEvent(qsTr("未检测到串口"))
                                                    }
                                                }
                                            }
                                            QGCCheckBox {
                                                Layout.fillWidth: true
                                                visible: false
                                                text: qsTr("启动时自动连接")
                                                textFontPointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                boxBackgroundColor: startPageOverlay._inputBg
                                                boxBorderColor: startPageOverlay._borderColor
                                                checkColor: startPageOverlay._focusColor
                                                hoverColor: startPageOverlay._focusColor
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                checked: false
                                                onToggled: {
                                                    startPageOverlay._autoConnectOnBoot = false
                                                    startPageOverlay._removeStartPageAutoConnectConfig()
                                                }
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.6
                                            QGCLabel { text: qsTr("波特率"); color: startPageOverlay._primaryText; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * startPageOverlay._leftFieldLabelWidth; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontFieldLabel }
                                            QGCComboBox {
                                                id: baudRateCombo
                                                Layout.fillWidth: true
                                                sizeToContents: true
                                                model: {
                                                    const baudRates = (startPageOverlay._linkManager && ScreenTools.isSerialAvailable)
                                                        ? startPageOverlay._linkManager.serialBaudRates
                                                        : []
                                                    const filteredRates = []

                                                    for (let i = 0; i < baudRates.length; i++) {
                                                        const baud = parseInt(baudRates[i])
                                                        if (!isNaN(baud) && baud >= 1200) {
                                                            filteredRates.push(baudRates[i])
                                                        }
                                                    }

                                                    return filteredRates.length > 0 ? filteredRates : ["1200"]
                                                }
                                                currentIndex: {
                                                    const baudText = "" + startPageOverlay._selectedBaudRate
                                                    const idx = model.indexOf(baudText)
                                                    return idx >= 0 ? idx : 0
                                                }
                                                font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                backgroundColor: startPageOverlay._inputBg
                                                borderColor: startPageOverlay._borderColor
                                                focusBorderColor: startPageOverlay._focusColor
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                showFocusBorder: true
                                                borderRadius: startPageOverlay._uiRadius
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onActivated: {
                                                    const baud = parseInt(currentText)
                                                    if (!isNaN(baud) && baud > 0) {
                                                        startPageOverlay._selectedBaudRate = baud
                                                        startPageOverlay._connectionSettingChanged(qsTr("波特率已更新，请重新连接"))
                                                    }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.6
                                            QGCLabel { text: qsTr("数据 / 停止位"); color: startPageOverlay._primaryText; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * startPageOverlay._leftFieldLabelWidth; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontFieldLabel }
                                            QGCComboBox { Layout.fillWidth: true; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10; sizeToContents: true; model: [qsTr("数据 5"), qsTr("数据 6"), qsTr("数据 7"), qsTr("数据 8")]; currentIndex: Math.max(0, Math.min(3, startPageOverlay._selectedDataBits - 5)); font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale; backgroundColor: startPageOverlay._inputBg; borderColor: startPageOverlay._borderColor; focusBorderColor: startPageOverlay._focusColor; textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText; showFocusBorder: true; borderRadius: startPageOverlay._uiRadius; stateAnimationDuration: startPageOverlay._uiAnimMs; onActivated: (index) => { startPageOverlay._selectedDataBits = index + 5; startPageOverlay._connectionSettingChanged(qsTr("串口参数已更新，请重新连接")) } }
                                            QGCComboBox { Layout.fillWidth: true; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 9; sizeToContents: true; model: [qsTr("停止 1"), qsTr("停止 2")]; currentIndex: Math.max(0, Math.min(1, startPageOverlay._selectedStopBits - 1)); font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale; backgroundColor: startPageOverlay._inputBg; borderColor: startPageOverlay._borderColor; focusBorderColor: startPageOverlay._focusColor; textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText; showFocusBorder: true; borderRadius: startPageOverlay._uiRadius; stateAnimationDuration: startPageOverlay._uiAnimMs; onActivated: (index) => { startPageOverlay._selectedStopBits = index + 1; startPageOverlay._connectionSettingChanged(qsTr("串口参数已更新，请重新连接")) } }
                                            QGCComboBox { Layout.fillWidth: true; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 11; sizeToContents: true; model: [qsTr("无奇偶"), qsTr("奇"), qsTr("偶")]; currentIndex: startPageOverlay._selectedParity === 3 ? 1 : (startPageOverlay._selectedParity === 2 ? 2 : 0); font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale; backgroundColor: startPageOverlay._inputBg; borderColor: startPageOverlay._borderColor; focusBorderColor: startPageOverlay._focusColor; textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText; showFocusBorder: true; borderRadius: startPageOverlay._uiRadius; stateAnimationDuration: startPageOverlay._uiAnimMs; onActivated: (index) => { startPageOverlay._selectedParity = index === 1 ? 3 : (index === 2 ? 2 : 0); startPageOverlay._connectionSettingChanged(qsTr("串口参数已更新，请重新连接")) } }
                                        }
                                        Item {
                                            Layout.fillHeight: true
                                            Layout.minimumHeight: 0
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 5.0
                                            Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 4.6
                                            spacing: ScreenTools.defaultFontPixelHeight * 0.35

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.0
                                                text: startPageOverlay._recentConnectionText
                                                color: startPageOverlay._secondaryText
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontMeta
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.34
                                                opacity: startPageOverlay._connectionInProgress ? 1 : 0
                                                radius: height / 2
                                                color: startPageOverlay._inputBg
                                                border.width: 1
                                                border.color: startPageOverlay._borderColor

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 1
                                                    width: Math.max(height, (parent.width - 2) * startPageOverlay._connectionProgress)
                                                    radius: height / 2
                                                    color: startPageOverlay._focusColor
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.55

                                                QGCButton {
                                                    Layout.fillWidth: true
                                                    text: startPageOverlay._isConnected ? qsTr("进入工作区") : (startPageOverlay._connectionInProgress ? qsTr("连接中...") : qsTr("连接飞行器"))
                                                    pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                    enabled: startPageOverlay._canConnect
                                                    showBorder: true
                                                    backRadius: startPageOverlay._uiRadius
                                                    borderColor: startPageOverlay._borderColor
                                                    backgroundColor: !enabled ? startPageOverlay._secondaryBtn : (pressed ? startPageOverlay._primaryBtnPressed : (hovered ? startPageOverlay._primaryBtnHover : startPageOverlay._primaryBtn))
                                                    textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                    stateAnimationDuration: startPageOverlay._uiAnimMs
                                                    onClicked: startPageOverlay._connectSelected()
                                                }
                                                QGCButton {
                                                    Layout.fillWidth: true
                                                    text: qsTr("离线访问")
                                                    pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                    enabled: true
                                                    showBorder: true
                                                    backRadius: startPageOverlay._uiRadius
                                                    borderColor: startPageOverlay._borderColor
                                                    backgroundColor: !enabled ? startPageOverlay._secondaryBtn : (pressed ? startPageOverlay._secondaryBtnPressed : (hovered ? startPageOverlay._secondaryBtnHover : startPageOverlay._secondaryBtn))
                                                    textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                    stateAnimationDuration: startPageOverlay._uiAnimMs
                                                    onClicked: {
                                                        if (startPageOverlay._connectionInProgress) {
                                                            startPageOverlay._timeoutConnectionProgress()
                                                        }
                                                        startPageOverlay._openWorkspaceTab(mainWindow._planTabIndex)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: parent.width * 0.34
                                    radius: startPageOverlay._uiRadius
                                    color: startPageOverlay._cardBg
                                    border.color: startPageOverlay._borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.9
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.62

                                        RowLayout {
                                            Layout.fillWidth: true
                                            QGCLabel { text: qsTr("事件日志"); color: startPageOverlay._primaryText; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontRightTitle; font.weight: Font.DemiBold }
                                            Item { Layout.fillWidth: true }
                                            QGCButton {
                                                text: qsTr("清空日志")
                                                pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontRightButtonScale
                                                showBorder: true
                                                backRadius: startPageOverlay._uiRadius
                                                borderColor: startPageOverlay._borderColor
                                                backgroundColor: !enabled ? startPageOverlay._secondaryBtn : (pressed ? startPageOverlay._secondaryBtnPressed : (hovered ? startPageOverlay._secondaryBtnHover : startPageOverlay._secondaryBtn))
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onClicked: startEventLogModel.clear()
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 10
                                            radius: startPageOverlay._uiRadius
                                            color: startPageOverlay._inputBg
                                            border.color: startPageOverlay._borderColor
                                            border.width: 1
                                            clip: true

                                            ListView {
                                                anchors.fill: parent
                                                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.55
                                                model: startEventLogModel
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.35
                                                delegate: RowLayout {
                                                    width: ListView.view.width
                                                    QGCLabel { text: "[" + model.timestamp + "]"; color: startPageOverlay._secondaryText; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10.5; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontRightLogTime }
                                                    QGCLabel { text: model.message; color: startPageOverlay._primaryText; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontRightLogMessage }
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
        }

        Rectangle {
            id:                 topNavigationSeparator
            visible:            !mainWindow._showStartPage
                                && mainViewTabBar
                                && (mainViewTabBar.currentIndex === _flyTabIndex)
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        topNavigationBar.bottom
            height:             Math.max(6, Math.round(ScreenTools.defaultFontPixelHeight * 0.38))
            color:              qgcPal.windowShadeDark
            opacity:            0.92
            z:                  1000
        }
    }

    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    MessageDialog {
        id:                 showTouchAreasNotification
        title:              qsTr("Debug Touch Areas")
        text:               qsTr("Touch Area display toggled")
        buttons:            MessageDialog.Ok
    }

    MessageDialog {
        id:                 advancedModeOnConfirmation
        title:              qsTr("Advanced Mode")
        text:               QGroundControl.corePlugin.showAdvancedUIMessage
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = true
            }
        }
    }

    MessageDialog {
        id:                 advancedModeOffConfirmation
        title:              qsTr("Advanced Mode")
        text:               qsTr("Turn off Advanced Mode?")
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = false
            }
        }
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null)
        }
    }

    // Toast notification shown when a view switch is blocked by a validation error
    ToolTip {
        id:             validationErrorToast
        x:              (mainWindow.width - width) / 2
        y:              mainWindow.height - height - ScreenTools.defaultFontPixelHeight * 3
        timeout:        3000
        closePolicy:    Popup.NoAutoClose
        text:           qsTr("Please correct the invalid value before continuing")

        background: Rectangle {
            color:  qgcPal.alertBackground
            radius: ScreenTools.defaultFontPixelWidth / 2
        }

        contentItem: QGCLabel {
            text:   validationErrorToast.text
            color:  qgcPal.alertText
        }
    }

    Component {
        id: toolSelectComponent

        SelectViewDropdown {
        }
    }

    Rectangle {
        id:             toolDrawer
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: _showUnderMainNavigation ? topNavigationBar.height : 0
        visible:        false
        color:          qgcPal.window

        property var backIcon
        property string toolTitle
        property alias toolSource:  toolDrawerLoader.source
        property var toolIcon
        property bool compactHeader: false
        readonly property bool _isSettingsTool: toolDrawer.toolSource
                                               && toolDrawer.toolSource.toString().indexOf("AppSettings.qml") !== -1
        readonly property bool _showUnderMainNavigation: !mainWindow._showStartPage
                                                         && (toolDrawer.toolSource === "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml")

        onVisibleChanged: {
            if (!toolDrawer.visible) {
                toolDrawerLoader.source = ""
                toolDrawer.compactHeader = false
            }
        }

        // This need to block click event leakage to underlying map.
        DeadMouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id:             toolDrawerToolbar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         ScreenTools.toolbarHeight
            color:          qgcPal.toolbarBackground

            RowLayout {
                id:                 toolDrawerToolbarLayout
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                spacing:            ScreenTools.defaultFontPixelWidth

                QGCToolBarButton {
                    id: qgcButton
                    height: parent.height
                    icon.source: toolDrawer.compactHeader
                                 ? (toolDrawer._isSettingsTool
                                     ? "/InstrumentValueIcons/cheveron-outline-left.svg"
                                     : (toolDrawer.toolIcon ? toolDrawer.toolIcon : "/InstrumentValueIcons/menu.svg"))
                                 : "/res/QGCLogoFull.svg"
                    logo: !toolDrawer.compactHeader
                    onClicked: {
                        if (toolDrawer._isSettingsTool) {
                            mainWindow.showFlyView()
                        } else {
                            mainWindow.showToolSelectDialog()
                        }
                    }
                }

                QGCLabel {
                    id:             toolbarDrawerText
                    text:           toolDrawer.toolTitle
                    font.pointSize: ScreenTools.largeFontPointSize
                    visible:        !toolDrawer.compactHeader
                }
            }
        }

        Loader {
            id:             toolDrawerLoader
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    toolDrawerToolbar.bottom
            anchors.bottom: parent.bottom

            Connections {
                target:                 toolDrawerLoader.item
                ignoreUnknownSignals:   true
                function onPopout() { toolDrawer.visible = false }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function _localizedVehicleMessage(message) {
        let localizedMessage = message || ""
        const replacements = [
            { "pattern": /No valid mission available, loitering/gi, "text": qsTr("没有可执行的有效任务，飞行器正在保持/盘旋") },
            { "pattern": /No valid mission available/gi, "text": qsTr("没有可执行的有效任务") },
            { "pattern": /loitering/gi, "text": qsTr("正在保持/盘旋") },
            { "pattern": /Mission rejected/gi, "text": qsTr("任务被拒绝") },
            { "pattern": /Mission upload failed/gi, "text": qsTr("任务上传失败") },
            { "pattern": /Mission transfer failed/gi, "text": qsTr("任务传输失败") },
            { "pattern": /Mission accepted/gi, "text": qsTr("任务已接受") },
            { "pattern": /Mission finished/gi, "text": qsTr("任务已完成") },
            { "pattern": /Preflight Fail: No connection to the GCS/gi, "text": qsTr("起飞前检查失败：未连接到地面站") },
            { "pattern": /Preflight Fail/gi, "text": qsTr("起飞前检查失败") },
            { "pattern": /Geofence violation/gi, "text": qsTr("触发地理围栏限制") },
            { "pattern": /Failsafe enabled/gi, "text": qsTr("失效保护已触发") },
            { "pattern": /Failsafe activated/gi, "text": qsTr("失效保护已激活") },
            { "pattern": /Battery low/gi, "text": qsTr("电池电量低") },
            { "pattern": /GPS signal lost/gi, "text": qsTr("GPS 信号丢失") },
            { "pattern": /Manual control lost/gi, "text": qsTr("手动控制链路丢失") },
            { "pattern": /Data link lost/gi, "text": qsTr("数传链路丢失") },
            { "pattern": /Return to launch/gi, "text": qsTr("正在返航") },
            { "pattern": /Takeoff detected/gi, "text": qsTr("检测到起飞") },
            { "pattern": /Landing detected/gi, "text": qsTr("检测到降落") },
            { "pattern": /GCS connection regained/gi, "text": qsTr("地面站连接已恢复") },
            { "pattern": /GCS connection lost/gi, "text": qsTr("地面站连接丢失") },
            { "pattern": /Switching to mode 'Position control' is currently not possible No manual control input/gi, "text": qsTr("当前无法切换到“位置控制”模式：没有手动控制输入") },
            { "pattern": /No manual control input/gi, "text": qsTr("没有手动控制输入") }
        ]

        for (let i = 0; i < replacements.length; i++) {
            localizedMessage = localizedMessage.replace(replacements[i].pattern, replacements[i].text)
        }
        return localizedMessage
    }

    function showCriticalVehicleMessage(message) {
        closeIndicatorDrawer()
        criticalVehicleMessagePopup.addMessage(message)

        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // Match QGC behavior: keep the current warning visible and mark that
            // additional messages are waiting in the vehicle message list.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              Math.min(mainWindow.width * 0.52, ScreenTools.defaultFontPixelWidth * 58)
        height:             criticalVehicleMessageContent.implicitHeight + ScreenTools.defaultFontPixelHeight
        modal:              false
        focus:              true
        padding:            0

        property int    maxVisibleCriticalMessages:         8
        property bool   additionalCriticalMessagesReceived: false

        function _escapeRichText(text) {
            let safeText = (text || "").toString()
            safeText = safeText.replace(/&/g, "&amp;")
            safeText = safeText.replace(/</g, "&lt;")
            safeText = safeText.replace(/>/g, "&gt;")
            return safeText
        }

        function _isHighPriorityMessage(text) {
            return /\b(Emergency|Alert|Critical|Error|Warning)\b/i.test(text || "")
        }

        function addMessage(message) {
            const localizedMessage = _localizedVehicleMessage(message)
            const highPriority = _isHighPriorityMessage(message) || _isHighPriorityMessage(localizedMessage)
            criticalVehicleMessageModel.insert(0, {
                                                   "message": _escapeRichText(localizedMessage),
                                                   "highPriority": highPriority
                                               })
            while (criticalVehicleMessageModel.count > maxVisibleCriticalMessages) {
                criticalVehicleMessageModel.remove(criticalVehicleMessageModel.count - 1)
            }
        }

        background: Rectangle {
            anchors.fill:   parent
            color:          Qt.rgba(0.10, 0.10, 0.11, 0.96)
            radius:         ScreenTools.defaultFontPixelHeight * 0.36
            border.color:   Qt.rgba(1.0, 0.66, 0.20, 0.72)
            border.width:   1
        }

        ListModel {
            id: criticalVehicleMessageModel
        }

        Column {
            id:                 criticalVehicleMessageContent
            anchors.fill:       parent
            anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.5
            spacing:            ScreenTools.defaultFontPixelHeight * 0.28

            Row {
                width:      parent.width
                spacing:    ScreenTools.defaultFontPixelWidth * 0.7

                Rectangle {
                    width:              ScreenTools.defaultFontPixelHeight * 0.55
                    height:             width
                    radius:             width / 2
                    color:              "#F59E0B"
                    anchors.verticalCenter: parent.verticalCenter
                }

                QGCLabel {
                    id:                 vehicleWarningLabel
                    text:               qsTr("飞行器告警")
                    color:              "#F8FAFC"
                    font.bold:          true
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.72
                    anchors.verticalCenter: parent.verticalCenter
                }

                QGCLabel {
                    text:               qsTr("点击关闭")
                    color:              Qt.rgba(1, 1, 1, 0.48)
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.58
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Repeater {
                model: criticalVehicleMessageModel

                QGCLabel {
                    width:              criticalVehicleMessageContent.width
                    wrapMode:           Text.WordWrap
                    color:              highPriority ? "#FF5A5F" : "#FDE68A"
                    textFormat:         TextEdit.RichText
                    text:               message
                    font.bold:          highPriority
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.68
                }
            }

            QGCLabel {
                width:              parent.width
                visible:            criticalVehicleMessageModel.count >= criticalVehicleMessagePopup.maxVisibleCriticalMessages
                text:               qsTr("已显示最近 %1 条告警，完整记录请打开消息列表。").arg(criticalVehicleMessagePopup.maxVisibleCriticalMessages)
                color:              Qt.rgba(1, 1, 1, 0.62)
                wrapMode:           Text.WordWrap
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.62
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
                    const flyPage = _flyPageItem()
                    if (flyPage) {
                        flyPage.dropMainStatusIndicatorTool()
                    }
                } else {
                    const activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                    if (activeVehicle) {
                        activeVehicle.resetErrorLevelMessages();
                    }
                }
                criticalVehicleMessageModel.clear()
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent
        indicatorDrawer.indicatorItem = indicatorItem
        indicatorDrawer.open()
    }

    function _handleIndicatorDrawerPostCloseAction(postCloseAction) {
        if (postCloseAction === "returnToVehicleConfigMenu") {
            showVehicleConfig()
        }
    }

    function closeIndicatorDrawer(postCloseAction = "") {
        indicatorDrawer.postCloseAction = postCloseAction
        if (indicatorDrawer.visible) {
            indicatorDrawer.close()
        } else {
            _handleIndicatorDrawerPostCloseAction(postCloseAction)
        }
    }

    Popup {
        id:             indicatorDrawer
        x:              calcXPosition()
        y:              ScreenTools.toolbarHeight + _margins
        leftInset:      0
        rightInset:     0
        topInset:       0
        bottomInset:    0
        padding:        _margins * 2
        visible:        false
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var sourceComponent
        property var indicatorItem
        property string postCloseAction: ""

        property bool _expanded:    false
        property real _margins:     ScreenTools.defaultFontPixelHeight / 4

        function calcXPosition() {
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)))
            } else {
                return _margins
            }
        }

        onOpened: {
            _expanded                               = false;
            indicatorDrawerLoader.sourceComponent   = indicatorDrawer.sourceComponent
        }
        onClosed: {
            const postCloseAction = indicatorDrawer.postCloseAction
            indicatorDrawer.postCloseAction = ""
            _expanded                               = false
            indicatorItem                           = undefined
            indicatorDrawerLoader.sourceComponent   = undefined
            if (postCloseAction !== "") {
                Qt.callLater(function() { _handleIndicatorDrawerPostCloseAction(postCloseAction) })
            }
        }

        background: Item {
            Rectangle {
                id:             backgroundRect
                anchors.fill:   parent
                color:          QGroundControl.globalPalette.window
                radius:         indicatorDrawer._margins
                opacity:        0.85
            }

            Rectangle {
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item._showExpand && !indicatorDrawer._expanded

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               ">"
                    color:              QGroundControl.globalPalette.buttonText
                }

                QGCMouseArea {
                    fillItem: parent
                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }

        contentItem: QGCFlickable {
            id:             indicatorDrawerLoaderFlickable
            implicitWidth:  Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width)
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            Loader {
                id: indicatorDrawerLoader

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "expanded"
                    value:      indicatorDrawer._expanded
                }

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "drawer"
                    value:      indicatorDrawer
                }
            }
        }
    }

    // We have to create the popup windows for the Analyze pages here so that the creation context is rooted
    // to mainWindow. Otherwise if they are rooted to the AnalyzeView itself they will die when the analyze viewSwitch
    // closes.

    function createWindowedAnalyzePage(title, source, requiresVehicle) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.source = source
        windowedPage.requiresVehicle = requiresVehicle
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    true

            property alias source: loader.source
            property bool requiresVehicle: false

            Connections {
                target: QGroundControl.multiVehicleManager
                function onActiveVehicleChanged() {
                    if (requiresVehicle) {
                        close()
                    }
                }
            }

            Rectangle {
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                source = ""
                Qt.callLater(destroy)
            }
        }
    }

}
