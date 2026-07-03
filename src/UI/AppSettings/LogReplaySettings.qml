import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    spacing: _rowSpacing

    function saveSettings() {
        console.log(logField.text)
        subEditConfig.filename = logField.text
    }

    QGCLabel {
        text: qsTr("Log File")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: _colSpacing

        QGCTextField {
            id: logField
            Layout.fillWidth: true
            Layout.preferredWidth: _secondColumnWidth
            text: subEditConfig.filename
        }

        QGCButton {
            text: qsTr("Browse")
            onClicked: filePicker.openForLoad()
        }
    }

    QGCFileDialog {
        id: filePicker
        title: qsTr("Select Telemetery Log")
        nameFilters: [ qsTr("Telemetry Logs (*.%1)").arg(_logFileExtension), qsTr("All Files (*)") ]
        folder: QGroundControl.settingsManager.appSettings.telemetrySavePath

        property string _logFileExtension: QGroundControl.settingsManager.appSettings.telemetryFileExtension

        onAcceptedForLoad: (file) => {
            logField.text = file
            close()
        }
    }
}
