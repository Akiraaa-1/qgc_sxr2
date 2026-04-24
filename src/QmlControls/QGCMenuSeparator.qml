import QtQuick
import QtQuick.Controls

import QGroundControl.Controls

MenuSeparator {
    id: control
    padding: 0
    topPadding: 4
    bottomPadding: 4

    QGCPopupStyle { id: popupStyle }

    contentItem: Rectangle {
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: 1
        color: popupStyle.borderColor
    }
}
