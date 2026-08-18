function envoy_on_request(request_handle)
    local path = request_handle:headers():get(":path")
    local contentType = request_handle:headers():get("content-type")

    -- Any other request except model index
    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)

    -- Model index requested?
    if path == "/inference.GRPCInferenceService/RepositoryIndex" and contentType == "application/grpc" then
        request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", false)

        local scale_from_zero = ("SCALE_FROM_ZERO_ENABLED" == "true")
        local prometheus_rate_limit_enabled = ("PROMETHEUS_RATE_LIMIT_ENABLED" == "true")

        -- Start the first GPU Triton and wait until it is Ready before forwarding
        -- RepositoryIndex. CMSSW treats a successful index as a commitment, then
        -- issues ModelConfig / inference with a short timeout.
        if scale_from_zero then
            local timeout_ms = (tonumber("READY_TIMEOUT_SECONDS") or 300) * 1000 + 2000
            request_handle:logInfo("Scale-from-zero: waiting for GPU Triton to become Ready")
            local wake_headers = request_handle:httpCall(
                "triton_admission",
                {
                    [":method"] = "GET",
                    [":path"] = "/wake",
                    [":authority"] = "triton_admission"
                },
                "",
                timeout_ms
            )
            if not wake_headers or wake_headers[":status"] ~= "200" then
                request_handle:logErr("GPU Triton was not Ready in time; rejecting RepositoryIndex")
                return
            end
            request_handle:logInfo("GPU Triton is Ready")
        end

        if prometheus_rate_limit_enabled then
            local query = SERVER_LOAD_METRIC
            local metric_threshold = tonumber(SERVER_LOAD_THRESHOLD)
            local query_response_template = '"value":%[%d+%.%d+,"([%d%.]+)"%]'
            local encoded_query = encode_query(query)

            request_handle:logInfo("Prometheus scheme: " .. "PROMETHEUS_SCHEME")
            request_handle:logInfo("Prometheus host: " .. "PROMETHEUS_HOST")
            request_handle:logInfo("Prometheus port: " .. "PROMETHEUS_PORT")
            request_handle:logInfo("Query: " .. query)
            request_handle:logInfo("Encoded query: " .. encoded_query)

            local headers, body = request_handle:httpCall(
                "prometheus_cluster",
                {
                    [":method"] = "GET",
                    [":path"] = "/api/v1/query?query=" .. encoded_query,
                    [":scheme"] = "PROMETHEUS_SCHEME",
                    [":authority"] = "PROMETHEUS_HOST" .. ":" .. "PROMETHEUS_PORT"
                },
                "",
                5000
            )
            if not headers then
                request_handle:logErr("HTTP call to Prometheus failed.")
                if scale_from_zero then
                    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
                end
                return
            end

            if not body or body == "" then
                request_handle:logErr("Prometheus could not be reached or returned no data.")
                if scale_from_zero then
                    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
                end
                return
            end

            request_handle:logInfo("Query response body: " .. body)
            local metric_value_str = string.match(body, query_response_template)
            request_handle:logInfo("Extracted metric: " .. tostring(metric_value_str))

            if metric_value_str then
                local metric_value = tonumber(metric_value_str)
                if metric_value > metric_threshold then
                    request_handle:logInfo("Metric value exceeds threshold: " .. metric_value .. " > " .. metric_threshold)
                else
                    request_handle:logInfo("Metric value below threshold: " .. metric_value .. " < " .. metric_threshold)
                    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
                end
            elseif scale_from_zero then
                request_handle:logInfo("No Prometheus metric value; treating load as 0")
                request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
            else
                request_handle:logErr("Failed to parse metric value from Prometheus response.")
            end
        else
            request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
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
