#include "SwarmUiCommandController.h"

#include "SwarmOperationAckHandler.h"
#include "SwarmUiSharedState.h"

SwarmUiCommandController::SwarmUiCommandController(QObject *parent)
    : QObject(parent)
    , _bridge(this)
{
}

void SwarmUiCommandController::_sendcom(int test1, int test2, int test3, int pause, int conti)
{
    const int groupId = test2;
    int operationType = SwarmOperationAckHandler::OperationUnknown;
    SwarmUiSharedState::instance().refreshFromAllVehicles();
    const int assignedVehicleCount = SwarmUiSharedState::instance().assignedCountForGroup(groupId);

    QVariantMap result;

    if (test1 == 1) {
        operationType = SwarmOperationAckHandler::OperationTakeoff;
        result = _bridge.takeoffGroup(groupId, assignedVehicleCount);
    } else if (test3 == 1) {
        operationType = SwarmOperationAckHandler::OperationLand;
        result = _bridge.landGroup(groupId, assignedVehicleCount);
    } else if (pause != 0) {
        operationType = SwarmOperationAckHandler::OperationPause;
        result = _bridge.pauseGroup(groupId, assignedVehicleCount);
    } else if (conti != 0) {
        operationType = SwarmOperationAckHandler::OperationResume;
        result = _bridge.resumeGroup(groupId, assignedVehicleCount);
    } else {
        result[QStringLiteral("success")] = false;
        result[QStringLiteral("message")] = tr("Unsupported swarm operation request for Group %1.").arg(groupId);
    }

    _emitOperationResult(operationType, result);
}

void SwarmUiCommandController::_emitOperationResult(int operationType, const QVariantMap &result)
{
    const bool success = result.value(QStringLiteral("success")).toBool();
    const QString message = result.value(QStringLiteral("message")).toString();
    const int sysId = result.value(QStringLiteral("vehicleId"), -1).toInt();

    emit swarmOperationAckReceived(sysId, operationType, success ? SwarmOperationAckHandler::AckSuccess : SwarmOperationAckHandler::AckFailed, 0, 0, message);
}
