import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.AppSettings

Rectangle {
    id:     settingsView
    property bool _qgcPopupChrome: true
    z:      QGroundControl.zOrderTopMost

    readonly property real _defaultTextHeight:  ScreenTools.defaultFontPixelHeight
    readonly property real _defaultTextWidth:   ScreenTools.defaultFontPixelWidth
    readonly property real _horizontalMargin:   _defaultTextWidth / 2
    readonly property real _verticalMargin:     _defaultTextHeight / 2

    property bool _first: true
    property bool _commingFromRIDSettings: false
    property int  _selectedPageIndex: -1
    property int  _selectedSectionIndex: -1
    property var  _expandedPages: ({})  // pageIndex -> bool
    property int  _expandedRevision: 0  // bumped to trigger re-evaluation
    property string _searchQuery: ""
    readonly property var _allowedSettingsPageUrlFragments: [
        "FlyViewSettings.qml",
        "ADSBServerSettings.qml",
        "CommLinksSettings.qml",
        "MapsSettings.qml",
        "VideoSettings.qml"
    ]

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#1E1E1E" }
        GradientStop { position: 1.0; color: "#222222" }
    }

    function _setExpanded(pageIndex, value) {
        _expandedPages[pageIndex] = value
        _expandedRevision++
    }

    function _isExpanded(pageIndex) {
        void _expandedRevision  // create binding dependency
        return !!_expandedPages[pageIndex]
    }

    function _isAllowedSettingsPage(entry) {
        if (!entry || entry.name === "Divider") {
            return false
        }

        var url = entry.url ? entry.url.toString() : ""
        for (var i = 0; i < _allowedSettingsPageUrlFragments.length; i++) {
            if (url.indexOf(_allowedSettingsPageUrlFragments[i]) !== -1) {
                return true
            }
        }
        return false
    }

    function _firstAllowedPageIndex() {
        for (var i = 0; i < settingsPagesModel.count; i++) {
            var entry = settingsPagesModel.get(i)
            var visibleFn = (entry && entry.pageVisible) ? entry.pageVisible : function() { return true }
            if (_isAllowedSettingsPage(entry) && visibleFn()) {
                return i
            }
        }
        return -1
    }

    // Search: returns array of matching section indices for a page, or empty if no match
    function _matchingSections(pageIndex) {
        var query = _searchQuery.toLowerCase().trim()
        if (query === "") return []  // empty = no filtering

        var entry = settingsPagesModel.get(pageIndex)
        if (!entry || !_isAllowedSettingsPage(entry)) return []

        // Check English search terms
        var termsStr = entry.searchTerms
        var matches = []
        var matched = {}
        if (termsStr && termsStr !== "") {
            try {
                var terms = JSON.parse(termsStr)
                for (var i = 0; i < terms.length; i++) {
                    if (terms[i].terms.indexOf(query) !== -1) {
                        matched[terms[i].section] = true
                        matches.push(terms[i].section)
                    }
                }
            } catch(e) {}
        }

        // Check translatable terms (translated at runtime)
        var trStr = entry.translatableTerms
        if (trStr && trStr !== "") {
            try {
                var trTerms = JSON.parse(trStr)
                for (var j = 0; j < trTerms.length; j++) {
                    if (matched[trTerms[j].section]) continue
                    var ctx = trTerms[j].context
                    var tList = trTerms[j].terms
                    for (var k = 0; k < tList.length; k++) {
                        if (qsTranslate(ctx, tList[k]).toLowerCase().indexOf(query) !== -1) {
                            matched[trTerms[j].section] = true
                            matches.push(trTerms[j].section)
                            break
                        }
                    }
                }
            } catch(e) {}
        }

        return matches
    }

    // Does this page have any search matches? (or is search empty = show all)
    function _pageMatchesSearch(pageIndex) {
        var entry = settingsPagesModel.get(pageIndex)
        if (!_isAllowedSettingsPage(entry)) return false
        if (_searchQuery.trim() === "") return true
        return _matchingSections(pageIndex).length > 0
    }

    function _navigateTo(pageIndex, sectionIndex) {
        var entry = settingsPagesModel.get(pageIndex)
        if (!entry || !_isAllowedSettingsPage(entry)) return

        var url = entry.url
        _selectedSectionIndex = sectionIndex

        if (_selectedPageIndex !== pageIndex) {
            _selectedPageIndex = pageIndex
            rightPanel.source = url
        }

        // Apply section filter after the page is loaded
        if (rightPanel.item && typeof rightPanel.item.sectionFilter !== "undefined") {
            rightPanel.item.sectionFilter = sectionIndex
        }
    }

    function showSettingsPage(settingsPage) {
        for (var i = 0; i < settingsPagesModel.count; i++) {
            var entry = settingsPagesModel.get(i)
            if (entry && _isAllowedSettingsPage(entry) && entry.name === settingsPage) {
                _navigateTo(i, -1)
                break
            }
        }
    }

    // This need to block click event leakage to underlying map.
    DeadMouseArea {
        anchors.fill: parent
    }

    QGCPalette { id: qgcPal }
    QGCPopupStyle { id: popupStyle }

    Component.onCompleted: {
        // Find and select the default page (restricted allow-list only)
        globals.commingFromRIDIndicator = false
        var firstAllowed = _firstAllowedPageIndex()
        if (firstAllowed >= 0) {
            _navigateTo(firstAllowed, -1)
        }
    }

    Connections {
        target: rightPanel
        function onLoaded() {
            if (rightPanel.item && typeof rightPanel.item.sectionFilter !== "undefined") {
                rightPanel.item.sectionFilter = _selectedSectionIndex
            }
        }
    }

    SettingsPagesModel { id: settingsPagesModel }

    Rectangle {
        id:                 leftPanel
        width:              Math.max(buttonColumn.implicitWidth + (_horizontalMargin * 2), ScreenTools.defaultFontPixelWidth * 22)
        anchors.topMargin:  _verticalMargin
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.leftMargin: _horizontalMargin
        anchors.left:       parent.left
        color:              popupStyle.panelBackground
        border.color:       popupStyle.borderColor
        border.width:       1
        radius:             popupStyle.cornerRadius

        readonly property real _panelPadding: _horizontalMargin

        ColumnLayout {
            anchors.fill:        parent
            anchors.margins:     leftPanel._panelPadding
            spacing:             _verticalMargin / 2

            QGCTextField {
                id:                 searchField
                Layout.fillWidth:   true
                placeholderText:    qsTr("Search settings...")

                onTextChanged: {
                    settingsView._searchQuery = text
                }
            }

            QGCFlickable {
                id:                 buttonList
                Layout.fillWidth:   true
                Layout.fillHeight:  true
                contentHeight:      buttonColumn.height + _verticalMargin
                flickableDirection: Flickable.VerticalFlick
                clip:               true

                ColumnLayout {
                    id:         buttonColumn
                    spacing:    0

                    Repeater {
                        id:     buttonRepeater
                        model:  settingsPagesModel

                        ColumnLayout {
                            id:     pageColumn
                            spacing: 0
                            Layout.fillWidth: true

                            required property int index
                            required property var model

                            property string pageName:    model.name ?? ""
                            property string pageUrl:     model.url ?? ""
                            property string pageIconUrl: model.iconUrl ?? ""
                            property var    pageVisible: model.pageVisible ?? function() { return true }
                            property var    pageSections: {
                                try {
                                    var s = model.sections
                                    return (s && s !== "") ? JSON.parse(s) : []
                                } catch(e) {
                                    return []
                                }
                            }
                            property bool isSelected: settingsView._selectedPageIndex === index
                            property bool hasMultipleSections: pageSections.length > 1
                            property bool isSearching: settingsView._searchQuery.trim() !== ""
                            property bool matchesSearch: settingsView._pageMatchesSearch(index)
                            property bool isExpanded: hasMultipleSections && (isSearching ? matchesSearch : settingsView._isExpanded(index))
                            property bool isAllowedPage: settingsView._isAllowedSettingsPage(model)

                            visible: {
                                if (pageName === "Divider") return false
                                if (!isAllowedPage) return false
                                if (!pageVisible()) return false
                                if (isSearching) return matchesSearch
                                return true
                            }

                            // Divider
                            Item {
                                Layout.fillWidth: true
                                height: ScreenTools.defaultFontPixelHeight / 2
                                visible: false
                            }

                            // Page button
                            SettingsButton {
                                Layout.fillWidth: true
                                text:          pageName
                                icon.source:   pageIconUrl
                                expandable:    hasMultipleSections
                                expanded:      isExpanded
                                checked:       isSelected && settingsView._selectedSectionIndex === -1
                                visible:       pageName !== "Divider" && pageVisible() && isAllowedPage

                                onClicked: {
                                    if (mainWindow.allowViewSwitch()) {
                                        settingsView._navigateTo(index, -1)
                                        if (hasMultipleSections) {
                                            // Toggle expand/collapse when re-clicking the same page
                                            if (isSelected && isExpanded) {
                                                settingsView._setExpanded(index, false)
                                            } else if (!isExpanded) {
                                                settingsView._setExpanded(index, true)
                                            }
                                        }
                                    }
                                }

                                onToggleExpand: {
                                    if (!mainWindow.allowViewSwitch()) {
                                        return
                                    }
                                    var expanding = !isExpanded
                                    settingsView._setExpanded(index, expanding)
                                    if (!expanding && isSelected) {
                                        settingsView._navigateTo(index, -1)
                                    }
                                }
                            }

                            // Section sub-items (indented, shown when page is expanded)
                            Repeater {
                                model: isExpanded ? pageSections : []

                                Button {
                                    id:               sectionBtn
                                    Layout.fillWidth: true
                                    padding:          ScreenTools.defaultFontPixelWidth * 0.75
                                    leftPadding:      ScreenTools.defaultFontPixelWidth * 3
                                    hoverEnabled:     !ScreenTools.isMobile
                                    autoExclusive:    true
                                    focusPolicy:      Qt.ClickFocus

                                    property int sectionIndex: index
                                    property bool sectionChecked: pageColumn.isSelected && settingsView._selectedSectionIndex === sectionIndex
                                    property bool sectionMatchesSearch: {
                                        if (!pageColumn.isSearching) return true
                                        var matches = settingsView._matchingSections(pageColumn.index)
                                        return matches.indexOf(sectionIndex) !== -1
                                    }
                                    property bool sectionContentVisible: {
                                        if (!pageColumn.isSelected) return true
                                        if (!rightPanel.item) return true
                                        if (typeof rightPanel.item.sectionVisible !== "function") return true
                                        return rightPanel.item.sectionVisible(sectionIndex)
                                    }
                                    property color textColor: sectionChecked || pressed
                                        ? popupStyle.primaryTextColor
                                        : popupStyle.secondaryTextColor
                                    visible: sectionMatchesSearch && sectionContentVisible

                                    background: Rectangle {
                                        color: sectionBtn.sectionChecked
                                            ? Qt.rgba(popupStyle.accentColor.r, popupStyle.accentColor.g, popupStyle.accentColor.b, 0.24)
                                            : (sectionBtn.pressed
                                                ? popupStyle.pressedColor(popupStyle.panelBackground)
                                                : (sectionBtn.enabled && sectionBtn.hovered
                                                    ? popupStyle.hoverColor(popupStyle.panelBackground)
                                                    : "transparent"))
                                        border.width: sectionBtn.sectionChecked ? 1 : 0
                                        border.color: sectionBtn.sectionChecked ? popupStyle.accentColor : popupStyle.borderColor
                                        radius: popupStyle.cornerRadius

                                        Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
                                        Behavior on border.color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
                                    }

                                    contentItem: QGCLabel {
                                        text:  modelData
                                        color: sectionBtn.textColor
                                        font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    onClicked: {
                                        if (mainWindow.allowViewSwitch()) {
                                            settingsView._navigateTo(pageColumn.index, sectionIndex)
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
        id:                     divider
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.leftMargin:     _horizontalMargin
        anchors.left:           leftPanel.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        width:                  1
        color:                  popupStyle.borderColor
    }

    //-- Panel Contents
    Loader {
        id:                     rightPanel
        anchors.leftMargin:     _horizontalMargin
        anchors.rightMargin:    _horizontalMargin
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.left:           divider.right
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
    }
}
