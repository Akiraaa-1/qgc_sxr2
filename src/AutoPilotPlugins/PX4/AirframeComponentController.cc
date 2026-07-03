#include "AirframeComponentController.h"
#include "AirframeComponentAirframes.h"
#include "MultiVehicleManager.h"
#include "QGCApplication.h"
#include "LinkManager.h"
#include "Fact.h"
#include "Vehicle.h"
#include "ParameterManager.h"

#include <QtCore/QThread>
#include <QtCore/QVariant>
#include <QtGui/QCursor>

bool AirframeComponentController::_typesRegistered = false;

QString AirframeComponentController::_translateAirframeType(const QString& name) const
{
    static const QHash<QString, QString> translations = {
        { QStringLiteral("Airship"),            tr("飞艇") },
        { QStringLiteral("Autogyro"),           tr("旋翼机") },
        { QStringLiteral("Balloon"),            tr("气球") },
        { QStringLiteral("Dodecarotor cox"),    tr("十二旋翼共轴") },
        { QStringLiteral("Flying Wing"),        tr("飞翼") },
        { QStringLiteral("Free-Flyer"),         tr("自由飞行器") },
        { QStringLiteral("Helicopter"),         tr("直升机") },
        { QStringLiteral("Hexarotor +"),        tr("六旋翼 +") },
        { QStringLiteral("Hexarotor Coaxial"),  tr("六旋翼共轴") },
        { QStringLiteral("Hexarotor x"),        tr("六旋翼 X") },
        { QStringLiteral("Octorotor +"),        tr("八旋翼 +") },
        { QStringLiteral("Octorotor Coaxial"),  tr("八旋翼共轴") },
        { QStringLiteral("Octorotor x"),        tr("八旋翼 X") },
        { QStringLiteral("Quadrotor +"),        tr("四旋翼 +") },
        { QStringLiteral("Quadrotor H"),        tr("四旋翼 H") },
        { QStringLiteral("Quadrotor x"),        tr("四旋翼 X") },
        { QStringLiteral("Plane A-Tail"),       tr("A 尾布局固定翼") },
        { QStringLiteral("Standard Plane"),     tr("标准固定翼") },
        { QStringLiteral("Rover"),              tr("无人车") },
        { QStringLiteral("Simulation"),         tr("仿真") },
        { QStringLiteral("Tricopter Y+"),       tr("三旋翼 Y+") },
        { QStringLiteral("Underwater Robot"),   tr("水下机器人") },
        { QStringLiteral("Vectored 6 DOF UUV"), tr("矢量 6 自由度 UUV") }
    };

    return translations.value(name, name);
}

QString AirframeComponentController::_translateAirframeName(const QString& name) const
{
    static const QHash<QString, QString> translations = {
        { QStringLiteral("Generic Quadcopter"),                 tr("通用四旋翼") },
        { QStringLiteral("Generic Flying Wing"),                tr("通用飞翼") },
        { QStringLiteral("Generic Dodecarotor cox geometry"),   tr("通用十二旋翼共轴构型") },
        { QStringLiteral("Generic Helicopter (Tail ESC)"),      tr("通用直升机（尾部电调）") },
        { QStringLiteral("Generic Hexarotor + geometry"),       tr("通用六旋翼 + 构型") },
        { QStringLiteral("Generic Hexarotor coaxial geometry"), tr("通用六旋翼共轴构型") },
        { QStringLiteral("Generic Hexarotor x geometry"),       tr("通用六旋翼 X 构型") },
        { QStringLiteral("Generic Octocopter + geometry"),      tr("通用八旋翼 + 构型") },
        { QStringLiteral("Generic Octocopter X geometry"),      tr("通用八旋翼 X 构型") },
        { QStringLiteral("Generic Quad + geometry"),            tr("通用四旋翼 + 构型") },
        { QStringLiteral("Generic 10\" Octo coaxial geometry"), tr("通用 10 寸八旋翼共轴构型") },
        { QStringLiteral("Generic Rover Differential"),         tr("通用差速无人车") },
        { QStringLiteral("Generic Rover Ackermann"),            tr("通用阿克曼无人车") },
        { QStringLiteral("Generic Rover Mecanum"),              tr("通用麦克纳姆无人车") },
        { QStringLiteral("Generic Standard Plane"),             tr("通用标准固定翼") },
        { QStringLiteral("Cloudship"),                          tr("云舰") }
    };

    return translations.value(name, name);
}

AirframeComponentController::AirframeComponentController(void) :
    _currentVehicleIndex(0),
    _autostartId(0),
    _showCustomConfigPanel(false)
{
    if (!_typesRegistered) {
        _typesRegistered = true;
    }

    QStringList usedParams;
    usedParams << "SYS_AUTOSTART" << "SYS_AUTOCONFIG";
    if (!_allParametersExists(ParameterManager::defaultComponentId, usedParams)) {
        return;
    }

    // Load up member variables

    bool autostartFound = false;
    _autostartId = getParameterFact(ParameterManager::defaultComponentId, "SYS_AUTOSTART")->rawValue().toInt();
    _currentVehicleName = QString::number(_autostartId); // Temp val. Replaced with actual vehicle name if found

    for (int tindex = 0; tindex < AirframeComponentAirframes::get().count(); tindex++) {

        const AirframeComponentAirframes::AirframeType_t* pType = AirframeComponentAirframes::get().values().at(tindex);

        const QString translatedTypeName = _translateAirframeType(pType->name);
        AirframeType* airframeType = new AirframeType(translatedTypeName, pType->imageResource, this);
        Q_CHECK_PTR(airframeType);

        for (int index = 0; index < pType->rgAirframeInfo.count(); index++) {
            const AirframeComponentAirframes::AirframeInfo_t* pInfo = pType->rgAirframeInfo.at(index);
            Q_CHECK_PTR(pInfo);

            if (_autostartId == pInfo->autostartId) {
                if (autostartFound) {
                    qWarning() << "AirframeComponentController::AirframeComponentController duplicate ids found:" << _autostartId;
                }
                autostartFound = true;
                _currentAirframeType = translatedTypeName;
                _currentVehicleName = _translateAirframeName(pInfo->name);
                _currentVehicleIndex = index;
            }
            airframeType->addAirframe(_translateAirframeName(pInfo->name), pInfo->autostartId);
        }

        _airframeTypes.append(QVariant::fromValue(airframeType));
    }

    if (_autostartId != 0 && !autostartFound) {
        _showCustomConfigPanel = true;
        emit showCustomConfigPanelChanged(true);
    }
}

AirframeComponentController::~AirframeComponentController()
{

}

void AirframeComponentController::changeAutostart(void)
{
    if (MultiVehicleManager::instance()->vehicles()->count() > 1) {
        qgcApp()->showAppMessage(tr("You cannot change airframe configuration while connected to multiple vehicles."));
		return;
	}

    QGuiApplication::setOverrideCursor(QCursor(Qt::WaitCursor));

    Fact* sysAutoStartFact  = getParameterFact(-1, "SYS_AUTOSTART");
    Fact* sysAutoConfigFact = getParameterFact(-1, "SYS_AUTOCONFIG");

    // We need to wait for the vehicleUpdated signals to come back before we reboot
    _waitParamWriteSignalCount = 0;
    connect(sysAutoStartFact, &Fact::vehicleUpdated, this, &AirframeComponentController::_waitParamWriteSignal);
    connect(sysAutoConfigFact, &Fact::vehicleUpdated, this, &AirframeComponentController::_waitParamWriteSignal);

    // We use forceSetValue to ensure params are sent even if the previous value is that same as the new value
    sysAutoStartFact->forceSetRawValue(_autostartId);
    sysAutoConfigFact->forceSetRawValue(1);
}

void AirframeComponentController::_waitParamWriteSignal(QVariant value)
{
    Q_UNUSED(value);

    _waitParamWriteSignalCount++;
    if (_waitParamWriteSignalCount == 2) {
        // Now that both params have made it to the vehicle we can reboot it. All these signals are flying
        // around on the main thread, so we need to allow the stack to unwind back to the event loop before
        // we reboot.
        QTimer::singleShot(800, this, &AirframeComponentController::_rebootAfterStackUnwind);
    }
}

void AirframeComponentController::_rebootAfterStackUnwind(void)
{
    _vehicle->sendMavCommand(_vehicle->defaultComponentId(), MAV_CMD_PREFLIGHT_REBOOT_SHUTDOWN, true /* showError */, 1.0f);
    QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents);
    for (unsigned i = 0; i < 2000; i++) {
        QThread::usleep(500);
        QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents);
    }
    QGuiApplication::restoreOverrideCursor();
    LinkManager::instance()->disconnectAll();
}

AirframeType::AirframeType(const QString& name, const QString& imageResource, QObject* parent) :
    QObject(parent),
    _name(name),
    _imageResource(imageResource)
{

}

AirframeType::~AirframeType()
{

}

void AirframeType::addAirframe(const QString& name, int autostartId)
{
    Airframe* airframe = new Airframe(name, autostartId);
    Q_CHECK_PTR(airframe);

    _airframes.append(QVariant::fromValue(airframe));
}

Airframe::Airframe(const QString& name, int autostartId, QObject* parent) :
    QObject(parent),
    _name(name),
    _autostartId(autostartId)
{

}

Airframe::~Airframe()
{

}
