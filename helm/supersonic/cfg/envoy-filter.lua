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

        -- Scale Triton to at least one replica and wait for a healthy Envoy upstream before forwarding RepositoryIndex.
        if scale_from_zero then
            local timeout_seconds = tonumber("READY_TIMEOUT_SECONDS") or 300
            request_handle:logInfo("Scale-from-zero: starting GPU Triton")
            -- /wake may wait behind an in-flight scaling pass and then make up to
            -- four Kubernetes API calls of its own (3s timeout each), so give it
            -- enough headroom for a slow apiserver.
            local wake_headers = request_handle:httpCall(
                "triton_admission",
                {
                    [":method"] = "GET",
                    [":path"] = "/wake",
                    [":authority"] = "triton_admission"
                },
                "",
                30000
            )
            if not wake_headers or wake_headers[":status"] ~= "200" then
                request_handle:logErr("Admission /wake failed; rejecting RepositoryIndex")
                return
            end

            -- Wait until Envoy reports a healthy Triton host, or until the deadline passes.
            -- Envoy Lua has no sleep primitive, so the loop is paced by the admission
            -- sidecar's /sleep endpoint, which blocks for ~1s before responding.
            local healthy = false
            local deadline = os.time() + timeout_seconds
            local sleep_failures = 0
            while os.time() < deadline do
                local stats_headers, stats_body = request_handle:httpCall(
                    "envoy_admin",
                    {
                        [":method"] = "GET",
                        [":path"] = "/stats?filter=cluster.triton_grpc_service.membership_healthy",
                        [":authority"] = "envoy_admin"
                    },
                    "",
                    1000
                )
                local n = 0
                if stats_body then
                    n = tonumber(string.match(stats_body, "cluster%.triton_grpc_service%.membership_healthy: ([0-9]+)")) or 0
                end
                if n > 0 then
                    healthy = true
                    break
                end
                local sleep_headers = request_handle:httpCall(
                    "triton_admission",
                    {
                        [":method"] = "GET",
                        [":path"] = "/sleep",
                        [":authority"] = "triton_admission"
                    },
                    "",
                    2000
                )
                if not sleep_headers or sleep_headers[":status"] ~= "200" then
                    -- Do not busy-spin against the admin endpoint if the sidecar is down.
                    sleep_failures = sleep_failures + 1
                    if sleep_failures >= 5 then
                        request_handle:logErr("Admission /sleep unavailable; aborting wait")
                        break
                    end
                else
                    sleep_failures = 0
                end
            end
            if not healthy then
                request_handle:logErr("No healthy Triton upstream in time; rejecting RepositoryIndex")
                return
            end
            request_handle:logInfo("GPU Triton has a healthy Envoy upstream")
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
    local metadata = response_handle:streamInfo():dynamicMetadata():get("envoy.lua")
    if metadata == nil then
        -- Not a RepositoryIndex request: envoy_on_request set no metadata,
        -- so pass the response through untouched.
        return
    end
    local accepted = metadata["accept_request"]
    local grpc_message = response_handle:headers():get("grpc-message") or ""
    local no_upstream = string.find(grpc_message, "no healthy upstream", 1, true)
    -- Reject the request if it was not accepted, or if Envoy has no healthy upstream.
    if not accepted or no_upstream then
        response_handle:logInfo("Sending error as a response.")
        response_handle:body():setBytes("")
        response_handle:headers():replace("grpc-status", "1")
        response_handle:headers():remove("grpc-message")
    end
end

function encode_query(query)
    return query:gsub("([^%w _%%%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+")
end
