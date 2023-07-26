local modname = minetest.get_current_modname()
local MOD_PATH = minetest.get_modpath(modname)
local LIB_PATH = MOD_PATH .. "/lasdata/"
dofile(MOD_PATH .. "/struct.lua")

local LASFile = {
    xdim = {},
    ydim = {},
    zdim = {},
    voxelMap = {},
    loadRealm = nil,
    realmEmergeContinue = nil,
    attributes = {
        ReturnNumber = true,
        NumberOfReturns = true,
        ClassificationFlagSynthetic = true,
        ClassificationFlagKeyPoint = true,
        ClassificationFlagWithheld = true,
        ClassificationFlagOverlap = true,
        ScannerChannel = true,
        ScanDirectionFlag = true,
        EdgeOfFlightLine = true,
        Classification = true,
        Intensity = true,
        UserData = true,
        ScanAngle = true,
        PointSourceID = true,
        GPSTime = true,
    },
    extent = {
        xmin = nil,
        xmax = nil,
        ymin = nil,
        ymax = nil,
    },
}

local function getBit(byte, index)
    return math.floor(byte / (2 ^ index)) % 2
end

local function leftShift(value, numBits)
    return value * (2 ^ numBits)
end

local function bitwiseOR(a, b)
    local result = 0
    local bit = 1
    while a > 0 or b > 0 do
        local bitA = a % 2
        local bitB = b % 2
        if bitA == 1 or bitB == 1 then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

function LASFile.header(file_path)
    local file = assert(io.open(file_path, "rb"))

    -- Read the file size
    local file_size = file:seek("end")

    -- Ensure the file is at least 375 bytes (size of LAS header)
    if file_size < 375 then
        print("Error: File is too small to contain a valid LAS header.")
        file:close()
        return
    end

    -- Reset file position to the beginning
    file:seek("set", 0)

    -- Read the LAS header information manually with little-endian byte order
    local header_format = "< c4 H H I H H L B B c32 c32 H H H I I B H I I I I I I d d d d d d d d d d d d L L I L L L L L L L L L L L L L L L L"
    local header_raw = file:read(375)
    local header = {struct.unpack(header_format, header_raw, 1)}

    -- Display header information
    print("File Signature:", header[1])
    print("File Source ID:", header[2])
    print("Global Encoding:", header[3])
    print("Project ID - GUID Data 1:", header[4])
    print("Project ID - GUID Data 2:", header[5])
    print("Project ID - GUID Data 3:", header[6])
    print("Project ID - GUID Data 4:", header[7])
    print("Version Major:", header[8])
    print("Version Minor:", header[9])
    print("System Identifier:", header[10])
    print("Generating Software:", header[11])
    print("File Creation Day of Year:", header[12])
    print("File Creation Year:", header[13])
    print("Header Size:", header[14])
    print("Offset to Point Data:", header[15])
    print("Number of Variable Length Records:", header[16])
    print("Point Data Record Format:", header[17])
    print("Point Data Record Length:", header[18])
    print("Legacy Number of Point Records:", header[19])
    print("Legacy Number of Point by Return:")
    for i = 1, 5 do
        print("    Return " .. i .. ":", header[19 + i])
    end
    print("X Scale Factor:", header[25])
    print("Y Scale Factor:", header[26])
    print("Z Scale Factor:", header[27])
    print("X Offset:", header[28])
    print("Y Offset:", header[29])
    print("Z Offset:", header[30])
    print("Max X:", header[31])
    print("Min X:", header[32])
    print("Max Y:", header[33])
    print("Min Y:", header[34])
    print("Max Z:", header[35])
    print("Min Z:", header[36])
    print("Start of Waveform Data Packet Record:", header[37])
    print("Start of First Extended Variable Length Record:", header[38])
    print("Number of Extended Variable Length Records:", header[39])
    print("Number of Point Records:", header[40])
    print("Number of Points by Return:")
    for i = 1, 15 do
        print("    Return " .. i .. ":", header[40 + i])
    end

    file:close()
end

function LASFile.points(file_path, attributes, extent)
    
    -- Sanitize input attributes
    if attributes then
        LASFile.attributes.ReturnNumber = attributes.ReturnNumber or nil
        LASFile.attributes.NumberOfReturns = attributes.NumberOfReturns
        LASFile.attributes.ClassificationFlagSynthetic = attributes.ClassificationFlagSynthetic or nil
        LASFile.attributes.ClassificationFlagKeyPoint = attributes.ClassificationFlagKeyPoint or nil
        LASFile.attributes.ClassificationFlagWithheld = attributes.ClassificationFlagWithheld or nil
        LASFile.attributes.ClassificationFlagOverlap = attributes.ClassificationFlagOverlap or nil
        LASFile.attributes.ScannerChannel = attributes.ScannerChannel or nil
        LASFile.attributes.ScanDirectionFlag = attributes.ScanDirectionFlag or nil
        LASFile.attributes.EdgeOfFlightLine = attributes.EdgeOfFlightLine or nil
        LASFile.attributes.Classification = attributes.Classification or nil
        LASFile.attributes.Intensity = attributes.Intensity or nil
        LASFile.attributes.UserData = attributes.UserData or nil
        LASFile.attributes.ScanAngle = attributes.ScanAngle or nil
        LASFile.attributes.PointSourceID = attributes.PointSourceID or nil
        LASFile.attributes.GPSTime = attributes.GPSTime or nil
    end

    -- Sanitize input processing extent
    if extent then
        LASFile.extent.xmin = extent.xmin or nil
        LASFile.extent.xmax = extent.xmax or nil
        LASFile.extent.ymin = extent.ymin or nil
        LASFile.extent.ymax = extent.ymax or nil
    end

    local file = assert(io.open(file_path, "rb"))

    -- Read the file size
    local file_size = file:seek("end")

    -- Ensure the file is at least 375 bytes (size of LAS header)
    if file_size < 375 then
        print("Error: File is too small to contain a valid LAS header.")
        file:close()
        return
    end

    -- Reset file position to the beginning
    file:seek("set", 0)

    -- Read the LAS header information manually with little-endian byte order
    local header_format = "< c4 H H I H H L B B c32 c32 H H H I I B H I I I I I I d d d d d d d d d d d d L L I L L L L L L L L L L L L L L L L"
    local header_raw = file:read(375)
    local header = {struct.unpack(header_format, header_raw, 1)}

    local xmin = tonumber(header[32])
    local xmax = tonumber(header[31])
    local ymin = tonumber(header[34])
    local ymax = tonumber(header[33])

    -- Check that we have valid processing extent values
    if (LASFile.extent.xmin == nil and LASFile.extent.xmax == nil and LASFile.extent.ymin == nil and LASFile.extent.ymax == nil) or (LASFile.extent.xmin and LASFile.extent.xmax and LASFile.extent.ymin and LASFile.extent.ymax) then

        -- Check that the processing extent values are specified correctly
        if (LASFile.extent.xmin == nil and LASFile.extent.xmax == nil and LASFile.extent.ymin == nil and LASFile.extent.ymax == nil) or (LASFile.extent.xmin < LASFile.extent.xmax and LASFile.extent.ymin < LASFile.extent.ymax) then

            -- Check if the processing extent intersects with the LAS file extent
            if (LASFile.extent.xmin == nil and LASFile.extent.xmax == nil and LASFile.extent.ymin == nil and LASFile.extent.ymax == nil) or ((LASFile.extent.xmin >= xmin and LASFile.extent.ymax >= ymin and LASFile.extent.xmin <= xmax and LASFile.extent.ymax <= ymax) or (LASFile.extent.xmax >= xmin and LASFile.extent.ymax >= ymin and LASFile.extent.xmax <= xmax and LASFile.extent.ymax <= ymax) or (LASFile.extent.xmin >= xmin and LASFile.extent.ymin <= ymax and LASFile.extent.xmin <= xmax and LASFile.extent.ymin >= ymin) or (LASFile.extent.xmax >= xmin and LASFile.extent.ymin <= ymax and LASFile.extent.xmax <= xmax and LASFile.extent.ymin >= ymin)) then
        
                -- Read and parse point data records
                file:seek("set", header[15]) -- Seek to the offset of the point data
                local point_format = "< i i i H B B B B h H d"
                local points = {}

                local time = os.date("*t")
                minetest.chat_send_all(("%02d:%02d:%02d"):format(time.hour, time.min, time.sec) .. " Collecting " .. header[40] .. " points now...")
                for i = 1, tonumber(header[40]) do
                    local point_raw = file:read(header[18]) -- Read one point data record
                    local point_data = {struct.unpack(point_format, point_raw, 1)}

                    -- Before we bother doing anything with the point, check if it is within the processing extent
                    local xx = tonumber(point_data[1])*tonumber(header[25])+tonumber(header[28])
                    local yy = tonumber(point_data[2])*tonumber(header[26])+tonumber(header[29])
                    if (LASFile.extent.xmin == nil and LASFile.extent.xmax == nil and LASFile.extent.ymin == nil and LASFile.extent.ymax == nil) or (LASFile.extent.xmin < xx and xx < LASFile.extent.xmax and LASFile.extent.ymin < yy and yy < LASFile.extent.ymax) then
                        local zz = tonumber(point_data[3])*tonumber(header[27])+tonumber(header[30])
                        local ReturnNumber, NumberOfReturns, ClassificationFlagSynthetic, ClassificationFlagKeyPoint, ClassificationFlagWithheld, ClassificationFlagOverlap, ScannerChannel, ScanDirectionFlag, EdgeOfFlightLine, Classification, Intensity, UserData, ScanAngle, PointSourceID, GPSTime = nil

                        -- Unpack the bits for Return Number, Number of Returns (Given Pulse), Scanner Channel, Scan Direction Flag, Classification Flags, Edge of Flight Line, and Classification
                        if LASFile.attributes.ReturnNumber then
                            local return_number_bit_0 = getBit(point_data[5], 0)
                            local return_number_bit_1 = getBit(point_data[5], 1)
                            local return_number_bit_2 = getBit(point_data[5], 2)
                            local return_number_bit_3 = getBit(point_data[5], 3)
                            ReturnNumber = bitwiseOR(bitwiseOR(leftShift(return_number_bit_3, 3), leftShift(return_number_bit_2, 2)), bitwiseOR(leftShift(return_number_bit_1, 1), return_number_bit_0))
                        end
                        
                        if LASFile.attributes.NumberOfReturns then
                            local number_of_returns_bit_4 = getBit(point_data[5], 4)
                            local number_of_returns_bit_5 = getBit(point_data[5], 5)
                            local number_of_returns_bit_6 = getBit(point_data[5], 6)
                            local number_of_returns_bit_7 = getBit(point_data[5], 7)
                            NumberOfReturns = bitwiseOR(bitwiseOR(leftShift(number_of_returns_bit_7, 3), leftShift(number_of_returns_bit_6, 2)), bitwiseOR(leftShift(number_of_returns_bit_5, 1), number_of_returns_bit_4))
                        end
        
                        if LASFile.attributes.ClassificationFlagSynthetic then
                            local classification_flags_bit_0 = getBit(point_data[6], 0)
                            ClassificationFlagSynthetic = classification_flags_bit_0
                        end
        
                        if LASFile.attributes.ClassificationFlagKeyPoint then
                            local classification_flags_bit_1 = getBit(point_data[6], 1)
                            ClassificationFlagKeyPoint = classification_flags_bit_1
                        end
        
                        if LASFile.attributes.ClassificationFlagWithheld then
                            local classification_flags_bit_2 = getBit(point_data[6], 2)
                            ClassificationFlagWithheld = classification_flags_bit_2
                        end
        
                        if LASFile.attributes.ClassificationFlagOverlap then
                            local classification_flags_bit_3 = getBit(point_data[6], 3)
                            ClassificationFlagOverlap = classification_flags_bit_3
                        end
        
                        if LASFile.attributes.ScannerChannel then 
                            local scanner_channel_bit_4 = getBit(point_data[6], 4)
                            local scanner_channel_bit_5 = getBit(point_data[6], 5)
                            ScannerChannel = bitwiseOR(leftShift(scanner_channel_bit_5, 1), scanner_channel_bit_4)
                        end
        
                        if LASFile.attributes.ScanDirectionFlag then 
                            local scan_direction_flag_bit_6 = getBit(point_data[6], 6)
                            ScanDirectionFlag = scan_direction_flag_bit_6
                        end
        
                        if LASFile.attributes.EdgeOfFlightLine then 
                            local edge_of_flight_line_bit_7 = getBit(point_data[6], 7)
                            EdgeOfFlightLine = edge_of_flight_line_bit_7
                        end
        
                        if LASFile.attributes.Classification then 
                            local classification_bit_0 = getBit(point_data[7], 0)
                            local classification_bit_1 = getBit(point_data[7], 1)
                            local classification_bit_2 = getBit(point_data[7], 2)
                            local classification_bit_3 = getBit(point_data[7], 3)
                            local classification_bit_4 = getBit(point_data[7], 4)
                            Classification = bitwiseOR(bitwiseOR(bitwiseOR(bitwiseOR(leftShift(classification_bit_4, 4), leftShift(classification_bit_3, 3)), leftShift(classification_bit_2, 2)), leftShift(classification_bit_1, 1)), classification_bit_0)
                        end
        
                        if LASFile.attributes.Intensity then 
                            Intensity = point_data[4]
                        end
        
                        if LASFile.attributes.UserData then 
                            UserData = point_data[8]
                        end
        
                        if LASFile.attributes.ScanAngle then
                            ScanAngle = tonumber(point_data[9])*0.006
                        end
        
                        if LASFile.attributes.PointSourceID then
                            PointSourceID = point_data[10]
                        end
        
                        if LASFile.attributes.GPSTime then
                            GPSTime = point_data[11]
                        end
        
                        points[i] = {
                            X = xx,
                            Y = yy,
                            Z = zz,
                            ReturnNumber = tonumber(ReturnNumber),
                            NumberOfReturns = tonumber(NumberOfReturns),
                            ClassificationFlagSynthetic = tonumber(ClassificationFlagSynthetic),
                            ClassificationFlagKeyPoint = tonumber(ClassificationFlagKeyPoint),
                            ClassificationFlagWithheld = tonumber(ClassificationFlagWithheld),
                            ClassificationFlagOverlap = tonumber(ClassificationFlagOverlap),
                            ScannerChannel = tonumber(ScannerChannel),
                            ScanDirectionFlag = tonumber(ScanDirectionFlag),
                            EdgeOfFlightLine = tonumber(EdgeOfFlightLine),
                            Classification = tonumber(Classification),
                            Intensity = tonumber(Intensity),
                            UserData = tonumber(UserData),
                            ScanAngle = tonumber(ScanAngle),
                            PointSourceID = tonumber(PointSourceID),
                            GPSTime = tonumber(GPSTime),
                        }
                    end

                end

                local time = os.date("*t")
                print(("%02d:%02d:%02d"):format(time.hour, time.min, time.sec)," Finished collecting points!")
                file:close()
                return points
            else
                print("Error: LAS file does not intersect with the processing extent.")
                file:close()
                return
            end
        else
            print("Error: Processing extent was not defined correctly.")
            file:close()
            return
        end
    else
        print("Error: Processing extent was not defined correctly or completely.")
        file:close()
        return
    end
end

function LASFile.createVoxelizedHeightMap(points)
    local voxelMap = {}
    
    -- Filter points by classification (ground points)
    local groundPoints = {}
    for _, point in ipairs(points) do
        if point.Classification == 2 then
            table.insert(groundPoints, point)
        end
    end

    -- Find the bounding extent of the ground points
    local xmin, ymin, zmin = math.huge, math.huge, math.huge
    local xmax, ymax, zmax = -math.huge, -math.huge, -math.huge
    for _, point in ipairs(groundPoints) do
        xmin = math.min(xmin, point.X)
        ymin = math.min(ymin, point.Y)
        zmin = math.min(zmin, point.Z)
        xmax = math.max(xmax, point.X)
        ymax = math.max(ymax, point.Y)
        zmax = math.max(zmax, point.Z)
    end

    -- Calculate the dimensions of the voxel grid
    xdim = math.ceil(xmax - xmin) + 1
    ydim = math.ceil(ymax - ymin) + 1
    zdim = math.ceil(zmax - zmin) + 1

    -- Initialize the voxel map
    for x = 1, xdim do
        voxelMap[x] = {}
        for y = 1, ydim do
            voxelMap[x][y] = -math.huge
        end
    end

    -- Populate the voxel map with maximum z values
    for _, point in ipairs(groundPoints) do
        local x = math.floor(point.X - xmin) + 1
        local y = math.floor(point.Y - ymin) + 1
        voxelMap[x][y] = math.max(voxelMap[x][y], point.Z)
    end

    -- Fill nil ground values with Inverse Distance Weighted value
    for x = 1, xdim do
        for y = 1, ydim do
            if voxelMap[x][y] == -math.huge then
                voxelMap[x][y] = voxel_IDW(x, y, voxelMap)
            end
        end
    end

    return voxelMap, xdim, ydim, zdim
end

-- Define Voxel Inverse Distance Weighting (IDW) function
function voxel_IDW(x, y, voxelMap, radius)
    local totalWeight = 0
    local weightedSum = 0
    local distances = {}
    local radius = 15
    local k = 5

    -- Calculate distances to all other points within the fixed radius
    for nx = math.max(1, x - radius), math.min(#voxelMap, x + radius) do
        for ny = math.max(1, y - radius), math.min(#voxelMap[nx], y + radius) do
            local z = voxelMap[nx][ny]
            if z ~= -math.huge then
                local dx = x - nx
                local dy = y - ny
                local dist = math.sqrt(dx * dx + dy * dy)
                table.insert(distances, {dist, z})
            end
        end
    end

    -- Sort distances in ascending order
    table.sort(distances, function(a, b) return a[1] < b[1] end)

    -- Get the k-nearest neighbours
    local neighbours = {}
    for i = 1, math.min(k, #distances) do
        table.insert(neighbours, distances[i])
    end

    local weightedSum = 0
    local totalWeight = 0
    for i, neighbour in ipairs(neighbours) do
        local weight = 1 / neighbour[1] ^ 2
        if neighbour[2] then
            weightedSum = weightedSum + neighbour[2] * weight
            totalWeight = totalWeight + weight
        end
    end

    if totalWeight == 0 then
        return nil
    else
        return math.floor((weightedSum / totalWeight) + 0.5)
    end
end
