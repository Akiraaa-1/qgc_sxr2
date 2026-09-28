#include "TrajectoryPoints.h"

#include <QtCore/QtMath>

#include "Fact.h"
#include "Vehicle.h"

TrajectoryPoints::TrajectoryPoints(Vehicle* vehicle, QObject* parent)
    : QObject       (parent)
    , _vehicle      (vehicle)
    , _lastAzimuth  (qQNaN())
{
}

void TrajectoryPoints::_vehicleCoordinateChanged(QGeoCoordinate coordinate)
{
    // The goal of this algorithm is to limit the number of trajectory points whic represent the vehicle path.
    // Fewer points means higher performance of map display.
    if (!coordinate.isValid()) {
        return;
    }

    if (_lastPoint.isValid()) {
        if (_shouldHoldGroundPointOnly()) {
            const double distance = _lastPoint.distanceTo(coordinate);
            if (!qIsNaN(distance) && distance <= _groundHoldJumpMeters) {
                return;
            }

            _lastPoint = coordinate;
            _lastAzimuth = qQNaN();
            _points[_points.count() - 1] = QVariant::fromValue(coordinate);
            emit updateLastPoint(coordinate);
            return;
        }

        double distance = _lastPoint.distanceTo(coordinate);
        if (distance > _distanceTolerance) {
            //-- Update flight distance
            _vehicle->updateFlightDistance(distance);
            // Vehicle has moved far enough from previous point for an update
            double newAzimuth = _lastPoint.azimuthTo(coordinate);
            if (qIsNaN(_lastAzimuth) || qAbs(newAzimuth - _lastAzimuth) > _azimuthTolerance) {
                // The new position IS NOT colinear with the last segment. Append the new position to the list.
                _lastAzimuth = _lastPoint.azimuthTo(coordinate);
                _lastPoint = coordinate;
                _points.append(QVariant::fromValue(coordinate));
                emit pointAdded(coordinate);
            } else {
                // The new position IS colinear with the last segment. Don't add a new point, just update
                // the last point to be the new position.
                _lastPoint = coordinate;
                _points[_points.count() - 1] = QVariant::fromValue(coordinate);
                emit updateLastPoint(coordinate);
            }
        }
    } else {
        // Add the very first trajectory point to the list
        _lastPoint = coordinate;
        _points.append(QVariant::fromValue(coordinate));
        emit pointAdded(coordinate);
    }
}

bool TrajectoryPoints::_shouldHoldGroundPointOnly() const
{
    if (!_vehicle || !(_vehicle->airship() || _vehicle->fixedWing() || _vehicle->multiRotor() || _vehicle->vtol())) {
        return false;
    }
    // Once armed, keep recording even if EXTENDED_SYS_STATE has not yet
    // reported airborne. Some flight controllers briefly report an unknown
    // or ground state during takeoff, which otherwise truncates the path.
    if (_vehicle->armed()) {
        return false;
    }

    const Fact* const groundSpeed = _vehicle->groundSpeed();
    const double groundSpeedMetersSecond = groundSpeed ? groundSpeed->rawValue().toDouble() : 0.0;
    return qIsNaN(groundSpeedMetersSecond) || groundSpeedMetersSecond < _minimumGroundTrackSpeed;
}

void TrajectoryPoints::start(void)
{
    // The vehicle can briefly report disarmed while airborne during a link
    // interruption. Keep the existing path so a recovered armed state does
    // not make the displayed trajectory start in the middle of the flight.
    connect(_vehicle, &Vehicle::coordinateChanged, this, &TrajectoryPoints::_vehicleCoordinateChanged);
}

void TrajectoryPoints::stop(void)
{
    disconnect(_vehicle, &Vehicle::coordinateChanged, this, &TrajectoryPoints::_vehicleCoordinateChanged);
}

void TrajectoryPoints::clear(void)
{
    _points.clear();
    _lastPoint = QGeoCoordinate();
    _lastAzimuth = qQNaN();
    emit pointsCleared();
}
