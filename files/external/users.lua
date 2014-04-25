--[[

	This file is part of HiT Hi FiT Hai's PtokaX scripts

	Copyright: © 2014 HiT Hi FiT Hai group
	Licence: GNU General Public Licence v3 https://www.gnu.org/licenses/gpl-3.0.html

--]]

package.path = Core.GetPtokaXPath().."scripts/files/dependency/?.lua;"..package.path
local Connection = require 'config'
local tSettings = {
	sBotName = SetMan.GetString( 21 ),
	sAsBot = "<"..(SetMan.GetString(21) or "PtokaX").."> ",
	tProfileName = {
		[-1] = "Unregistered",
		[0] = "Admin/Master",
		[1] = "Gods",
		[2] = "Operators",
		[3] = "VIP",
		[4] = "Moderator",
		[5] = "Registered",
		[6] = "sVIP",
		[7] = "Gymkhana",
	},
}

local function FilterData( tInput, bLogOut )
	tInput.sDate, tInput.sNick = ( tInput.sDate and ("'%s'"):format(tInput.sDate) ) or "NOW()", SQLCon:escape( tInput.sNick )
	if bLogOut then
		return tInput
	end
	tInput.sTag, tInput.sClient = SQLCon:escape( tInput.sTag ), SQLCon:escape( tInput.sClient )
	tInput.sEmail, tInput.sDescription = ( tInput.sEmail and ("'%s'"):format(SQLCon:escape(tInput.sEmail)) ) or "NULL", ( tInput.sDescription and ("'%s'"):format(SQLCon:escape(tInput.sDescription)) ) or "NULL"
	return tInput
end

tFunction = {
	Connect = function()
		local luasql
		if not luasql then
			luasql = require "luasql.mysql"
		end
		if not SQLEnv then
			_G.SQLEnv = assert( luasql.mysql() )
			_G.SQLCon = assert( SQLEnv:connect(Connection 'ptokax') )
		end
	end,

	GetSize = function( iSize )
		local iSizeTemp, sPrefix, i = tonumber(iSize) or 0, {"", "Ki", "Mi", "Gi", "Ti", "Pi"}, 1
		while iSizeTemp > 1024 do
			iSizeTemp, i = iSizeTemp/1024, i + 1
		end
		return string.format( "%.2f %sB", iSizeTemp, sPrefix[i] )
	end,

	LogIn = function( tInput )
		tInput = FilterData( tInput )
		local sQuery = [[INSERT INTO `ipstats` (`ip`, `last_used`)
			VALUES ( '%s', %s )
			ON DUPLICATE KEY UPDATE
				`online` = 'y',
				`last_used` = %s,
				`id` = LAST_INSERT_ID(`id`) ]]
		local SQLCur = assert( SQLCon:execute(sQuery:format(tInput.sIP, tInput.sDate, tInput.sDate)) )
		tInput.iIPId = SQLCon:getlastautoid()
		sQuery = [[INSERT INTO `ipstats_nicks` (`ipstats_id`, `nick`, `last_used`)
			VALUES ( %d, '%s', %s )
			ON DUPLICATE KEY
			UPDATE `last_used` = %s,
				`online` = 'y',
				`used_times` = `used_times` + 1 ]]
		SQLCur = assert( SQLCon:execute(sQuery:format(tInput.iIPId, tInput.sNick, tInput.sDate, tInput.sDate)) )
		sQuery = [[INSERT INTO `nickstats`
			(`nick`, `mode`, `description`, `email`,
			`sharesize`, `profile`, `tag`, `client`,
			`hubs`, `slots`, `last_used`)
			VALUES ( '%s', '%s', %s, %s, '%s', %d, '%s', '%s', %d, %d, %s )
			ON DUPLICATE KEY
			UPDATE `last_used` = %s,
				`online` = 'y',
				`mode` = '%s',
				`description` = %s,
				`email` = %s,
				`sharesize` = '%s',
				`profile` = %d,
				`hubs` = %d,
				`slots` = '%d',
				`tag` = '%s',
				`client` = '%s',
				`id` = LAST_INSERT_ID(`id`) ]]
		SQLCur = assert( SQLCon:execute(sQuery:format(tInput.sNick, tInput.sMode, tInput.sDescription, tInput.sEmail, tInput.iShare, tInput.iProfile, tInput.sTag, tInput.sClient, tInput.iHubs, tInput.iSlots, tInput.sDate, tInput.sDate, tInput.sMode, tInput.sDescription, tInput.sEmail, tInput.iShare, tInput.iProfile, tInput.iHubs, tInput.iSlots, tInput.sTag, tInput.sClient)) )
		tInput.iNickId = SQLCon:getlastautoid()
		sQuery= [[INSERT INTO `nickstats_login` (`nickstats_id`, `ip`, `login`)
			VALUES ( %d, '%s', %s ) ]]
		SQLCur = assert( SQLCon:execute(sQuery:format(tInput.iNickId, tInput.sIP, tInput.sDate)) )
	end,

	LogOut = function( tInput )
		tInput = FilterData( tInput, true )
		local sQuery = [[UPDATE `ipstats`
			SET `online`='n',
				`last_used` = NOW(),
				`id` = LAST_INSERT_ID(`id`)
			WHERE `ip` = '%s'
			LIMIT 1]]
		SQLCur = assert( SQLCon:execute(sQuery:format(tInput.sIP)) )
		tInput.iIPId = SQLCon:getlastautoid()

		sQuery = [[UPDATE `ipstats_nicks`
			SET `online` = 'n',
				`last_used` = NOW()
			WHERE `ipstats_id` = %d
				AND `nick` = '%s' ]]
		SQLCur = assert( SQLCon:execute(sQuery:format(tInput.iIPId, tInput.sNick)) )

		sQuery = [[UPDATE `nickstats`
			SET `online`='n',
				`last_used` = NOW(),
				`id` = LAST_INSERT_ID(`id`)
			WHERE `nick` = '%s'
			LIMIT 1;]]
		SQLCur = assert( SQLCon:execute(sQuery:format(tInput.sNick)) )
		tInput.iNickId = SQLCon:getlastautoid()

		sQuery = [[UPDATE `nickstats_login`
			SET `logout` = NOW()
			WHERE `nickstats_id` = %d
				AND `ip` = '%s'
			ORDER BY `login` DESC
			LIMIT 1 ]]
		SQLCur = assert( SQLCon:execute(sQuery:format(tInput.iNickId, tInput.sIP)) )
	end,
}

tCommands = {
	ui = function( sNick, sFrom )
		local sNick, iNum = sNick:gsub( "%*", "%%" )
		if iNum == 0 then sNickQuery = "='%s' "
		else sNickQuery = " LIKE '%s' " end
		local sQuery = [[SELECT *
				FROM `nickstats`
				WHERE `nick`]]..sNickQuery..[[
				LIMIT 5 ]]
		sQuery = string.format( sQuery, SQLCon:escape(sNick) )
		Cur = assert( SQLCon:execute(sQuery) )
		tRowUser = Cur:fetch( {}, "a" )
		while tRowUser do
			sIPQuery = [[SELECT `ip`, `login`, `logout`
				FROM `nickstats_login`
				WHERE `nickstats_id`=%d
				ORDER BY `login` DESC
				LIMIT 25 ]]
			sIPQuery = string.format( sIPQuery, tonumber(tRowUser.id) )
			CurIP = assert( SQLCon:execute(sIPQuery) )
			tRowIP = CurIP:fetch( {}, "a" )
			local sCompleteUserData = "\n"..string.rep("-",100).."\n&#124; Showing information on: "..tRowUser.nick.." \n"..string.rep("-",100).."\n"
			sCompleteUserData = sCompleteUserData.."&#124; General Information:\n&#124;  User: "..tRowUser.nick
			if tRowUser.online == "y" and Core.GetUser(tRowUser.nick) then
				sCompleteUserData = sCompleteUserData..string.rep(" ", 8).."(Online)\n&#124;  IP: "..tRowIP.ip.."\n"
			elseif tRowUser.online == "n" then
				sCompleteUserData = sCompleteUserData..string.rep(" ", 8).."(Offline since "..tRowUser.last_used..")\n"
			end
			sCompleteUserData = sCompleteUserData.."&#124;  Profile: "..tSettings.tProfileName[tonumber(tRowUser.profile)].."\n"
			if tRowUser.email then
				sCompleteUserData = sCompleteUserData.."&#124;  Email: "..tRowUser.email.."\n"
			end if tRowUser.description then
				sCompleteUserData = sCompleteUserData.."&#124;  Description: "..tRowUser.description.."\n"
			end
			sCompleteUserData = sCompleteUserData.."&#124;  Mode: "..tRowUser.mode.."\n\n"
			sCompleteUserData = sCompleteUserData.."&#124;  Sharesize: "..tFunction.GetSize(tRowUser.sharesize).." (Exact Share: "..tRowUser.sharesize.." B)\n"
			sCompleteUserData = sCompleteUserData.."&#124;  Tag: "..tRowUser.tag.."\n"
			sCompleteUserData = sCompleteUserData.."&#124;  Client: "..tRowUser.client.."\n"
			sCompleteUserData = sCompleteUserData.."&#124;  Slots: "..tRowUser.slots.."\n\n&#124; IP History:\n"
			while tRowIP do
				sCompleteUserData = sCompleteUserData..string.format("&#124;  %s          From: %s          To: %s\n", tRowIP.ip, tRowIP.login, tRowIP.logout or "Still connected")
				tRowIP = CurIP:fetch( {}, "a" )
			end
			CurIP:close()
			Core.SendPmToNick( sFrom, tSettings.sBotName, sCompleteUserData )
			tRowUser = Cur:fetch( {}, "a" )
		end
	end,

	ii = function( sIP, sFrom )
		local sCompleteUserData = "\n"..string.rep("-",100).."\n~ Showing information for: "..sIP
		local sIP, iNum = sIP:gsub( "%*", "%%" )
		if iNum == 0 then sIPQuery = "='%s' "
		else sIPQuery = " LIKE '%s' " end
		local sQuery = [[SELECT *
				FROM `ipstats`
				WHERE `ip`]]..sIPQuery..[[
				LIMIT 200 ]]
		sQuery = string.format( sQuery, SQLCon:escape(sIP) )
		Cur = assert( SQLCon:execute(sQuery) )
		tRowIP = Cur:fetch( {}, "a" )
		sCompleteUserData = sCompleteUserData.." \n~ Total results found were "..tostring( Cur:numrows() ).." (Limit 200)\n"..string.rep("-",100).."\n"
		while tRowIP do
			sQueryIPStats = [[SELECT `nick`, `used_times`, `last_used`
				FROM `ipstats_nicks`
				WHERE `ipstats_id` = %d
				ORDER BY `used_times` DESC
				LIMIT 2 ]]
			sQueryIPStats = string.format( sQueryIPStats, tonumber(tRowIP.id) )
			CurIP = assert( SQLCon:execute(sQueryIPStats) )
			tRowIPStats = CurIP:fetch( {}, "a" )
			while tRowIPStats do
				sCompleteUserData = sCompleteUserData..string.format("~  %s    \t    %s (%d times used)    \t    Last Usage: %s\n", tRowIP.ip, tRowIPStats.nick, tRowIPStats.used_times, tRowIPStats.last_used)
				tRowIPStats = CurIP:fetch( {}, "a" )
			end
			CurIP:close()
			tRowIP = Cur:fetch( {}, "a" )
		end
		Core.SendPmToNick( sFrom, tSettings.sBotName, sCompleteUserData )
	end,
}

function OnExit()
	SQLCon:close()
	SQLEnv:close()
end