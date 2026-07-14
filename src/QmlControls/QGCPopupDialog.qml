import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

// Provides the standard dialog mechanism for QGC. Works 99% like Qml Dialog.
//
// Example usage:
//      QGCPopupDialogFactory {
//          id: myDialogFactory
//          dialogComponent: myDialogComponent
//      }
//
//      Component {
//          id: myDialogComponent
//
//          QGCPopupDialog {
//              ...
//          }
//      }
//
//      onFoo: myDialogFactory.open()
//      onBar: myDialogFactory.open({ title: "My Title", myProp: someValue })
//
// Notes:
//  * Use QGCPopupDialogFactory to create and open dialogs. The factory handles correct parenting and cleanup of the dialog instances.
//  * The dialog automatically reparents itself to Overlay.overlay on creation, while tracking the original parent's lifetime to prevent orphaned dialogs.
// Differences from standard Qml Dialog:
//  * The QGCPopupDialog object will automatically be destroyed when it closed. You can override this
//      behaviour by setting destroyOnClose to false if it was not created dynamically.
//  * Dialog will automatically close after accepted/rejected signal processing. You can prevent this by setting
//      preventClose = true prior to returning from your signal handlers.
Popup {
    id:                 root
    width:  mainWindow.width
    height: mainWindow.height
    modal:              true
    focus:              true
    margins:            0
    property bool _qgcPopupChrome: true

    default property alias dialogContent: dialogContentParent.data

    property string title
    property var    buttons:                Dialog.Ok
    property string acceptButtonText:        ""
    property string rejectButtonText:        ""
    property bool   bottomActionButtons:     false
    property bool   showTitleAccent:         false
    property bool   useExplicitActionColors: false
    property color  actionPrimaryBackgroundColor: popupStyle.primaryButtonColor
    property color  actionPrimaryBorderColor:     actionPrimaryBackgroundColor
    property color  actionPrimaryTextColor:       popupStyle.primaryTextColor
    property color  actionSecondaryBackgroundColor: popupStyle.secondaryButtonColor
    property color  actionSecondaryBorderColor:     popupStyle.borderColor
    property color  actionSecondaryTextColor:       popupStyle.primaryTextColor
    property real   actionButtonRadius:       popupStyle.cornerRadius
    property alias  acceptButtonEnabled:    acceptButton.enabled
    property alias  rejectButtonEnabled:    rejectButton.enabled
    property var    dialogProperties
    property bool   destroyOnClose:         true
    property bool   preventClose:           false

    property real maxContentAvailableWidth:    mainWindow.width - _contentMargin * 6
    property real maxContentAvailableHeight:   mainWindow.height - titleRowLayout.height - _contentMargin * 7
    readonly property real _outerMargin:       _contentMargin * 2

    readonly property real headerMinWidth: titleLabel.implicitWidth + (showTitleAccent ? titleAccent.implicitWidth : 0) + (bottomActionButtons ? 0 : rejectButton.width + acceptButton.width) + titleRowLayout.spacing * 3

    signal accepted
    signal rejected

    property var    _qgcPal:            QGroundControl.globalPalette
    property real   _frameSize:         ScreenTools.defaultFontPixelWidth
    property real   _contentMargin:     ScreenTools.defaultFontPixelHeight / 2
    property bool   _acceptAllowed:     _acceptButtonVisible
    property bool   _rejectAllowed:     _rejectButtonVisible
    property bool   _acceptButtonVisible: false
    property bool   _rejectButtonVisible: false
    property int    _previousValidationErrorCount: 0

    QGCPopupStyle { id: popupStyle }

    background: Item {
        width:  mainWindow.width
        height: mainWindow.height

        Rectangle {
            anchors.fill: parent
            color: popupStyle.overlayColor
        }

        QGCMouseArea {
            anchors.fill: parent

            onClicked: {
                if (root.closePolicy & Popup.CloseOnPressOutside) {
                    root._reject()
                }
            }
        }
    }

    // We use this to track when the original parent of the dialog is destroyed. This allows us to automatically close the dialog when that happens which prevents
    // orphaned dialogs which cause crashes.
    Connections {
        id: originalParentConnections
        ignoreUnknownSignals: true // Prevents warning from initial connection when parent is null
        onDestroyed: root.close()
    }

    Component.onCompleted: {
        originalParentConnections.target = parent
        parent = Overlay.overlay
    }

    onAboutToShow: {
        _previousValidationErrorCount = globals.validationErrorCount
        setupDialogButtons(buttons)
    }

    onClosed: {
        globals.validationErrorCount = _previousValidationErrorCount
        Qt.inputMethod.hide()
        if (destroyOnClose) {
            root.destroy()
        }
    }

    function _accept() {
        if (_acceptAllowed && mainWindow.allowViewSwitch(_previousValidationErrorCount)) {
            accepted()
            if (preventClose) {
                preventClose = false
            } else {
                close()
            }
        }
    }

    function _reject() {
        // Dialogs with cancel button are allowed to close with validation errors
        if (_rejectAllowed && ((buttons & Dialog.Cancel) || mainWindow.allowViewSwitch(_previousValidationErrorCount))) {
            rejected()
            if (preventClose) {
                preventClose = false
            } else {
                close()
            }
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    function setupDialogButtons(buttons) {
        _acceptButtonVisible = false
        _rejectButtonVisible = false
        // Accept role buttons
        if (buttons & Dialog.Ok) {
            acceptButton.text = qsTr("确定")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.Open) {
            acceptButton.text = qsTr("打开")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.Save) {
            acceptButton.text = qsTr("保存")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.Apply) {
            acceptButton.text = qsTr("应用")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.Open) {
            acceptButton.text = qsTr("打开")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.SaveAll) {
            acceptButton.text = qsTr("全部保存")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.Yes) {
            acceptButton.text = qsTr("是")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.YesToAll) {
            acceptButton.text = qsTr("全部是")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.Retry) {
            acceptButton.text = qsTr("重试")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.Reset) {
            acceptButton.text = qsTr("重置")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.RestoreToDefaults) {
            acceptButton.text = qsTr("恢复默认")
            _acceptButtonVisible = true
        } else if (buttons & Dialog.Ignore) {
            acceptButton.text = qsTr("忽略")
            _acceptButtonVisible = true
        }

        // Reject role buttons
        if (buttons & Dialog.Cancel) {
            rejectButton.text = qsTr("取消")
            _rejectButtonVisible = true
        } else if (buttons & Dialog.Close) {
            rejectButton.text = qsTr("关闭")
            _rejectButtonVisible = true
        } else if (buttons & Dialog.No) {
            rejectButton.text = qsTr("否")
            _rejectButtonVisible = true
        } else if (buttons & Dialog.NoToAll) {
            rejectButton.text = qsTr("全部否")
            _rejectButtonVisible = true
        } else if (buttons & Dialog.Abort) {
            rejectButton.text = qsTr("中止")
            _rejectButtonVisible = true
        }

        closePolicy = Popup.NoAutoClose
        if (buttons & Dialog.Cancel) {
            closePolicy |= Popup.CloseOnEscape
        }
        if (_acceptButtonVisible && acceptButtonText !== "") {
            acceptButton.text = acceptButtonText
        }
        if (_rejectButtonVisible && rejectButtonText !== "") {
            rejectButton.text = rejectButtonText
        }
    }

    function disableAcceptButton() {
        acceptButton.enabled = false
    }

    Item {
        id:             dialogChrome
        x:              mainLayout.x - root._contentMargin * 1.5
        y:              mainLayout.y - root._contentMargin * 1.5
        width:          mainLayout.width + root._contentMargin * 3
        height:         mainLayout.height + root._contentMargin * 3

        Rectangle {
            anchors.fill: parent
            radius:         popupStyle.cornerRadius
            color:          popupStyle.popupBackground
            border.width:   1
            border.color:   popupStyle.borderColor
        }
    }

    ColumnLayout {
        id:                 mainLayout
        x:                  Math.max(root._outerMargin, (root.width - width) / 2)
        y:                  Math.max(root._outerMargin, (root.height - height) / 2)
        width:              Math.min(root.maxContentAvailableWidth, Math.max(root.headerMinWidth, dialogPanel.totalContentWidth))
        spacing:            root._contentMargin

        RowLayout {
            id:                     titleRowLayout
            Layout.fillWidth:       true
            Layout.preferredWidth:  mainLayout.width
            spacing:                root._contentMargin

            Rectangle {
                id:                 titleAccent
                Layout.alignment:   Qt.AlignVCenter
                implicitWidth:      ScreenTools.defaultFontPixelWidth * 0.45
                implicitHeight:     ScreenTools.defaultFontPixelHeight * 1.5
                radius:             width / 2
                color:              root.actionPrimaryBackgroundColor
                visible:            root.showTitleAccent || root.bottomActionButtons
            }

            QGCLabel {
                id:                 titleLabel
                Layout.fillWidth:   true
                text:               root.title
                font.pointSize:     ScreenTools.mediumFontPointSize
                font.bold:          true
                color:              popupStyle.primaryTextColor
                verticalAlignment:  Text.AlignVCenter
            }

            QGCButton {
                id:                     rejectButton
                visible:                root._rejectButtonVisible && !root.bottomActionButtons
                useExplicitPopupColors: root.useExplicitActionColors
                backgroundColor:        root.actionSecondaryBackgroundColor
                borderColor:            root.actionSecondaryBorderColor
                textColor:              root.actionSecondaryTextColor
                overlayColor:           root.actionPrimaryBackgroundColor
                hoverOverlayOpacity:    0.12
                pressedOverlayOpacity:  0.20
                backRadius:             root.actionButtonRadius
                showBorder:             true
                fontWeight:             root.useExplicitActionColors ? Font.DemiBold : Font.Normal
                heightFactor:           root.useExplicitActionColors ? 0.38 : 0.5
                onClicked:              root._reject()
                Layout.minimumWidth:    height * 1.5
            }

            QGCButton {
                id:                     acceptButton
                visible:                root._acceptButtonVisible && !root.bottomActionButtons
                primary:                true
                useExplicitPopupColors: root.useExplicitActionColors
                backgroundColor:        root.actionPrimaryBackgroundColor
                borderColor:            root.actionPrimaryBorderColor
                textColor:              root.actionPrimaryTextColor
                overlayColor:           "#FFFFFF"
                hoverOverlayOpacity:    0.10
                pressedOverlayOpacity:  0.18
                backRadius:             root.actionButtonRadius
                showBorder:             true
                fontWeight:             root.useExplicitActionColors ? Font.DemiBold : Font.Normal
                heightFactor:           root.useExplicitActionColors ? 0.38 : 0.5
                onClicked:              root._accept()
                Layout.minimumWidth:    height * 1.5
            }
        }

        Rectangle {
            id:                     dialogPanel
            Layout.fillWidth:       true
            Layout.preferredWidth:  Math.min(maxAvailableWidth, Math.max(root.headerMinWidth, totalContentWidth))
            Layout.preferredHeight: Math.min(maxAvailableHeight, totalContentHeight)
            color:                  popupStyle.panelBackground
            radius:                 popupStyle.cornerRadius
            border.width:           1
            border.color:           popupStyle.borderColor
            clip:                   true

            property real totalContentWidth:    dialogContentParent.childrenRect.width + root._contentMargin * 2
            property real totalContentHeight:   dialogContentParent.childrenRect.height + root._contentMargin * 2
            property real maxAvailableWidth:    mainWindow.width - root._contentMargin * 4
            property real maxAvailableHeight:   mainWindow.height - titleRowLayout.height - (footerActionRow.visible ? footerActionRow.implicitHeight : 0) - root._contentMargin * 6

            QGCFlickable {
                id:                 contentFlickable
                anchors.margins:    root._contentMargin
                anchors.fill:       parent
                contentWidth:       dialogContentParent.childrenRect.width
                contentHeight:      dialogContentParent.childrenRect.height
                clip:               true
                boundsBehavior:     Flickable.StopAtBounds
                interactive:        (contentHeight > height) || (contentWidth > width)

                Item {
                    id:     dialogContentParent
                    width:  Math.max(childrenRect.width, contentFlickable.width)
                    focus:  true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape && root._rejectAllowed) {
                            root._reject()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        RowLayout {
            id:                     footerActionRow
            Layout.fillWidth:       true
            spacing:                root._contentMargin * 0.75
            visible:                root.bottomActionButtons && (root._acceptButtonVisible || root._rejectButtonVisible)

            Item {
                Layout.fillWidth: true
            }

            QGCButton {
                visible:                root._rejectButtonVisible
                text:                   rejectButton.text
                enabled:                rejectButton.enabled
                useExplicitPopupColors: root.useExplicitActionColors
                backgroundColor:        root.actionSecondaryBackgroundColor
                borderColor:            root.actionSecondaryBorderColor
                textColor:              root.actionSecondaryTextColor
                overlayColor:           root.actionPrimaryBackgroundColor
                hoverOverlayOpacity:    0.12
                pressedOverlayOpacity:  0.20
                backRadius:             root.actionButtonRadius
                showBorder:             true
                fontWeight:             Font.DemiBold
                heightFactor:           0.42
                Layout.minimumWidth:    ScreenTools.defaultFontPixelWidth * 10
                onClicked:              root._reject()
            }

            QGCButton {
                visible:                root._acceptButtonVisible
                text:                   acceptButton.text
                enabled:                acceptButton.enabled
                primary:                !root.useExplicitActionColors
                useExplicitPopupColors: root.useExplicitActionColors
                backgroundColor:        root.actionPrimaryBackgroundColor
                borderColor:            root.actionPrimaryBorderColor
                textColor:              root.actionPrimaryTextColor
                overlayColor:           "#FFFFFF"
                hoverOverlayOpacity:    0.10
                pressedOverlayOpacity:  0.18
                backRadius:             root.actionButtonRadius
                showBorder:             true
                fontWeight:             Font.DemiBold
                heightFactor:           0.42
                Layout.minimumWidth:    ScreenTools.defaultFontPixelWidth * 10
                onClicked:              root._accept()
            }
        }
    }
}
