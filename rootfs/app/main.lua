local mappings = ngx.shared.mappings

-- Retrieve the serialized mapping data from the shared dictionary
local serialized_data = mappings:get("mappings")

-- Define the target for redirection
local target = "jtelgmbh.atlassian.net"

-- Deserialize the JSON string to a Lua table
local cjson = require("cjson.safe") -- Use safe version for error handling
local mapping_data, err = cjson.decode(serialized_data)

if not mapping_data then
    ngx.log(ngx.ERR, "Error decoding JSON: ", err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Get the query parameters
local query_parameters = ngx.req.get_uri_args()
local page_id = query_parameters.pageId
query_parameters.pageId = nil
local query_string = ngx.encode_args(query_parameters)

local uri = ngx.var.uri
local redirect_path

-- Pattern matching optimizations
local tiny_key = uri:match("/x/(.+)")
local is_viewpage_action = uri:find("viewpage.action")

if tiny_key then
    redirect_path = mapping_data[tiny_key] and '/wiki/display' .. mapping_data[tiny_key]
elseif is_viewpage_action and page_id then
    redirect_path = mapping_data[page_id] and '/wiki/display' .. mapping_data[page_id]
else
    redirect_path = '/wiki' .. uri -- Preserving the existing URI
end

if redirect_path then
    local target_url = ngx.var.scheme .. "://" .. target .. redirect_path

    -- Append query parameters if present
    if query_string ~= "" then
        target_url = target_url .. "?" .. query_string
    end

    -- Perform the redirect
    ngx.redirect(target_url, ngx.HTTP_MOVED_PERMANENTLY) -- 301 redirect
else
    -- Handle cases where no redirect path is found
    ngx.exit(ngx.HTTP_NOT_FOUND)
end
