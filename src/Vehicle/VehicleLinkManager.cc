#include "VehicleLinkManager.h"
#include "MAVLinkLib.h"
#include "Vehicle.h"
#include "LinkManager.h"
#include "SettingsManager.h"
#include "MavlinkSettings.h"
#include "QGCApplication.h"
#include "AudioOutput.h"
#ifndef QGC_NO_SERIAL_LINK
    #include "SerialLink.h"
#endif
#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(VehicleLinkManagerLog, "Vehicle.VehicleLinkManager")

VehicleLinkManager::VehicleLinkManager(Vehicle *vehicle)
    : QObject(vehicle)
    , _vehicle(vehicle)
    , _commLostCheckTimer(new QTimer(this))
{
    // qCDebug(VehicleLinkManagerLog) << Q_FUNC_INFO << this;

    (void) connect(this, &VehicleLinkManager::linkNamesChanged, this, &VehicleLinkManager::linkStatusesChanged);
    (void) connect(_commLostCheckTimer, &QTimer::timeout, this, &VehicleLinkManager::_commLostCheck);

    _commLostCheckTimer->setSingleShot(false);
    _commLostCheckTimer->setInterval(_commLostCheckTimeoutMSecs);
    _lastMavlinkDispatchTimer.start();
}

VehicleLinkManager::~VehicleLinkManager()
{
    // qCDebug(VehicleLinkManagerLog) << Q_FUNC_INFO << this;
}

void VehicleLinkManager::mavlinkMessageReceived(LinkInterface *link, const mavlink_message_t &message)
{
    // Radio status messages come from Sik Radios directly. It doesn't indicate there is any life on the other end.
    if (message.msgid == MAVLINK_MSG_ID_RADIO_STATUS) {
        return;
    }

    const qint64 dispatchGap = _lastMavlinkDispatchTimer.restart();
    if (dispatchGap >= 500) {
        qCWarning(VehicleLinkManagerLog) << "MAVLink dispatch gap" << dispatchGap << "ms for message" << message.msgid
                                         << "vehicle" << _vehicle->id();
    }

    const int linkIndex = _containsLinkIndex(link);
    if (linkIndex == -1) {
        _addLink(link);
        return;
    }

    LinkInfo_t &linkInfo = _rgLinkInfo[linkIndex];
    linkInfo.heartbeatElapsedTimer.restart();
    if (_rgLinkInfo[linkIndex].commLost) {
        _commRegainedOnLink(link);
    }
}

void VehicleLinkManager::_commRegainedOnLink(LinkInterface *link)
{

    const int linkIndex = _containsLinkIndex(link);
    if (linkIndex == -1) {
        return;
    }

    _rgLinkInfo[linkIndex].commLost = false;

    // Notify the user of communication regained
    QString commRegainedMessage;
    const bool isPrimaryLink = link == _primaryLink.lock().get();
    if (_rgLinkInfo.count() > 1) {
        commRegainedMessage = tr("%1Communication regained on %2 link").arg(_vehicle->_vehicleIdSpeech()).arg(isPrimaryLink ? tr("primary") : tr("secondary"));
    } else {
        commRegainedMessage = tr("%1Communication regained").arg(_vehicle->_vehicleIdSpeech());
    }

    // Try to switch to another link
    QString primarySwitchMessage;
    if (_updatePrimaryLink()) {
        primarySwitchMessage = tr("%1正在切换通信到新的主链路").arg(_vehicle->_vehicleIdSpeech());
    }

    if (!commRegainedMessage.isEmpty()) {
        AudioOutput::instance()->say(commRegainedMessage.toLower());
    }

    if (!primarySwitchMessage.isEmpty()) {
        AudioOutput::instance()->say(primarySwitchMessage.toLower());
        qCInfo(VehicleLinkManagerLog) << primarySwitchMessage;
    }

    emit linkStatusesChanged();

    // Check recovery from total communication loss
    if (!_communicationLost) {
        return;
    }

    bool noCommunicationLoss = true;
    for (const LinkInfo_t &linkInfo: _rgLinkInfo) {
        if (linkInfo.commLost) {
            noCommunicationLoss = false;
            break;
        }
    }

    if (noCommunicationLoss) {
        _communicationLost = false;
        _communicationLostElapsedTimer.invalidate();
        emit communicationLostChanged(_communicationLost);
    }
}

void VehicleLinkManager::_commLostCheck()
{
    if (!_communicationLostEnabled) {
        return;
    }

    // Use much shorter heartbeat timeout in unit tests since MockLink sends heartbeats instantly
    int heartbeatTimeout = _heartbeatMaxElpasedMSecs;
    if (qgcApp()->runningUnitTests()) {
        heartbeatTimeout = kTestHeartbeatTimeoutMs;
    } else {
        const Fact *const heartbeatTimeoutFact = SettingsManager::instance()->mavlinkSettings()->vehicleHeartbeatTimeout();
        const int heartbeatTimeoutSeconds = heartbeatTimeoutFact ? heartbeatTimeoutFact->rawValue().toInt() : 0;
        if (heartbeatTimeoutSeconds > 0) {
            heartbeatTimeout = heartbeatTimeoutSeconds * 1000;
        }
    }

    bool linkStatusChange = false;
    for (LinkInfo_t &linkInfo: _rgLinkInfo) {
        if (!linkInfo.commLost && !linkInfo.link->linkConfiguration()->isHighLatency() && (linkInfo.heartbeatElapsedTimer.elapsed() > heartbeatTimeout)) {
            linkInfo.commLost = true;
            linkStatusChange = true;

            // Notify the user of individual link communication loss
            const bool isPrimaryLink = linkInfo.link.get() == _primaryLink.lock().get();
            if (_rgLinkInfo.count() > 1) {
                const QString msg = tr("%1Communication lost on %2 link.").arg(_vehicle->_vehicleIdSpeech()).arg(isPrimaryLink ? tr("primary") : tr("secondary"));
                AudioOutput::instance()->say(msg.toLower());
            }
        }
    }

    if (linkStatusChange) {
        emit linkStatusesChanged();
    }

    if (_updatePrimaryLink()) {
        QString msg = tr("%1正在切换通信到备用链路。").arg(_vehicle->_vehicleIdSpeech());
        AudioOutput::instance()->say(msg.toLower());
        qCInfo(VehicleLinkManagerLog) << msg;
    }

    if (_communicationLost) {
        if (_shouldRemoveLostVehicle()) {
            closeVehicle();
        }
        return;
    }

    bool totalCommunicationLoss = true;
    for (const LinkInfo_t &linkInfo: _rgLinkInfo) {
        if (!linkInfo.commLost) {
            totalCommunicationLoss = false;
            break;
        }
    }

    if (totalCommunicationLoss) {
        if (_autoDisconnect) {
            // There is only one link to the vehicle and we want to auto disconnect from it
            closeVehicle();
            return;
        }

        AudioOutput::instance()->say(tr("%1Communication lost").arg(_vehicle->_vehicleIdSpeech()).toLower());
        QStringList lostLinkNames;
        for (const LinkInfo_t &linkInfo: _rgLinkInfo) {
            const SharedLinkConfigurationPtr config = linkInfo.link ? linkInfo.link->linkConfiguration() : SharedLinkConfigurationPtr();
            lostLinkNames.append(config ? config->name() : tr("unknown link"));
        }
        const QString lostLinksText = lostLinkNames.isEmpty() ? tr("active link") : lostLinkNames.join(QStringLiteral(", "));
        qCWarning(VehicleLinkManagerLog) << tr("%1Communication lost: no MAVLink heartbeat received on %2. Check the UDP/TCP endpoint, vehicle power, and MAVLink output.")
                                             .arg(_vehicle->_vehicleIdSpeech(), lostLinksText);

        emit mylink_disconnected(_vehicle->id());

        _communicationLost = true;
        _communicationLostElapsedTimer.start();
        emit communicationLostChanged(_communicationLost);
    }
}

bool VehicleLinkManager::_shouldRemoveLostVehicle() const
{
    // An armed or airborne vehicle must remain visible after a lost network link so
    // the operator retains its last known state and can recover the connection.
    if (_vehicle->armed() || _vehicle->flying() || !_communicationLostElapsedTimer.isValid()) {
        return false;
    }

    // UDP has no peer disconnect event, and a TCP peer can occasionally disappear
    // without delivering one. Do not apply this expiry to serial, Bluetooth, or
    // high-latency links, whose reconnect and loss semantics are different.
    if (_rgLinkInfo.isEmpty()) {
        return false;
    }

    for (const LinkInfo_t &linkInfo : _rgLinkInfo) {
        const SharedLinkConfigurationPtr config = linkInfo.link ? linkInfo.link->linkConfiguration() : SharedLinkConfigurationPtr();
        if (!config) {
            return false;
        }

        const LinkConfiguration::LinkType type = config->type();
        const bool isNetworkLink = type == LinkConfiguration::TypeUdp || type == LinkConfiguration::TypeTcp;
#ifdef QGC_UNITTEST_BUILD
        const bool isTestLink = qgcApp()->runningUnitTests() && type == LinkConfiguration::TypeMock;
        if (!isNetworkLink && !isTestLink) {
#else
        if (!isNetworkLink) {
#endif
            return false;
        }
    }

    const int removalTimeout = qgcApp()->runningUnitTests()
        ? kTestLostUnarmedVehicleRemovalMSecs
        : _lostUnarmedVehicleRemovalMSecs;
    return _communicationLostElapsedTimer.elapsed() >= removalTimeout;
}

int VehicleLinkManager::_containsLinkIndex(const LinkInterface *link)
{
    for (int i = 0; i < _rgLinkInfo.count(); i++) {
        if (_rgLinkInfo[i].link.get() == link) {
            return i;
        }
    }

    return -1;
}

void VehicleLinkManager::_addLink(LinkInterface *link)
{
    if (_containsLinkIndex(link) != -1) {
        qCWarning(VehicleLinkManagerLog) << "_addLink call with link which is already in the list";
        return;
    }

    SharedLinkInterfacePtr sharedLink = LinkManager::instance()->sharedLinkInterfacePointerForLink(link);
    if (!sharedLink) {
        qCDebug(VehicleLinkManagerLog) << "_addLink stale link" << (void*)link;
        return;
    }

    qCDebug(VehicleLinkManagerLog) << "_addLink:" << link->linkConfiguration()->name() << QString("%1").arg((qulonglong)link, 0, 16);

    link->addVehicleReference();

    LinkInfo_t linkInfo;
    linkInfo.link = sharedLink;
    if (!link->linkConfiguration()->isHighLatency()) {
        linkInfo.heartbeatElapsedTimer.start();
    }
    _rgLinkInfo.append(linkInfo);

    _updatePrimaryLink();

    (void) connect(link, &LinkInterface::disconnected, this, &VehicleLinkManager::_linkDisconnected);

    emit linkNamesChanged();

    if (_rgLinkInfo.count() == 1) {
        _commLostCheckTimer->start();
    }
}

void VehicleLinkManager::_removeLink(LinkInterface *link)
{
    const int linkIndex = _containsLinkIndex(link);
    if (linkIndex == -1) {
        qCWarning(VehicleLinkManagerLog) << "_removeLink call with link which is already in the list";
        return;
    }

    qCDebug(VehicleLinkManagerLog) << "_removeLink:" << QString("%1").arg((qulonglong)link, 0, 16);

    if (link == _primaryLink.lock().get()) {
        _primaryLink.reset();
        emit primaryLinkChanged();
    }

    disconnect(link, &LinkInterface::disconnected, this, &VehicleLinkManager::_linkDisconnected);
    link->removeVehicleReference();
    emit linkNamesChanged();
    _rgLinkInfo.removeAt(linkIndex); // Remove the link last since it may cause the link itself to be deleted

    if (_rgLinkInfo.isEmpty()) {
        _commLostCheckTimer->stop();
    }
}

void VehicleLinkManager::_linkDisconnected()
{
    qCDebug(VehicleLog) << Q_FUNC_INFO << "linkCount" << _rgLinkInfo.count();

    LinkInterface *link = qobject_cast<LinkInterface*>(sender());
    if (!link) {
        return;
    }

    _removeLink(link);
    _updatePrimaryLink();
    if (_rgLinkInfo.isEmpty() && !_allLinksRemovedSignalledByCloseVehicle) {
        qCDebug(VehicleLog) << "signalling allLinksRemoved";
        // Stop command processing timers immediately to prevent callbacks during the
        // asynchronous vehicle destruction sequence
        _vehicle->_stopCommandProcessing();
        emit allLinksRemoved(_vehicle);
    }
}

SharedLinkInterfacePtr VehicleLinkManager::_bestActivePrimaryLink()
{
#ifndef QGC_NO_SERIAL_LINK
    // Best choice is a USB connection
    for (const LinkInfo_t &linkInfo: _rgLinkInfo) {
        if (linkInfo.commLost) {
            continue;
        }

        SharedLinkInterfacePtr candidateLink = linkInfo.link;
        auto linkInterface = candidateLink.get();
        if (linkInterface && LinkManager::isLinkUSBDirect(linkInterface)) {
            return candidateLink;
        }
    }
#endif

    // Next best is normal latency link
    for (const LinkInfo_t &linkInfo: _rgLinkInfo) {
        if (linkInfo.commLost) {
            continue;
        }

        SharedLinkInterfacePtr candidateLink = linkInfo.link;
        const SharedLinkConfigurationPtr config = candidateLink->linkConfiguration();
        if (config && !config->isHighLatency()) {
            return candidateLink;
        }
    }

    // Last possible choice is a high latency link
    SharedLinkInterfacePtr primaryLink = _primaryLink.lock();
    if (primaryLink && primaryLink->linkConfiguration()->isHighLatency()) {
        // Best choice continues to be the current high latency link
        return primaryLink;
    }

    // Pick any high latency link if one exists
    for (const LinkInfo_t &linkInfo: _rgLinkInfo) {
        if (linkInfo.commLost) {
            continue;
        }

        SharedLinkInterfacePtr candidateLink = linkInfo.link;
        const SharedLinkConfigurationPtr config = candidateLink->linkConfiguration();
        if (config && config->isHighLatency()) {
            return candidateLink;
        }
    }

    return {};
}

bool VehicleLinkManager::_updatePrimaryLink()
{
    SharedLinkInterfacePtr primaryLink = _primaryLink.lock();
    const int linkIndex = _containsLinkIndex(primaryLink.get());

    if ((linkIndex != -1) && !_rgLinkInfo[linkIndex].commLost && !primaryLink->linkConfiguration()->isHighLatency()) {
        // Current priority link is still valid
        return false;
    }

    SharedLinkInterfacePtr bestActivePrimaryLink = _bestActivePrimaryLink();
    if ((linkIndex != -1) && !bestActivePrimaryLink) {
        // Nothing better available, leave things set to current primary link
        return false;
    }

    if (bestActivePrimaryLink == primaryLink) {
        return false;
    }

    if (primaryLink && primaryLink->linkConfiguration()->isHighLatency()) {
        _vehicle->sendMavCommand(
            MAV_COMP_ID_AUTOPILOT1,
            MAV_CMD_CONTROL_HIGH_LATENCY,
            true,
            0 // Stop transmission on this link
        );
    }

    _primaryLink = bestActivePrimaryLink;
    emit primaryLinkChanged();

    if (bestActivePrimaryLink && bestActivePrimaryLink->linkConfiguration()->isHighLatency()) {
        _vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1,
                       MAV_CMD_CONTROL_HIGH_LATENCY,
                       true,
                       1); // Start transmission on this link
    }

    return true;
}

void VehicleLinkManager::closeVehicle()
{
    // Vehicle is no longer communicating with us. Remove all link references

    const QList<LinkInfo_t> rgLinkInfoCopy = _rgLinkInfo;
    for (const LinkInfo_t &linkInfo: rgLinkInfoCopy) {
        _removeLink(linkInfo.link.get());
    }

    _rgLinkInfo.clear();

    _allLinksRemovedSignalledByCloseVehicle = true; // Prevent double signal of allLinksRemoved
    // Stop command processing timers immediately to prevent callbacks during the
    // asynchronous vehicle destruction sequence
    _vehicle->_stopCommandProcessing();
    emit allLinksRemoved(_vehicle);
}

void VehicleLinkManager::setCommunicationLostEnabled(bool communicationLostEnabled)
{
    if (_communicationLostEnabled != communicationLostEnabled) {
        _communicationLostEnabled = communicationLostEnabled;
        emit communicationLostEnabledChanged(communicationLostEnabled);
    }
}

bool VehicleLinkManager::containsLink(LinkInterface* link)
{
    return (_containsLinkIndex(link) != -1);
}

QString VehicleLinkManager::primaryLinkName() const
{
    if (!_primaryLink.expired()) {
        return _primaryLink.lock()->linkConfiguration()->name();
    }

    return QString();
}

int VehicleLinkManager::primaryMavlinkVersion() const
{
    const SharedLinkInterfacePtr primaryLink = _primaryLink.lock();
    const SharedLinkConfigurationPtr config = primaryLink ? primaryLink->linkConfiguration() : SharedLinkConfigurationPtr();
    return config ? config->mavlinkVersion() : 0;
}

void VehicleLinkManager::setPrimaryLinkByName(const QString &name)
{
    for (const LinkInfo_t& linkInfo: _rgLinkInfo) {
        if (linkInfo.link->linkConfiguration()->name() == name) {
            _primaryLink = linkInfo.link;
            emit primaryLinkChanged();
        }
    }
}

QStringList VehicleLinkManager::linkNames() const
{
    QStringList rgNames;

    for (const LinkInfo_t &linkInfo: _rgLinkInfo) {
        rgNames.append(linkInfo.link->linkConfiguration()->name());
    }

    return rgNames;
}

QStringList VehicleLinkManager::linkStatuses() const
{
    QStringList rgStatuses;

    for (const LinkInfo_t &linkInfo: _rgLinkInfo) {
        rgStatuses.append(linkInfo.commLost ? tr("Comm Lost") : "");
    }

    return rgStatuses;
}
