local const = require("constants");
require('common');
local chat = require('chat');
local imgui = require('imgui');
local func = T{};

func.emptyBucket = function(clammy, turnedIn, isReset)
    clammy.bucketSize = 50;
	clammy.weight = 0;
	clammy.money = 0;
	clammy.hasBucket = false
	clammy.showItemSeparator = false;

	for idx,citem in ipairs(clammy.items) do
		clammy.bucket[idx] = 0;
	end
	if (isReset == false) then
        if (Config.log[1] == true) and (Config.logAllResults[1] == false) then
            local file = func.openLogFile(clammy, turnedIn);
            for _,row in ipairs(clammy.trackingBucket) do
                if turnedIn == true then
                    clammy.sessionValue = clammy.sessionValue + row.gil;
                    if(row.vendor == true) then
                        clammy.sessionValueNPC = clammy.sessionValueNPC + row.gil;
                    else
                        clammy.sessionValueAH = clammy.sessionValueAH + row.gil;
                    end
                end
                local fdata = ('%s, %s, %s, %s, %s, %s\n'):fmt(
                    row.datetime,
                    row.item,
                    row.gil,
                    row.vendor,
                    row.moonPercent,
                    row.bucketsPurchased
                );
                file:write(fdata);
            end
            func.closeLogFile(file);
        end
    end

	clammy.trackingBucket = {};
	if Config.subtractBucketCostFromGilEarned[1] == true then
		clammy.trueSessionValue = clammy.sessionValue - (clammy.bucketsPurchased * 500);
	else
		clammy.trueSessionValue = clammy.sessionValue;
	end
	clammy.trueSessionValueNPC = clammy.sessionValueNPC;
	clammy.trueSessionValueAH = clammy.sessionValueAH;
	clammy = func.updateGilPerHour(clammy);
	if isReset == true then
		clammy.bucketAverageTime = 0;
	end
	return clammy;
end

func.writeBucket = function(clammy, item)
	local fdata = {
		datetime = os.date('%Y-%m-%d %H:%M:%S'),
		item = item.item,
		gil = item.gil[1],
		vendor = item.vendor[1],
		moonPercent = clammy.moonTable.moonPercent,
		bucketsPurchased = clammy.bucketsPurchased,
	}
	table.insert(clammy.trackingBucket, fdata);
	return clammy;
end

func.playSound = function(clammy)
	if (Config.tone[1] == true) and (clammy.playTone == true) then
		ashita.misc.play_sound(addon.path:append("clam.wav"));
		clammy.playTone = false;
	end
    return clammy;
end

func.updateGilPerHour = function(clammy)
	local now = os.clock();
	if ((now - clammy.startingTime) > 0) then
		clammy.gilPerHourMinusBucket = math.floor(clammy.trueSessionValue / ((now - clammy.startingTime) / 3600));
		clammy.gilPerHour = math.floor(clammy.sessionValue / ((now - clammy.startingTime) / 3600));
		clammy.gilPerHourNPC = math.floor(clammy.trueSessionValueNPC / ((now - clammy.startingTime) / 3600));
		clammy.gilPerHourAH = math.floor(clammy.trueSessionValueAH / ((now - clammy.startingTime) / 3600));
	end
	return clammy;
end

func.calculateTimePerBucket = function(clammy)
	local now = os.clock();
	local thisBucketTime = now - clammy.bucketStartTime;
	if clammy.bucketAverageTime == 0 then
		clammy.bucketAverageTime = thisBucketTime;
	else
		clammy.bucketAverageTime = (clammy.bucketAverageTime + thisBucketTime) / 2;
	end
	return clammy
end

func.calculateChanceOfBreak = function(clammy, remainingWeight)
	local sixWeightPercent = 0;
	local sevenWeightPercent = 0;
	local elevenWeightPercent = 0;
	local twentyWeightPercent = 0;
	for _, item in ipairs(Config.items) do
		if (item.weight == 20) then
			twentyWeightPercent = twentyWeightPercent + item.rarity[1];
		elseif (item.weight == 11) then
			elevenWeightPercent = elevenWeightPercent + item.rarity[1];
		elseif (item.weight == 7) then
			sevenWeightPercent = sevenWeightPercent + item.rarity[1];
		elseif (item.weight == 6) then
			sixWeightPercent = sixWeightPercent + item.rarity[1];
		end
	end
	local returnData = T{ };
	if remainingWeight < 3 then
	returnData = T {
			color = {1.0, 0.0, 0.0, 1.0},
			percentWeight = 100,
		}
	elseif remainingWeight < 6 then
		returnData = T {
			color = {1.0, 0.05, 0.0, 1.0},
			percentWeight = (twentyWeightPercent + elevenWeightPercent + sevenWeightPercent + sixWeightPercent),
		};
	elseif remainingWeight < 7 then
		returnData = T {
			color = {1.0, 0.32, 0.0, 1.0},
			percentWeight = (twentyWeightPercent + elevenWeightPercent + sevenWeightPercent),
		};
	elseif remainingWeight < 11 then
		returnData = T {
			color = {1.0, 0.98, 0.0, 1.0},
			percentWeight = (twentyWeightPercent + elevenWeightPercent),
		};
	elseif remainingWeight < 20 then
		returnData = T {
			color = {0.0, 1.0, 0.098, 1.0},
			percentWeight = twentyWeightPercent,
		};
	else
		returnData = T {
			color = {1.0, 1.0, 1.0, 1.0},
			percentWeight = 0,
		};
	end
	if (clammy.bucketSize == 200) then
		if (returnData.percentWeight == 100) then
			returnData.percentWeight = 100;
		else
			returnData.percentWeight = 1 - ((1 - returnData.percentWeight) * 0.95);
		end
	end
	if (returnData.percentWeight == 0) or (returnData.percentWeight == 100) then
		returnData.percentWeight = ("%0.0f"):fmt(returnData.percentWeight);
	else
		returnData.percentWeight = ("%.2f"):fmt(returnData.percentWeight * 100);
	end
	return returnData;
end

func.openLogFile = function(clammy, notBroken)
	if (ashita.fs.create_directory(clammy.fileDir) ~= false) then
        local file;
		if notBroken == false then
			file = io.open(clammy.filePathBroken, 'a');
		else
			file = io.open(clammy.filePath, 'a');
		end

		if (file == nil) then
			print("Clammy: Could not open log file.")
		else
			return file;
		end
	end
end

func.closeLogFile = function(file)
	if (file ~= nil) then
		io.close(file)
	end
end

func.writeLogFile = function(clammy, item)
	local file = func.openLogFile(clammy);

	if (file ~= nil) then
		local fdata = ('%s, %s %s\n'):fmt(os.date('%Y-%m-%d %H:%M:%S'), item.item, item.gil[1]);
		file:write(fdata);
	end

	func.closeLogFile(file);
end

func.renderEditor = function(clammy)
    if (not clammy.editorIsOpen[1]) then
        return clammy;
    end
    imgui.SetNextWindowSize({ 500, 495, });
    imgui.SetNextWindowSizeConstraints({ 0, 0, }, { FLT_MAX, FLT_MAX, });
    if (imgui.Begin('Clammy##Config', clammy.editorIsOpen)) then

        if (imgui.Button('Save Settings')) then
            Settings.save();
            print(chat.header(addon.name):append(chat.message('Settings saved.')));
        end
        imgui.SameLine();
        if (imgui.Button('Reset Settings')) then
            Settings.reset();
            print(chat.header(addon.name):append(chat.message('Settings reset to defaults.')));
        end
        imgui.SameLine();
        if (imgui.Button('Reset Session')) then
            clammy = func.resetSession(clammy);
            print(chat.header(addon.name):append(chat.message('Reset session.')));
        end

        imgui.Separator();

        if (imgui.BeginTabBar('##clammy_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
            if (imgui.BeginTabItem('General', nil)) then
                func.renderGeneralConfig();
                imgui.EndTabItem();
            end
            if (imgui.BeginTabItem('Items', nil)) then
                func.renderItemListConfig();
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end

    end
    imgui.End();
    return clammy;
end

func.renderGeneralConfig = function()
    imgui.Text('General Settings');
    imgui.BeginChild('settings_general', { 0, 375, }, true);
        imgui.Checkbox('Items in Bucket', Config.showItems);
        imgui.ShowHelp('Toggles whether items in current bucket should be shown.');
        imgui.Checkbox('Show Session Info', Config.showSessionInfo);
        imgui.ShowHelp('Toggles whether total clamming value, gil earned per hour, and buckets purchased should be shown.');
		imgui.Checkbox('Split gil/hr and total session value by Vendor/AH', Config.splitItemsBySellType);
		imgui.ShowHelp('Toggles whether session info should show split between items sold to vendor and items sold to AH.');
		imgui.Checkbox('Log Results', Config.log);
        imgui.ShowHelp('Toggles if Clammy should create a log file.');
        imgui.Checkbox('All Results', Config.logAllResults);
        imgui.ShowHelp('Deprecated: Ensures logs work exactly as they did in original version for compatibility.');
        imgui.Checkbox('Play Tone', Config.tone);
        imgui.ShowHelp('Toggles if Clammy should play a tone when you can clam again.');
        imgui.Checkbox('Track Moon Info', Config.trackMoonPhase);
        imgui.ShowHelp('Toggles if moon phase should be tracked and shown.');
        imgui.Checkbox('Set Weight Color Based On Value', Config.colorWeightBasedOnValue);
        imgui.ShowHelp('Toggles if the weight in the window should be based on value of the bucket.');
        imgui.Checkbox('No clammy outside the bay', Config.hideInDifferentZone);
        imgui.ShowHelp('Toggles if the clammy window should hide if not in Bibiki Bay.');
		imgui.Checkbox('Show Profit', Config.subtractBucketCostFromGilEarned);
		imgui.ShowHelp('Subtract cost of buckets from total clamming value amount.');
		imgui.Checkbox('Show Time per Bucket', Config.showAverageTimePerBucket);
		imgui.ShowHelp('Calculate and show average time per bucket received.');
		imgui.Checkbox('Show % chance bucket break', Config.showPercentChanceToBreak);
		imgui.ShowHelp('Calculates the chance that the next clamming attempt will break your bucket.');
		imgui.SetNextItemWidth(100);
		imgui.InputInt('High value amount', Config.highValue);
		imgui.ShowHelp('Indicates when bucket weight turns red at less than 20 ponze of space remaining.');
		imgui.SetNextItemWidth(100);
		imgui.InputInt('Medium value amount', Config.midValue);
		imgui.ShowHelp('Indicates when bucket weight turns red at less than 11 ponze of space remaining.');
		imgui.SetNextItemWidth(100);
		imgui.InputInt('Low value amount', Config.lowValue);
		imgui.ShowHelp('Indicates when bucket weight turns red at less than 7 ponze of space remaining.');
    imgui.EndChild();
end

func.renderItemListConfig = function()
    imgui.BeginChild("settings_items", {0, 375, }, true);
		imgui.Text('    Item Value:');
		imgui.ShowHelp('Set sale price of item.');
		imgui.SameLine();
		imgui.Text('                Vendor:')
		imgui.ShowHelp('Check whether to sell to a vendor or the AH.');
		imgui.Separator();
		imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[1].item .. '      ', Config.items[1].gil); -- Bibiki slug      -- 17
		imgui.SameLine();
		imgui.Checkbox(Config.items[1].item, Config.items[1].vendor);
		imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[2].item .. '    ', Config.items[2].gil); -- Bibiki urchin
		imgui.SameLine();
		imgui.Checkbox(Config.items[2].item, Config.items[2].vendor);
		imgui.SetNextItemWidth(100);
        imgui.InputInt('Bkn. willow rod  ', Config.items[3].gil); -- Broken willow fishing rod
		imgui.SameLine();
		imgui.Checkbox('Bkn. willow rod', Config.items[3].vendor, 'Bkn. willow rod');
		imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[4].item .. '   ', Config.items[4].gil); -- Coral fragment
		imgui.SameLine();
		imgui.Checkbox(Config.items[4].item, Config.items[4].vendor, Config.items[4].item);
		imgui.SetNextItemWidth(100);
        imgui.InputInt('H.Q. crab shell  ', Config.items[5].gil); -- Quality crab shell
        imgui.SameLine();
		imgui.Checkbox(Config.items[5].item, Config.items[5].vendor, 'H.Q. crab shell');
		imgui.SetNextItemWidth(100);
		imgui.InputInt(Config.items[6].item .. '       ', Config.items[6].gil); -- Crab shell
		imgui.SameLine();
		imgui.Checkbox(Config.items[6].item, Config.items[6].vendor, Config.items[6].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[7].item .. '  ', Config.items[7].gil); -- Elshimo coconut (Not in Horizon)
		imgui.SameLine();
		imgui.Checkbox(Config.items[7].item, Config.items[7].vendor, Config.items[7].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[8].item .. '          ', Config.items[8].gil); -- Elm log
		imgui.SameLine();
		imgui.Checkbox(Config.items[8].item, Config.items[8].vendor, Config.items[8].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[9].item .. '      ', Config.items[9].gil); -- Fish scales
		imgui.SameLine();
		imgui.Checkbox(Config.items[9].item, Config.items[9].vendor, Config.items[9].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[10].item .. '     ', Config.items[10].gil); -- Goblin armor
		imgui.SameLine();
		imgui.Checkbox(Config.items[10].item, Config.items[10].vendor, Config.items[10].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[11].item .. '      ', Config.items[11].gil); -- Goblin mail
		imgui.SameLine();
		imgui.Checkbox(Config.items[11].item, Config.items[11].vendor, Config.items[11].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[12].item .. '      ', Config.items[12].gil); -- Goblin mask
		imgui.SameLine();
		imgui.Checkbox(Config.items[12].item, Config.items[12].vendor, Config.items[12].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[13].item .. '  ', Config.items[13].gil); -- Hobgoblin bread
		imgui.SameLine();
		imgui.Checkbox(Config.items[13].item, Config.items[13].vendor, Config.items[13].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[14].item .. '    ', Config.items[14].gil); -- Hobgoblin pie
		imgui.SameLine();
		imgui.Checkbox(Config.items[14].item, Config.items[14].vendor, Config.items[14].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[15].item .. '     ', Config.items[15].gil); -- Igneous rock (Not on Horizon)
		imgui.SameLine();
		imgui.Checkbox(Config.items[15].item, Config.items[15].vendor, Config.items[15].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[16].item .. '         ', Config.items[16].gil); -- Jacknife
		imgui.SameLine();
		imgui.Checkbox(Config.items[16].item, Config.items[16].vendor, Config.items[16].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[17].item .. ' ', Config.items[17].gil); -- Lacquer tree log
		imgui.SameLine();
		imgui.Checkbox(Config.items[17].item, Config.items[17].vendor, Config.items[17].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[18].item .. '        ', Config.items[18].gil); -- Maple log
		imgui.SameLine();
		imgui.Checkbox(Config.items[18].item, Config.items[18].vendor, Config.items[18].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[19].item .. '       ', Config.items[19].gil); -- Nebimonite
		imgui.SameLine();
		imgui.Checkbox(Config.items[19].item, Config.items[19].vendor, Config.items[19].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[20].item .. '          ', Config.items[20].gil); -- Oxblood
		imgui.SameLine();
		imgui.Checkbox(Config.items[20].item, Config.items[20].vendor, Config.items[20].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[21].item .. '          ', Config.items[21].gil); -- Pamamas
		imgui.SameLine();
		imgui.Checkbox(Config.items[21].item, Config.items[21].vendor, Config.items[21].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[22].item .. '      ', Config.items[22].gil); -- Pamtam kelp
		imgui.SameLine();
		imgui.Checkbox(Config.items[22].item, Config.items[22].vendor, Config.items[22].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[23].item .. '           ', Config.items[23].gil); -- Pebble
		imgui.SameLine();
		imgui.Checkbox(Config.items[23].item, Config.items[23].vendor, Config.items[23].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[24].item .. '    ', Config.items[24].gil); -- Petrified log
		imgui.SameLine();
		imgui.Checkbox(Config.items[24].item, Config.items[24].vendor, Config.items[24].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt('H.Q. pugil Scls. ', Config.items[25].gil); -- Quality pugil scales
		imgui.SameLine();
		imgui.Checkbox('H.Q. pugil Scls.', Config.items[25].vendor, Config.items[25].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[26].item .. '     ', Config.items[26].gil); -- Pugil scales
		imgui.SameLine();
		imgui.Checkbox(Config.items[26].item, Config.items[26].vendor, Config.items[26].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[27].item .. '        ', Config.items[27].gil); -- Rock salt (Not on Horizon)
		imgui.SameLine();
		imgui.Checkbox(Config.items[27].item, Config.items[27].vendor, Config.items[27].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[28].item .. '         ', Config.items[28].gil); -- Seashell
		imgui.SameLine();
		imgui.Checkbox(Config.items[28].item, Config.items[28].vendor, Config.items[28].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[29].item .. '      ', Config.items[29].gil); -- Shall shell
		imgui.SameLine();
		imgui.Checkbox(Config.items[29].item, Config.items[29].vendor, Config.items[29].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[30].item .. ' ', Config.items[30].gil); -- Titanictus shell
		imgui.SameLine();
		imgui.Checkbox(Config.items[30].item, Config.items[30].vendor, Config.items[30].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[31].item .. '    ', Config.items[31].gil); -- Tropical clam
		imgui.SameLine();
		imgui.Checkbox(Config.items[31].item, Config.items[31].vendor, Config.items[31].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[32].item .. '     ', Config.items[32].gil); -- Turtle shell
		imgui.SameLine();
		imgui.Checkbox(Config.items[32].item, Config.items[32].vendor, Config.items[32].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[33].item .. '   ', Config.items[33].gil); -- Uragnite shell
		imgui.SameLine();
		imgui.Checkbox(Config.items[33].item, Config.items[33].vendor, Config.items[33].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[34].item .. '     ', Config.items[34].gil); -- Vongola clam
		imgui.SameLine();
		imgui.Checkbox(Config.items[34].item, Config.items[34].vendor, Config.items[34].item);
        imgui.SetNextItemWidth(100);
        imgui.InputInt(Config.items[35].item .. '       ', Config.items[35].gil); -- White sand
		imgui.SameLine();
		imgui.Checkbox(Config.items[35].item, Config.items[35].vendor, Config.items[35].item);
    imgui.EndChild();
end

func.resetSession = function(clammy)
	clammy.startingTime = os.clock();
	clammy.fileName = ('log_%s.txt'):fmt(os.date('%Y_%m_%d__%H_%M_%S'));
	clammy.filePathBroken =('log_broken_%s.txt'):fmt(os.date('%Y_%m_%d__%H_%M_%S'));
	clammy.filePath = clammy.fileDir .. clammy.fileName;
	clammy = func.emptyBucket(clammy, false, true);
	clammy.gilPerHour = 0;
	clammy.gilPerHourMinusBucket = 0;
	clammy.gilPerHourAH = 0;
	clammy.gilPerHourNPC = 0;
	clammy.bucketsPurchased = 0;
	clammy.bucketsReceived = 0;
	clammy.sessionValue = 0;
	clammy.sessionValueAH = 0;
	clammy.sessionValueNPC = 0;
	clammy.bucketIsBroke = false;
	return clammy;
end

func.formatInt = function(number)
    if (string.len(number) < 4) then
        return number
    end
    if (number ~= nil and number ~= '' and type(number) == 'number') then
        local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)');

        -- we sometimes get a nil int from the above tostring, just return number in those cases
        if (int == nil) then
            return number
        end

        -- reverse the int-string and append a comma to all blocks of 3 digits
        int = int:reverse():gsub("(%d%d%d)", "%1,");
  
        -- reverse the int-string back remove an optional comma and put the 
        -- optional minus and fractional part back
        return minus .. int:reverse():gsub("^,", "") .. fraction;
    else
        return 'NaN';
    end
end

func.getTimestamp = function()
    local pVanaTime = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0, 0);
    local pointer = ashita.memory.read_uint32(pVanaTime + 0x34);
    local rawTime = ashita.memory.read_uint32(pointer + 0x0C) + 92514960;
    local timestamp = {};
    timestamp.day = math.floor(rawTime / 3456);
    timestamp.hour = math.floor(rawTime / 144) % 24;
    timestamp.minute = math.floor((rawTime % 144) / 2.4);
    return timestamp;
end

func.getMoon = function(clammy)
    local timestamp = func.getTimestamp();
    local moonIndex = ((timestamp.day + 26) % 84) + 1;
    if (moonIndex < 43) then
		clammy.moonTable.moonPercent = const.moonPhasePercent[moonIndex]  * -1;
	else
		clammy.moonTable.moonPercent = const.moonPhasePercent[moonIndex];
	end
    clammy.moonTable.moonPhase = const.moonPhase[moonIndex];
    return clammy;
end

func.formatTimestamp = function(timer)
    local hours = math.floor(timer / 3600);
    local minutes = math.floor((timer / 60) - (hours * 60));
    local seconds = math.floor(timer - (hours * 3600) - (minutes * 60));

    return ('%0.2i:%0.2i:%0.2i'):fmt(hours, minutes, seconds);
end

func.toggleShowValue = function(shouldShowValue)
	if (shouldShowValue == "true") or (shouldShowValue == nil and Config.showValue[1] == false) then
		Config.showValue[1] = true;
		print(chat.header(addon.name):append(chat.message('Show value turned on.')));
	else
		Config.showValue[1] = false;
		print(chat.header(addon.name):append(chat.message('Show value turned off.')));
	end
	Settings.save();
end

func.toggleLogAllResults = function(shouldLogAllResults)
	if (shouldLogAllResults == "true") or
        (shouldLogAllResults == nil and Config.logAllResults[1] == false) then
		Config.logAllResults[1] = true;
		print(chat.header(addon.name):append(chat.message('Logging all items.')));
	elseif(shouldLogAllResults == "false") or
        (shouldLogAllResults == nil and Config.logAllResults[1] == true) then
		Config.logAllResults[1] = false;
		print(chat.header(addon.name):append(chat.message('Logging only items actually received.')));
	end

	Settings.save();
end

func.toggleShowSessionInfo = function(shouldShowSessionInfo)
	if (shouldShowSessionInfo == "true") or (shouldShowSessionInfo == nil and Config.showSessionInfo[1] == false) then
		Config.showSessionInfo[1] = true;
		print(chat.header(addon.name):append(chat.message('Showing gil earned and gil per hour.')));
	elseif(shouldShowSessionInfo == "false") or (shouldShowSessionInfo == nil and Config.showSessionInfo[1] == true) then
		Config.showSessionInfo[1] = false;
		print(chat.header(addon.name):append(chat.message('Not showing gil earned and gil per hour.')));
	end

	Settings.save();
end

func.toggleUseBucketValueForWeightColor = function(shouldUseBucketValueForWeightColor)
	if (shouldUseBucketValueForWeightColor == 'true') or
        (shouldUseBucketValueForWeightColor == nil and Config.colorWeightBasedOnValue[1] == false) then
		Config.colorWeightBasedOnValue[1] = true;
		print(chat.header(addon.name):append(chat.message('Bucket weight color based on value of items in bucket.')));

	elseif (shouldUseBucketValueForWeightColor == 'false') or
         (shouldUseBucketValueForWeightColor == nil and Config.colorWeightBasedOnValue[1] == true) then
		Config.colorWeightBasedOnValue[1] = false;
		print(chat.header(addon.name):append(chat.message('Bucket weight color based on odds of breaking bucket.')));
	end

	Settings.save();
end

func.setWeightValues = function(weightLevel, value)
	if(weightLevel == 'highvalue') then
		Config.highValue[1] = tonumber(value);
		HighValue = tonumber(value);
		print(chat.header(addon.name):append(chat.message(('highvalue setweightvalues set to %s.'):fmt(Config.highValue[1]))));
	elseif (weightLevel == 'midvalue') then
		Config.midValue[1] = tonumber(value);
		MidValue = tonumber(value);
		print(chat.header(addon.name):append(chat.message(('midvalue setweightvalues set to %s.'):fmt(Config.midValue[1]))));
	elseif (weightLevel == 'lowvalue') then
		Config.lowValue[1] = tonumber(value);
		LowValue = tonumber(value);
		print(chat.header(addon.name):append(chat.message(('lowvalue setweightvalues set to %s.'):fmt(Config.lowValue[1]))));
	elseif (weightLevel == 'showvalues') then
		print(chat.header(addon.name):append(chat.message(('Low value is set to %s.'):fmt(Config.lowValue[1]))));
		print(chat.header(addon.name):append(chat.message(('Mid value is set to %s.'):fmt(Config.midValue[1]))));
		print(chat.header(addon.name):append(chat.message(('High value is set to %s.'):fmt(Config.highValue[1]))));
	else
		print(chat.header(addon.name):append(chat.message('Invalid setweightvalues parameter passed.')));
	end

	Settings.save();
end

func.toggleShowItems = function(shouldShowItems)
	if (shouldShowItems == "true") or
        (shouldShowItems == nil and Config.showItems[1] == false) then
		Config.showItems[1] = true;
		print(chat.header(addon.name):append(chat.message('Show items turned on.')));
	elseif (shouldShowItems == "false") or
        (shouldShowItems == nil and Config.showItems[1] == true) then
		Config.showItems[1] = false;
		print(chat.header(addon.name):append(chat.message('Show items turned off.')));
	end

	Settings.save();
end

func.toggleLogItems = function(shouldLogItems)
	if (shouldLogItems == "true") or (shouldLogItems == nil and Config.log[1] == false) then
		Config.log[1] = true;
		print(chat.header(addon.name):append(chat.message('Logging items turned on.')));
	elseif (shouldLogItems == "false") or (shouldLogItems == nil and Config.log[1] == true) then
		Config.log[1] = false;
		print(chat.header(addon.name):append(chat.message('Logging items turned off.')));
	end

	Settings.save();
end

func.togglePlayTone = function(shouldPlayTone)
	if (shouldPlayTone == "true") or (shouldPlayTone == nil and Config.tone[1] == false) then
		Config.tone[1] = true;
		print(chat.header(addon.name):append(chat.message('Play tone turned on.')));
	elseif (shouldPlayTone == "false") or (shouldPlayTone == nil and Config.tone[1] == true) then
		Config.tone[1] = false;
		print(chat.header(addon.name):append(chat.message('Play tone turned off.')));
	end

	Settings.save();
end

func.toggleTrackMoon = function(shouldShowMoon)
    if (shouldShowMoon == "true") or (shouldShowMoon == nil and Config.trackMoonPhase[1] == false) then
        Config.trackMoonPhase[1] = true;
        print(chat.header(addon.name):append(chat.message('Display Moon turned on.')));
    elseif (shouldShowMoon == "false") or (shouldShowMoon == nil and Config.trackMoonPhase == true) then
        Config.trackMoonPhase[1] = false;
        print(chat.header(addon.name):append(chat.message('Display Moon turned off.')));
    end

    Settings.save();
end

func.handleChatCommands = function(args, clammy)
    if (#args == 1) then
		clammy.editorIsOpen[1] = true;
        return clammy;
	end

    if (#args == 2 and args[2]:any('reset')) then --manually empty the bucket
		clammy = func.emptyBucket(clammy, false, true);
		print(chat.header(addon.name):append(chat.message('Bucket reset.')));
        return clammy;
    end

	if (#args == 2 and args[2]:any('resetsession')) then
		clammy = func.resetSession(clammy);
		print(chat.header(addon.name):append(chat.message('Session reset.')));
		return clammy;
	end

    if (#args == 3 and args[2]:any('weight')) then --manually overide the bucket's weight
        clammy.weight = tonumber(args[3]);
		print(chat.header(addon.name):append(chat.message(('Weight manually set to %s.'):fmt(clammy.weight))));
        return clammy;
    end

    if (args[2]:any('showvalue')) then --turns loggin on/off
        func.toggleShowValue(args[3])
        return clammy;
    end

	if(args[2]:any('logbrokenbucketitems')) then
		func.toggleLogAllResults(args[3]);
        return clammy;
	end

	if(args[2]:any('showsessioninfo')) then
		func.toggleShowSessionInfo(args[3]);
        return clammy;
	end

	if(args[2]:any('usebucketvalueforweightcolor')) then
		func.toggleUseBucketValueForWeightColor(args[3]);
		return clammy;
	end

	if(args[2]:any('setweightvalues')) then
		func.setWeightValues(args[3], args[4]);
		return clammy;
	end

	if (#args == 3 and args[2]:any('showitems')) then --turns loggin on/off
        func.toggleShowItems(args[3]);
        return clammy;
    end

	if (#args == 3 and args[2]:any('log')) then --turns loggin on/off
       func.toggleLogItems(args[3]);
        return clammy;
    end

	if (#args == 3 and args[2]:any('tone')) then --turns ready tone on/off
        func.togglePlayTone(args[3]);
        return clammy;
    end

    print(chat.header(addon.name):append(chat.message('Invalid command passed, try /clammy for config menu.')));
    return clammy;
end

func.handleTextIn = function(e, clammy)

    local weightColor = {
        {diff=200, color={1.0, 1.0, 1.0, 1.0}},
        {diff=35, color={1.0, 1.0, 0.8, 1.0}},
        {diff=20, color={1.0, 1.0, 0.4, 1.0}},
        {diff=11, color={1.0, 1.0, 0.0, 1.0}},
        {diff=7, color={1.0, 0.6, 0.0, 1.0}},
        {diff=6, color={1.0, 0.4, 0.0, 1.0}},
        {diff=3, color={1.0, 0.3, 0.0, 1.0}},
    }

    if (string.match(e.message, "You return the")) then
		clammy = func.emptyBucket(clammy, true, false);
		clammy.bucketColor = {1.0, 1.0, 1.0, 1.0};
		clammy = func.calculateTimePerBucket(clammy);
		return clammy;
	end

	if (string.match(e.message, "Obtained key item:")) then
		clammy.bucketsPurchased = clammy.bucketsPurchased + 1;
		clammy.bucketsReceived = clammy.bucketsReceived + 1;
		clammy.hasBucket = true;
		clammy.bucketIsBroke = false;
		clammy.bucketStartTime = os.clock();
        return clammy;
	end

	--Your clamming capacity has increased to XXX ponzes!
	if (string.match(e.message, "Your clamming capacity has increased to")) then
		clammy.bucketSize = clammy.bucketSize + 50;
		clammy.bucketsReceived = clammy.bucketsReceived + 1;
		clammy.bucketColor = {1.0, 1.0, 1.0, 1.0};
		clammy = func.calculateTimePerBucket(clammy);
		clammy.bucketStartTime = os.clock();
		return clammy;
	end

	if (string.match(e.message, "All your shellfish are washed back into the sea")) then
		clammy = func.emptyBucket(clammy, false, false);
		clammy.bucketIsBroke = true;
		clammy.bucketColor = {1.0, 1.0, 1.0, 1.0};
		clammy = func.calculateTimePerBucket(clammy);
		return clammy;
	end

	if (string.match(e.message, "You find a")) then
		for idx,citem in ipairs(clammy.items) do
			if (string.match(string.lower(e.message), string.lower(citem.item)) ~= nil) then
				clammy = func.writeBucket(clammy, citem);
				clammy.weight = clammy.weight + citem.weight;
				clammy.money = clammy.money + citem.gil[1];
				clammy.bucket[idx] = clammy.bucket[idx] + 1;
				clammy.cooldown =  os.clock() + 10.5;

				if Config.colorWeightBasedOnValue[1] == false then
					for _, item in ipairs(weightColor) do
						if ((clammy.bucketSize - clammy.weight) < item.diff) then
							clammy.bucketColor = item.color;
						end
					end
				else
					local relativeWeight = clammy.bucketSize - clammy.weight;
					if  (relativeWeight < 6) or
						(clammy.money >= clammy.lowValue and relativeWeight < 7) or
						(clammy.money >= clammy.midValue and relativeWeight < 11) or
						(clammy.money >= clammy.highValue and relativeWeight < 20) or
						(clammy.weight > 130) then
						clammy.bucketColor = {1.0, 0.1, 0.0, 1.0};
					else
						clammy.bucketColor = {1.0, 1.0, 1.0, 1.0};
					end
				end

				clammy.playTone = true;

				if (Config.log[1] == true) and (Config.logAllResults[1] == true) then
					clammy.writeLogFile(citem);
				end

				return clammy;
			end
		end
	end
    return clammy;
end

func.renderClammy = function(clammy)
	local windowSize = 300;
    imgui.SetNextWindowBgAlpha(0.8);
    imgui.SetNextWindowSize({ windowSize, -1, }, ImGuiCond_Always);

	if (imgui.Begin('Clammy', true, bit.bor(ImGuiWindowFlags_NoDecoration))) then

		if (clammy.hasBucket == true) then
			imgui.TextColored({0.0, 1.0, 0.0, 1.0}, "Bucket")
		elseif(clammy.bucketIsBroke == true) then
			imgui.TextColored({0.1, 0.1, 0.1, 1.0}, "Bucket")
		else
			imgui.TextColored({0.9, 0.9, 0.0, 1.0}, "Bucket")
		end
		if (Config.trackMoonPhase[1] == true) then
			clammy = func.getMoon(clammy);
		end
		imgui.SameLine()
		imgui.Text("Weight [" .. clammy.bucketSize .. "]:");
		imgui.SameLine();
		imgui.SetWindowFontScale(1.3);
		imgui.SetCursorPosY(imgui.GetCursorPosY()-2);
		imgui.TextColored(clammy.bucketColor, tostring(clammy.weight));
		imgui.SetWindowFontScale(1.0);
		imgui.SameLine();
		imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x - imgui.CalcTextSize("[999]"));
		local cdTime = math.floor(clammy.cooldown - os.clock());
		if (cdTime <= 0) then
			imgui.TextColored({ 0.5, 1.0, 0.5, 1.0 }, "  [*]");
			clammy = func.playSound(clammy);
		else
			imgui.TextColored({ 1.0, 1.0, 0.5, 1.0 }, "  [" .. cdTime .. "]");
		end
		if (Config.showPercentChanceToBreak[1] == true) then
			local bucketBreakChance = func.calculateChanceOfBreak(clammy, (clammy.bucketSize - clammy.weight));
			imgui.Text("Percent chance to break: "); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Percent chance to break:  ")); imgui.SetWindowFontScale(1.3); imgui.SetCursorPosY(imgui.GetCursorPosY()-2);
			imgui.TextColored(bucketBreakChance.color, bucketBreakChance.percentWeight); imgui.SameLine(); imgui.SetWindowFontScale(1.0); imgui.SetCursorPosY(imgui.GetCursorPosY()+2);
			if (string.len(bucketBreakChance.percentWeight) == 1) then
				imgui.SetCursorPosX(imgui.CalcTextSize("Percent chance to break:   " .. bucketBreakChance.percentWeight));
			elseif (string.len(bucketBreakChance.percentWeight) == 3) then
				imgui.SetCursorPosX(imgui.CalcTextSize("Percent chance to break:    " .. bucketBreakChance.percentWeight));
			elseif (string.len(bucketBreakChance.percentWeight) == 4) then
				imgui.SetCursorPosX(imgui.CalcTextSize("Percent chance to break:    " .. bucketBreakChance.percentWeight));
			elseif (string.len(bucketBreakChance.percentWeight) == 5) then
				imgui.SetCursorPosX(imgui.CalcTextSize("Percent chance to break:    " .. bucketBreakChance.percentWeight));
			end
			imgui.Text("%");
		end
		if (Config.showValue[1] == true) then
			imgui.Text("Estimated Value: " .. func.formatInt(clammy.money));
		end

		local textColor = {0.0, 0.75, 0.60, 1};
		if (Config.showSessionInfo[1] == true) then
			if Config.subtractBucketCostFromGilEarned[1] == true then
				clammy.trueSessionValue = clammy.sessionValue - (clammy.bucketsPurchased * 500);
			else
				clammy.trueSessionValue = clammy.sessionValue
			end
			clammy.trueSessionValueNPC = clammy.sessionValueNPC;
			clammy.trueSessionValueAH = clammy.sessionValueAH;
			imgui.Separator();
			if(Config.subtractBucketCostFromGilEarned[1] == true) then
				imgui.Text("Gil made"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Gil made  "));
				imgui.TextColored(textColor,"(Profit)"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Gil made  (Profit)"));
				imgui.Text(":"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "));
				imgui.Text("".. func.formatInt(clammy.sessionValue)); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   " .. func.formatInt(clammy.sessionValue) .. " "));
				imgui.TextColored(textColor, "(" .. func.formatInt(clammy.trueSessionValue) .. ")");
			else
				imgui.Text("Gil made: "); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "));
				imgui.Text("" .. func.formatInt(clammy.trueSessionValue));
			end

			if (Config.splitItemsBySellType[1] == true) then
				imgui.Text("Total gil earned(NPC): "); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "));
				imgui.Text("" .. func.formatInt(clammy.trueSessionValueNPC));
				imgui.Text("Total gil earned(AH): "); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "));
				imgui.Text("" .. func.formatInt(clammy.trueSessionValueAH));
			end
			if(Config.subtractBucketCostFromGilEarned[1] == true) then
				imgui.Text("Gil/hr"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Gil/hr  "));
				imgui.TextColored(textColor, "(Profit)"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Gil/hr  (Profit)"));
				imgui.Text(":"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "));
				imgui.Text(""  .. func.formatInt(clammy.gilPerHour)) imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "   .. func.formatInt(clammy.gilPerHour) .. " "));
				imgui.TextColored(textColor, "(" .. func.formatInt(clammy.gilPerHourMinusBucket) .. ")");
			else
				imgui.Text("Gil/hr: "); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "));
				imgui.Text("" .. func.formatInt(clammy.gilPerHour));
			end
			if (Config.splitItemsBySellType[1] == true) then
				imgui.Text("Gil/hr(NPC): "); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "));
				imgui.Text("" .. func.formatInt(clammy.gilPerHourNPC));
				imgui.Text("Gil/hr(AH): "); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Total gil earned(NPC):   "));
				imgui.Text("" .. func.formatInt(clammy.gilPerHourAH));
			end
			imgui.Separator();

			if (Config.subtractBucketCostFromGilEarned[1] == true) then
				local bucketCost = clammy.bucketsPurchased * 500;
				imgui.Text("Buckets"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Buckets "));
				imgui.TextColored(textColor, "(Bought)(Spent)"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Buckets (Bought)(Spent)"));
				imgui.Text(": " .. clammy.bucketsReceived); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Buckets  Bought)(Gil):    " .. clammy.bucketsReceived));
				imgui.TextColored(textColor, "(".. func.formatInt(clammy.bucketsPurchased) .. ")(" .. func.formatInt(bucketCost) .. ")");
			else

				imgui.Text("Buckets : "); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Buckets  (Gil spent):   "));
				imgui.Text("" .. clammy.bucketsPurchased);
			end
			local now = os.clock();
			imgui.Text("Session length:"); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Buckets (Bought)(Spent): "));
			imgui.Text("".. func.formatTimestamp(now - clammy.startingTime))
			if Config.showAverageTimePerBucket[1] == true then
				imgui.Text('Avg time/bucket:'); imgui.SameLine(); imgui.SetCursorPosX(imgui.CalcTextSize("Buckets (Bought)(Spent): "));
				imgui.Text('' .. func.formatTimestamp(clammy.bucketAverageTime));
			end
		end
		if (Config.trackMoonPhase[1] == true) then
			imgui.Separator();
			imgui.Text("Current moon phase is: " .. clammy.moonTable.moonPhase);
			imgui.Text("Current moon phase percentage is: " .. clammy.moonTable.moonPercent .. "%");
		end

		if (Config.showItems[1] == true) then
			if clammy.showItemSeparator == true then
				imgui.Separator();
			end
			for idx,citem in ipairs(clammy.items) do
				if (clammy.bucket[idx] ~= 0) then
					clammy.showItemSeparator = true;
					imgui.Text(" - " .. clammy.items[idx].item .. " [" .. clammy.bucket[idx] .. "]");
					imgui.SameLine();
					local valTxt = "(" .. func.formatInt(clammy.items[idx].gil[1] * clammy.bucket[idx]) .. ")"
					local x, _  = imgui.CalcTextSize(valTxt);
					imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - x - imgui.GetStyle().FramePadding.x);
					imgui.Text(valTxt);

				end
			end
		end
    end
    imgui.End();
	return clammy;
end

return func;