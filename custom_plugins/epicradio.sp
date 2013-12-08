/***************************************************************************
	
	Radio SourceMod Plugin
	Copyright (c) 2011 JokerIce <http://forums.jokerice.co.uk/>

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
	See the	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
	
****************************************************************************/

#define PLUGINVERSION "1.1"

#pragma semicolon 1
#include <sourcemod>
#include <socket>
#include <base64>
#include <colors>

new Handle:g_hCvarPluginStatus = INVALID_HANDLE;
new Handle:g_hCvarInteract = INVALID_HANDLE;
new Handle:g_hCvarRating = INVALID_HANDLE;
new Handle:g_hCvarWelcomeAdvert = INVALID_HANDLE;
new Handle:g_hCvarAdverts = INVALID_HANDLE;
new Handle:g_hCvarAdvertsInterval = INVALID_HANDLE;
new Handle:g_hCvarGetStreamInfo = INVALID_HANDLE;
new Handle:g_hCvarStreamInterval = INVALID_HANDLE;
new Handle:g_hCvarStreamHost = INVALID_HANDLE;
new Handle:g_hCvarStreamPort = INVALID_HANDLE;
new Handle:g_hCvarStreamGamePath = INVALID_HANDLE;
new Handle:g_hCvarStreamUpdatePath = INVALID_HANDLE;
new Handle:g_hCvarStreamStatsPath = INVALID_HANDLE;
new Handle:g_hCvarWebPlayerScript = INVALID_HANDLE;
new Handle:g_hCvarServerUpdateInterval = INVALID_HANDLE;

new Handle:g_hAdvertsTimer = INVALID_HANDLE;
new Handle:g_hStreamTimer = INVALID_HANDLE;
new Handle:g_hServerTimer = INVALID_HANDLE;

new String:g_sDataReceived[5120];
new String:g_sDJ[512];
new String:g_sSong[512];

new bool:PluginEnabled;
new bool:InteractEnabled;
new bool:RatingEnabled;
new bool:WelcomeAdvertsEnabled;
new bool:AdvertsEnabled;
new Float:AdvertsInterval;
new bool:GetStreamInfo;
new Float:StreamInterval;
new String:StreamHost[512];
new StreamPort;
new String:StreamGamePath[512];
new String:StreamUpdatePath[512];
new String:StreamStatsPath[512];
new String:WebPlayerScript[512];
new Float:ServerUpdateInterval;
new bool:isTuned[100];
new tunedVol[100];
new AdsIndex = 0;

new String:Adverts[8][2048] = {
	"Get involved in the community @ wowmod.eu",
	"Hate the song your listening to? Type !poon to show us some hate!",
	"Type !dj to see what dj is currently broadcasting!",
	"Type !request <song> to request a song to be played on air!",
	"Like the song your listening to? Type !choon to show your appreciation!",
	"Type !shoutout <message> to ask the online presenter to say something on air!",
	"Type !song to see what song is currently playing!",
	"Not hearing any music from the radio? Make sure you have flash installed!"
};

public Plugin:myinfo = {
	name = "Radio SourceMod Plugin",
	author = "BomBom - Dunceantix",
	description = "Radio SourceMod Plugin",
	version = PLUGINVERSION,
	url = "http://www.epicradio.co.uk/"
}

public OnPluginStart() {
	g_hCvarPluginStatus = CreateConVar("epic_enabled", "1", "Enables or disables the Radio radio plugin.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarPluginStatus, Cvar_Change_Enabled);
	
	g_hCvarInteract = CreateConVar("epic_interact", "1", "Enables or disables the request and shoutout commands.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarInteract, Cvar_Changed);
	
	g_hCvarRating = CreateConVar("epic_rating", "1", "Enables or disables the song and dj rating commands.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarRating, Cvar_Changed);
	
	g_hCvarWelcomeAdvert = CreateConVar("epic_welcomeadvert", "1", "Enables or disables the welcome advert you see when joining the server.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarWelcomeAdvert, Cvar_Changed);
	
	g_hCvarAdverts = CreateConVar("epic_adverts", "1", "Enables or disables chat adverts that display after a time limit.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarAdverts, Cvar_Change_Adverts);
	
	g_hCvarAdvertsInterval = CreateConVar("epic_adverts_interval", "180.0", "Sets the time between adverts shown in chat.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarAdvertsInterval, Cvar_Changed);
	
	g_hCvarGetStreamInfo = CreateConVar("epic_streaminfo", "1", "Enables or disables stream information from being gathered.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarGetStreamInfo, Cvar_Change_StreamInfo);
	
	g_hCvarStreamInterval = CreateConVar("epic_streaminfo_interval", "10.0", "Sets the time between stream info updates.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarStreamInterval, Cvar_Changed);

	g_hCvarStreamHost = CreateConVar("epic_stream_host", "www.epicradio.co.uk", "Sets the website hostname used to send and retrieve info.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarStreamHost, Cvar_Changed);
	
	g_hCvarStreamPort = CreateConVar("epic_stream_port", "80", "Sets the website port used to send and retrieve info.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarStreamPort, Cvar_Changed);
	
	g_hCvarStreamGamePath = CreateConVar("epic_stream_game_path", "/sm/request", "Website path used for rating and interaction.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarStreamGamePath, Cvar_Changed);
	
	g_hCvarStreamUpdatePath = CreateConVar("epic_stream_update_path", "/sm/update", "Website path used for sending server info.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarStreamUpdatePath, Cvar_Changed);
	
	g_hCvarStreamStatsPath = CreateConVar("epic_stream_stats_path", "/sm/status", "Website path used for getting stream info.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarStreamStatsPath, Cvar_Changed);
	
	g_hCvarWebPlayerScript = CreateConVar("epic_webplayer_script", "/listen/player", "Website script used for the web player.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarWebPlayerScript, Cvar_Changed);
	
	g_hCvarServerUpdateInterval = CreateConVar("epic_server_update_interval", "180.0", "Sets the time between server info updates.", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarServerUpdateInterval, Cvar_Changed);
	
	RegConsoleCmd("sm_dj", Cmd_ShowDJ);
	RegConsoleCmd("sm_song", Cmd_ShowSong);
	RegConsoleCmd("sm_radio", Cmd_RadioMenu);
	RegConsoleCmd("sm_request", Cmd_Request);
	RegConsoleCmd("sm_r", Cmd_Request);
	RegConsoleCmd("sm_shoutout", Cmd_Shoutout);
	RegConsoleCmd("sm_s", Cmd_Shoutout);
	RegConsoleCmd("sm_choon", Cmd_Choon);
	RegConsoleCmd("sm_ch", Cmd_Choon);
	RegConsoleCmd("sm_poon", Cmd_Poon);
	RegConsoleCmd("sm_p", Cmd_Poon);
	RegConsoleCmd("sm_djftw", Cmd_djFTW);
	RegConsoleCmd("sm_djftl", Cmd_djFTL);

}

public OnClientPutInServer(client) {
	if (WelcomeAdvertsEnabled) {
		WelcomeAdvert(client);
	}
}

public OnClientDisconnect(client) {
	isTuned[client] = false;
}

stock ClearTimer(&Handle:timer) {
	if (timer != INVALID_HANDLE) {
		KillTimer(timer);
	}
	
	timer = INVALID_HANDLE;
}

public Action:WelcomeAdvert(any:client) {
	PrintToChat(client, "\x04[Radio]\x01 To listen to the radio type !radio in chat!");
}

public Action:Advertise(Handle:timer) {
	if (AdsIndex == 8) {
		AdsIndex = 0;
		PrintToChatAll("\x04[Radio]\x01 %s", Adverts[AdsIndex]);
		AdsIndex++;
	} else {
		PrintToChatAll("\x04[Radio]\x01 %s", Adverts[AdsIndex]);
		AdsIndex++;
	}
}

public OnMapEnd() {
	ClearTimer(g_hAdvertsTimer);
	ClearTimer(g_hStreamTimer);
	ClearTimer(g_hServerTimer);
}

public Cvar_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
	OnConfigsExecuted();
}

public Cvar_Change_Enabled(Handle:convar, const String:oldValue[], const String:newValue[]) {
	PluginEnabled = GetConVarBool(g_hCvarPluginStatus);

	if (PluginEnabled) {
		if (AdvertsEnabled) {
			g_hAdvertsTimer = CreateTimer(AdvertsInterval, Advertise, 0, TIMER_REPEAT);
		}
		
		if (GetStreamInfo) {
			Server_Receive();
			g_hStreamTimer = CreateTimer(StreamInterval, UpdateStreamInfo, 0, TIMER_REPEAT);
			
			Server_Send();
			g_hServerTimer = CreateTimer(ServerUpdateInterval, UpdateServerList, 0, TIMER_REPEAT);
		}
		
		for (new i=1; i<= MaxClients; i++) {
			if (IsClientConnected(i) && IsClientInGame(i)) {
				if (isTuned[i]) {
					StreamPanel("Thanks for tuning into Radio!", "about:blank", i);
					
					decl String:url[256];
					FormatEx(url, sizeof(url), "http://%s/%s?vol=%s", StreamHost, WebPlayerScript, tunedVol[i]);
					StreamPanel("You are tuned into Radio!", url, i);
					
					PrintToChat(i, "\x04[Radio]\x01 The Radio plugin has been enabled, you have been auto tuned in.");
				}
			}
		}
	} else {
		ClearTimer(g_hAdvertsTimer);
		ClearTimer(g_hStreamTimer);
		ClearTimer(g_hServerTimer);
		
		for (new i=1; i<= MaxClients; i++) {
			if (IsClientConnected(i) && IsClientInGame(i)) {
				if (isTuned[i]) {
					StreamPanel("Thanks for tuning into Radio!", "about:blank", i);
					PrintToChat(i, "\x04[Radio]\x01 The Radio plugin has been disabled, you have been auto tuned out.");
				}
			}
		}
	}
}

public Cvar_Change_Adverts(Handle:convar, const String:oldValue[], const String:newValue[]) {
	AdvertsEnabled = GetConVarBool(g_hCvarAdverts);
	
	if (AdvertsEnabled) {
		g_hAdvertsTimer = CreateTimer(AdvertsInterval, Advertise, 0, TIMER_REPEAT);
	} else {
		ClearTimer(g_hAdvertsTimer);
	}
}

public Cvar_Change_StreamInfo(Handle:convar, const String:oldValue[], const String:newValue[]) {
	GetStreamInfo = GetConVarBool(g_hCvarGetStreamInfo);
	
	if (GetStreamInfo) {
		Server_Receive();
		g_hStreamTimer = CreateTimer(StreamInterval, UpdateStreamInfo, 0, TIMER_REPEAT);
		
		Server_Send();
		g_hServerTimer = CreateTimer(ServerUpdateInterval, UpdateServerList, 0, TIMER_REPEAT);
	} else {
		ClearTimer(g_hStreamTimer);
		ClearTimer(g_hServerTimer);
	}
}

public OnConfigsExecuted() {
	PluginEnabled = GetConVarBool(g_hCvarPluginStatus);
	InteractEnabled = GetConVarBool(g_hCvarInteract);
	RatingEnabled = GetConVarBool(g_hCvarRating);
	WelcomeAdvertsEnabled = GetConVarBool(g_hCvarWelcomeAdvert);
	AdvertsEnabled = GetConVarBool(g_hCvarAdverts);
	AdvertsInterval = GetConVarFloat(g_hCvarAdvertsInterval);
	GetStreamInfo = GetConVarBool(g_hCvarGetStreamInfo);
	StreamInterval = GetConVarFloat(g_hCvarStreamInterval);
	GetConVarString(g_hCvarStreamHost, StreamHost, sizeof(StreamHost));
	StreamPort = GetConVarInt(g_hCvarStreamPort);
	GetConVarString(g_hCvarStreamGamePath, StreamGamePath, sizeof(StreamGamePath));
	GetConVarString(g_hCvarStreamUpdatePath, StreamUpdatePath, sizeof(StreamUpdatePath));
	GetConVarString(g_hCvarStreamStatsPath, StreamStatsPath, sizeof(StreamStatsPath));
	GetConVarString(g_hCvarWebPlayerScript, WebPlayerScript, sizeof(WebPlayerScript));
	ServerUpdateInterval = GetConVarFloat(g_hCvarServerUpdateInterval);
	
	if (PluginEnabled) {
		if (AdvertsEnabled) {
			g_hAdvertsTimer = CreateTimer(AdvertsInterval, Advertise, 0, TIMER_REPEAT);
		}
		
		if (GetStreamInfo) {
			Server_Receive();
			g_hStreamTimer = CreateTimer(StreamInterval, UpdateStreamInfo, 0, TIMER_REPEAT);
			
			Server_Send();
			g_hServerTimer = CreateTimer(ServerUpdateInterval, UpdateServerList, 0, TIMER_REPEAT);
		}
	}
}

public Action:UpdateStreamInfo(Handle:timer) {
	Server_Receive();
}

public Action:UpdateServerList(Handle:timer) {
	Server_Send();
}

public Cmd_Check(String:type[], client) {
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client)) {
		if (!PluginEnabled) {
			ReplyToCommand(client, "\x04[Radio]\x01 The Radio Plugin has been disabled.");
			return false;
		}
		
		if (StrEqual(type, "streaminfo") && !GetStreamInfo) {
			ReplyToCommand(client, "\x04[Radio]\x01 Stream info gathering has been disabled.");
			return false;
		} else if (StrEqual(type, "interact") && !InteractEnabled) {
			ReplyToCommand(client, "\x04[Radio]\x01 Interaction commands have been disabled.");
			return false;
		} else if (StrEqual(type, "rating") && !RatingEnabled) {
			ReplyToCommand(client, "\x04[Radio]\x01 Rating commands have been disabled.");
			return false;
		}
		
		if (!StrEqual(type, "streaminfo") && isTuned[client] != true) {
			ReplyToCommand(client, "\x04[Radio]\x01 You are not tuned in, type !radio to tune in!");
			return false;
		}
	} else {
		ReplyToCommand(client, "[Radio] That command can only be used by clients!");
		return false;
	}
	
	return true;
}

public Action:Cmd_ShowDJ(client, args) {
	if (Cmd_Check("streaminfo", client)) {		
		if (GetStreamInfo && !StrEqual(g_sDJ, "")) {
			ReplyToCommand(client, "\x04[Radio] Current DJ:\x01 %s", g_sDJ);
		} else {
			ReplyToCommand(client, "\x04[Radio]\x01 No stream info has been received yet!");
		}
	}

	return Plugin_Handled;
}

public Action:Cmd_ShowSong(client, args) {
	if (Cmd_Check("streaminfo", client)) {		
		if (GetStreamInfo && !StrEqual(g_sSong, "")) {
			ReplyToCommand(client, "\x04[Radio] Current Song:\x01 %s", g_sSong);
		} else {
			ReplyToCommand(client, "\x04[Radio]\x01 No stream info has been received yet!");
		}
	}

	return Plugin_Handled;
}

public StreamPanel(String:title[], String:url[], client) {
	new Handle:Radio = CreateKeyValues("data");
	KvSetString(Radio, "title", title);
	KvSetString(Radio, "type", "2");
	KvSetString(Radio, "msg", url);
	ShowVGUIPanel(client, "info", Radio, false);
	CloseHandle(Radio);
}

public RadioMenuHandle(Handle:menu, MenuAction:action, client, choice) {
	if (action == MenuAction_Select) {
		new String:info[32];
		new bool:found = GetMenuItem(menu, choice, info, sizeof(info));
		
		if (found) {
			if (StringToInt(info) == 0) {
				isTuned[client] = false;
				tunedVol[client] = 0;
				
				StreamPanel("Thanks for tuning into Radio!", "about:blank", client);
				PrintToChat(client, "\x04[Radio]\x01 Thanks for tuning into Radio!");
			} else {
				new vol = StringToInt(info);
				new bool:stinky=false;
				if(vol >= 1000)	{
					stinky = true;
					vol -= 1000;
				}
				
				if (isTuned[client] != true) {
					decl String:name[128];
					GetClientName(client, name, sizeof(name));
					if(!stinky)
						PrintToChatAll("\x04[Radio]\x01 %s has tuned into the radio by typing !radio", name);
					else	{
						PrintToChatAll("\x04[StinkyRadio]\x01 %s has tuned into the STINKY radio by typing !radio", name);
					}
				}
				
				StreamPanel("Thanks for tuning into Radio!", "about:blank", client);
				
				isTuned[client] = true;
				tunedVol[client] = vol;
				
				decl String:url[256];			
				FormatEx(url, sizeof(url), "http://%s/%s?vol=%s", StreamHost, WebPlayerScript, info);
				if(stinky)	{
					Format(url, sizeof(url), "http://wowmod.eu/radio.php?vol=%d", vol);
				}
				StreamPanel("You are tuned into Radio!", url, client);
			}
		}
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

public Action:Cmd_RadioMenu(client, args) {
	if (!PluginEnabled) {
		ReplyToCommand(client, "\x04[Radio]\x01 The Radio Plugin has been disabled.");
		return Plugin_Handled;
	}
	
	if (args > 1) {
	
	
	return Plugin_Handled;
	}
	
	new Handle:menu = CreateMenu(RadioMenuHandle);
	
	if (GetStreamInfo && !StrEqual(g_sDJ, "") && !StrEqual(g_sSong, "")) {
		SetMenuTitle(menu, "Radio Menu\n \nDJ: %s\nSong: %s\n \n", g_sDJ, g_sSong);
	} else {
		SetMenuTitle(menu, "Radio Menu\n \n");
	}
	
	AddMenuItem(menu, "100", "100% Volume");
	AddMenuItem(menu, "80", "70% Volume");
	AddMenuItem(menu, "60", "30% Volume");
	AddMenuItem(menu, "1100", "100% Volume StinkyRadio");
	AddMenuItem(menu, "1070", "70% Volume StinkyRadio");
	AddMenuItem(menu, "1030", "30% Volume StinkyRadio");
	
	if (isTuned[client]) {
		AddMenuItem(menu, "0", "Stop Listening");
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);

	return Plugin_Handled;
}

public Action:Cmd_Request(client, args) {
	if (Cmd_Check("interact", client)) {	
		if (args < 1) {
			ReplyToCommand(client, "\x04[Radio]\x01 Usage: !request <song>");
			return Plugin_Handled;
		}
		
		decl String:request[256];
		GetCmdArgString(request, sizeof(request));
				
		if (strlen(request) < 8) {
			ReplyToCommand(client, "\x04[Radio]\x01 Requests must be more than 8 characters.");
			return Plugin_Handled;
		} else if (strlen(request) > 255) {
			ReplyToCommand(client, "\x04[Radio]\x01 Requests must be less than 255 characters.");
			return Plugin_Handled;
		}
		
		if (GetStreamInfo && !StrEqual(g_sDJ, "")) {
			ReplyToCommand(client, "\x04[Radio]\x01 Your song request has been sent to %s", g_sDJ);
		} else {
			ReplyToCommand(client, "\x04[Radio]\x01 Your song request has been sent!");
		}
		
		Client_Send("req", request, client);
	}
	
	return Plugin_Handled;
}

public Action:Cmd_Shoutout(client, args) {
	if (Cmd_Check("interact", client)) {		
		if (args < 1) {
			ReplyToCommand(client, "\x04[Radio]\x01 Usage: !shoutout <message>");
			return Plugin_Handled;
		}

		decl String:shoutout[256];
		GetCmdArgString(shoutout, sizeof(shoutout));
		
		if (StrEqual(g_sDJ, "AutoDJ")) {
			ReplyToCommand(client, "\x04[Radio]\x01 Shoutouts cannot be made when AutoDJ is onair");
			return Plugin_Handled;
		}
		
		if (strlen(shoutout) < 8) {
			ReplyToCommand(client, "\x04[Radio]\x01 Shoutouts must be more than 8 characters.");
			return Plugin_Handled;
		} else if (strlen(shoutout) > 255) {
			ReplyToCommand(client, "\x04[Radio]\x01 Shoutouts must be less than 255 characters.");
			return Plugin_Handled;
		}
		
		if (GetStreamInfo && !StrEqual(g_sDJ, "")) {
			ReplyToCommand(client, "\x04[Radio]\x01 Your shoutout has been sent to %s", g_sDJ);
		} else {
			ReplyToCommand(client, "\x04[Radio]\x01 Your shoutout has been sent!");
		}
		
		Client_Send("shout", shoutout, client);
	}
	
	return Plugin_Handled;
}

public Action:Cmd_Choon(client, args) {
	if (Cmd_Check("rating", client)) {		
		decl String:name[128];
		GetClientName(client, name, sizeof(name));
		
		if (GetStreamInfo && !StrEqual(g_sSong, "")) {
			PrintToChatAll("\x04[Radio]\x01 %s thinks %s is a CHOON!", name, g_sSong);
		} else {
			PrintToChatAll("\x04[Radio]\x01 %s thinks the current song is a CHOON!", name);
		}
		
		Client_Send("song", "ftw", client);
	}
	
	return Plugin_Handled;
}

public Action:Cmd_Poon(client, args) {
	if (Cmd_Check("rating", client)) {		
		decl String:name[128];
		GetClientName(client, name, sizeof(name));
		
		if (GetStreamInfo && !StrEqual(g_sSong, "")) {
			PrintToChatAll("\x04[Radio]\x01 %s thinks %s is a POON!", name, g_sSong);
		} else {
			PrintToChatAll("\x04[Radio]\x01 %s thinks the current song is a POON!", name);
		}
		
		Client_Send("song", "ftl", client);
	}
	
	return Plugin_Handled;
}

public Action:Cmd_djFTW(client, args) {
	if (Cmd_Check("rating", client)) {		
		decl String:name[128];
		GetClientName(client, name, sizeof(name));
		
		if (GetStreamInfo && !StrEqual(g_sDJ, "")) {
			PrintToChatAll("\x04[Radio]\x01 %s thinks %s is EPIC!", name, g_sDJ);
		} else {
			PrintToChatAll("\x04[Radio]\x01 %s thinks the current dj is EPIC!", name);
		}
		
		Client_Send("dj", "ftw", client);
	}
	
	return Plugin_Handled;
}

public Action:Cmd_djFTL(client, args) {
	if (Cmd_Check("rating", client)) {		
		decl String:name[128];
		GetClientName(client, name, sizeof(name));
		
		if (GetStreamInfo && !StrEqual(g_sDJ, "")) {
			PrintToChatAll("\x04[Radio]\x01 %s thinks %s FAILS!", name, g_sDJ);
		} else {
			PrintToChatAll("\x04[Radio]\x01 %s thinks the current dj FAILS!", name);
		}
		
		Client_Send("dj", "ftl", client);
	}
	
	return Plugin_Handled;
}

public Action:Server_Send() {
	new Handle:dp = CreateDataPack();
	
	WritePackString(dp, "serverinfo");
	
	decl String:serverip[32];
	decl String:serverport[32];
	decl String:serverinfo[64];
		
	GetConVarString(FindConVar("hostip"), serverip, sizeof(serverip));
	new hostip = GetConVarInt(FindConVar("hostip"));	
	FormatEx(serverip, sizeof(serverip), "%u.%u.%u.%u", (hostip >> 24) & 0x000000FF, (hostip >> 16) & 0x000000FF, (hostip >> 8) & 0x000000FF, hostip & 0x000000FF);
	GetConVarString(FindConVar("hostport"), serverport, sizeof(serverport));
	FormatEx(serverinfo, sizeof(serverinfo), "%s:%s", serverip, serverport);
	WritePackString(dp, serverinfo);
	
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetArg(socket, dp);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, StreamHost, StreamPort);
}

public Action:Server_Receive() {
	new Handle:dp = CreateDataPack();
	
	WritePackString(dp, "streaminfo");
	
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetArg(socket, dp);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, StreamHost, StreamPort);
}

public Action:Client_Send(String:type[], String:message[], client) {
	new Handle:dp = CreateDataPack();
	
	WritePackString(dp, type);
	WritePackString(dp, message);
	
	decl String:ip[32];
	GetClientIP(client, ip, sizeof(ip), true);
	WritePackString(dp, ip);
	
	decl String:name[128];
	GetClientName(client, name, sizeof(name));
	WritePackString(dp, name);
	
	decl String:steamid[64];
	GetClientAuthString(client, steamid, sizeof(steamid));
	WritePackString(dp, steamid);
	
	decl String:serverip[32];
	decl String:serverport[32];
	decl String:serverinfo[64];
		
	GetConVarString(FindConVar("hostip"), serverip, sizeof(serverip));
	new hostip = GetConVarInt(FindConVar("hostip"));	
	FormatEx(serverip, sizeof(serverip), "%u.%u.%u.%u", (hostip >> 24) & 0x000000FF, (hostip >> 16) & 0x000000FF, (hostip >> 8) & 0x000000FF, hostip & 0x000000FF);
	GetConVarString(FindConVar("hostport"), serverport, sizeof(serverport));
	FormatEx(serverinfo, sizeof(serverinfo), "%s:%s", serverip, serverport);
	
	WritePackString(dp, serverinfo);
	WritePackCell(dp, client);
	
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetArg(socket, dp);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, StreamHost, StreamPort);
}

public OnSocketConnected(Handle:socket, any:dp) {	
	ResetPack(dp);
	
	decl String:type[32];
	ReadPackString(dp, type, sizeof(type));
	
	decl String:socketStr[1024];
	
	if (StrEqual(type, "serverinfo")) {
		decl String:ip[64];
		ReadPackString(dp, ip, sizeof(ip));
		decl String:eip[128];
		EncodeBase64(eip, sizeof(eip), ip);
	
		FormatEx(socketStr, sizeof(socketStr), "GET %s?ip=%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", StreamUpdatePath, eip, StreamHost);
	} else if (StrEqual(type, "streaminfo")) {
		FormatEx(socketStr, sizeof(socketStr), "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", StreamStatsPath, StreamHost);
	} else {
		decl String:etype[64];
		EncodeBase64(etype, sizeof(etype), type);
	
		decl String:message[256];
		ReadPackString(dp, message, sizeof(message));
		decl String:emessage[512];
		EncodeBase64(emessage, sizeof(emessage), message);
		
		decl String:ip[64];
		ReadPackString(dp, ip, sizeof(ip));
		decl String:eip[128];
		EncodeBase64(eip, sizeof(eip), ip);
		
		decl String:name[128];
		ReadPackString(dp, name, sizeof(name));
		decl String:ename[256];
		EncodeBase64(ename, sizeof(ename), name);
		
		decl String:steamid[64];
		ReadPackString(dp, steamid, sizeof(steamid));
		decl String:esteamid[128];
		EncodeBase64(esteamid, sizeof(esteamid), steamid);
		
		decl String:serverinfo[64];
		ReadPackString(dp, serverinfo, sizeof(serverinfo));
		decl String:eserverinfo[128];
		EncodeBase64(eserverinfo, sizeof(eserverinfo), serverinfo);
		
		FormatEx(socketStr, sizeof(socketStr), "GET %s?type=%s&content=%s&playersip=%s&playersname=%s&playerssteam=%s&serversip=%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", StreamGamePath, etype, emessage, eip, ename, esteamid, eserverinfo, StreamHost);
	}
	
	SocketSend(socket, socketStr);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:dp) {
	ResetPack(dp);
	
	decl String:type[32];
	ReadPackString(dp, type, sizeof(type));
	
	if (StrEqual(type, "streaminfo")) {
		strcopy(g_sDataReceived, sizeof(g_sDataReceived), receiveData);
	}
}

public OnSocketDisconnected(Handle:socket, any:dp) {
	ResetPack(dp);
	
	decl String:type[32];
	ReadPackString(dp, type, sizeof(type));
	
	if (StrEqual(type, "streaminfo")) {		
		new pos = StrContains(g_sDataReceived, "INFO");
		
		if (pos > 0) {
			decl String:streaminfo[5120];
			
			strcopy(streaminfo, sizeof(streaminfo), g_sDataReceived[pos - 1]);
			
			new String:file[512];
			BuildPath(Path_SM, file, 512, "configs/epicradio_stream_info.txt");

			new Handle:hFile = OpenFile(file, "wb");
			WriteFileString(hFile, streaminfo, false);
			CloseHandle(hFile);
			
			new Handle:Info = CreateKeyValues("INFO");
			FileToKeyValues(Info, file);
			
			DeleteFile(file);
			
			if (KvJumpToKey(Info, "epicRadio"))	{
				decl String:dj[512];
				decl String:song[512];
				KvGetString(Info, "DJ", dj, sizeof(dj), "Unknown");
				KvGetString(Info, "SONG", song, sizeof(song), "Unknown");
				
				if(!StrEqual(dj, g_sDJ)) {
					g_sDJ = dj;
					PrintToChatAll("\x04[Radio] Now Presenting:\x01 %s", g_sDJ);
				}

				if(!StrEqual(song, g_sSong)) {
					g_sSong = song;
					PrintToChatAll("\x04[Radio] Now Playing:\x01 %s", g_sSong);
				}
			}
			
			CloseHandle(Info);
		}
	}

	CloseHandle(dp);
	CloseHandle(socket);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:dp) {
	LogError("[Radio] Socket error %d (errno %d)", errorType, errorNum);
	
	CloseHandle(dp);
	CloseHandle(socket);
}
