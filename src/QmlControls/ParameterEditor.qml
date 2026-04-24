import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id:         _root

    property bool   _qgcPopupChrome: true
    property Fact   _editorDialogFact: Fact { }
    property int    _rowHeight:         ScreenTools.defaultFontPixelHeight * 2
    property int    _rowWidth:          10 // Dynamic adjusted at runtime
    property bool   _searchFilter:      searchText.text.trim() != "" || controller.showModifiedOnly || controller.showFavoritesOnly  ///< true: showing results of search
    property var    _searchResults      ///< List of parameter names from search results
    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _showRCToParam:     _activeVehicle.px4Firmware
    property var    _appSettings:       QGroundControl.settingsManager.appSettings
    property var    _controller:        controller
    property var    _favorites:         controller.favoriteParameterNames
    property real   _margins:           ScreenTools.defaultFontPixelHeight / 2
    readonly property real _pageOuterMargin: Math.max(ScreenTools.defaultFontPixelHeight, 16)
    readonly property real _pageInnerMargin: Math.max(ScreenTools.defaultFontPixelHeight * 0.9, 14)
    readonly property real _panelInnerMargin: Math.max(ScreenTools.defaultFontPixelHeight * 0.7, 10)
    readonly property real _panelSpacing: Math.max(ScreenTools.defaultFontPixelWidth * 0.9, 10)
    readonly property real _cardWidth: {
        const availableWidth = Math.max(ScreenTools.defaultFontPixelWidth * 34, width - (_pageOuterMargin * 2))
        const targetWidth = ScreenTools.defaultFontPixelWidth * 118
        const compactWidth = ScreenTools.defaultFontPixelWidth * 56
        return availableWidth < compactWidth ? availableWidth : Math.min(targetWidth, availableWidth)
    }
    readonly property real _cardHeight: {
        const availableHeight = Math.max(ScreenTools.defaultFontPixelHeight * 18, height - (_pageOuterMargin * 2))
        const targetHeight = ScreenTools.defaultFontPixelHeight * 42
        const compactHeight = ScreenTools.defaultFontPixelHeight * 28
        return availableHeight < compactHeight ? availableHeight : Math.min(targetHeight, availableHeight)
    }
    readonly property real _groupPanelWidth: Math.min(ScreenTools.defaultFontPixelWidth * 27, Math.max(ScreenTools.defaultFontPixelWidth * 20, _cardWidth * 0.27))
    readonly property real _toolsMenuWidth: Math.max(ScreenTools.defaultFontPixelWidth * 42, ScreenTools.implicitButtonWidth * 2.8)

    QGCPopupStyle { id: popupStyle }

    function _openToolsMenu() {
        const menuMargin = ScreenTools.defaultFontPixelWidth
        const popupPoint = toolsButton.mapToItem(_root, 0, toolsButton.height)
        const popupHeight = Math.max(toolsMenu.implicitHeight, ScreenTools.implicitButtonHeight)
        const popupGap = Math.max(2, ScreenTools.defaultFontPixelHeight * 0.08)
        const maxX = Math.max(menuMargin, _root.width - toolsMenu.width - menuMargin)
        const maxY = Math.max(menuMargin, _root.height - popupHeight - menuMargin)
        const popupX = Math.max(menuMargin, Math.min(popupPoint.x + toolsButton.width - toolsMenu.width, maxX))
        const popupY = Math.max(menuMargin, Math.min(popupPoint.y + popupGap, maxY))

        toolsMenu.popup(popupX, popupY)
    }

    ParameterEditorController {
        id: controller
    }

    Rectangle {
        anchors.fill: parent
        color: popupStyle.popupBackground
    }

    Rectangle {
        id: editorCard
        anchors.centerIn: parent
        width: _cardWidth
        height: _cardHeight
        color: popupStyle.panelBackground
        border.width: 1
        border.color: popupStyle.borderColor
        radius: popupStyle.cornerRadius
    }

    Rectangle {
        id: groupPanel
        anchors.left: editorCard.left
        anchors.leftMargin: _pageInnerMargin
        anchors.top: tabBar.bottom
        anchors.topMargin: _panelSpacing
        anchors.bottom: editorCard.bottom
        anchors.bottomMargin: _pageInnerMargin
        width: _groupPanelWidth
        visible: !_searchFilter
        color: popupStyle.panelBackground
        border.width: 1
        border.color: popupStyle.borderColor
        radius: popupStyle.cornerRadius
    }

    Rectangle {
        id: tablePanel
        anchors.left: _searchFilter ? editorCard.left : groupPanel.right
        anchors.leftMargin: _searchFilter ? _pageInnerMargin : _panelSpacing
        anchors.top: tabBar.bottom
        anchors.topMargin: _panelSpacing
        anchors.right: editorCard.right
        anchors.rightMargin: _pageInnerMargin
        anchors.bottom: editorCard.bottom
        anchors.bottomMargin: _pageInnerMargin
        color: popupStyle.panelBackground
        border.width: 1
        border.color: popupStyle.borderColor
        radius: popupStyle.cornerRadius
    }

    Timer {
        id:         clearTimer
        interval:   100;
        running:    false;
        repeat:     false
        onTriggered: {
            searchText.text = ""
            controller.searchText = ""
        }
    }

    QGCMenu {
        id:                 toolsMenu
        width:              _toolsMenuWidth

        QGCMenuItem {
            text:           qsTr("Refresh")
            onTriggered:	controller.refresh()
        }
        QGCMenuItem {
            text:           qsTr("Reset all to firmware's defaults")
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Reset All"),
                                                         qsTr("Select Reset to reset all parameters to their defaults.\n\nNote that this will also completely reset everything, including UAVCAN nodes, all vehicle settings, setup and calibrations."),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToDefaults() })
        }
        QGCMenuItem {
            text:           qsTr("Reset to vehicle's configuration defaults")
            visible:        !_activeVehicle.apmFirmware
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Reset All"),
                                                         qsTr("Select Reset to reset all parameters to the vehicle's configuration defaults."),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToVehicleConfiguration() })
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Load from file for review...")
            onTriggered: {
                fileDialog.title =          qsTr("Load Parameters")
                fileDialog.openForLoad()
            }
        }
        QGCMenuItem {
            text:           qsTr("Save to file...")
            onTriggered: {
                fileDialog.title =          qsTr("Save Parameters")
                fileDialog.openForSave()
            }
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Clear all favorites")
            onTriggered:    controller.clearAllFavorites()
        }
        QGCMenuSeparator { visible: _showRCToParam }
        QGCMenuItem {
            text:           qsTr("Clear all RC to Param")
            onTriggered:	_activeVehicle.clearAllParamMapRC()
            visible:        _showRCToParam
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Reboot Vehicle")
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Reboot Vehicle"),
                                                         qsTr("Select Ok to reboot vehicle."),
                                                         Dialog.Cancel | Dialog.Ok,
                                                         function() { _activeVehicle.rebootVehicle() })
        }
    }


    QGCFileDialog {
        id:             fileDialog
        folder:         _appSettings.parameterSavePath
        nameFilters:    [ qsTr("Parameter Files (*.%1)").arg(_appSettings.parameterFileExtension) , qsTr("All Files (*)") ]

        onAcceptedForSave: (file) => {
            controller.saveToFile(file)
            close()
        }

        onAcceptedForLoad: (file) => {
            close()
            if (controller.buildDiffFromFile(file)) {
                parameterDiffDialogFactory.open()
            }
        }
    }

    QGCPopupDialogFactory {
        id: editorDialogFactory

        dialogComponent: editorDialogComponent
    }

    Component {
        id: editorDialogComponent

        ParameterEditorDialog {
            fact:           _editorDialogFact
            showRCToParam:  _showRCToParam
        }
    }

    QGCPopupDialogFactory {
        id: parameterDiffDialogFactory

        dialogComponent: parameterDiffDialog
    }

    Component {
        id: parameterDiffDialog

        ParameterDiffDialog {
            paramController: _controller
        }
    }

    RowLayout {
        id:             header
        anchors.left:   editorCard.left
        anchors.leftMargin: _pageInnerMargin
        anchors.right:  editorCard.right
        anchors.rightMargin: _pageInnerMargin
        anchors.top:    editorCard.top
        anchors.topMargin: _pageInnerMargin
        spacing:        _panelSpacing

        RowLayout {
            Layout.alignment:   Qt.AlignLeft
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCTextField {
                id:                     searchText
                Layout.preferredWidth:  Math.min(editorCard.width * 0.42, ScreenTools.defaultFontPixelWidth * 30)
                placeholderText:        qsTr("Search")
                onDisplayTextChanged:   controller.searchText = displayText
            }

            QGCButton {
                text: qsTr("Clear")
                onClicked: {
                    if(ScreenTools.isMobile) {
                        Qt.inputMethod.hide();
                    }
                    clearTimer.start()
                }
            }
        }

        QGCButton {
            id:                 toolsButton
            Layout.alignment:   Qt.AlignRight
            text:               qsTr("Tools")
            onClicked:          _root._openToolsMenu()
        }
    }

    QGCTabBar {
        id:             tabBar
        anchors.left:   editorCard.left
        anchors.leftMargin: _pageInnerMargin
        anchors.right:  editorCard.right
        anchors.rightMargin: _pageInnerMargin
        anchors.top:        header.bottom
        anchors.topMargin:  _panelSpacing

        QGCTabButton {
            text:                   qsTr("Full List")
            showBorder:             true
            backRadius:             popupStyle.cornerRadius
            buttonColor:            popupStyle.secondaryButtonColor
            checkedButtonColor:     popupStyle.accentColor
            hoverButtonColor:       popupStyle.secondaryButtonHoverColor()
            buttonBorderColor:      popupStyle.borderColor
            buttonTextColor:        popupStyle.secondaryTextColor
            checkedButtonTextColor: popupStyle.primaryTextColor
        }
        QGCTabButton {
            text:                   qsTr("Modified")
            showBorder:             true
            backRadius:             popupStyle.cornerRadius
            buttonColor:            popupStyle.secondaryButtonColor
            checkedButtonColor:     popupStyle.accentColor
            hoverButtonColor:       popupStyle.secondaryButtonHoverColor()
            buttonBorderColor:      popupStyle.borderColor
            buttonTextColor:        popupStyle.secondaryTextColor
            checkedButtonTextColor: popupStyle.primaryTextColor
        }
        QGCTabButton {
            text:                   qsTr("Favorites")
            showBorder:             true
            backRadius:             popupStyle.cornerRadius
            buttonColor:            popupStyle.secondaryButtonColor
            checkedButtonColor:     popupStyle.accentColor
            hoverButtonColor:       popupStyle.secondaryButtonHoverColor()
            buttonBorderColor:      popupStyle.borderColor
            buttonTextColor:        popupStyle.secondaryTextColor
            checkedButtonTextColor: popupStyle.primaryTextColor
        }

        onCurrentIndexChanged: {
            controller.showModifiedOnly  = (currentIndex === 1)
            controller.showFavoritesOnly = (currentIndex === 2)
        }
    }

    /// Group buttons
    QGCFlickable {
        id :                groupScroll
        anchors.fill:       groupPanel
        anchors.margins:    _panelInnerMargin
        width:              parent ? Math.max(0, parent.width - (_panelInnerMargin * 2)) : 0
        clip:               true
        pixelAligned:       true
        contentHeight:      groupedViewCategoryColumn.height
        flickableDirection: Flickable.VerticalFlick
        visible:            !_searchFilter

        ColumnLayout {
            id:             groupedViewCategoryColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)

            Repeater {
                model: controller.categories

                Column {
                    Layout.fillWidth:   true
                    spacing:            Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)


                    SectionHeader {
                        id:             categoryHeader
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           object.name
                        color:          popupStyle.primaryTextColor
                        checked:        object == controller.currentCategory

                        onCheckedChanged: {
                            if (checked) {
                                controller.currentCategory  = object
                            }
                        }
                    }

                    Repeater {
                        model: categoryHeader.checked ? object.groups : 0

                        QGCButton {
                            width:          groupedViewCategoryColumn.width
                            text:           object.name
                            height:         _rowHeight
                            checked:        object == controller.currentGroup
                            autoExclusive:  true

                            onClicked: {
                                if (!checked) _rowWidth = 10
                                checked = true
                                controller.currentGroup = object
                            }
                        }
                    }
                }
            }
        }
    }

    HorizontalHeaderView {
        id:                 headerView
        anchors.left:       tableView.left
        anchors.right:      tableView.right
        anchors.top:        tablePanel.top
        anchors.topMargin:  _panelInnerMargin
        syncView:           tableView
        clip:               true

        delegate: Rectangle {
            implicitWidth:  column === 0 ? ScreenTools.implicitCheckBoxHeight + ScreenTools.defaultFontPixelWidth
                                         : headerLabel.contentWidth + ScreenTools.defaultFontPixelWidth
            implicitHeight: headerLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
            color:          popupStyle.inputBackground

            QGCLabel {
                id:                     headerLabel
                anchors.left:           parent.left
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                anchors.verticalCenter: parent.verticalCenter
                text:                   display
                font.bold:              true
                color:                  popupStyle.secondaryTextColor
            }

            // Top border
            Rectangle {
                anchors.top:    parent.top
                width:          parent.width
                height:         1
                color:          popupStyle.borderColor
            }

            // Left border
            Rectangle {
                anchors.left:   parent.left
                height:         parent.height
                width:          1
                color:          popupStyle.borderColor
            }

            // Right border (last column only)
            Rectangle {
                anchors.right:  parent.right
                height:         parent.height
                width:          1
                color:          popupStyle.borderColor
                visible:        column == 3
            }

            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         1
                color:          popupStyle.borderColor
            }
        }
    }

    TableView {
        id:                 tableView
        anchors.leftMargin: _panelInnerMargin
        anchors.top:        headerView.bottom
        anchors.bottom:     tablePanel.bottom
        anchors.bottomMargin: _panelInnerMargin
        anchors.left:       tablePanel.left
        anchors.right:      tablePanel.right
        anchors.rightMargin: _panelInnerMargin
        columnSpacing:      0
        rowSpacing:         0
        model:              controller.parameters
        contentWidth:       width
        clip:               true

        // Qt is supposed to adjust column widths automatically when larger widths come into view.
        // But it doesn't work. So we have to do it force a layout manually when we scroll.
        Timer {
            id:             forceLayoutTimer
            interval:       500
            repeat:         false
            onTriggered:    tableView.forceLayout()
        }

        onTopRowChanged: forceLayoutTimer.start()
        onModelChanged: {
            positionViewAtRow(0, TableView.AlignLeft | TableView.AlignTop)
            forceLayoutTimer.start()
        }

        delegate: Rectangle {
            implicitWidth:  column === 0 ? ScreenTools.implicitCheckBoxHeight + ScreenTools.defaultFontPixelWidth
                                         : column === 2 ? ScreenTools.defaultFontPixelWidth * 16
                                                        : label.contentWidth + ScreenTools.defaultFontPixelWidth
            implicitHeight: label.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
            color:          row % 2 === 0 ? popupStyle.panelBackground : popupStyle.inputBackground
            clip:           true

            // Bottom grid line
            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         1
                color:          popupStyle.borderColor
            }

            // Left grid line
            Rectangle {
                anchors.left:   parent.left
                height:         parent.height
                width:          1
                color:          popupStyle.borderColor
            }

            // Right grid line (last column only)
            Rectangle {
                anchors.right:  parent.right
                height:         parent.height
                width:          1
                color:          popupStyle.borderColor
                visible:        column == 3
            }

            QGCCheckBox {
                visible:                column === 0
                anchors.centerIn:       parent
                checked:                _root._favorites.indexOf(fact.name) >= 0
                z:                      1
                onClicked:              controller.toggleFavorite(fact.name)
            }

            QGCLabel {
                id:                 label
                visible:            column !== 0
                anchors.left:       parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth / 2
                anchors.verticalCenter: parent.verticalCenter
                width:              column == 2 ? ScreenTools.defaultFontPixelWidth * 15 : contentWidth
                text:               column == 2 ? col1String() : display
                color:              column == 2 && fact.defaultValueAvailable && !fact.valueEqualsDefault
                                        ? qgcPal.modifiedParamValue
                                        : (column === 1 ? popupStyle.primaryTextColor : popupStyle.secondaryTextColor)
                font.bold:          column == 2 && fact.defaultValueAvailable && !fact.valueEqualsDefault
                maximumLineCount:   1
                elide:              column == 2 ? Text.ElideRight : Text.ElideNone

                function col1String() {
                    if (fact.enumStrings.length === 0) {
                        return fact.valueString + " " + fact.units
                    }
                    if (fact.bitmaskStrings.length != 0) {
                        return fact.selectedBitmaskStrings.join(',')
                    }
                    return fact.enumStringValue
                }
            }

            QGCMouseArea {
                anchors.fill: parent
                visible:      column !== 0
                onClicked: mouse => {
                    _editorDialogFact = fact
                    editorDialogFactory.open()
                }
            }
        }
    }
}
