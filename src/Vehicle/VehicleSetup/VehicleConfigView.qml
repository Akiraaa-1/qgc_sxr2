import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:     vehicleConfigView
    color:  "#2F3032"
    z:      QGroundControl.zOrderTopMost

    // This need to block click event leakage to underlying map.
    DeadMouseArea {
        anchors.fill: parent
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real  _defaultTextHeight:         ScreenTools.defaultFontPixelHeight
    readonly property real  _defaultTextWidth:          ScreenTools.defaultFontPixelWidth
    readonly property real  _horizontalMargin:          _defaultTextWidth / 2
    readonly property real  _verticalMargin:            _defaultTextHeight / 2
    readonly property real  _buttonWidth:               _defaultTextWidth * 18
    readonly property string _armedVehicleText:         qsTr("This operation cannot be performed while the vehicle is armed.")
    readonly property real  _cornerRadius:              8
    readonly property int   _stateAnimationDuration:    200
    readonly property color _panelColor:                "#2D2D2D"
    readonly property color _panelHoverColor:           "#343434"
    readonly property color _panelPressedColor:         "#252525"
    readonly property color _inputColor:                "#252525"
    readonly property color _borderColor:               "#333333"
    readonly property color _primaryTextColor:          "#FFFFFF"
    readonly property color _secondaryTextColor:        "#B0B0B0"
    readonly property color _disabledTextColor:         "#666666"
    readonly property color _accentColor:               "#2563EB"
    readonly property color _menuPopupColor:            "#1A1A1A"

    property bool   useOfflineVehicleFallback:      false
    property bool   readOnlyMode:                   false
    property var    _activeVehicle:                 QGroundControl.multiVehicleManager.activeVehicle
                                                    ? QGroundControl.multiVehicleManager.activeVehicle
                                                    : (useOfflineVehicleFallback ? QGroundControl.multiVehicleManager.offlineEditingVehicle : null)
    property bool   _vehicleArmed:                  _activeVehicle ? _activeVehicle.armed : false
    property string _messagePanelText:              qsTr("missing message panel text")
    property bool   _parametersReadyForActiveVehicle: _activeVehicle ? _activeVehicle.parameterManager.parametersReady : false
    property bool   _fullParameterVehicleAvailable: _parametersReadyForActiveVehicle && !_activeVehicle.parameterManager.missingParameters
    property var    _corePlugin:                    QGroundControl.corePlugin

    // Tree view state
    property int    _selectedComponentIndex: -1     // -1 = summary or special button
    property int    _selectedSectionIndex:   -1
    property string _selectedSpecial:        ""     // "menu", "summary", "parameters", "firmware", "opticalflow"
    property var    _expandedComponents:     ({})
    property int    _expandedRevision:       0
    property string _searchQuery:            ""
    property bool   _hadConnectedVehicle:    false

    function _setExpanded(compIndex, value) {
        _expandedComponents[compIndex] = value
        _expandedRevision++
    }

    function _isExpanded(compIndex) {
        void _expandedRevision
        return !!_expandedComponents[compIndex]
    }

    /// Translate a section name using the component's JSON filename as context.
    /// Falls back to the raw name when no vehicleConfigJson is set.
    function _translateSection(component, name) {
        var context = _translationContext(component)
        if (!context) return name
        return qsTranslate(context, name)
    }

    /// Get the section name for a sidebar entry.
    function _sectionName(compIndex, sectionIndex) {
        if (sectionIndex < 0 || !_fullParameterVehicleAvailable) return ""
        var components = _activeVehicle.autopilotPlugin.vehicleComponents
        if (compIndex < 0 || compIndex >= components.length) return ""
        var secs = components[compIndex].sections
        if (sectionIndex < secs.length) return secs[sectionIndex]
        return ""
    }

    /// Extract the translation context (JSON filename) from a component.
    function _translationContext(component) {
        if (!component || !component.vehicleConfigJson) return ""
        var path = component.vehicleConfigJson.toString()
        var slash = path.lastIndexOf("/")
        return slash >= 0 ? path.substring(slash + 1) : path
    }

    function _componentMatchesSearch(component) {
        if (_searchQuery.trim() === "") return true
        var query = _searchQuery.toLowerCase().trim()
        if (component.name.toLowerCase().indexOf(query) !== -1) return true
        var context = _translationContext(component)
        var secs = component.sections
        if (secs) {
            for (var i = 0; i < secs.length; i++) {
                if (secs[i].toLowerCase().indexOf(query) !== -1) return true
                if (context && qsTranslate(context, secs[i]).toLowerCase().indexOf(query) !== -1) return true
            }
        }
        var keywords = component.sectionKeywords
        if (keywords) {
            for (var key in keywords) {
                var terms = keywords[key]
                for (var j = 0; j < terms.length; j++) {
                    if (terms[j].toLowerCase().indexOf(query) !== -1) return true
                    if (context && qsTranslate(context, terms[j]).toLowerCase().indexOf(query) !== -1) return true
                }
            }
        }
        return false
    }

    function _sectionMatchesSearch(component, sectionName) {
        if (_searchQuery.trim() === "") return true
        var query = _searchQuery.toLowerCase().trim()
        if (sectionName.toLowerCase().indexOf(query) !== -1) return true
        var context = _translationContext(component)
        if (context && qsTranslate(context, sectionName).toLowerCase().indexOf(query) !== -1) return true
        var keywords = component.sectionKeywords
        if (keywords && keywords[sectionName]) {
            var terms = keywords[sectionName]
            for (var i = 0; i < terms.length; i++) {
                if (terms[i].toLowerCase().indexOf(query) !== -1) return true
                if (context && qsTranslate(context, terms[i]).toLowerCase().indexOf(query) !== -1) return true
            }
        }
        return false
    }

    function showSummaryPanel() {
        if (mainWindow.allowViewSwitch()) {
            _showSummaryPanel()
        }
    }

    function showMenuPanel() {
        if (mainWindow.allowViewSwitch()) {
            _showMenuPanel()
        }
    }

    function _showSummaryPanel() {
        _selectedSpecial = "summary"
        _selectedComponentIndex = -1
        _selectedSectionIndex = -1
        if (readOnlyMode) {
            panelLoader.setSourceComponent(offlineReadOnlyPanelComponent)
            return
        }
        if (_fullParameterVehicleAvailable) {
            if (_activeVehicle.autopilotPlugin.vehicleComponents.length === 0) {
                panelLoader.setSourceComponent(noComponentsVehicleSummaryComponent)
            } else {
                panelLoader.setSource("qrc:/qml/QGroundControl/VehicleSetup/VehicleSummary.qml")
            }
        } else if (_activeVehicle && _parametersReadyForActiveVehicle && _activeVehicle.parameterManager.missingParameters) {
            panelLoader.setSourceComponent(missingParametersVehicleSummaryComponent)
        } else {
            panelLoader.setSourceComponent(disconnectedVehicleAndParamsSummaryComponent)
        }
    }

    function _showMenuPanel() {
        _selectedSpecial = "menu"
        _selectedComponentIndex = -1
        _selectedSectionIndex = -1
        if (readOnlyMode) {
            panelLoader.setSourceComponent(offlineReadOnlyPanelComponent)
            return
        }
        if (_fullParameterVehicleAvailable) {
            if (_activeVehicle.autopilotPlugin.vehicleComponents.length === 0) {
                panelLoader.setSourceComponent(noComponentsVehicleSummaryComponent)
            } else {
                panelLoader.setSource("qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigMenu.qml")
            }
        } else if (_activeVehicle && _parametersReadyForActiveVehicle && _activeVehicle.parameterManager.missingParameters) {
            panelLoader.setSourceComponent(missingParametersVehicleSummaryComponent)
        } else {
            panelLoader.setSourceComponent(disconnectedVehicleAndParamsSummaryComponent)
        }
    }

    function _refreshRootPanelForParameterState() {
        if (_selectedSpecial === "summary") {
            _showSummaryPanel()
        } else if (_selectedSpecial === "menu") {
            _showMenuPanel()
        }
    }

    function showPanel(specialName, qmlSource) {
        if (mainWindow.allowViewSwitch()) {
            if (readOnlyMode) {
                _showMenuPanel()
                return
            }
            _selectedSpecial = specialName
            _selectedComponentIndex = -1
            _selectedSectionIndex = -1
            panelLoader.setSource(qmlSource)
        }
    }

    function _navigateToComponent(compIndex, sectionIndex) {
        if (!mainWindow.allowViewSwitch()) return
        if (readOnlyMode) return
        if (!_fullParameterVehicleAvailable) return

        var components = _activeVehicle.autopilotPlugin.vehicleComponents
        if (compIndex < 0 || compIndex >= components.length) return
        var vehicleComponent = components[compIndex]

        var autopilotPlugin = _activeVehicle.autopilotPlugin
        var prereq = autopilotPlugin.prerequisiteSetup(vehicleComponent)
        if (prereq !== "") {
            // Move out of menu state so the Back to Menu button remains available
            // when we show prerequisite guidance instead of the target setup page.
            _selectedSpecial = "prereq"
            _selectedComponentIndex = -1
            _selectedSectionIndex = -1
            _messagePanelText = qsTr("%1 setup must be completed prior to %2 setup.").arg(prereq).arg(vehicleComponent.name)
            panelLoader.setSourceComponent(messagePanelComponent)
            return
        }

        _selectedSpecial = ""

        // If component opts in and root was clicked, auto-select first section
        if (sectionIndex < 0 && vehicleComponent.showFirstSectionOnRootClick && vehicleComponent.sections.length > 0) {
            sectionIndex = 0
        }
        _selectedSectionIndex = sectionIndex

        if (_selectedComponentIndex !== compIndex) {
            _selectedComponentIndex = compIndex
            panelLoader.setSource(vehicleComponent.setupSource, vehicleComponent)
        }

        // Apply section filter
        if (panelLoader.item && typeof panelLoader.item.sectionNameFilter !== "undefined") {
            panelLoader.item.sectionNameFilter = _sectionName(compIndex, sectionIndex)
        }
    }

    function showParametersPanel() {
        showPanel("parameters", "qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml")
    }

    function showVehicleComponentPanel(vehicleComponent) {
        if (!mainWindow.allowViewSwitch()) return
        if (!_fullParameterVehicleAvailable) return

        var components = _activeVehicle.autopilotPlugin.vehicleComponents
        for (var i = 0; i < components.length; i++) {
            if (components[i] === vehicleComponent) {
                _navigateToComponent(i, -1)
                return
            }
        }
    }

    Component.onCompleted: _showMenuPanel()

    Connections {
        target: QGroundControl.corePlugin
        function onShowAdvancedUIChanged(showAdvancedUI) {
            // Advanced UI visibility changes should not force navigation away
            // from the page the user is currently viewing.
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleAvailableChanged(activeVehicleAvailable) {
            if (activeVehicleAvailable) {
                vehicleConfigView._hadConnectedVehicle = true
            }
        }

        function onParameterReadyVehicleAvailableChanged(parametersReady) {
            if (_selectedSpecial === "summary") {
                _showSummaryPanel()
            } else if (_selectedSpecial === "menu") {
                _showMenuPanel()
            }
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager.vehicles
        ignoreUnknownSignals: true

        function onCountChanged() {
            if (count === 0 && vehicleConfigView._hadConnectedVehicle) {
                vehicleConfigView._showMenuPanel()
            }
        }
    }

    Connections {
        target: _activeVehicle ? _activeVehicle.parameterManager : null
        ignoreUnknownSignals: true

        function onParametersReadyChanged(parametersReady) {
            if (parametersReady) {
                _refreshRootPanelForParameterState()
            }
        }

        function onMissingParametersChanged(missingParameters) {
            _refreshRootPanelForParameterState()
        }
    }

    Connections {
        target: panelLoader
        function onLoaded() {
            if (panelLoader.item && typeof panelLoader.item.sectionNameFilter !== "undefined") {
                panelLoader.item.sectionNameFilter = _sectionName(_selectedComponentIndex, _selectedSectionIndex)
            }
            if (panelLoader.item && typeof panelLoader.item.useDarkStyle !== "undefined") {
                panelLoader.item.useDarkStyle = true
            }
        }
    }

    Component {
        id: offlineReadOnlyPanelComponent

        Rectangle {
            color: vehicleConfigView._panelColor
            radius: vehicleConfigView._cornerRadius
            border.width: 1
            border.color: vehicleConfigView._borderColor

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - (_defaultTextWidth * 4), ScreenTools.defaultFontPixelWidth * 48)
                spacing: ScreenTools.defaultFontPixelHeight * 0.8

                QGCLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pointSize: ScreenTools.largeFontPointSize
                    font.weight: Font.DemiBold
                    color: vehicleConfigView._primaryTextColor
                    text: qsTr("离线配置（只读）")
                }

                QGCLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: vehicleConfigView._secondaryTextColor
                    text: qsTr("当前正在离线浏览配置。在连接飞行器并完成参数下载之前，编辑和校准操作将被禁用。")
                }

                QGCLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: vehicleConfigView._secondaryTextColor
                    text: _activeVehicle
                        ? qsTr("离线飞行器：%1").arg(_activeVehicle.vehicleClassInternalName())
                        : qsTr("无法获取离线飞行器信息。")
                }
            }
        }
    }

    Component {
        id: noComponentsVehicleSummaryComponent
        Rectangle {
            color: vehicleConfigView._panelColor
            radius: vehicleConfigView._cornerRadius
            border.width: 1
            border.color: vehicleConfigView._borderColor
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                color:                  vehicleConfigView._secondaryTextColor
                                        text:                   qsTr("%1 当前不支持对该飞行器进行配置。").arg(QGroundControl.appName) +
                                        qsTr("如果飞行器已经完成配置，仍然可以进行飞行。")
            }
        }
    }

    Component {
        id: disconnectedVehicleAndParamsSummaryComponent
        Rectangle {
            id: disconnectedRect
            color: vehicleConfigView._panelColor
            radius: vehicleConfigView._cornerRadius
            border.width: 1
            border.color: vehicleConfigView._borderColor
            Column {
                anchors.centerIn:   parent
                spacing:            ScreenTools.defaultFontPixelHeight
                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:              disconnectedRect.width - _defaultTextWidth * 4
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode:           Text.WordWrap
                    font.pointSize:     ScreenTools.largeFontPointSize
                    color:              vehicleConfigView._secondaryTextColor
                    text:               !_activeVehicle
                                            ? qsTr("连接飞行器并完成参数下载后，将显示飞行器配置页面。")
                                            : (_activeVehicle.parameterManager.parameterDownloadSkipped
                                                ? qsTr("由于飞行器正在飞行，参数下载已被跳过。完成参数下载后即可使用配置页面。")
                                                : qsTr("正在等待下载飞行器参数……"))
                }
                QGCButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:       qsTr("Download Parameters")
                    visible:    _activeVehicle && _activeVehicle.parameterManager.parameterDownloadSkipped
                    enabled:    _activeVehicle && _activeVehicle.parameterManager.parameterDownloadSkipped && _activeVehicle.parameterManager.loadProgress === 0
                    backgroundColor: vehicleConfigView._accentColor
                    borderColor: vehicleConfigView._accentColor
                    textColor: vehicleConfigView._primaryTextColor
                    overlayColor: "#1D4ED8"
                    hoverOverlayOpacity: 0.20
                    pressedOverlayOpacity: 0.35
                    backRadius: vehicleConfigView._cornerRadius
                    showBorder: true
                    onClicked:  _activeVehicle.parameterManager.refreshAllParameters()
                }
            }
        }
    }

    Component {
        id: missingParametersVehicleSummaryComponent

        Rectangle {
            color: vehicleConfigView._panelColor
            radius: vehicleConfigView._cornerRadius
            border.width: 1
            border.color: vehicleConfigView._borderColor

            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                color:                  vehicleConfigView._secondaryTextColor
                text:                   qsTr("Vehicle did not return the full parameter list. ") +
                                        qsTr("As a result, the configuration pages are not available.")
            }
        }
    }

    Component {
        id: messagePanelComponent

        Rectangle {
            color: vehicleConfigView._panelColor
            radius: vehicleConfigView._cornerRadius
            border.width: 1
            border.color: vehicleConfigView._borderColor

            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                color:                  vehicleConfigView._secondaryTextColor
                text:                   _messagePanelText
            }
        }
    }

    Rectangle {
        id:                 leftPanelCard
        visible:            false
        width:              0
        anchors.topMargin:  _verticalMargin
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.leftMargin: _horizontalMargin
        anchors.left:       parent.left
        color:              _panelColor
        radius:             _cornerRadius
        border.width:       1
        border.color:       _borderColor

        property real _panelPadding: _verticalMargin

        ColumnLayout {
            id:                 leftPanel
            anchors.fill:       parent
            anchors.margins:    leftPanelCard._panelPadding
            spacing:            _verticalMargin / 2

            QGCTextField {
                id:                 searchField
                Layout.fillWidth:   true
                placeholderText:    qsTr("Search configuration...")
                placeholderTextColor: vehicleConfigView._secondaryTextColor
                visible:            _fullParameterVehicleAvailable
                backgroundColor:    vehicleConfigView._inputColor
                borderColor:        vehicleConfigView._borderColor
                focusBorderColor:   vehicleConfigView._accentColor
                focusGlowColor:     vehicleConfigView._accentColor
                borderRadius:       vehicleConfigView._cornerRadius
                borderWidth:        1
                focusBorderWidth:   1
                showFocusGlow:      true
                textColor:          vehicleConfigView._primaryTextColor

                onTextChanged: {
                    vehicleConfigView._searchQuery = text
                }
            }

            QGCFlickable {
                Layout.fillWidth:   true
                Layout.fillHeight:  true
                contentHeight:      buttonColumn.height + _verticalMargin
                flickableDirection: Flickable.VerticalFlick
                clip:               true
                boundsBehavior:     Flickable.StopAtBounds

                ColumnLayout {
                    id:         buttonColumn
                    width:      parent.width
                    spacing:    0

                    // Summary button
                    ConfigButton {
                        id:                 summaryButton
                        icon.source:        "/qmlimages/VehicleSummaryIcon.png"
                        checked:            vehicleConfigView._selectedSpecial === "summary"
                        text:               qsTr("Summary")
                        Layout.fillWidth:   true
                        visible:            vehicleConfigView._searchQuery.trim() === ""
                        textColor:          checked || pressed ? vehicleConfigView._primaryTextColor : vehicleConfigView._secondaryTextColor
                        icon.color:         textColor

                        onClicked: showSummaryPanel()
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight / 2
                        visible: vehicleConfigView._searchQuery.trim() === ""
                    }

                    // Vehicle component tree
                    Repeater {
                        id:     componentRepeater
                        model:  _fullParameterVehicleAvailable ? _activeVehicle.autopilotPlugin.vehicleComponents : 0

                        ColumnLayout {
                            id:             compColumn
                            spacing:        0
                            Layout.fillWidth: true

                            required property int index
                            required property var modelData

                            property var    comp:           modelData
                            property string compName:       comp ? comp.name : ""
                            property var    compSections:   comp ? comp.sections : []
                            property bool   isSelected:     vehicleConfigView._selectedComponentIndex === index && vehicleConfigView._selectedSpecial === ""
                            property bool   hasSections:    compSections.length > 1
                            property bool   isSearching:    vehicleConfigView._searchQuery.trim() !== ""
                            property bool   matchesSearch:  comp ? vehicleConfigView._componentMatchesSearch(comp) : false
                            property bool   isExpanded:     hasSections && (isSearching ? matchesSearch : vehicleConfigView._isExpanded(index))

                            visible: {
                                if (!comp) return false
                                if (comp.setupSource.toString() === "") return false
                                if (isSearching) return matchesSearch
                                return true
                            }

                            ConfigButton {
                                Layout.fillWidth:   true
                                icon.source:        compColumn.comp ? compColumn.comp.iconResource : ""
                                setupComplete:      compColumn.comp ? compColumn.comp.setupComplete : true
                                text:               compColumn.compName
                                expandable:         compColumn.hasSections
                                expanded:           compColumn.isExpanded
                                checked:            compColumn.isSelected && vehicleConfigView._selectedSectionIndex === -1
                                textColor:          checked || pressed ? vehicleConfigView._primaryTextColor : vehicleConfigView._secondaryTextColor
                                icon.color:         setupComplete ? textColor : vehicleConfigView._accentColor

                                onClicked: {
                                    vehicleConfigView._navigateToComponent(compColumn.index, -1)
                                    if (compColumn.hasSections) {
                                        if (compColumn.isSelected && compColumn.isExpanded) {
                                            vehicleConfigView._setExpanded(compColumn.index, false)
                                        } else if (!compColumn.isExpanded) {
                                            vehicleConfigView._setExpanded(compColumn.index, true)
                                        }
                                    }
                                }

                                onToggleExpand: {
                                    if (!mainWindow.allowViewSwitch()) return
                                    var expanding = !compColumn.isExpanded
                                    vehicleConfigView._setExpanded(compColumn.index, expanding)
                                    if (!expanding && compColumn.isSelected) {
                                        vehicleConfigView._navigateToComponent(compColumn.index, -1)
                                    }
                                }
                            }

                            // Section sub-items
                            Repeater {
                                model: compColumn.isExpanded ? compColumn.compSections : []

                                Button {
                                    id:             sectionBtn
                                    Layout.fillWidth: true
                                    padding:        ScreenTools.defaultFontPixelWidth * 0.75
                                    leftPadding:    ScreenTools.defaultFontPixelWidth * 3
                                    hoverEnabled:   !ScreenTools.isMobile

                                    property int sectionIndex: index
                                    property bool sectionChecked: compColumn.isSelected && vehicleConfigView._selectedSectionIndex === sectionIndex
                                    property bool sectionMatchesSearch: {
                                        if (!compColumn.isSearching) return true
                                        return vehicleConfigView._sectionMatchesSearch(compColumn.comp, modelData)
                                    }
                                    property bool sectionContentVisible: {
                                        if (!compColumn.isSelected) return true
                                        if (!panelLoader.item) return true
                                        if (typeof panelLoader.item.sectionVisible !== "function") return true
                                        return panelLoader.item.sectionVisible(modelData)
                                    }
                                    property color textColor: sectionChecked || pressed ? vehicleConfigView._primaryTextColor : vehicleConfigView._secondaryTextColor
                                    visible: sectionMatchesSearch && sectionContentVisible

                                    background: Rectangle {
                                        color: sectionBtn.sectionChecked
                                            ? Qt.rgba(vehicleConfigView._accentColor.r, vehicleConfigView._accentColor.g, vehicleConfigView._accentColor.b, 0.28)
                                            : (sectionBtn.pressed
                                                ? vehicleConfigView._panelPressedColor
                                                : (sectionBtn.enabled && sectionBtn.hovered
                                                    ? vehicleConfigView._panelHoverColor
                                                    : "transparent"))
                                        border.width: sectionBtn.sectionChecked ? 1 : 0
                                        border.color: sectionBtn.sectionChecked ? vehicleConfigView._accentColor : "transparent"
                                        radius: vehicleConfigView._cornerRadius

                                        Behavior on color { ColorAnimation { duration: vehicleConfigView._stateAnimationDuration } }
                                        Behavior on border.color { ColorAnimation { duration: vehicleConfigView._stateAnimationDuration } }
                                    }

                                    contentItem: RowLayout {
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.5

                                        Rectangle {
                                            width:   ScreenTools.defaultFontPixelWidth
                                            height:  width
                                            radius:  width / 2
                                            color:   vehicleConfigView._accentColor
                                            visible: compColumn.comp && typeof compColumn.comp.sectionSetupComplete === "function"
                                                         && !compColumn.comp.sectionSetupComplete(modelData)
                                        }

                                        QGCLabel {
                                            text:  vehicleConfigView._translateSection(compColumn.comp, modelData)
                                            color: sectionBtn.textColor
                                            font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                                            horizontalAlignment: Text.AlignLeft
                                            Layout.fillWidth: true
                                        }
                                    }

                                    onClicked: {
                                        vehicleConfigView._navigateToComponent(compColumn.index, sectionIndex)
                                    }
                                }
                            }
                        }
                    }

                    // Optical Flow (special)
                    ConfigButton {
                        visible:            _activeVehicle ? _activeVehicle.flowImageIndex > 0 : false
                        text:               qsTr("Optical Flow")
                        Layout.fillWidth:   true
                        checked:            vehicleConfigView._selectedSpecial === "opticalflow"
                        textColor:          checked || pressed ? vehicleConfigView._primaryTextColor : vehicleConfigView._secondaryTextColor
                        icon.color:         textColor
                        onClicked:          showPanel("opticalflow", "qrc:/qml/QGroundControl/VehicleSetup/OpticalFlowSensor.qml")
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight / 2
                        visible: vehicleConfigView._searchQuery.trim() === ""
                    }

                    ConfigButton {
                        id:                 parametersButton
                        visible:            QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable &&
                                            !_activeVehicle.usingHighLatencyLink &&
                                            _corePlugin.showAdvancedUI &&
                                            vehicleConfigView._searchQuery.trim() === ""
                        text:               qsTr("Parameters")
                        Layout.fillWidth:   true
                        icon.source:        "/qmlimages/subMenuButtonImage.png"
                        checked:            vehicleConfigView._selectedSpecial === "parameters"
                        textColor:          checked || pressed ? vehicleConfigView._primaryTextColor : vehicleConfigView._secondaryTextColor
                        icon.color:         textColor
                        onClicked:          showPanel("parameters", "qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml")
                    }

                    ConfigButton {
                        id:                 firmwareButton
                        icon.source:        "/qmlimages/FirmwareUpgradeIcon.png"
                        visible:            !ScreenTools.isMobile && _corePlugin.options.showFirmwareUpgrade &&
                                            vehicleConfigView._searchQuery.trim() === ""
                        text:               qsTr("Firmware")
                        Layout.fillWidth:   true
                        checked:            vehicleConfigView._selectedSpecial === "firmware"
                        textColor:          checked || pressed ? vehicleConfigView._primaryTextColor : vehicleConfigView._secondaryTextColor
                        icon.color:         textColor

                        onClicked: showPanel("firmware", "qrc:/qml/QGroundControl/VehicleSetup/FirmwareUpgrade.qml")
                    }
                }
            }
        }
    }

    Rectangle {
        id:                     divider
        visible:                false
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.leftMargin:     _horizontalMargin
        anchors.left:           leftPanelCard.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        width:                  0
        color:                  _borderColor
    }

    Rectangle {
        id:                     panelHost
        anchors.topMargin:      0
        anchors.bottomMargin:   returnMenuFooter.visible ? returnMenuFooter.height : 0
        anchors.leftMargin:     0
        anchors.rightMargin:    0
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        color:                  "#2F3032"
        radius:                 0
        border.width:           0
        border.color:           "transparent"
        clip:                   true

        Loader {
            id:                     panelLoader
            anchors.fill:           parent
            anchors.margins:        0

            function setSource(source, vehicleComponent) {
                panelLoader.source = ""
                panelLoader.vehicleComponent = vehicleComponent
                panelLoader.source = source
            }

            function setSourceComponent(sourceComponent, vehicleComponent) {
                panelLoader.sourceComponent = undefined
                panelLoader.vehicleComponent = vehicleComponent
                panelLoader.sourceComponent = sourceComponent
            }

            property var vehicleComponent
            readonly property var vehicleConfigViewRef: vehicleConfigView
        }
    }

    Rectangle {
        id: returnMenuFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: visible ? ScreenTools.defaultFontPixelHeight * 2.25 : 0
        color: vehicleConfigView._panelColor
        visible: _fullParameterVehicleAvailable && vehicleConfigView._selectedSpecial !== "menu"
        z: QGroundControl.zOrderWidgets

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: vehicleConfigView._borderColor
        }

        QGCButton {
            id: backToMenuButton
            anchors.centerIn: parent
            text: qsTr("返回菜单")
            backgroundColor: "#6B7280"
            borderColor: "#80879A"
            textColor: "#FFFFFF"
            overlayColor: "#4B5563"
            hoverOverlayOpacity: 0.20
            pressedOverlayOpacity: 0.34
            backRadius: vehicleConfigView._cornerRadius
            showBorder: true
            onClicked: vehicleConfigView.showMenuPanel()
        }
    }
}
