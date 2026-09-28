#include "VehicleReadinessSITLTest.h"

#include <QtCore/QRegularExpression>
#include <QtTest/QSignalSpy>

#ifdef Q_OS_UNIX
#include <cerrno>
#include <csignal>
#include <cstring>
#endif

#include "Fact.h"
#include "HealthAndArmingCheckReport.h"
#include "LinkManager.h"
#include "ParameterManager.h"
#include "UDPLink.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"
#include "VehicleReadiness.h"

namespace {
constexpr int kConnectTimeoutMs = 60000;
constexpr int kHealthReportTimeoutMs = 30000;
constexpr int kCommunicationLossTimeoutMs = 15000;
}

void VehicleReadinessSITLTest::init()
{
    CommsTest::init();

    bool portOk = false;
    _sitlPort = qEnvironmentVariableIntValue("BTFW_T029_SITL_PORT", &portOk);
    bool gcsPortOk = false;
    _gcsPort = qEnvironmentVariableIntValue("BTFW_T029_GCS_PORT", &gcsPortOk);
    bool pidOk = false;
    _sitlPid = qEnvironmentVariableIntValue("BTFW_T029_SITL_PID", &pidOk);
    if (!portOk || _sitlPort <= 0 || !gcsPortOk || _gcsPort <= 0 || !pidOk || _sitlPid <= 0) {
        QSKIP("Set BTFW_T029_GCS_PORT, BTFW_T029_SITL_PORT, and BTFW_T029_SITL_PID for the temporary PX4 SITL instance.");
    }

#ifndef Q_OS_UNIX
    QSKIP("The T-029 SITL reconnect scenario currently requires UNIX signal support.");
#else
    if (::kill(static_cast<pid_t>(_sitlPid), 0) != 0) {
        QFAIL(qPrintable(QStringLiteral("BTFW_T029_SITL_PID %1 is not a running process: %2")
                             .arg(_sitlPid)
                             .arg(QString::fromLocal8Bit(std::strerror(errno)))));
    }
#endif

    UDPConfiguration* const udpConfig = new UDPConfiguration(QStringLiteral("T-029 temporary SITL"));
    udpConfig->setDynamic(true);
    udpConfig->setLocalPort(static_cast<quint16>(_gcsPort));
    udpConfig->addHost(QStringLiteral("127.0.0.1"), static_cast<quint16>(_sitlPort));
    _linkConfig = SharedLinkConfigurationPtr(udpConfig);

    QVERIFY(linkManager()->createConnectedLink(_linkConfig));
    _vehicle = waitForVehicleConnect(kConnectTimeoutMs);
    QVERIFY(_vehicle);
    QVERIFY_TRUE_WAIT(_vehicle->isInitialConnectComplete(), kConnectTimeoutMs);
    QVERIFY_TRUE_WAIT(_vehicle->parameterManager()->parametersReady(), kConnectTimeoutMs);
    QVERIFY_TRUE_WAIT(_healthReportAllowsArm(), kHealthReportTimeoutMs);
}

void VehicleReadinessSITLTest::cleanup()
{
    _resumeSitl();

    if (_vehicle && _vehicle->armed()) {
        _vehicle->setArmed(false, false);
        (void) UnitTest::waitForCondition([this]() { return !_vehicle->armed(); }, TestTimeout::mediumMs(),
                                          QStringLiteral("temporary SITL is disarmed"));
    }

    _vehicle = nullptr;
    _linkConfig.reset();
    CommsTest::cleanup();
}

void VehicleReadinessSITLTest::_healthReportReadinessScenarios()
{
    QVERIFY(_vehicle);
    VehicleReadiness* const readiness = _vehicle->readiness();
    QVERIFY(readiness);

    // Modern health report allows arming and BTFW-GCS forwards the arm request.
    QCOMPARE(readiness->source(), VehicleReadiness::SourceHealthReport);
    QCOMPARE(readiness->armingVerdict(), VehicleReadiness::VerdictAllowed);
    QVERIFY(readiness->canRequestArm());
    QVERIFY(!readiness->armConfirmationRequired());
    QVERIFY(_vehicle->requestArm(false));
    QVERIFY_TRUE_WAIT(_vehicle->armed(), TestTimeout::mediumMs());
    QCOMPARE(readiness->armRequestState(), VehicleReadiness::ArmRequestConfirmed);

    _vehicle->setArmed(false, true);
    QVERIFY_TRUE_WAIT(!_vehicle->armed(), TestTimeout::mediumMs());

    // A current health report with an explicit failure must reject both normal
    // and manually confirmed requests before an arm command is dispatched.
    QVERIFY(_setParameter(QStringLiteral("COM_ARMABLE"), 0));
    _vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, MAV_CMD_RUN_PREARM_CHECKS, false);
    QVERIFY_TRUE_WAIT(_healthReportDeniesArm(), kHealthReportTimeoutMs);
    QVERIFY(readiness->hasHealthWarnings());
    QVERIFY(!readiness->canRequestArm());
    QVERIFY(!readiness->armConfirmationRequired());
    QVERIFY(!readiness->armReason().isEmpty());
    expectLogMessage(QtDebugMsg, QRegularExpression(QStringLiteral("health report is blocking arming")));
    QVERIFY(!_vehicle->requestArm(false));
    QVERIFY(!_vehicle->requestArm(true));
    QVERIFY(!_vehicle->armed());

    QVERIFY(_setParameter(QStringLiteral("COM_ARMABLE"), 1));
    _vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, MAV_CMD_RUN_PREARM_CHECKS, false);
    QVERIFY_TRUE_WAIT(_healthReportAllowsArm(), kHealthReportTimeoutMs);

    // A lost link invalidates every readiness source. After recovery, a fresh
    // SYS_STATUS and health report must arrive before readiness is restored.
    QVERIFY(_pauseSitl());
    QVERIFY_TRUE_WAIT(_vehicle->vehicleLinkManager()->communicationLost(), kCommunicationLossTimeoutMs);
    QCOMPARE(readiness->source(), VehicleReadiness::SourceUnavailable);
    QVERIFY(!readiness->canRequestArm());
    expectLogMessage(QtDebugMsg, QRegularExpression(QStringLiteral("Communication is unavailable")));
    QVERIFY(!_vehicle->requestArm(true));

    _resumeSitl();
    QVERIFY_TRUE_WAIT(!_vehicle->vehicleLinkManager()->communicationLost(), kCommunicationLossTimeoutMs);
    QVERIFY_TRUE_WAIT(_vehicle->sysStatusReceived(), kHealthReportTimeoutMs);
    QVERIFY_TRUE_WAIT(_healthReportAllowsArm(), kHealthReportTimeoutMs);
}

bool VehicleReadinessSITLTest::_setParameter(const QString& name, int value)
{
    if (!_vehicle || !_vehicle->parameterManager()) {
        return false;
    }

    ParameterManager* const parameterManager = _vehicle->parameterManager();
    if (!parameterManager->parameterExists(ParameterManager::defaultComponentId, name)) {
        return false;
    }

    Fact* const fact = parameterManager->getParameter(ParameterManager::defaultComponentId, name);
    if (!fact) {
        return false;
    }

    QSignalSpy spyParamSetSuccess(parameterManager, &ParameterManager::_paramSetSuccess);
    if (!spyParamSetSuccess.isValid()) {
        return false;
    }

    fact->setRawValue(value);
    if (!UnitTest::waitForCondition([this, &spyParamSetSuccess, &name]() {
            return _hasParameterSetSuccess(spyParamSetSuccess, name);
        },
        TestTimeout::longMs(),
        QStringLiteral("COM_ARMABLE parameter write"))) {
        return false;
    }

    return UnitTest::waitForCondition([parameterManager]() { return !parameterManager->pendingWrites(); },
                                      TestTimeout::mediumMs(),
                                      QStringLiteral("COM_ARMABLE parameter write completion"));
}

bool VehicleReadinessSITLTest::_hasParameterSetSuccess(const QSignalSpy& spy, const QString& name) const
{
    for (const QList<QVariant>& arguments : spy) {
        if (arguments.count() == 2 && arguments.at(1).toString() == name) {
            return true;
        }
    }
    return false;
}

bool VehicleReadinessSITLTest::_healthReportAllowsArm() const
{
    return _vehicle
        && _vehicle->readiness()
        && _vehicle->readiness()->source() == VehicleReadiness::SourceHealthReport
        && _vehicle->readiness()->armingVerdict() == VehicleReadiness::VerdictAllowed;
}

bool VehicleReadinessSITLTest::_healthReportDeniesArm() const
{
    return _vehicle
        && _vehicle->readiness()
        && _vehicle->readiness()->source() == VehicleReadiness::SourceHealthReport
        && _vehicle->readiness()->armingVerdict() == VehicleReadiness::VerdictDenied;
}

bool VehicleReadinessSITLTest::_pauseSitl()
{
#ifdef Q_OS_UNIX
    if (::kill(static_cast<pid_t>(_sitlPid), SIGSTOP) == 0) {
        _sitlPaused = true;
        return true;
    }
#endif
    return false;
}

void VehicleReadinessSITLTest::_resumeSitl()
{
#ifdef Q_OS_UNIX
    if (_sitlPaused) {
        (void) ::kill(static_cast<pid_t>(_sitlPid), SIGCONT);
        _sitlPaused = false;
    }
#endif
}

UT_REGISTER_TEST_STANDALONE(VehicleReadinessSITLTest, TestLabel::Integration, TestLabel::Vehicle, TestLabel::Network,
                            TestLabel::Serial)
