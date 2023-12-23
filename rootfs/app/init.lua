-- Define the path to the mapping CSV file
local mapping_file_path = "/app/mapping.csv"

-- Initialize a shared dictionary to store the mapping data
local mappings = ngx.shared.mappings

-- Function to load the mapping data from the CSV file
function load_mapping_data()
    local mapping = {}
    local file = io.open(mapping_file_path, "r")
    if file then
        for line in file:lines() do
            local page_id, tiny_url, full_path = line:match("([^,]+),([^,]+),([^,]+)")
            if page_id and tiny_url and full_path then
                -- Map both page ID and tiny URL to the full path. This will
                -- result in something like this:
                --
                -- mapping = {
                --     ['327753'] = '/jpw/Supervisor+-+Realtime+Values',
                --     ['SQAF'] = '/jpw/Supervisor+-+Realtime+Values',
                --     ['327854'] = '/jpw/Supervisor+and+Wallboard+Content',
                --     ['rgAF'] = '/jpw/Supervisor+and+Wallboard+Content',
                --     ['327852'] = '/jpw/Supervisor+-+Today\'s++Statistics',
                --     ['rAAF'] = '/jpw/Supervisor+-+Today\'s++Statistics',
                --     -- and so on for each line in the CSV file...
                -- }
                mapping[page_id] = full_path
                mapping[tiny_url] = full_path
            end
        end
        file:close()
    else
        ngx.log(ngx.ERR, "Failed to open mapping file: ", mapping_file_path)
    end
    return mapping
end

-- Load the mapping data into the shared dictionary immediately during initialization
local mapping_data = load_mapping_data()
local mappings_serialized = require("cjson").encode(mapping_data)
mappings:set("mappings", mappings_serialized)
