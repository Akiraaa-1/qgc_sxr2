#pragma once

#include "MAVLinkMessageType.h"

#define MAVLINK_MSG_ID_SWARM_OPERATION_ACK 12924
#define MAVLINK_MSG_ID_SWARM_OPERATION_ACK_LEN 5
#define MAVLINK_MSG_ID_SWARM_OPERATION_ACK_MIN_LEN 5

typedef struct __mavlink_swarm_operation_ack_t {
    uint8_t target_system;
    uint8_t operation_type;
    uint8_t result;
    uint8_t old_value;
    uint8_t new_value;
} mavlink_swarm_operation_ack_t;

static inline uint8_t mavlink_msg_swarm_operation_ack_get_target_system(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint8_t(msg, 0);
}

static inline uint8_t mavlink_msg_swarm_operation_ack_get_operation_type(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint8_t(msg, 1);
}

static inline uint8_t mavlink_msg_swarm_operation_ack_get_result(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint8_t(msg, 2);
}

static inline uint8_t mavlink_msg_swarm_operation_ack_get_old_value(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint8_t(msg, 3);
}

static inline uint8_t mavlink_msg_swarm_operation_ack_get_new_value(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint8_t(msg, 4);
}

static inline void mavlink_msg_swarm_operation_ack_decode(const mavlink_message_t *msg, mavlink_swarm_operation_ack_t *ack)
{
    ack->target_system = mavlink_msg_swarm_operation_ack_get_target_system(msg);
    ack->operation_type = mavlink_msg_swarm_operation_ack_get_operation_type(msg);
    ack->result = mavlink_msg_swarm_operation_ack_get_result(msg);
    ack->old_value = mavlink_msg_swarm_operation_ack_get_old_value(msg);
    ack->new_value = mavlink_msg_swarm_operation_ack_get_new_value(msg);
}
