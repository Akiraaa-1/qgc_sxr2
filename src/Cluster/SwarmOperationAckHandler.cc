#include "SwarmOperationAckHandler.h"

#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(SwarmOperationAckHandlerLog, "Cluster.SwarmOperationAckHandler")

SwarmOperationAckHandler::SwarmOperationAckHandler(QObject *parent)
    : QObject(parent)
{
}

QVariantMap SwarmOperationAckHandler::buildAckResult(int vehicleId, int operationType, int result, int oldValue, int newValue) const
{
    const bool success = (result == AckSuccess);
    QString message;

    if (success) {
        switch (operationType) {
        case OperationGroupChange:
            message = tr("Vehicle %1 accepted a cluster group sync request from %2 to %3. Vehicle-side confirmation is still pending.").arg(vehicleId).arg(oldValue).arg(newValue);
            break;
        case OperationLeaderChange:
            message = tr("Vehicle %1 accepted a cluster role sync request from %2 to %3. Vehicle-side confirmation is still pending.").arg(vehicleId).arg(oldValue == 1 ? tr("Leader") : tr("Follower")).arg(newValue == 1 ? tr("Leader") : tr("Follower"));
            break;
        default:
            message = tr("Vehicle %1 accepted cluster action %2 for dispatch. Vehicle-side completion is still pending.").arg(vehicleId).arg(operationText(operationType));
            break;
        }
    } else {
        message = tr("Vehicle %1 could not accept cluster action %2.").arg(vehicleId).arg(operationText(operationType));
    }

    QVariantMap ack;
    ack[QStringLiteral("success")] = success;
    ack[QStringLiteral("vehicleId")] = vehicleId;
    ack[QStringLiteral("operationType")] = operationType;
    ack[QStringLiteral("result")] = result;
    ack[QStringLiteral("oldValue")] = oldValue;
    ack[QStringLiteral("newValue")] = newValue;
    ack[QStringLiteral("message")] = message;
    return ack;
}

QVariantMap SwarmOperationAckHandler::publishAck(int vehicleId, int operationType, int result, int oldValue, int newValue)
{
    const QVariantMap ack = buildAckResult(vehicleId, operationType, result, oldValue, newValue);
    emit operationAckReceived(ack);
    return ack;
}

QString SwarmOperationAckHandler::operationText(int operationType) const
{
    switch (operationType) {
    case OperationGroupChange:
        return tr("Group Change");
    case OperationLeaderChange:
        return tr("Leader Change");
    case OperationArm:
        return tr("Arm");
    case OperationDisarm:
        return tr("Disarm");
    case OperationTakeoff:
        return tr("Takeoff");
    case OperationLand:
        return tr("Land");
    case OperationPause:
        return tr("Pause");
    case OperationResume:
        return tr("Resume");
    default:
        return tr("Unknown");
    }
}

QString SwarmOperationAckHandler::resultText(int result) const
{
    return (result == AckSuccess) ? tr("Success") : tr("Failed");
}
