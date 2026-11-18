.pragma library

var _idCounter = 1;

function getNextId() {
    return _idCounter++;
}

function parseIncomingMessage(messageStr) {
    try {
        var data = JSON.parse(messageStr);
        return { success: true, data: data };
    } catch (e) {
        return { success: false, error: e };
    }
}

function buildAuthPayload(token) {
    return JSON.stringify({
        type: "auth",
        access_token: token
    });
}

function buildSubscribeEventsPayload(msgId, eventType) {
    return JSON.stringify({
        id: msgId,
        type: "subscribe_events",
        event_type: eventType || "state_changed"
    });
}

function buildGetStatesPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "get_states"
    });
}

function buildGetConfigPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "get_config"
    });
}

function buildGetAreasPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "config/area_registry/list"
    });
}

function buildGetDevicesPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "config/device_registry/list"
    });
}

function buildGetEntityRegistryPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "config/entity_registry/list"
    });
}

function buildGetFloorsPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "config/floor_registry/list"
    });
}

function buildGetLabelsPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "config/label_registry/list"
    });
}

function buildGetServicesPayload(msgId) {
    return JSON.stringify({
        id: msgId,
        type: "get_services"
    });
}

function buildSearchRelatedPayload(msgId, itemType, itemId) {
    return JSON.stringify({
        id: msgId,
        type: "search/related",
        item_type: itemType,
        item_id: itemId
    });
}

function buildHistoryPayload(msgId, entityIds, startTime, endTime, minimalResponse) {
    return JSON.stringify({
        id: msgId,
        type: "history/history_during_period",
        start_time: startTime,
        end_time: endTime,
        entity_ids: Array.isArray(entityIds) ? entityIds : [entityIds],
        minimal_response: minimalResponse !== false,
        no_attributes: false
    });
}

function buildLogbookPayload(msgId, startTime, endTime, entityIds) {
    return JSON.stringify({
        id: msgId,
        type: "logbook/get_events",
        start_time: startTime,
        end_time: endTime,
        entity_ids: Array.isArray(entityIds) ? entityIds : [entityIds]
    });
}

function buildCallServicePayload(msgId, domain, service, serviceData, targetEntityId, options) {
    var payload = {
        id: msgId,
        type: "call_service",
        domain: domain,
        service: service,
        service_data: serviceData || {}
    };

    if (options && options.target) {
        payload.target = options.target;
    } else if (targetEntityId) {
        payload.target = {
            entity_id: targetEntityId
        };
    }

    if (options && options.returnResponse) {
        payload.return_response = true;
    }

    return JSON.stringify(payload);
}
