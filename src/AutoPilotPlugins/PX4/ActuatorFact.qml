import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Loader {
	property var fact
	id:                     loader

	Component {
		id: factComboBox
		FactComboBox {
			fact:           loader.fact
			indexModel:     false
			sizeToContents: true
			extraTranslations: ({
				"Enabled": qsTr("启用"),
				"Disabled": qsTr("禁用"),
				"Upwards": qsTr("向上"),
				"Downwards": qsTr("向下"),
				"Forwards": qsTr("向前"),
				"Backwards": qsTr("向后"),
				"Leftwards": qsTr("向左"),
				"Rightwards": qsTr("向右")
			})
		}
	}
	Component {
		id: factCheckbox
		FactCheckBox {
			fact:           loader.fact
		}
	}

	Component {
		id: factTextField
		FactTextField {
			fact:           loader.fact
			width:          ScreenTools.defaultFontPixelWidth * 8
			showUnits:      false
		}
	}
	Component {
		id: factReadOnly
		QGCLabel {
			text:           loader.fact.valueString
		}
	}
	Component {
		id: notAvailable
		QGCLabel {
			text:           qsTr("(参数不可用)")
		}
	}
	sourceComponent: fact ?
		(fact.enumStrings.length > 0 ? factComboBox :
			(fact.readOnly ? factReadOnly : (fact.typeIsBool ? factCheckbox : factTextField))
		) : notAvailable
}
