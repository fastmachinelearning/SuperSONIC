function envoy_on_request(request_handle)
    local path = request_handle:headers():get(":path")
    local contentType = request_handle:headers():get("content-type")

    ---- Extract model_name from ModelInferRequest ----
    if contentType == "application/grpc" then
        if path == "/inference.GRPCInferenceService/ModelInfer" then
            -- grab entire request body (you may need to configure the filter to buffer bodies)
            local body = request_handle:body():getBytes(0, request_handle:body():length())
            if body and #body > 5 then
                -- strip the 5-byte gRPC header (1-byte flag + 4-byte msg-len)
                local msg = body:sub(6)

                -- protobuf wire format for field 1, wire type 2: tag = 0x0A
                -- field 1 is the model name - we know it from here:
                -- https://github.com/kserve/open-inference-protocol/blob/main/specification/protocol/inference_grpc.md#inference
                -- wire type 2 means that the field is length-delimited
                if msg:byte(1) == 0x0A then
                    -- next byte is a varint length (assumes <128 bytes)
                    local name_len = msg:byte(2)
                    -- extract UTF-8 model name
                    local model_name = msg:sub(3, 2 + name_len)

                    -- log and propagate via dynamic metadata
                    request_handle:logWarn("ModelInfer model_name = " .. model_name)
                    if model_name then
                        local hostHeader = model_name .. ".NAMESPACE.svc.cluster.local:8001"
                        request_handle:logWarn("route-to = " .. hostHeader)
                        -- add header
                        request_handle:headers():add("route-to", hostHeader)
                    end
                    -- for k, v in pairs(request_handle:headers()) do
                    --     request_handle:logInfo("Header " .. k .. ": " .. v)
                    -- end
                else
                    request_handle:logErr("Unexpected protobuf tag: " .. string.format("0x%02X", msg:byte(1)))
                end
            end
        else
            --- for non-inference calls, for now just forward to default service
            request_handle:headers():add("route-to", "RELEASE-triton.NAMESPACE.svc.cluster.local:8001")
        end
    end
end