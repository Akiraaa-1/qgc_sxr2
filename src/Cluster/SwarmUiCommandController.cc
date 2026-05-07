#include "SwarmUiCommandController.h"

#include "MAVLinkProtocol.h"
#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"
#include "SwarmOperationAckHandler.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"

#include "mavlink_msg_swarm_operation_ack.h"
#include "mavlink_msg_swarm_start_flag.h"
#include "mavlink_msg_uav_info.h"

QGC_LOGGING_CATEGORY(SwarmUiCommandControllerLog, "Cluster.SwarmUiCommandController")

SwarmUiCommandController::SwarmUiCommandController(QObject *parent)
    : QObject(parent)
{
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    if (manager) {
        (void) connect(manager, &MultiVehicleManager::activeVehicleChanged, this, &SwarmUiCommandController::_handleActiveVehicleChanged);
        _handleActiveVehicleChanged(manager->activeVehicle());
    }

    MAVLinkProtocol *const mavlinkProtocol = MAVLinkProtocol::instance();
    if (mavlinkProtocol) {
        (void) connect(mavlinkProtocol, &MAVLinkProtocol::messageReceived, this, &SwarmUiCommandController::_receiveMessage);
    }
}

void SwarmUiCommandController::_sendcom(int test1, int test2, int test3, int pause, int conti)
{
    Vehicle *const vehicle = _vehicle ? _vehicle : (MultiVehicleManager::instance() ? MultiVehicleManager::instance()->activeVehicle() : nullptr);
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
    } else if (!_sendSwarmStartFlag(vehicle, test1, groupId, test3, pause, conti)) {
        result[QStringLiteral("vehicleId")] = vehicle->id();
        result[QStringLiteral("message")] = tr("Could not send swarm command to Group %1 because the active vehicle link is not available.").arg(groupId);
    } else {
        return;
    }

    _emitOperationResult(operationType, result);
}

void SwarmUiCommandController::_handleActiveVehicleChanged(Vehicle *vehicle)
{
    _vehicle = vehicle;
    if (_vehicle) {
        qCDebug(SwarmUiCommandControllerLog) << "Active vehicle changed" << _vehicle->id() << _vehicle->parameterManager();
    }
}

void SwarmUiCommandController::_receiveMessage(LinkInterface *link, const mavlink_message_t &message)
{
    Q_UNUSED(link);

    if (message.msgid == MAVLINK_MSG_ID_UAV_INFO) {
        Vehicle *const vehicle = _vehicle ? _vehicle : (MultiVehicleManager::instance() ? MultiVehicleManager::instance()->activeVehicle() : nullptr);
        (void) _echoUavInfo(vehicle, message);
        return;
    }

    if (message.msgid != MAVLINK_MSG_ID_SWARM_OPERATION_ACK) {
        return;
    }

    mavlink_swarm_operation_ack_t ack{};
    mavlink_msg_swarm_operation_ack_decode(&message, &ack);

    const QString messageText = _formatOperationAckMessage(ack.target_system,
                                                           ack.operation_type,
                                                           ack.result,
                                                           ack.old_value,
                                                           ack.new_value);

    qCInfo(SwarmUiCommandControllerLog) << "Received SWARM_OPERATION_ACK" << messageText;
    emit swarmOperationAckReceived(ack.target_system,
                                   ack.operation_type,
                                   ack.result,
                                   ack.old_value,
                                   ack.new_value,
                                   messageText);
}

QString SwarmUiCommandController::_formatOperationAckMessage(int sysId, int operationType, int result, int oldValue, int newValue) const
{
    if (result == SwarmOperationAckHandler::AckSuccess) {
        if (operationType == SwarmOperationAckHandler::OperationGroupChange) {
            return tr("Vehicle %1: group changed from %2 to %3 successfully.").arg(sysId).arg(oldValue).arg(newValue);
        }

        if (operationType == SwarmOperationAckHandler::OperationLeaderChange) {
            const QString oldRole = (oldValue == 1) ? tr("leader") : tr("follower");
            const QString newRole = (newValue == 1) ? tr("leader") : tr("follower");
            return tr("Vehicle %1: role changed from %2 to %3 successfully.").arg(sysId).arg(oldRole, newRole);
        }

        return tr("Vehicle %1: swarm operation %2 succeeded.").arg(sysId).arg(SwarmOperationAckHandler().operationText(operationType));
    }

    if (operationType == SwarmOperationAckHandler::OperationGroupChange) {
        return tr("Vehicle %1: group change failed.").arg(sysId);
    }

    if (operationType == SwarmOperationAckHandler::OperationLeaderChange) {
        return tr("Vehicle %1: role change failed.").arg(sysId);
    }

    return tr("Vehicle %1: swarm operation %2 failed.").arg(sysId).arg(SwarmOperationAckHandler().operationText(operationType));
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

bool SwarmUiCommandController::_echoUavInfo(Vehicle *vehicle, const mavlink_message_t &incomingMessage) const
{
    if (!vehicle) {
        return false;
    }

    const WeakLinkInterfacePtr weakLink = vehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        qCWarning(SwarmUiCommandControllerLog) << "Cannot echo UAV_INFO: primary link expired" << "vehicle" << vehicle->id();
        return false;
    }

    const SharedLinkInterfacePtr sharedLink = weakLink.lock();
    if (!sharedLink) {
        qCWarning(SwarmUiCommandControllerLog) << "Cannot echo UAV_INFO: primary link unavailable" << "vehicle" << vehicle->id();
        return false;
    }

    mavlink_uav_info_t uavInfo{};
    mavlink_msg_uav_info_decode(&incomingMessage, &uavInfo);

    mavlink_message_t message{};
    (void) mavlink_msg_uav_info_pack_chan(static_cast<uint8_t>(MAVLinkProtocol::instance()->getSystemId()),
                                          static_cast<uint8_t>(MAVLinkProtocol::getComponentId()),
                                          sharedLink->mavlinkChannel(),
                                          &message,
                                          uavInfo.mavid,
                                          uavInfo.group_id,
                                          uavInfo.is_leader,
                                          uavInfo.lat,
                                          uavInfo.lon,
                                          uavInfo.yaw,
                                          uavInfo.yaw_speed,
                                          uavInfo.rel_alt,
                                          uavInfo.vx,
                                          uavInfo.vy,
                                          uavInfo.vz,
                                          uavInfo.land);

    qCInfo(SwarmUiCommandControllerLog) << "Echoing UAV_INFO" << "vehicle" << vehicle->id() << "mavid" << uavInfo.mavid
                                        << "group" << uavInfo.group_id << "leader" << uavInfo.is_leader;
    return vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
}
