#include "SwarmUiCommandController.h"

#include "MAVLinkProtocol.h"
#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"
#include "SwarmOperationAckHandler.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"

#include "mavlink_msg_swarm_start_flag.h"

QGC_LOGGING_CATEGORY(SwarmUiCommandControllerLog, "Cluster.SwarmUiCommandController")

SwarmUiCommandController::SwarmUiCommandController(QObject *parent)
    : QObject(parent)
{
}

void SwarmUiCommandController::_sendcom(int test1, int test2, int test3, int pause, int conti)
{
    Vehicle *const vehicle = MultiVehicleManager::instance() ? MultiVehicleManager::instance()->activeVehicle() : nullptr;
    const int groupId = test2;
    int operationType = SwarmOperationAckHandler::OperationUnknown;

    if (test1 == 1) {
        operationType = SwarmOperationAckHandler::OperationTakeoff;
    } else if (test3 == 1) {
        operationType = SwarmOperationAckHandler::OperationLand;
    } else if (pause != 0) {
        operationType = SwarmOperationAckHandler::OperationPause;
    } else if (conti != 0) {
        operationType = SwarmOperationAckHandler::OperationResume;
    }

    QVariantMap result;
    result[QStringLiteral("success")] = false;
    result[QStringLiteral("groupId")] = groupId;

    if (operationType == SwarmOperationAckHandler::OperationUnknown) {
        result[QStringLiteral("message")] = tr("Unsupported swarm operation request for Group %1.").arg(groupId);
    } else if (!vehicle) {
        result[QStringLiteral("message")] = tr("No active vehicle is available to send the swarm command for Group %1.").arg(groupId);
    } else if (_sendSwarmStartFlag(vehicle, test1, groupId, test3, pause, conti)) {
        result[QStringLiteral("success")] = true;
        result[QStringLiteral("vehicleId")] = vehicle->id();
        result[QStringLiteral("message")] = tr("Sent swarm %1 command to Group %2 through the custom swarm_start_flag MAVLink message. Vehicle-side completion is still pending.")
            .arg(SwarmOperationAckHandler().operationText(operationType))
            .arg(groupId);
    } else {
        result[QStringLiteral("vehicleId")] = vehicle->id();
        result[QStringLiteral("message")] = tr("Could not send swarm command to Group %1 because the active vehicle link is not available.").arg(groupId);
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

bool SwarmUiCommandController::_sendSwarmStartFlag(Vehicle *vehicle, int startAuto, int groupId, int stop, int pause, int resume) const
{
    if (!vehicle) {
        return false;
    }

    const WeakLinkInterfacePtr weakLink = vehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        qCWarning(SwarmUiCommandControllerLog) << "Cannot send swarm_start_flag: primary link expired" << "vehicle" << vehicle->id() << "group" << groupId;
        return false;
    }

    const SharedLinkInterfacePtr sharedLink = weakLink.lock();
    if (!sharedLink) {
        qCWarning(SwarmUiCommandControllerLog) << "Cannot send swarm_start_flag: primary link unavailable" << "vehicle" << vehicle->id() << "group" << groupId;
        return false;
    }

    mavlink_message_t message{};
    (void) mavlink_msg_swarm_start_flag_pack_chan(
        static_cast<uint8_t>(MAVLinkProtocol::instance()->getSystemId()),
        static_cast<uint8_t>(MAVLinkProtocol::getComponentId()),
        sharedLink->mavlinkChannel(),
        &message,
        static_cast<uint8_t>(startAuto),
        static_cast<uint8_t>(groupId),
        static_cast<uint8_t>(stop),
        static_cast<uint8_t>(pause),
        static_cast<uint8_t>(resume)
    );

    qCInfo(SwarmUiCommandControllerLog) << "Sending custom swarm_start_flag" << "vehicle" << vehicle->id() << "group" << groupId
                                        << "startAuto" << startAuto << "stop" << stop << "pause" << pause << "resume" << resume;
    return vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
}
