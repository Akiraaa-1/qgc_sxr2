import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.AnalyzeView
import QGroundControl.Controls

AnalyzePage {
    id:                 geoTagPage
    pageComponent:      pageComponent
    pageDescription:    qsTr("Tag images from a survey mission with GPS coordinates from your flight log.")

    readonly property real _margin: ScreenTools.defaultFontPixelWidth

    AnalyzePalette { id: analyzePalette }

    Component {
        id: pageComponent

        ColumnLayout {
            spacing:    _margin * 2
            width:      availableWidth

            // Status Card
            AnalyzeCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: statusColumn.height + _margin * 2
                visible:                GeoTagController.inProgress || GeoTagController.errorMessage || GeoTagController.taggedCount > 0

                ColumnLayout {
                    id:                 statusColumn
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    _margin
                    spacing:            _margin

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            _margin
                        visible:            GeoTagController.inProgress

                        BusyIndicator {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                            running:                GeoTagController.inProgress
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: _margin / 2

                            QGCLabel {
                                text:               qsTr("Geotagging in progress...")
                                font.bold:          true
                            }

                            ProgressBar {
                                Layout.fillWidth:   true
                                from:               0
                                to:                 100
                                value:              GeoTagController.progress
                            }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth:       true
                        text:                   GeoTagController.errorMessage
                        color:                  analyzePalette.accent
                        font.bold:              true
                        wrapMode:               Text.WordWrap
                        horizontalAlignment:    Text.AlignHCenter
                        visible:                GeoTagController.errorMessage && !GeoTagController.inProgress
                    }

                    QGCLabel {
                        Layout.fillWidth:       true
                        text: {
                            if (GeoTagController.taggedCount > 0 && !GeoTagController.inProgress) {
                                let msg = qsTr("Successfully tagged %1 images").arg(GeoTagController.taggedCount)
                                let details = []
                                if (GeoTagController.skippedCount > 0) {
                                    details.push(qsTr("%1 skipped").arg(GeoTagController.skippedCount))
                                }
                                if (GeoTagController.failedCount > 0) {
                                    details.push(qsTr("%1 failed").arg(GeoTagController.failedCount))
                                }
                                if (details.length > 0) {
                                    msg += " (" + details.join(", ") + ")"
                                }
                                return msg
                            }
                            return ""
                        }
                        color:                  analyzePalette.textSecondary
                        font.bold:              true
                        horizontalAlignment:    Text.AlignHCenter
                        visible:                GeoTagController.taggedCount > 0 && !GeoTagController.inProgress
                    }
                }
            }

            // Step 1: Log File
            AnalyzeCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: step1Column.height + _margin * 2

                ColumnLayout {
                    id:                 step1Column
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    _margin
                    spacing:            _margin

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.5
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                            radius:                 height / 2
                            color:                  GeoTagController.logFile ? analyzePalette.accent : analyzePalette.secondaryButton

                            QGCLabel {
                                anchors.centerIn:   parent
                                text:               GeoTagController.logFile ? "\u2713" : "1"
                                color:              GeoTagController.logFile ? analyzePalette.textPrimary : analyzePalette.textSecondary
                                font.bold:          true
                            }
                        }

                        QGCLabel {
                            text:       qsTr("Select Flight Log")
                            font.bold:  true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        AnalyzeButton {
                            text:               qsTr("Browse...")
                            enabled:            !GeoTagController.inProgress
                            onClicked:          openLogFile.openForLoad()

                            QGCFileDialog {
                                id:             openLogFile
                                title:          qsTr("Select Flight Log")
                                nameFilters:    [qsTr("Flight logs (*.ulg *.bin)"), qsTr("ULog (*.ulg)"), qsTr("DataFlash (*.bin)"), qsTr("All Files (*)")]
                                defaultSuffix:  "ulg"
                                onAcceptedForLoad: (file) => {
                                    GeoTagController.logFile = file
                                    close()
                                }
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            text:               GeoTagController.logFile ? GeoTagController.logFile : qsTr("No file selected")
                            elide:              Text.ElideMiddle
                            opacity:            GeoTagController.logFile ? 1.0 : 0.5
                        }
                    }
                }
            }

            // Step 2: Image Directory
            AnalyzeCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: step2Column.height + _margin * 2

                ColumnLayout {
                    id:                 step2Column
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    _margin
                    spacing:            _margin

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.5
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                            radius:                 height / 2
                            color:                  GeoTagController.imageDirectory ? analyzePalette.accent : analyzePalette.secondaryButton

                            QGCLabel {
                                anchors.centerIn:   parent
                                text:               GeoTagController.imageDirectory ? "\u2713" : "2"
                                color:              GeoTagController.imageDirectory ? analyzePalette.textPrimary : analyzePalette.textSecondary
                                font.bold:          true
                            }
                        }

                        QGCLabel {
                            text:       qsTr("Select Image Folder")
                            font.bold:  true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        AnalyzeButton {
                            text:               qsTr("Browse...")
                            enabled:            !GeoTagController.inProgress
                            onClicked:          selectImageDir.openForLoad()

                            QGCFileDialog {
                                id:             selectImageDir
                                title:          qsTr("Select Image Folder")
                                selectFolder:   true
                                onAcceptedForLoad: (file) => {
                                    GeoTagController.imageDirectory = file
                                    close()
                                }
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            text:               GeoTagController.imageDirectory ? GeoTagController.imageDirectory : qsTr("No folder selected")
                            elide:              Text.ElideMiddle
                            opacity:            GeoTagController.imageDirectory ? 1.0 : 0.5
                        }
                    }
                }
            }

            // Step 3: Save Directory (Optional)
            AnalyzeCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: step3Column.height + _margin * 2

                ColumnLayout {
                    id:                 step3Column
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    _margin
                    spacing:            _margin

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.5
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                            radius:                 height / 2
                            color:                  analyzePalette.secondaryButton

                            QGCLabel {
                                anchors.centerIn:   parent
                                text:               "3"
                                color:              analyzePalette.textSecondary
                                font.bold:          true
                            }
                        }

                        QGCLabel {
                            text:       qsTr("Output Folder (Optional)")
                            font.bold:  true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        AnalyzeButton {
                            text:               qsTr("Browse...")
                            enabled:            !GeoTagController.inProgress
                            onClicked:          selectDestDir.openForLoad()

                            QGCFileDialog {
                                id:             selectDestDir
                                title:          qsTr("Select Output Folder")
                                selectFolder:   true
                                onAcceptedForLoad: (file) => {
                                    GeoTagController.saveDirectory = file
                                    close()
                                }
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            text: {
                                if (GeoTagController.saveDirectory) {
                                    return GeoTagController.saveDirectory
                                } else if (GeoTagController.imageDirectory) {
                                    return GeoTagController.imageDirectory + "/TAGGED"
                                }
                                return qsTr("Default: /TAGGED subfolder")
                            }
                            elide:              Text.ElideMiddle
                            opacity:            GeoTagController.saveDirectory ? 1.0 : 0.5
                        }
                    }
                }
            }

            // Advanced Options
            AnalyzeCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: advancedColumn.height + _margin * 2

                ColumnLayout {
                    id:                 advancedColumn
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    _margin
                    spacing:            _margin

                    QGCLabel {
                        text:       qsTr("Advanced Options")
                        font.bold:  true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        QGCLabel {
                            text: qsTr("Time Offset (seconds):")
                        }

                        AnalyzeTextField {
                            id:                     timeOffsetField
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 10
                            text:                   GeoTagController.timeOffsetSecs.toFixed(1)
                            enabled:                !GeoTagController.inProgress
                            inputMethodHints:       Qt.ImhFormattedNumbersOnly
                            validator:              DoubleValidator { bottom: -3600; top: 3600; decimals: 1 }
                            onEditingFinished:      GeoTagController.timeOffsetSecs = parseFloat(text) || 0
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            text:               qsTr("Adjust if camera clock differs from flight log")
                            opacity:            0.7
                            font.pointSize:     ScreenTools.smallFontPointSize
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        AnalyzeCheckBox {
                            id:         previewCheckbox
                            text:       qsTr("Preview mode (don't write files)")
                            checked:    GeoTagController.previewMode
                            enabled:    !GeoTagController.inProgress
                            onClicked:  GeoTagController.previewMode = checked
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            text:               qsTr("Verify time offset before committing")
                            opacity:            0.7
                            font.pointSize:     ScreenTools.smallFontPointSize
                        }
                    }
                }
            }

            // Action Button
            AnalyzeButton {
                Layout.alignment:       Qt.AlignHCenter
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 20
                primary:                true
                text: {
                    if (GeoTagController.inProgress) {
                        return qsTr("Cancel")
                    } else if (GeoTagController.previewMode) {
                        return qsTr("Preview")
                    } else {
                        return qsTr("Start Tagging")
                    }
                }
                enabled:                (GeoTagController.logFile && GeoTagController.imageDirectory) || GeoTagController.inProgress
                onClicked: {
                    if (GeoTagController.inProgress) {
                        GeoTagController.cancelTagging()
                    } else {
                        GeoTagController.startTagging()
                    }
                }
            }

            // Image List
            AnalyzeCard {
                Layout.fillWidth:       true
                Layout.fillHeight:      true
                Layout.minimumHeight:   ScreenTools.defaultFontPixelHeight * 10
                visible:                GeoTagController.imageModel.count > 0

                ColumnLayout {
                    anchors.fill:       parent
                    anchors.margins:    _margin
                    spacing:            _margin / 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _margin

                        QGCLabel {
                            text:       qsTr("Images (%1)").arg(GeoTagController.imageModel.count)
                            font.bold:  true
                        }

                        Item { Layout.fillWidth: true }

                        // Legend
                        Row {
                            spacing: _margin

                            Row {
                                spacing: _margin / 4
                                Rectangle { width: 10; height: 10; radius: 2; color: analyzePalette.textDisabled; opacity: 0.8 }
                                QGCLabel { text: qsTr("Pending"); font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            Row {
                                spacing: _margin / 4
                                Rectangle { width: 10; height: 10; radius: 2; color: analyzePalette.accent }
                                QGCLabel { text: qsTr("Processing"); font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            Row {
                                spacing: _margin / 4
                                Rectangle { width: 10; height: 10; radius: 2; color: "#8CB3FF" }
                                QGCLabel { text: qsTr("Tagged"); font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            Row {
                                spacing: _margin / 4
                                Rectangle { width: 10; height: 10; radius: 2; color: "#7A7A7A" }
                                QGCLabel { text: qsTr("Skipped"); font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            Row {
                                spacing: _margin / 4
                                Rectangle { width: 10; height: 10; radius: 2; color: "#5A5A5A" }
                                QGCLabel { text: qsTr("Failed"); font.pointSize: ScreenTools.smallFontPointSize }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:   true
                        height:             1
                        color:              analyzePalette.border
                        opacity:            0.2
                    }

                    QGCListView {
                        id:                 imageListView
                        Layout.fillWidth:   true
                        Layout.fillHeight:  true
                        model:              GeoTagController.imageModel

                        delegate: Rectangle {
                            width:      imageListView.width
                            height:     ScreenTools.defaultFontPixelHeight * 2
                            color:      index % 2 === 0 ? "transparent" : analyzePalette.surfaceHover
                            radius:     analyzePalette.cornerRadius

                            RowLayout {
                                anchors.fill:       parent
                                anchors.leftMargin: _margin / 2
                                anchors.rightMargin: _margin / 2
                                spacing:            _margin

                                // Status indicator
                                Rectangle {
                                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.8
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.8
                                    radius:                 ScreenTools.defaultFontPixelWidth / 4
                                    color: {
                                        switch (model.status) {
                                        case 0: return analyzePalette.textDisabled   // Pending
                                        case 1: return analyzePalette.accent         // Processing
                                        case 2: return "#8CB3FF"                     // Tagged
                                        case 3: return "#7A7A7A"                     // Skipped
                                        case 4: return "#5A5A5A"                     // Failed
                                        default: return analyzePalette.textDisabled
                                        }
                                    }
                                    opacity: model.status === 0 ? 0.5 : 1.0

                                    // Processing animation
                                    SequentialAnimation on opacity {
                                        running: model.status === 1
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 500 }
                                        NumberAnimation { to: 1.0; duration: 500 }
                                    }
                                }

                                // File name
                                QGCLabel {
                                    Layout.fillWidth:   true
                                    text:               model.fileName
                                    elide:              Text.ElideMiddle
                                }

                                // Coordinate (if tagged)
                                QGCLabel {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20
                                    text: {
                                        if (model.coordinate && model.coordinate.isValid) {
                                            return model.coordinate.latitude.toFixed(6) + ", " + model.coordinate.longitude.toFixed(6)
                                        }
                                        return ""
                                    }
                                    font.pointSize:     ScreenTools.smallFontPointSize
                                    opacity:            0.7
                                    visible:            model.status === 2
                                }

                                // Status text or error
                                QGCLabel {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                                    text:               model.errorMessage ? model.errorMessage : model.statusString
                                    font.pointSize:     ScreenTools.smallFontPointSize
                                    color:              model.status === 1 ? analyzePalette.accent : analyzePalette.textSecondary
                                    elide:              Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
