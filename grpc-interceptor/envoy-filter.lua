function envoy_on_request(request_handle)
    local path = request_handle:headers():get(":path")
    local contentType = request_handle:headers():get("content-type")

    -- Any other request except model index
    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)

    -- Model index requested?
    if path == "/inference.GRPCInferenceService/RepositoryIndex" and contentType == "application/grpc" then
        request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", false)

        local server_name = 'triton-run2-lb'
        local query = string.format('sonic_lb_saturated{lb_name="%s"}', server_name)
        local metric_threshold = 0.5
        local query_response_template = '"value":%[%d+%.%d+,"([%d%.]+)"%]'

        -- request_handle:logInfo("Query: " .. query)

        local encoded_query = encode_query(query)

        local headers, body = request_handle:httpCall(
            "prometheus_cluster",
            {
                [":method"] = "GET",
                [":path"] = "/api/v1/query?query=" .. encoded_query,
                [":authority"] = "prometheus-service.cms.geddes.rcac.purdue.edu"
            },
            "",
            5000
        )

        if not body or body == "" then
            request_handle:logErr("Prometheus could not be reached or returned no data.")
            return
        end

        -- request_handle:logInfo("Query response body: " .. body)
        local metric_value_str = string.match(body, query_response_template)
        -- request_handle:logInfo("Extracted metric: " .. metric_value_str)

        if metric_value_str then
            local metric_value = tonumber(metric_value_str)
            if metric_value > metric_threshold then
                request_handle:logInfo("Metric value exceeds threshold: " .. metric_value .. " > " .. metric_threshold)
            else
                request_handle:logInfo("Metric value below threshold: " .. metric_value .. " < " .. metric_threshold)
                request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
            end
        else
            request_handle:logErr("Failed to parse metric value from Prometheus response.")
        end
    end
end

function envoy_on_response(response_handle)
    -- Send error back if request was not accepted
    if not response_handle:streamInfo():dynamicMetadata():get("envoy.lua")["accept_request"] then
        response_handle:logInfo("Sending error as a response.")
        response_handle:body():setBytes("")
        response_handle:headers():replace("grpc-status", "1")
    end
end

function encode_query(query)
    return query:gsub("([^%w _%%%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+")
end