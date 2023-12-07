local mappings = ngx.shared.mappings

-- Retrieve the serialized mapping data from the shared dictionary
local serialized_data = mappings:get("mappings")

-- Define the target for redirection
local target = "jtelgmbh.atlassian.net/wiki/spaces/JPW"
local target = "wiki.jtel.de"

-- Deserialize the JSON string to a Lua table
local cjson = require("cjson")
local mapping_data = cjson.decode(serialized_data)

-- Now you can use 'mapping_data' in your logic
if mapping_data then

    -- Get the query parameters
    local query_parameters = ngx.req.get_uri_args()
    local query_string = ngx.encode_args(query_parameters)

    local uri = ngx.var.uri
    local tiny_path = uri:match("/(.+)")
    local full_path = mapping_data[tiny_path]

    local target_url
    if full_path then
        -- Construct the target URL with the 'target' variable
        target_url = ngx.var.scheme .. "://" .. target .. full_path
    else
        -- If no match is found, redirect without changing the path to the target host
        target_url = ngx.var.scheme .. "://" .. target .. ngx.var.uri
    end

    -- Append the preserved query parameters
    if query_string ~= "" then
        target_url = target_url .. "?" .. query_string
    end

    ngx.redirect(target_url, ngx.HTTP_MOVED_PERMANENTLY) -- 301 redirect
end
