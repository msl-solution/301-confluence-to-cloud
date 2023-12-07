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
            local tiny_path, full_path = line:match("([^,]+),([^,]+)")
            if tiny_path and full_path then
                mapping[tiny_path] = full_path
            end
        end
        file:close()
    end
    return mapping
end

-- Load the mapping data into the shared dictionary immediately during initialization
local mapping_data = load_mapping_data()
local mappings_serialized = require("cjson").encode(mapping_data)
mappings:set("mappings", mappings_serialized)
