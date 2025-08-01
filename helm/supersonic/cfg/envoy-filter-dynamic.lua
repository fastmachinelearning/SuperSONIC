function envoy_on_request(request_handle)
    local path = request_handle:headers():get(":path")
    local contentType = request_handle:headers():get("content-type")


    ---- Extract model_name from ModelInferRequest ----
    if contentType == "application/grpc" then
        -- request_handle:logInfo("path = " .. path)
        if path == "/inference.GRPCInferenceService/ModelInfer" then

            local model_name, model_version = extract_model_name_and_version(request_handle, body)
            -- request_handle:logInfo("ModelInfer model_name = " .. model_name .. " model_version = " .. model_version)

            -- log and propagate via dynamic metadata
            if model_name and model_version then
                local svc_name = "RELEASE-" .. model_name .. "-v" .. model_version
                local header_value = svc_name .. ".NAMESPACE.svc.cluster.local:8001"
                request_handle:logInfo("route-to = " .. header_value)
                -- add header
                request_handle:headers():add("route-to", header_value)
            end
        else
            --- for non-inference calls, for now just forward to default service
            request_handle:headers():add("route-to", "RELEASE-triton.NAMESPACE.svc.cluster.local:8001")
        end
    end
end

function extract_model_name_and_version(request_handle)
    local model_name = ""
    local model_version = ""
    local body = request_handle:body():getBytes(0, request_handle:body():length())

    if body and #body > 5 then
        -- strip the 5-byte gRPC header (1-byte flag + 4-byte msg-len)
        local msg = body:sub(6)

        -- protobuf wire format for field 1, wire type 2: tag = 0x0A
        -- field 1 is the model name - we know it from here:
        -- wire type 2 means that the field is length-delimited
        if msg:byte(1) == 0x0A then
            -- next byte is a varint length (assumes <128 bytes)
            local name_len = msg:byte(2)
            -- extract UTF-8 model name
            model_name = msg:sub(3, 2 + name_len)
            -- request_handle:logInfo("ModelInfer model_name = " .. model_name)
            local offset = 3 + name_len

            -- Extract model version (field 2, wire type 2, tag 0x12)
            if msg:byte(offset) == 0x12 then
                local ver_len = msg:byte(offset + 1)
                model_version = msg:sub(offset + 2, offset + 1 + ver_len)
                -- request_handle:logInfo("ModelInfer model_version = " .. model_version)
                offset = offset + 2 + ver_len
            else
                request_handle:logWarn(string.format("No model_version field (expected tag 0x12 at offset %d, got 0x%02X)", 
                    offset, msg:byte(offset)))
            end
        else
            request_handle:logErr("Unexpected protobuf tag: " .. string.format("0x%02X", msg:byte(1)))
        end
    end
    return model_name, model_version
end