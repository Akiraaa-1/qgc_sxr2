import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: communicationLinkPage

    property var rootItem
    property color panelColor: "#2F2F2F"

    readonly property var _activeVehicle: rootItem ? rootItem._activeVehicle : null
    readonly property real _titleFontSize: ScreenTools.defaultFontPixelHeight * 0.64
    readonly property real _cardTitleFontSize: ScreenTools.defaultFontPixelHeight * 0.68
    readonly property real _metricFontSize: ScreenTools.defaultFontPixelHeight * 0.62
    readonly property real _metricSecondaryFontSize: ScreenTools.defaultFontPixelHeight * 0.58
    readonly property real _blockRadius: ScreenTools.defaultFontPixelHeight * 0.14
    readonly property color _cardColor: "#4C4D50"
    readonly property color _cardInnerColor: "#282A2D"
    readonly property color _accentColor: "#00C7A4"

    readonly property real _telemetryRssiDbm: rootItem ? rootItem._communicationTelemetryRssiDbm(_activeVehicle) : -65
    readonly property real _telemetryLossPercent: rootItem ? rootItem._communicationTelemetryLossPercent(_activeVehicle) : 0
    readonly property real _telemetryQualityPercent: rootItem ? rootItem._communicationTelemetryQualityPercent(_activeVehicle) : 100
    readonly property string _telemetryStatus: rootItem ? rootItem._communicationTelemetryStatusText(_telemetryQualityPercent) : qsTr("Good")
    readonly property color _telemetryStatusColor: rootItem ? rootItem._communicationStatusColor(_telemetryQualityPercent) : _accentColor
    readonly property int _telemetryBarCount: Math.max(1, Math.min(5, Math.round((_telemetryQualityPercent / 100) * 5)))

    readonly property real _videoBitrateMbps: rootItem ? rootItem._communicationVideoBitrateMbps(_activeVehicle) : 4.2
    readonly property real _videoLatencyMs: rootItem ? rootItem._communicationVideoLatencyMs(_activeVehicle) : 110
    readonly property real _videoFps: rootItem ? rootItem._communicationVideoFps(_activeVehicle) : 25
    readonly property real _videoQualityPercent: rootItem ? rootItem._communicationVideoQualityPercent(_activeVehicle, _videoBitrateMbps, _videoFps, _videoLatencyMs) : 98
    readonly property string _videoStatus: rootItem ? rootItem._communicationVideoStatusText(_videoQualityPercent) : qsTr("Excellent")
    readonly property color _videoStatusColor: rootItem ? rootItem._communicationStatusColor(_videoQualityPercent) : _accentColor

    readonly property int _meshOnlineNodes: rootItem ? rootItem._communicationMeshOnlineNodes() : 5
    readonly property int _meshTotalNodes: rootItem ? rootItem._communicationMeshTotalNodes() : 5
    readonly property int _meshQualityPercent: rootItem ? rootItem._communicationMeshLinkQualityPercent() : 98
    readonly property string _meshStatus: rootItem ? rootItem._communicationMeshStatusText(_meshQualityPercent, _meshOnlineNodes, _meshTotalNodes) : qsTr("Stable")
    readonly property color _meshStatusColor: rootItem ? rootItem._communicationStatusColor(_meshQualityPercent) : _accentColor
    readonly property int _topologyNodeCount: 5
    readonly property int _topologyActiveNodes: _meshOnlineNodes <= 0
                                                        ? 0
                                                        : Math.max(1, Math.min(_topologyNodeCount, Math.round((_meshOnlineNodes / Math.max(_meshTotalNodes, 1)) * _topologyNodeCount)))

    property real _wavePhase: 0

    onVisibleChanged: {
        if (visible) {
            if (videoWaveCanvas) {
                videoWaveCanvas.requestPaint()
            }
            if (meshTopologyCanvas) {
                meshTopologyCanvas.requestPaint()
            }
        }
    }
    on_VideoQualityPercentChanged: {
        if (videoWaveCanvas) {
            videoWaveCanvas.requestPaint()
        }
    }
    on_TopologyActiveNodesChanged: {
        if (meshTopologyCanvas) {
            meshTopologyCanvas.requestPaint()
        }
    }

    Timer {
        interval: 240
        repeat: true
        running: communicationLinkPage.visible
        onTriggered: {
            communicationLinkPage._wavePhase += 0.2
            if (videoWaveCanvas) {
                videoWaveCanvas.requestPaint()
            }
            if (meshTopologyCanvas) {
                meshTopologyCanvas.requestPaint()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.18
        anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.18
        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.12
        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.12
        spacing: ScreenTools.defaultFontPixelHeight * 0.11

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.16
            spacing: ScreenTools.defaultFontPixelWidth * 0.16

            QGCLabel {
                Layout.fillWidth: true
                color: "#FFFFFF"
                font.weight: Font.DemiBold
                font.pixelSize: communicationLinkPage._titleFontSize
                horizontalAlignment: Text.AlignLeft
                text: qsTr("COMMUNICATION/LINK")
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.96
                Layout.preferredHeight: Layout.preferredWidth
                color: communicationLinkPage.panelColor
                radius: 4

                QGCColoredImage {
                    anchors.centerIn: parent
                    width: parent.height * 0.52
                    height: width
                    color: "#ADB2B8"
                    fillMode: Image.PreserveAspectFit
                    source: "/InstrumentValueIcons/cog.svg"
                }

                QGCMouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (rootItem && typeof rootItem._openCommunicationLinkSettings === "function") {
                            rootItem._openCommunicationLinkSettings()
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.28

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: communicationLinkPage._cardColor
                radius: communicationLinkPage._blockRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#FFFFFF"
                        font.pixelSize: communicationLinkPage._cardTitleFontSize
                        font.weight: Font.DemiBold
                        text: qsTr("Telemetry Link")
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#E6E8EB"
                        font.pixelSize: communicationLinkPage._metricFontSize
                        text: qsTr("RSSI %1dBm").arg(Math.round(communicationLinkPage._telemetryRssiDbm))
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#E6E8EB"
                        font.pixelSize: communicationLinkPage._metricFontSize
                        text: qsTr("Packet Loss %1%").arg(Math.round(communicationLinkPage._telemetryLossPercent))
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: communicationLinkPage._telemetryStatusColor
                        font.pixelSize: communicationLinkPage._metricFontSize
                        font.weight: Font.DemiBold
                        text: qsTr("Status %1").arg(communicationLinkPage._telemetryStatus)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.centerIn: parent
                            width: ScreenTools.defaultFontPixelWidth * 4.6
                            height: parent.height * 0.84
                            color: communicationLinkPage._cardInnerColor
                            radius: communicationLinkPage._blockRadius

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                spacing: ScreenTools.defaultFontPixelWidth * 0.16

                                Repeater {
                                    model: 5

                                    delegate: Rectangle {
                                        required property int index

                                        readonly property real _ratio: (index + 1) / 5
                                        width: ScreenTools.defaultFontPixelWidth * 0.46
                                        height: (parent.height * (0.28 + (_ratio * 0.72)))
                                        radius: width * 0.4
                                        color: index < communicationLinkPage._telemetryBarCount ? communicationLinkPage._accentColor : "#3B4A47"
                                        opacity: index < communicationLinkPage._telemetryBarCount ? 1 : 0.42
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: communicationLinkPage._cardColor
                radius: communicationLinkPage._blockRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth * 0.18

                        QGCLabel {
                            Layout.fillWidth: true
                            color: "#FFFFFF"
                            font.pixelSize: communicationLinkPage._cardTitleFontSize
                            font.weight: Font.DemiBold
                            text: qsTr("Video Link")
                        }

                        Rectangle {
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.88
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4.2
                            color: Qt.rgba(0.09, 0.12, 0.11, 0.92)
                            radius: ScreenTools.defaultFontPixelHeight * 0.44

                            QGCLabel {
                                anchors.centerIn: parent
                                color: communicationLinkPage._videoStatusColor
                                font.pixelSize: communicationLinkPage._metricSecondaryFontSize
                                font.weight: Font.DemiBold
                                text: communicationLinkPage._videoStatus
                            }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#E6E8EB"
                        font.pixelSize: communicationLinkPage._metricFontSize
                        text: qsTr("Bitrate %1Mbps").arg(communicationLinkPage._videoBitrateMbps.toFixed(1))
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#E6E8EB"
                        font.pixelSize: communicationLinkPage._metricFontSize
                        text: qsTr("Latency %1ms").arg(Math.round(communicationLinkPage._videoLatencyMs))
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#E6E8EB"
                        font.pixelSize: communicationLinkPage._metricFontSize
                        text: qsTr("FPS %1").arg(Math.round(communicationLinkPage._videoFps))
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: communicationLinkPage._cardInnerColor
                        radius: communicationLinkPage._blockRadius

                        Canvas {
                            id: videoWaveCanvas
                            anchors.fill: parent

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                const left = ScreenTools.defaultFontPixelWidth * 0.26
                                const right = ScreenTools.defaultFontPixelWidth * 0.2
                                const top = ScreenTools.defaultFontPixelHeight * 0.2
                                const bottom = ScreenTools.defaultFontPixelHeight * 0.2
                                const plotWidth = Math.max(1, width - left - right)
                                const plotHeight = Math.max(1, height - top - bottom)
                                const centerY = top + (plotHeight * 0.5)
                                const qualityGain = Math.max(0.18, Math.min(1, communicationLinkPage._videoQualityPercent / 100))
                                const bitrateGain = Math.max(0.75, Math.min(1.45, communicationLinkPage._videoBitrateMbps / 4.2))

                                ctx.strokeStyle = "rgba(255,255,255,0.08)"
                                ctx.lineWidth = 1
                                for (let row = 0; row <= 4; row++) {
                                    const y = top + ((plotHeight * row) / 4)
                                    ctx.beginPath()
                                    ctx.moveTo(left, y)
                                    ctx.lineTo(left + plotWidth, y)
                                    ctx.stroke()
                                }

                                ctx.beginPath()
                                const pointCount = 48
                                for (let i = 0; i <= pointCount; i++) {
                                    const t = i / pointCount
                                    const x = left + (plotWidth * t)
                                    const primary = Math.sin((t * 6.4) + communicationLinkPage._wavePhase)
                                    const secondary = Math.cos((t * 12.8) + (communicationLinkPage._wavePhase * 0.68)) * 0.35
                                    const amplitude = plotHeight * (0.26 + (qualityGain * 0.18)) * bitrateGain
                                    const y = centerY - ((primary + secondary) * amplitude)
                                    if (i === 0) {
                                        ctx.moveTo(x, y)
                                    } else {
                                        ctx.lineTo(x, y)
                                    }
                                }
                                ctx.strokeStyle = communicationLinkPage._accentColor
                                ctx.lineWidth = 2
                                ctx.lineJoin = "round"
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: communicationLinkPage._cardColor
                radius: communicationLinkPage._blockRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#FFFFFF"
                        font.pixelSize: communicationLinkPage._cardTitleFontSize
                        font.weight: Font.DemiBold
                        text: qsTr("Mesh Network")
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#E6E8EB"
                        font.pixelSize: communicationLinkPage._metricFontSize
                        text: qsTr("Nodes %1/%2").arg(communicationLinkPage._meshOnlineNodes).arg(communicationLinkPage._meshTotalNodes)
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#E6E8EB"
                        font.pixelSize: communicationLinkPage._metricFontSize
                        text: qsTr("Link Quality %1%").arg(Math.round(communicationLinkPage._meshQualityPercent))
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: communicationLinkPage._meshStatusColor
                        font.pixelSize: communicationLinkPage._metricFontSize
                        font.weight: Font.DemiBold
                        text: qsTr("Status %1").arg(communicationLinkPage._meshStatus)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: communicationLinkPage._cardInnerColor
                        radius: communicationLinkPage._blockRadius

                        Canvas {
                            id: meshTopologyCanvas
                            anchors.fill: parent

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                const centerX = width * 0.5
                                const centerY = height * 0.52
                                const radius = Math.min(width, height) * 0.34
                                const nodes = []

                                for (let i = 0; i < communicationLinkPage._topologyNodeCount; i++) {
                                    const angle = (-Math.PI / 2) + ((Math.PI * 2 * i) / communicationLinkPage._topologyNodeCount)
                                    nodes.push({
                                        "x": centerX + (Math.cos(angle) * radius),
                                        "y": centerY + (Math.sin(angle) * radius)
                                    })
                                }

                                ctx.lineWidth = 1.4
                                ctx.strokeStyle = "rgba(173, 178, 184, 0.56)"
                                for (let i = 0; i < nodes.length; i++) {
                                    const next = (i + 1) % nodes.length
                                    ctx.beginPath()
                                    ctx.moveTo(nodes[i].x, nodes[i].y)
                                    ctx.lineTo(nodes[next].x, nodes[next].y)
                                    ctx.stroke()
                                }

                                for (let i = 0; i < nodes.length; i++) {
                                    ctx.beginPath()
                                    ctx.moveTo(centerX, centerY)
                                    ctx.lineTo(nodes[i].x, nodes[i].y)
                                    ctx.stroke()
                                }

                                for (let i = 0; i < nodes.length; i++) {
                                    const node = nodes[i]
                                    const online = i < communicationLinkPage._topologyActiveNodes
                                    ctx.beginPath()
                                    ctx.arc(node.x, node.y, Math.max(2, ScreenTools.defaultFontPixelHeight * 0.2), 0, Math.PI * 2)
                                    ctx.fillStyle = online ? communicationLinkPage._accentColor : "#5E646B"
                                    ctx.fill()
                                }

                                ctx.beginPath()
                                ctx.arc(centerX, centerY, Math.max(2, ScreenTools.defaultFontPixelHeight * 0.22), 0, Math.PI * 2)
                                ctx.fillStyle = communicationLinkPage._meshStatusColor
                                ctx.fill()
                            }
                        }
                    }
                }
            }
        }
    }
}
