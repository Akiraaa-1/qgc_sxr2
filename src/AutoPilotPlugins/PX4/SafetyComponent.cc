#include "SafetyComponent.h"

SafetyComponent::SafetyComponent(Vehicle* vehicle, AutoPilotPlugin* autopilot, QObject* parent) :
    VehicleComponent(vehicle, autopilot, AutoPilotPlugin::KnownSafetyVehicleComponent, parent),
    _name(tr("Safety"))
{
}

QString SafetyComponent::name(void) const
{
    return _name;
}

QString SafetyComponent::description(void) const
{
    return tr("配置故障保护动作、地理围栏、返航以及降落模式设置。");
}

QString SafetyComponent::iconResource(void) const
{
    return "/qmlimages/SafetyComponentIcon.png";
}

bool SafetyComponent::requiresSetup(void) const
{
    return false;
}

bool SafetyComponent::setupComplete(void) const
{
    // FIXME: What aboout invalid settings?
    return true;
}

QStringList SafetyComponent::setupCompleteChangedTriggerList(void) const
{
    return QStringList();
}

QUrl SafetyComponent::setupSource(void) const
{
    return QUrl::fromUserInput("qrc:/qml/QGroundControl/AutoPilotPlugins/PX4/SafetyComponent.qml");
}

QUrl SafetyComponent::summaryQmlSource(void) const
{
    return QUrl::fromUserInput("qrc:/qml/QGroundControl/AutoPilotPlugins/PX4/SafetyComponentSummary.qml");
}

QString SafetyComponent::vehicleConfigJson(void) const
{
    return QStringLiteral(":/qml/QGroundControl/AutoPilotPlugins/PX4/VehicleConfig/Safety.VehicleConfig.json");
}
