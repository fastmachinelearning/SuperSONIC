function envoy_on_request(request_handle)
    local path = request_handle:headers():get(":path")
    local contentType = request_handle:headers():get("content-type")

    if path == "/inference.GRPCInferenceService/RepositoryIndex" and contentType == "application/grpc" then
        request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", false)

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
            return
        end

        if not body or body == "" then
            request_handle:logErr("Prometheus could not be reached or returned no data.")
            return
        end

        request_handle:logInfo("Query response body: " .. body)
        local metric_value_str = string.match(body, query_response_template)
        request_handle:logInfo("Extracted metric: " .. metric_value_str)

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
            ---- Temporary ---- 
            request_handle:logErr("Accepting request regardless of metric value.")
            request_handle:streamInfo():dynamicMetadata():set("envoy.lua", "accept_request", true)
        end
    end

    ---- Extract model_name from ModelInferRequest ----
    if contentType == "application/grpc" then
        if path == "/inference.GRPCInferenceService/ModelInfer" then
            -- grab entire request body (you may need to configure the filter to buffer bodies)
            local body = request_handle:body():getBytes(0, request_handle:body():length())
            if body and #body > 5 then
                -- strip the 5-byte gRPC header (1-byte flag + 4-byte msg-len)
                local msg = body:sub(6)

                -- protobuf wire format for field 1, wire type 2: tag = 0x0A
                if msg:byte(1) == 0x0A then
                    -- next byte is a varint length (assumes <128 bytes)
                    local name_len = msg:byte(2)
                    -- extract UTF-8 model name
                    local model_name = msg:sub(3, 2 + name_len)

                    -- log and propagate via dynamic metadata
                    request_handle:logInfo("ModelInfer model_name = " .. model_name)
                    if model_name then
                        local hostHeader = model_name .. ".cms.svc.cluster.local:8001"
                        request_handle:logInfo("x-model-host = " .. hostHeader)
                        request_handle:headers():add("x-model-host", hostHeader)
                    end
                    for k, v in pairs(request_handle:headers()) do
                        request_handle:logInfo("Header " .. k .. ": " .. v)
                    end
                else
                    request_handle:logErr("Unexpected protobuf tag: " .. string.format("0x%02X", msg:byte(1)))
                end
            end
        else
            --- for non-inference calls, for now just forward to default service
            request_handle:headers():add("x-model-host", "supersonic-test-triton.cms.svc.cluster.local:8001")
        end
    end
end

function envoy_on_response(response_handle)
    local md = response_handle:streamInfo():dynamicMetadata():get("envoy.lua")

    if not md or md.accept_request == nil then
      return
    end

    if not response_handle:streamInfo():dynamicMetadata():get("envoy.lua")["accept_request"] then
        response_handle:logInfo("Sending error as a response.")
        local body = response_handle:body()
        if body then
          body:setBytes("")
        end
        response_handle:headers():replace("grpc-status", "1")
    end
end

function encode_query(query)
    return query:gsub("([^%w _%%%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+")
end