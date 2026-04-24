import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AnalyzePage {
    id: root
    pageComponent: pageComponent
    pageDescription: qsTr("Provides a connection to the vehicle's system shell.")
    allowPopout: true

    AnalyzePalette { id: analyzePalette }

    property bool isLoaded: false

    // Key input on mobile is handled differently, so use a separate command input text field.
    // E.g. for android see https://bugreports.qt.io/browse/QTBUG-40803
    readonly property bool _separateCommandInput: ScreenTools.isMobile

    MAVLinkConsoleController { id: conController }

    Component {
        id: pageComponent

        ColumnLayout {
            height: availableHeight
            width: availableWidth
            spacing: ScreenTools.defaultFontPixelHeight * 0.75
            property int _consoleOutputLen: 0

            function scrollToBottom() {
                if (flickable.contentHeight > flickable.height) {
                    flickable.contentY = flickable.contentHeight - flickable.height
                }
            }

            function getCommand() { return textConsole.getText(_consoleOutputLen, textConsole.length) }

            function getCommandAndClear() {
                const command = getCommand()
                textConsole.remove(_consoleOutputLen, textConsole.length)
                return command
            }

            function pasteFromClipboard() {
                // we need to handle a few cases here:
                // in the general form we have: <command_pre><cursor><command_post>
                // and the clipboard may contain newlines
                const cursor = textConsole.cursorPosition - _consoleOutputLen
                var command = getCommandAndClear()
                var command_pre = ""
                var command_post = command
                if (cursor > 0) {
                    command_pre = command.substr(0, cursor)
                    command_post = command.substr(cursor)
                }
                var command_leftover = conController.handleClipboard(command_pre) + command_post
                textConsole.insert(textConsole.length, command_leftover)
                textConsole.cursorPosition = textConsole.length - command_post.length
            }

            function resetPrompt() {
                textConsole.text = "> "
                _consoleOutputLen = textConsole.length
                textConsole.cursorPosition = textConsole.length
            }

            function refreshConsoleFromModel() {
                const command = getCommand()
                const cursor = textConsole.cursorPosition - _consoleOutputLen

                textConsole.text = conController.text
                _consoleOutputLen = textConsole.length
                textConsole.insert(textConsole.length, command)
                textConsole.cursorPosition = textConsole.length

                if (cursor >= 0) {
                    textConsole.cursorPosition = _consoleOutputLen + cursor
                }

                if (textConsole.length === 0) {
                    resetPrompt()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: statusContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                radius: analyzePalette.cornerRadius
                color: analyzePalette.inputSurface
                border.width: analyzePalette.borderWidth
                border.color: analyzePalette.border

                RowLayout {
                    id: statusContent
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.45
                    spacing: ScreenTools.defaultFontPixelWidth

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight * 0.15

                        QGCLabel {
                            Layout.fillWidth: true
                            text: conController.activeVehicleAvailable
                                ? (conController.linkActive
                                    ? qsTr("%1 shell connected").arg(conController.vehicleName)
                                    : qsTr("%1 detected, waiting for link").arg(conController.vehicleName))
                                : qsTr("Connect a vehicle to open the MAVLink shell")
                            color: analyzePalette.textPrimary
                            wrapMode: Text.WordWrap
                            font.pointSize: ScreenTools.defaultFontPointSize
                            font.weight: Font.DemiBold
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text: ScreenTools.isMobile
                                ? qsTr("Enter commands below and tap Send.")
                                : qsTr("Press Enter to send, use Up/Down for command history, and Ctrl+V to paste multiple commands.")
                            color: analyzePalette.textSecondary
                            wrapMode: Text.WordWrap
                        }
                    }

                    AnalyzeButton {
                        text: qsTr("Reconnect")
                        enabled: conController.activeVehicleAvailable
                        onClicked: {
                            conController.reopenConsole()
                            if (!_separateCommandInput) {
                                textConsole.forceActiveFocus()
                            }
                        }
                    }

                    AnalyzeButton {
                        text: qsTr("Clear")
                        enabled: root.isLoaded
                        onClicked: {
                            conController.clear()
                            resetPrompt()
                            if (!_separateCommandInput) {
                                textConsole.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Connections {
                target: conController
                function onDataChanged(topLeft, bottomRight, roles) {
                    if (isLoaded) {
                        // rate-limit updates to reduce CPU load
                        updateTimer.start();
                    }
                }
                function onModelReset() {
                    if (isLoaded) {
                        resetPrompt()
                    }
                }
            }

            Timer {
                id: updateTimer
                interval: 30
                running: false
                repeat: false
                onTriggered: {
                    // only update if scroll bar is at the bottom
                    if (flickable.atYEnd) {
                        refreshConsoleFromModel()
                        scrollToBottom()
                    } else {
                        updateTimer.start();
                    }
                }
            }

            QGCFlickable {
                id: flickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 12
                contentWidth: textConsole.width
                contentHeight: textConsole.height

                TextArea.flickable: TextArea {
                    id: textConsole
                    width: availableWidth
                    wrapMode: Text.WordWrap
                    readOnly: _separateCommandInput || !conController.activeVehicleAvailable || !conController.linkActive
                    textFormat: TextEdit.RichText
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhMultiLine
                    text: "> "
                    focus: conController.activeVehicleAvailable && !_separateCommandInput
                    color: analyzePalette.textPrimary
                    selectedTextColor: analyzePalette.inputSurface
                    selectionColor: analyzePalette.textPrimary
                    font.pointSize: ScreenTools.defaultFontPointSize
                    font.family: ScreenTools.fixedFontFamily

                    Component.onCompleted: {
                        root.isLoaded = true
                        _consoleOutputLen = textConsole.length
                        textConsole.cursorPosition = _consoleOutputLen
                        if (!_separateCommandInput) {
                            textConsole.forceActiveFocus()
                        }
                    }

                    background: Rectangle {
                        color:          analyzePalette.inputSurface
                        radius:         analyzePalette.cornerRadius
                        border.width:   analyzePalette.borderWidth
                        border.color:   analyzePalette.border
                    }

                    Keys.onPressed: (event) => {
                        // ignore tabs
                        if (event.key == Qt.Key_Tab) {
                            event.accepted = true
                        }

                        // ignore for now
                        if (event.matches(StandardKey.Cut)) {
                            event.accepted = true
                        }

                        if (!event.matches(StandardKey.Copy) &&
                            event.key != Qt.Key_Escape &&
                            event.key != Qt.Key_Insert &&
                            event.key != Qt.Key_Pause &&
                            event.key != Qt.Key_Print &&
                            event.key != Qt.Key_SysReq &&
                            event.key != Qt.Key_Clear &&
                            event.key != Qt.Key_Home &&
                            event.key != Qt.Key_End &&
                            event.key != Qt.Key_Left &&
                            event.key != Qt.Key_Up &&
                            event.key != Qt.Key_Right &&
                            event.key != Qt.Key_Down &&
                            event.key != Qt.Key_PageUp &&
                            event.key != Qt.Key_PageDown &&
                            event.key != Qt.Key_Shift &&
                            event.key != Qt.Key_Control &&
                            event.key != Qt.Key_Meta &&
                            event.key != Qt.Key_Alt &&
                            event.key != Qt.Key_AltGr &&
                            event.key != Qt.Key_CapsLock &&
                            event.key != Qt.Key_NumLock &&
                            event.key != Qt.Key_ScrollLock &&
                            event.key != Qt.Key_Super_L &&
                            event.key != Qt.Key_Super_R &&
                            event.key != Qt.Key_Menu &&
                            event.key != Qt.Key_Hyper_L &&
                            event.key != Qt.Key_Hyper_R &&
                            event.key != Qt.Key_Direction_L &&
                            event.key != Qt.Key_Direction_R) {
                            // Note: dead keys do not generate keyPressed event on linux, see
                            // https://bugreports.qt.io/browse/QTBUG-79216

                            scrollToBottom()

                            // ensure cursor position is at an editable region
                            if (textConsole.selectionStart < _consoleOutputLen) {
                                textConsole.select(_consoleOutputLen, textConsole.selectionEnd)
                            }

                            if (textConsole.cursorPosition < _consoleOutputLen) {
                                textConsole.cursorPosition = textConsole.length
                            }
                        }

                        switch (event.key) {
                        case Qt.Key_Left:
                            // don't move beyond current command
                            if (textConsole.cursorPosition == _consoleOutputLen) {
                                event.accepted = true
                            }
                            break;
                        case Qt.Key_Backspace:
                            if (textConsole.cursorPosition <= _consoleOutputLen) {
                                event.accepted = true
                            }
                            break;
                        case Qt.Key_Enter:
                        case Qt.Key_Return:
                            if (conController.activeVehicleAvailable && conController.linkActive) {
                                conController.sendCommand(getCommandAndClear())
                            }
                            event.accepted = true
                            break;
                        default:
                            break;
                        }

                        if (event.matches(StandardKey.Paste)) {
                            pasteFromClipboard()
                            event.accepted = true
                        }

                        // command history
                        if (event.key == Qt.Key_Up) {
                            const command = conController.historyUp(getCommandAndClear())
                            textConsole.insert(textConsole.length, command)
                            textConsole.cursorPosition = textConsole.length
                            event.accepted = true
                        } else if (event.key == Qt.Key_Down) {
                            const command = conController.historyDown(getCommandAndClear())
                            textConsole.insert(textConsole.length, command)
                            textConsole.cursorPosition = textConsole.length
                            event.accepted = true
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: _separateCommandInput

                AnalyzeTextField {
                    id: commandInput
                    Layout.fillWidth: true
                    placeholderText:  qsTr("Enter Commands here...")
                    inputMethodHints: Qt.ImhNoAutoUppercase
                    enabled: conController.activeVehicleAvailable && conController.linkActive
                    onAccepted: sendCommand()

                    function sendCommand() {
                        if (!enabled || text === "") {
                            return
                        }
                        conController.sendCommand(text)
                        text = ""
                        scrollToBottom()
                    }

                }

                AnalyzeButton {
                    primary: true
                    text: qsTr("Send")
                    enabled: commandInput.enabled && commandInput.text !== ""
                    onClicked: commandInput.sendCommand()
                }
            }
        }
    } // Component
} // AnalyzePage
