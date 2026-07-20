import QtQuick
import QtQuick3D
import "UAVModelAssets"

Item {
    id: root

    property real roll: 0
    property real pitch: 0
    property real yaw: 0
    property real modelScale: 55.0
    property real displayYawOffset: -45
    property color backgroundColor: "transparent"
    readonly property bool modelLoaded: true

    function _degToRad(deg) {
        return deg * Math.PI / 180.0
    }

    function _axisAngle(x, y, z, deg) {
        const half = _degToRad(deg) * 0.5
        const s = Math.sin(half)
        return Qt.quaternion(Math.cos(half), x * s, y * s, z * s)
    }

    function _mul(a, b) {
        return Qt.quaternion(
            a.scalar * b.scalar - a.x * b.x - a.y * b.y - a.z * b.z,
            a.scalar * b.x + a.x * b.scalar + a.y * b.z - a.z * b.y,
            a.scalar * b.y - a.x * b.z + a.y * b.scalar + a.z * b.x,
            a.scalar * b.z + a.x * b.y - a.y * b.x + a.z * b.scalar)
    }

    function attitudeQuaternion() {
        const qRoll = _axisAngle(1, 0, 0, roll)
        const qPitch = _axisAngle(0, 1, 0, pitch)
        const qYaw = _axisAngle(0, 0, 1, yaw + displayYawOffset)
        return _mul(qYaw, _mul(qPitch, qRoll))
    }

    View3D {
        anchors.fill: parent
        renderMode: View3D.Inline
        environment: SceneEnvironment {
            backgroundMode: root.backgroundColor.a > 0 ? SceneEnvironment.Color : SceneEnvironment.Transparent
            clearColor: root.backgroundColor
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        OrthographicCamera {
            id: camera
            position: Qt.vector3d(300, 250, 260)
            eulerRotation: Qt.vector3d(-42, 0, 48)
            clipNear: 1
            clipFar: 5000
            horizontalMagnification: 185
            verticalMagnification: 185
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-50, 25, -35)
            brightness: 3.2
            castsShadow: true
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(35, -55, 145)
            brightness: 1.1
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-10, 105, 20)
            brightness: 0.55
        }

        Node {
            id: attitudeNode
            rotation: root.attitudeQuaternion()

            Node {
                id: zUpToQuick3D
                // GLB keeps the aircraft body axes: nose +X, wings Y, height Z.
                // Qt Quick 3D is Y-up, so this display adapter maps model Z-up into the scene.
                eulerRotation: Qt.vector3d(-90, 0, 0)
                scale: Qt.vector3d(root.modelScale, root.modelScale, root.modelScale)

                UAVAttitudeModel {
                    id: aircraftModel
                    position: Qt.vector3d(0, 0, 0)
                }
            }
        }
    }
}
