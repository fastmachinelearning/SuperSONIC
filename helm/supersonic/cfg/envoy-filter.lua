function envoy_on_request(request_handle)
    local path = request_handle:headers():get(":path")
    local contentType = request_handle:headers():get("content-type")

    -- Metadata is set only for RepositoryIndex requests, so envoy_on_response
    -- leaves every other response untouched.

    -- Model index requested?
    if path == "/inference.GRPCInferenceService/RepositoryIndex" and contentType == "application/grpc" then
        request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", false)

        local scale_from_zero = ("SCALE_FROM_ZERO_ENABLED" == "true")
        local prometheus_rate_limit_enabled = ("PROMETHEUS_RATE_LIMIT_ENABLED" == "true")

        -- Scale the inference server to at least one replica and wait for a healthy Envoy upstream before forwarding RepositoryIndex.
        if scale_from_zero then
            local timeout_seconds = tonumber("READY_TIMEOUT_SECONDS") or 300
            request_handle:logInfo("Scale-from-zero: starting the inference server")
            -- /wake may wait behind an in-flight scaling pass and then make up to
            -- four Kubernetes API calls of its own (3s timeout each), so give it
            -- enough headroom for a slow apiserver.
            local wake_headers = request_handle:httpCall(
                "inference_server_admission",
                {
                    [":method"] = "GET",
                    [":path"] = "/wake",
                    [":authority"] = "inference_server_admission"
                },
                "",
                30000
            )
            if not wake_headers or wake_headers[":status"] ~= "200" then
                request_handle:logErr("Admission /wake failed; rejecting RepositoryIndex")
                request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "reject_reason", "no healthy upstream: scale-from-zero wake failed")
                return
            end

            -- Wait until Envoy reports a healthy inference server host, or until the deadline passes.
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
                        [":path"] = "/stats?filter=cluster.inference_server_grpc_service.membership_healthy",
                        [":authority"] = "envoy_admin"
                    },
                    "",
                    1000
                )
                local n = 0
                if stats_body then
                    n = tonumber(string.match(stats_body, "cluster%.inference_server_grpc_service%.membership_healthy: ([0-9]+)")) or 0
                end
                if n > 0 then
                    healthy = true
                    break
                end
                local sleep_headers = request_handle:httpCall(
                    "inference_server_admission",
                    {
                        [":method"] = "GET",
                        [":path"] = "/sleep",
                        [":authority"] = "inference_server_admission"
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
                request_handle:logErr("No healthy inference server upstream in time; rejecting RepositoryIndex")
                request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "reject_reason", "no healthy upstream: inference server did not become ready in time")
                return
            end
            request_handle:logInfo("Inference server has a healthy Envoy upstream")

            -- Refresh the KEDA hold now that the inference server is ready. The first /wake
            -- anchored hold-until at the moment the wake started, so by the time
            -- the index is answered only hold - startup_time of it would remain
            -- (and could be nearly nothing after a slow start). /wake only moves
            -- hold-until forward and does not lower minReplicaCount, so calling it
            -- again is safe. Failure is non-fatal: the index is about to be served
            -- and the original hold still applies. The timeout is shorter than the
            -- first wake's because this must not delay the index much; the
            -- admission sidecar finishes the wake pass server-side even if Envoy
            -- stops waiting for the reply.
            local refresh_headers = request_handle:httpCall(
                "inference_server_admission",
                {
                    [":method"] = "GET",
                    [":path"] = "/wake",
                    [":authority"] = "inference_server_admission"
                },
                "",
                10000
            )
            if not refresh_headers or refresh_headers[":status"] ~= "200" then
                request_handle:logWarn("Admission /wake refresh after readiness failed; hold is anchored at wake time")
            end
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
                else
                    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "reject_reason", "request rejected: rate limiter could not reach Prometheus")
                end
                return
            end

            if not body or body == "" then
                request_handle:logErr("Prometheus could not be reached or returned no data.")
                if scale_from_zero then
                    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
                else
                    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "reject_reason", "request rejected: rate limiter got no data from Prometheus")
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
                    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "reject_reason", "request rejected: server load above threshold, retry later")
                else
                    request_handle:logInfo("Metric value below threshold: " .. metric_value .. " < " .. metric_threshold)
                    request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
                end
            elseif scale_from_zero then
                request_handle:logInfo("No Prometheus metric value; treating load as 0")
                request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
            else
                request_handle:logErr("Failed to parse metric value from Prometheus response.")
                request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "reject_reason", "request rejected: rate limiter could not parse Prometheus response")
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
        -- Prefer Envoy's own message (e.g. "no healthy upstream"), then the reason
        -- recorded by envoy_on_request, then a generic fallback.
        local message = grpc_message
        if message == "" then
            message = metadata["reject_reason"] or "request rejected"
        end
        response_handle:logInfo("Sending error as a response: " .. message)
        -- A headers-only response (e.g. Envoy's own 503) has no body object.
        local body = response_handle:body()
        if body then
            body:setBytes("")
        end
        -- UNAVAILABLE (14) is the retryable code gRPC clients expect for
        -- "no upstream" and "try again later" (rate-limited) conditions.
        response_handle:headers():replace("grpc-status", "14")
        response_handle:headers():replace("grpc-message", message)
    end
end

function encode_query(query)
    return query:gsub("([^%w _%%%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+")
end
