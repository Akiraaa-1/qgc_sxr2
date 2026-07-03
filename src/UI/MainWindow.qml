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

    property string closeDialogTitle: qsTr("Close %1").arg(QGroundControl.appName)

    function checkForUnsavedMission() {
        const planViewItem = _planViewItem()
        if (planViewItem && (planViewItem._planMasterController.dirtyForSave || planViewItem._planMasterController.dirtyForUpload)) {
            QGroundControl.showMessageDialog(mainWindow, closeDialogTitle,
                              qsTr("You have a mission edit in progress which has not been saved/uploaded. If you close you will lose changes. Are you sure you want to close?"),
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
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
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
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
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

            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.2
                spacing:            ScreenTools.defaultFontPixelWidth * 0.75

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
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
                            radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                            color:                  "transparent"

                            QGCLabel {
                                anchors.centerIn:   parent
                                text:               qsTr("文件")
                                color:              integratedMainView._navTextColor
                                opacity:            0.78
                            }

                            QGCMouseArea {
                                anchors.fill: parent
                                onClicked: mainWindow.showSettingsTool()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
                            radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                            color:                  "transparent"

                            QGCLabel {
                                anchors.centerIn:   parent
                                text:               qsTr("设置")
                                color:              integratedMainView._navTextColor
                                opacity:            0.78
                            }

                            QGCMouseArea {
                                anchors.fill: parent
                                onClicked: mainWindow.showSettingsTool()
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Item {
                    Layout.alignment:       Qt.AlignHCenter
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 102
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4

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
                        anchors.centerIn:   parent
                        spacing:            ScreenTools.defaultFontPixelWidth * 0.95

                        Repeater {
                            model: {
                                const uniformTabWidth = ScreenTools.defaultFontPixelWidth * 24
                                const tabs = [
                                    { label: qsTr("Plan"), icon: "/qmlimages/Plan.svg", width: uniformTabWidth, iconSize: ScreenTools.defaultFontPixelHeight * 0.85, tabIndex: _planTabIndex, offlineAvailable: true },
                                    { label: qsTr("Fly"), icon: "/qmlimages/PaperPlane.svg", width: uniformTabWidth, iconSize: ScreenTools.defaultFontPixelHeight * 0.85, tabIndex: _flyTabIndex, offlineAvailable: false },
                                    { label: qsTr("Summary"), icon: "/qmlimages/VehicleSummaryIcon.png", width: uniformTabWidth, iconSize: ScreenTools.defaultFontPixelHeight * 0.85, tabIndex: _summaryTabIndex, offlineAvailable: true },
                                    { label: qsTr("Configure"), icon: "/InstrumentValueIcons/cog.svg", width: uniformTabWidth, iconSize: ScreenTools.defaultFontPixelHeight * 0.85, tabIndex: _configureTabIndex, offlineAvailable: true }
                                ]
                                if (mainWindow._analyzeEnabled) {
                                    tabs.push({ label: qsTr("Analyze"), icon: "/qmlimages/Analyze.svg", width: uniformTabWidth, iconSize: ScreenTools.defaultFontPixelHeight * 0.85, tabIndex: _analyzeTabIndex, offlineAvailable: false })
                                }
                                tabs.push({ label: qsTr("Console"), icon: "/qmlimages/MAVLinkConsoleIcon.svg", width: uniformTabWidth, iconSize: ScreenTools.defaultFontPixelHeight * 0.85, tabIndex: _mavlinkConsoleTabIndex, offlineAvailable: false })
                                return tabs
                            }

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected: mainViewTabBar.currentIndex === modelData.tabIndex
                                readonly property bool enabledForState: mainWindow._hasAnyConnectedVehicle() || !!modelData.offlineAvailable

                                width:          modelData.width
                                height:         ScreenTools.defaultFontPixelHeight * 2.2
                                radius:         ScreenTools.defaultFontPixelHeight * 0.22
                                color:          selected ? integratedMainView._tabSelectedBg : "transparent"
                                border.color:   selected ? integratedMainView._tabSelectedBorder : "transparent"
                                border.width:   selected ? 1 : 0

                                Row {
                                    anchors.centerIn:   parent
                                    spacing:            ScreenTools.defaultFontPixelWidth * 0.35

                                    Item {
                                        width:      modelData.iconSize
                                        height:     modelData.iconSize

                                        QGCColoredImage {
                                            anchors.fill:       parent
                                            source:             modelData.icon
                                            fillMode:           Image.PreserveAspectFit
                                            color:              integratedMainView._navTextColor
                                            opacity:            !enabledForState ? 0.28 : (selected ? 1 : 0.72)
                                        }
                                    }

                                    QGCLabel {
                                        text:               modelData.label
                                        color:              integratedMainView._navTextColor
                                        opacity:            !enabledForState ? 0.32 : (selected ? 1 : 0.72)
                                        font.weight:        selected ? Font.DemiBold : Font.Normal
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
                    Layout.fillWidth: true
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
                            width: visible ? (ScreenTools.defaultFontPixelWidth * 12.8) : 0
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
                                text:           qsTr("Connected Vehicles")
                                font.pointSize: ScreenTools.mediumFontPointSize
                                font.weight:    Font.DemiBold
                            }

                            QGCLabel {
                                Layout.fillWidth:       true
                                horizontalAlignment:    Text.AlignHCenter
                                text:                   qsTr("No connected vehicles")
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
                            id:                 turnCoordinatorCard
                            Layout.fillWidth:   true
                            Layout.fillHeight:  true
                            color:              qgcPal.windowShade
                            radius:             _panelRadius * 0.75
                            border.color:       qgcPal.windowShadeLight
                            border.width:       1

                            property bool hasTurnValue: globals.activeVehicle && !isNaN(Number(globals.activeVehicle.roll.rawValue))
                            // Use roll as a lightweight turn/slip proxy when no dedicated turn coordinator fact is exposed.
                            property real turnValue: hasTurnValue ? Number(globals.activeVehicle.roll.rawValue) : 0
                            property real needleRotation: mainWindow._clamp(turnValue, -45, 45)

                            ColumnLayout {
                                anchors.fill:       parent
                                anchors.margins:    _panelMargin
                                spacing:            _panelMargin

                                QGCLabel {
                                    text:       qsTr("Turn Coordinator")
                                    color:      qgcPal.text
                                    opacity:    0.7
                                }

                                Item {
                                    Layout.fillWidth:   true
                                    Layout.fillHeight:  true

                                    Rectangle {
                                        id:                 turnDial
                                        width:              Math.min(parent.width, parent.height) * 0.8
                                        height:             width
                                        radius:             width / 2
                                        color:              qgcPal.window
                                        border.color:       qgcPal.windowShadeLight
                                        border.width:       1
                                        anchors.centerIn:   parent
                                    }

                                    Rectangle {
                                        width:                  turnDial.width * 0.34
                                        height:                 Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                                        radius:                 height / 2
                                        x:                      turnDial.x + (turnDial.width / 2)
                                        y:                      turnDial.y + ((turnDial.height - height) / 2)
                                        transformOrigin:        Item.Left
                                        rotation:               turnCoordinatorCard.needleRotation
                                        color:                  qgcPal.text
                                    }

                                    Rectangle {
                                        width:                  ScreenTools.defaultFontPixelWidth
                                        height:                 width
                                        radius:                 width / 2
                                        color:                  qgcPal.colorBlue
                                        anchors.centerIn:       turnDial
                                    }

                                    QGCLabel {
                                        anchors.horizontalCenter:   turnDial.horizontalCenter
                                        anchors.bottom:             parent.bottom
                                        text:                       turnCoordinatorCard.hasTurnValue ? mainWindow._formatSignedValue(turnCoordinatorCard.turnValue, 0, "\u00B0") : "--"
                                        font.pointSize:             ScreenTools.largeFontPointSize
                                        font.weight:                Font.DemiBold
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
                        if (key === "locate") {
                            return _vehicleHasPosition(_activeVehicle)
                        }
                        return !requiresVehicle || !!_activeVehicle
                    }

                    function _isMapStripSelected(key) {
                        if (key === "traffic") {
                            return _trafficViewVisible
                        }
                        if (key === "pan") {
                            return _mapNavigationSelection === "pan"
                        }
                        if (key === "locate") {
                            return _mapNavigationSelection === "locate"
                        }
                        return false
                    }

                    function _triggerMapStripAction(command) {
                        const guidedController = globals.guidedControllerFlyView
                        switch (command) {
                        case "traffic":
                            _trafficViewVisible = !_trafficViewVisible
                            if (_trafficViewVisible) {
                                fallbackTrafficViewPanel.refresh()
                            }
                            break
                        case "list":
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
                        case "play":
                            if (!guidedController) {
                                break
                            }
                            if (guidedController.showContinueMission) {
                                guidedController.confirmAction(guidedController.actionContinueMission)
                            } else if (guidedController.showStartMission) {
                                guidedController.confirmAction(guidedController.actionStartMission)
                            }
                            break
                        case "pause":
                            if (guidedController) {
                                guidedController.confirmAction(guidedController.actionPause)
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

                    PlanMasterController {
                        id: fallbackPlanController
                        flyView: true

                        Component.onCompleted: start()
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
                        showMissionPaths: true
                        planMasterController: fallbackPlanController
                        rightPanelWidth: 0
                        toolInsets: fallbackToolInsets
                    }

                    Rectangle {
                        id: fallbackFloatingMapStrip
                        anchors.left: parent.left
                        anchors.leftMargin: fallbackFlyMapHost._margin
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property real _buttonHeight: ScreenTools.defaultFontPixelHeight * 2.18
                        readonly property real _innerMargin: ScreenTools.defaultFontPixelHeight * 0.16
                        readonly property real _expandedWidth: ScreenTools.defaultFontPixelHeight * 2.75
                        readonly property real _collapsedWidth: 0
                        readonly property real _expandedHeight: fallbackStripButtonColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.38)
                        readonly property real _collapsedHeight: 0
                        width: fallbackFlyMapHost._mapStripExpanded ? _expandedWidth : _collapsedWidth
                        height: fallbackFlyMapHost._mapStripExpanded ? _expandedHeight : _collapsedHeight
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

                        ColumnLayout {
                            id: fallbackStripButtonColumn
                            anchors.fill: parent
                            anchors.margins: fallbackFloatingMapStrip._innerMargin
                            spacing: ScreenTools.defaultFontPixelHeight * 0.12

                            Repeater {
                                model: [
                                    { "key": "traffic",   "icon": "/InstrumentValueIcons/border-outer.svg",    "requiresVehicle": false, "slashed": false },
                                    { "key": "list",      "icon": "/InstrumentValueIcons/clipboard.svg",       "requiresVehicle": false, "slashed": false },
                                    { "key": "orbit",     "icon": "/InstrumentValueIcons/reload.svg",          "requiresVehicle": false, "slashed": false },
                                    { "key": "lockOrbit", "icon": "/InstrumentValueIcons/reload.svg",          "requiresVehicle": false, "slashed": true  },
                                    { "key": "up",        "icon": "/InstrumentValueIcons/arrow-base-up.svg",   "requiresVehicle": true,  "slashed": false },
                                    { "key": "down",      "icon": "/InstrumentValueIcons/arrow-base-down.svg", "requiresVehicle": true,  "slashed": false },
                                    { "key": "rtl",       "icon": "/res/rtl.svg",                              "requiresVehicle": true,  "slashed": false },
                                    { "key": "play",      "icon": "/InstrumentValueIcons/play-outline.svg",    "requiresVehicle": true,  "slashed": false },
                                    { "key": "pause",     "icon": "/InstrumentValueIcons/pause-outline.svg",   "requiresVehicle": true,  "slashed": false },
                                    { "key": "pan",       "icon": "/InstrumentValueIcons/map-pan.svg",         "requiresVehicle": false, "slashed": false },
                                    { "key": "locate",    "icon": "/InstrumentValueIcons/map-follow.svg",      "requiresVehicle": true,  "slashed": false }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    readonly property bool _enabled: fallbackFlyMapHost._isMapStripActionEnabled(modelData.key, modelData.requiresVehicle)
                                    readonly property bool _selected: fallbackFlyMapHost._isMapStripSelected(modelData.key)

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: fallbackFloatingMapStrip._buttonHeight
                                    color: _selected ? "#2F6FC7" : (fallbackStripMouseArea.pressed ? "#1A1C1F" : "#121315")
                                    opacity: fallbackFlyMapHost._mapStripExpanded ? (_enabled ? 1 : 0.42) : 0
                                    radius: ScreenTools.defaultFontPixelHeight * 0.18

                                    Item {
                                        anchors.fill: parent

                                        QGCColoredImage {
                                            anchors.centerIn: parent
                                            width: parent.height * 0.42
                                            height: width
                                            color: "#FFFFFF"
                                            fillMode: Image.PreserveAspectFit
                                            source: modelData.icon
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
                                        enabled: fallbackFlyMapHost._mapStripExpanded && parent._enabled
                                        onClicked: fallbackFlyMapHost._triggerMapStripAction(modelData.key)
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
                        z: QGroundControl.zOrderWidgets

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
                                text: qsTr("TRAFFIC VIEW")
                            }

                            QGCLabel {
                                anchors.right: parent.right
                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.68
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#5FB5FF"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                text: fallbackTrafficViewPanel.trafficCount > 0
                                    ? qsTr("%1 LIVE").arg(fallbackTrafficViewPanel.trafficCount)
                                    : qsTr("LIVE")
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
                            text: qsTr("Range %1 km").arg((fallbackTrafficViewPanel.displayRangeMeters / 1000).toFixed(1))
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
                                ? qsTr("Waiting for live traffic data")
                                : qsTr("Traffic detected. Waiting for vehicle position")
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
                                 !flyPageContent.guidedController._vehicleFlying &&
                                 !flyPageContent.guidedController._missionActive &&
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
                                text: qsTr("开始任务")
                                color: "#F8FAFC"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                text: flyPageContent.guidedController.showStartMission
                                    ? flyPageContent.guidedController.startMissionMessage
                                    : qsTr("按下“开始”以检查任务是否可以开始。")
                                color: "#E5E7EB"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            QGCButton {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("开始")
                                primary: true
                                onClicked: flyPageContent._showStartMissionSlider()
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
                            ScreenTools.defaultFontPixelWidth * 38,
                            Math.max(ScreenTools.defaultFontPixelWidth * 24, fallbackFlyMapHost.width - (fallbackFlyMapHost._margin * 2))
                        )
                        height: ScreenTools.defaultFontPixelHeight * 5.8
                        visible: fallbackFlyMapHost.visible && !!flyPageContent && flyPageContent._startMissionSliderVisible
                        color: Qt.rgba(0.10, 0.10, 0.11, 0.96)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.28
                        z: QGroundControl.zOrderWidgets + 20

                        onVisibleChanged: {
                            if (visible) {
                                fallbackStartMissionMapSliderSwitch.forceActiveFocus()
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.42
                            spacing: ScreenTools.defaultFontPixelHeight * 0.3

                            QGCLabel {
                                Layout.fillWidth: true
                                text: flyPageContent && flyPageContent.guidedController ? flyPageContent.guidedController.startMissionMessage : qsTr("开始任务")
                                color: "#F1F3F5"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.55

                                SliderSwitch {
                                    id: fallbackStartMissionMapSliderSwitch
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.45
                                    focus: fallbackStartMissionMapSliderPanel.visible
                                    confirmText: qsTr("滑动或按住空格键")
                                    onAccept: flyPageContent._confirmStartMissionSlider()
                                }

                                Rectangle {
                                    Layout.preferredWidth: fallbackStartMissionMapSliderSwitch.height
                                    Layout.preferredHeight: Layout.preferredWidth
                                    radius: width / 2
                                    color: "#9CC1D7"

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
                    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
                    readonly property string _startPageAutoConnectConfigName: "Start Page Auto Connect"
                    property bool _serialPortAvailable: false
                    readonly property bool _canConnect: _isConnected
                                                           || (_availableLinkNames.length > 0)
                                                           || (_serialPortAvailable
                                                               && _selectedSerialPortIndex >= 0
                                                               && _selectedSerialPortIndex < _serialPortNames.length)
                    property var _availableLinkConfigs: []
                    property var _availableLinkNames: []
                    property var _serialPortNames: []
                    property var _serialPortDisplayNames: []
                    property var _vehicleConnectionStateMap: ({})
                    property var _temporaryStartSerialConfig: null
                    property int _selectedLinkIndex: -1
                    property int _selectedSerialPortIndex: -1
                    property int _selectedBaudRate: 57600
                    property bool _selectedFlowControlEnabled: false
                    property int _selectedDataBits: 8
                    property int _selectedStopBits: 1
                    property int _selectedParity: 0
                    property int _selectedMavlinkVersion: 2
                    property bool _autoConnectOnBoot: false
                    property int _connectedVehicleCount: 0
                    property bool _isConnected: false
                    property string _statusText: qsTr("Select a link and connect the vehicle")
                    property string _recentConnectionText: qsTr("Recent connection: No successful connection yet")

                    function _setSelectedMavlinkVersionIndex(index) {
                        _selectedMavlinkVersion = index === 0 ? 1 : 2
                    }

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
                            _selectedMavlinkVersion = 2
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

                        if (cfg && cfg.mavlinkVersion !== undefined && cfg.mavlinkVersion !== null) {
                            _selectedMavlinkVersion = Number(cfg.mavlinkVersion) <= 1 ? 1 : 2
                        } else {
                            _selectedMavlinkVersion = 2
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
                            _appendEvent(qsTr("Link manager unavailable"))
                            return
                        }

                        const editingConfig = _linkManager.createConfiguration(ScreenTools.isSerialAvailable ? LinkConfiguration.TypeSerial : LinkConfiguration.TypeUdp, "")
                        if (!editingConfig) {
                            _appendEvent(qsTr("Unable to create link configuration"))
                            return
                        }

                        startPageLinkDialogFactory.open({ editingConfig: editingConfig, originalConfig: null })
                    }

                    function _refreshSerialSelection(forceRefresh = false) {
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

                        _selectedSerialPortIndex = Math.max(0, Math.min(_selectedSerialPortIndex, serialPorts.length - 1))
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
                            config.mavlinkVersion = connectionConfig.mavlinkVersion !== undefined && connectionConfig.mavlinkVersion !== null
                                ? connectionConfig.mavlinkVersion
                                : _selectedMavlinkVersion
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
                        config.mavlinkVersion = _selectedMavlinkVersion
                        config.autoConnect = true
                        _linkManager.endCreateConfiguration(config)
                        _refreshLinks()
                        return true
                    }

                    function _applyStartPagePersistentSettings(connectionConfig) {
                        if (_autoConnectOnBoot) {
                            if (_persistStartPageAutoConnectConfig(connectionConfig)) {
                                _appendEvent(qsTr("Auto connect on boot enabled"))
                            } else {
                                _appendEvent(qsTr("Auto connect on boot could not be saved for this connection"))
                            }
                        } else {
                            _removeStartPageAutoConnectConfig()
                        }
                    }

                    function _temporarySerialConfig() {
                        if (!_linkManager || !_serialPortAvailable) {
                            return null
                        }

                        _refreshSerialSelection()

                        const portName = _selectedSerialPortName()
                        if (portName === "") {
                            return null
                        }

                        let config = _temporaryStartSerialConfig
                        if (!config) {
                            config = _linkManager.createConfiguration(LinkConfiguration.TypeSerial, qsTr("Start Page Serial Link"))
                            if (!config) {
                                return null
                            }

                            config.dynamic = true
                            _linkManager.endCreateConfiguration(config)
                            _temporaryStartSerialConfig = config
                        }

                        config.name = qsTr("Start Page Serial (%1)").arg(_selectedSerialPortDisplayName())
                        config.portName = portName
                        config.baud = _selectedBaudRate
                        config.flowControl = _selectedFlowControlEnabled ? 1 : 0
                        config.dataBits = _selectedDataBits
                        config.stopBits = _selectedStopBits
                        config.parity = _selectedParity
                        config.mavlinkVersion = _selectedMavlinkVersion
                        config.autoConnect = _autoConnectOnBoot

                        return config
                    }

                    function _vehicleKey(vehicle) {
                        return vehicle && vehicle.id !== undefined && vehicle.id !== null ? ("" + vehicle.id) : ""
                    }

                    function _vehicleLabel(vehicleIdText) {
                        return qsTr("Vehicle %1").arg(vehicleIdText)
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
                                        _appendEvent(qsTr("%1 connected").arg(_vehicleLabel(vehicleIdText)))
                                    }
                                } else if (previousState !== isConnected) {
                                    _appendEvent(
                                        isConnected
                                            ? qsTr("%1 connected").arg(_vehicleLabel(vehicleIdText))
                                            : qsTr("%1 disconnected").arg(_vehicleLabel(vehicleIdText))
                                    )
                                }
                            }
                        }

                        if (logChanges) {
                            for (const vehicleIdText in _vehicleConnectionStateMap) {
                                if (_vehicleConnectionStateMap[vehicleIdText] && nextStates[vehicleIdText] === undefined) {
                                    _appendEvent(qsTr("%1 disconnected").arg(_vehicleLabel(vehicleIdText)))
                                }
                            }
                        }

                        _vehicleConnectionStateMap = nextStates
                        _connectedVehicleCount = connectedCount
                        _isConnected = connectedCount > 0

                        if (_isConnected) {
                            if (_activeVehicle && _activeVehicle.id !== undefined && _activeVehicle.id !== null) {
                                _statusText = qsTr("Vehicle %1 connected. Review settings, then click Connect Vehicle to enter").arg(_activeVehicle.id)
                                _recentConnectionText = qsTr("Recent connection: Vehicle %1 connected").arg(_activeVehicle.id)
                            } else if (_connectedVehicleCount === 1) {
                                _statusText = qsTr("1 vehicle connected. Review settings, then click Connect Vehicle to enter")
                                _recentConnectionText = qsTr("Recent connection: 1 vehicle connected")
                            } else {
                                _statusText = qsTr("%1 vehicles connected. Review settings, then click Connect Vehicle to enter").arg(_connectedVehicleCount)
                                _recentConnectionText = qsTr("Recent connection: %1 vehicles connected").arg(_connectedVehicleCount)
                            }
                        } else {
                            _statusText = qsTr("Select a link and connect the vehicle")
                        }

                        const wasShowingStartPage = mainWindow._showStartPage

                        // The hidden start page overlay should not seize global navigation
                        // when vehicle state momentarily fluctuates while the user is working
                        // in another workspace (for example opening Parameters).
                        if (wasShowingStartPage) {
                            mainWindow._syncStartPageVisibility()
                        } else if (!_isConnected) {
                            _appendEvent(qsTr("No connected vehicle available. Staying in current workspace"))
                        }
                    }

                    function _connectSelected(enterWorkspace = true) {
                        if (!_linkManager) {
                            _appendEvent(qsTr("Link manager unavailable"))
                            return
                        }

                        _syncConnectionState(false)

                        if (_isConnected) {
                            if (enterWorkspace) {
                                _appendEvent(qsTr("Entering main workspace"))
                                mainWindow._ensureMainInterfaceAccess(mainWindow._flyTabIndex, true)
                            } else {
                                _appendEvent(qsTr("Vehicle link already active"))
                            }
                            return
                        }

                        let cfg = null
                        let selectedLinkConfig = null
                        if (_selectedLinkIndex >= 0 && _selectedLinkIndex < _availableLinkConfigs.length) {
                            selectedLinkConfig = _availableLinkConfigs[_selectedLinkIndex]
                        }

                        if (selectedLinkConfig && selectedLinkConfig.linkType !== LinkConfiguration.TypeSerial) {
                            cfg = selectedLinkConfig
                        } else {
                            cfg = _temporarySerialConfig()
                            if (!cfg) {
                                cfg = selectedLinkConfig
                            }
                        }

                        if (!cfg) {
                            _appendEvent(qsTr("No available links or serial ports"))
                            return
                        }

                        if (cfg.mavlinkVersion !== undefined && cfg.mavlinkVersion !== null) {
                            cfg.mavlinkVersion = _selectedMavlinkVersion
                        }
                        _applyStartPagePersistentSettings(cfg)
                        _appendEvent((enterWorkspace ? qsTr("Connecting using %1 ...") : qsTr("Testing %1 ...")).arg(cfg.name))
                        _linkManager.createConnectedLink(cfg)
                    }

                    function _startDemo() {
                        QGroundControl.startPX4MockLink(false, false, false)
                        _appendEvent(qsTr("Starting demo vehicle..."))
                    }

                    ListModel {
                        id: startEventLogModel
                    }

                    Component.onCompleted: {
                        _refreshLinks()
                        _autoConnectOnBoot = _findSavedConfigByName(_startPageAutoConnectConfigName) !== null
                        _appendEvent(qsTr("Start page initialized"))
                        _syncConnectionState(false)
                    }

                    onVisibleChanged: {
                        if (visible) {
                            _refreshLinks()
                            _autoConnectOnBoot = _findSavedConfigByName(_startPageAutoConnectConfigName) !== null
                            _syncConnectionState(false)
                        }
                    }

                    Connections {
                        target: startPageOverlay._linkManager
                        ignoreUnknownSignals: true

                        function onCommPortsChanged() {
                            startPageOverlay._refreshSerialSelection()
                        }

                        function onCommPortStringsChanged() {
                            startPageOverlay._refreshSerialSelection()
                        }
                    }

                    Connections {
                        target: QGroundControl.multiVehicleManager
                        ignoreUnknownSignals: true
                        function onActiveVehicleChanged(activeVehicle) {
                            startPageOverlay._syncConnectionState()
                        }
                        function onVehicleAdded(vehicle) {
                            startPageOverlay._syncConnectionState()
                        }
                        function onVehicleRemoved(vehicle) {
                            startPageOverlay._syncConnectionState()
                        }
                    }

                    Instantiator {
                        model: QGroundControl.multiVehicleManager.vehicles

                        delegate: Connections {
                            required property var object

                            target: object && object.vehicleLinkManager ? object.vehicleLinkManager : null
                            ignoreUnknownSignals: true

                            function onCommunicationLostChanged() {
                                startPageOverlay._syncConnectionState()
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
                                startPageOverlay._appendEvent(qsTr("Added link configuration '%1'").arg(savedConfigName))
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
                                                    startPageOverlay._syncSelectedLinkSettings()
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
                                                onActivated: startPageOverlay._selectedSerialPortIndex = index
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
                                                    startPageOverlay._refreshSerialSelection(true)
                                                    if (serialPortCombo.enabled) {
                                                        startPageOverlay._appendEvent(qsTr("串口列表已刷新"))
                                                    } else {
                                                        startPageOverlay._appendEvent(qsTr("未检测到串口"))
                                                    }
                                                }
                                            }
                                            QGCCheckBox {
                                                Layout.fillWidth: true
                                                text: qsTr("启动时自动连接")
                                                textFontPointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                boxBackgroundColor: startPageOverlay._inputBg
                                                boxBorderColor: startPageOverlay._borderColor
                                                checkColor: startPageOverlay._focusColor
                                                hoverColor: startPageOverlay._focusColor
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                checked: startPageOverlay._autoConnectOnBoot
                                                onToggled: {
                                                    startPageOverlay._autoConnectOnBoot = checked
                                                    if (!checked && !startPageOverlay._isConnected) {
                                                        startPageOverlay._removeStartPageAutoConnectConfig()
                                                    }
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
                                                    }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.6
                                            QGCLabel { text: qsTr("数据 / 停止位"); color: startPageOverlay._primaryText; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * startPageOverlay._leftFieldLabelWidth; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontFieldLabel }
                                            QGCComboBox { Layout.fillWidth: true; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10; sizeToContents: true; model: [qsTr("数据 5"), qsTr("数据 6"), qsTr("数据 7"), qsTr("数据 8")]; currentIndex: Math.max(0, Math.min(3, startPageOverlay._selectedDataBits - 5)); font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale; backgroundColor: startPageOverlay._inputBg; borderColor: startPageOverlay._borderColor; focusBorderColor: startPageOverlay._focusColor; textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText; showFocusBorder: true; borderRadius: startPageOverlay._uiRadius; stateAnimationDuration: startPageOverlay._uiAnimMs; onActivated: (index) => startPageOverlay._selectedDataBits = index + 5 }
                                            QGCComboBox { Layout.fillWidth: true; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 9; sizeToContents: true; model: [qsTr("停止 1"), qsTr("停止 2")]; currentIndex: Math.max(0, Math.min(1, startPageOverlay._selectedStopBits - 1)); font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale; backgroundColor: startPageOverlay._inputBg; borderColor: startPageOverlay._borderColor; focusBorderColor: startPageOverlay._focusColor; textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText; showFocusBorder: true; borderRadius: startPageOverlay._uiRadius; stateAnimationDuration: startPageOverlay._uiAnimMs; onActivated: (index) => startPageOverlay._selectedStopBits = index + 1 }
                                            QGCComboBox { Layout.fillWidth: true; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 11; sizeToContents: true; model: [qsTr("无奇偶"), qsTr("奇"), qsTr("偶")]; currentIndex: startPageOverlay._selectedParity === 3 ? 1 : (startPageOverlay._selectedParity === 2 ? 2 : 0); font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale; backgroundColor: startPageOverlay._inputBg; borderColor: startPageOverlay._borderColor; focusBorderColor: startPageOverlay._focusColor; textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText; showFocusBorder: true; borderRadius: startPageOverlay._uiRadius; stateAnimationDuration: startPageOverlay._uiAnimMs; onActivated: (index) => startPageOverlay._selectedParity = index === 1 ? 3 : (index === 2 ? 2 : 0) }
                                            QGCComboBox {
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                                                sizeToContents: true
                                                model: ["MAVLink 1", "MAVLink 2"]
                                                currentIndex: startPageOverlay._selectedMavlinkVersion <= 1 ? 0 : 1
                                                font.pointSize: ScreenTools.defaultFontPointSize * startPageOverlay._fontControlScale
                                                backgroundColor: startPageOverlay._inputBg
                                                borderColor: startPageOverlay._borderColor
                                                focusBorderColor: startPageOverlay._focusColor
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                showFocusBorder: true
                                                borderRadius: startPageOverlay._uiRadius
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onActivated: function(index) {
                                                    startPageOverlay._setSelectedMavlinkVersionIndex(index)
                                                }
                                                onCurrentIndexChanged: {
                                                    if (activeFocus && currentIndex >= 0) {
                                                        startPageOverlay._setSelectedMavlinkVersionIndex(currentIndex)
                                                    }
                                                }
                                            }
                                        }
                                        Item { Layout.fillHeight: true; Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 3.6 }
                                        QGCLabel { Layout.fillWidth: true; text: startPageOverlay._recentConnectionText; color: startPageOverlay._secondaryText; font.pixelSize: ScreenTools.defaultFontPixelHeight * startPageOverlay._fontMeta }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.55
                                            QGCButton {
                                                Layout.fillWidth: true
                                                text: qsTr("连接飞行器")
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
                                                showBorder: true
                                                backRadius: startPageOverlay._uiRadius
                                                borderColor: startPageOverlay._borderColor
                                                backgroundColor: !enabled ? startPageOverlay._secondaryBtn : (pressed ? startPageOverlay._secondaryBtnPressed : (hovered ? startPageOverlay._secondaryBtnHover : startPageOverlay._secondaryBtn))
                                                textColor: enabled ? startPageOverlay._primaryText : startPageOverlay._disabledText
                                                stateAnimationDuration: startPageOverlay._uiAnimMs
                                                onClicked: startPageOverlay._openWorkspaceTab(mainWindow._planTabIndex)
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

    function showCriticalVehicleMessage(message) {
        closeIndicatorDrawer()
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true

        property string criticalVehicleMessage:             ""
        property bool   additionalCriticalMessagesReceived: false

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("飞行器错误")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("收到更多错误信息")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
            text:               criticalVehicleMessagePopup.criticalVehicleMessage
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





