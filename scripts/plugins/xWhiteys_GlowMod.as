array<CScheduledFunction@> g_dict_lpfnLoops(33);
array<float> g_a_flHUEs(33);

void PluginInit() {
    g_Module.ScriptInfo.SetAuthor("xWhitey");
    g_Module.ScriptInfo.SetContactInfo("tyabus @ Discord");
    
    for (uint idx = 0; idx < g_dict_lpfnLoops.length(); idx++) {
        CScheduledFunction@ func = g_dict_lpfnLoops[idx];
        if (func is null) continue;
        if (func.HasBeenRemoved()) continue;
        
        g_Scheduler.RemoveTimer(func);
    }
    for (uint idx = 0; idx < g_a_flHUEs.length(); idx++) {
        g_a_flHUEs[idx] = 0.0f;
    }
}

void MapInit() {
    for (uint idx = 0; idx < g_dict_lpfnLoops.length(); idx++) {
        CScheduledFunction@ func = g_dict_lpfnLoops[idx];
        if (func is null) continue;
        if (func.HasBeenRemoved()) continue;
        
        g_Scheduler.RemoveTimer(func);
    }
    for (uint idx = 0; idx < g_a_flHUEs.length(); idx++) {
        g_a_flHUEs[idx] = 0.0f;
    }
}

float GlowMod_UTIL_Hue2RGB(float p, float q, float t) {
    if (t < 0.0f) {
        t = t + 1.0f;
    }

    if (t > 1.0f) {
        t = t - 1.0f;
    }

    if (t < 1.0f / 6.0f) {
        return p + (q - p) * 6.0f * t;
    }

    if (t < 1.0f / 2.0f) {
        return q;
    }

    if (t < 2.0f / 3.0f) {
        return p + (q - p) * ((2.0f / 3.0f) - t) * 6.0f;
    }

    return p;
}

Vector GlowMod_UTIL_HSL2RGB(Vector _HSL) {
    Vector vecRGB;

    if (_HSL.y == 0.0f) {
        vecRGB.x = _HSL.z;
        vecRGB.y = _HSL.z;
        vecRGB.z = _HSL.z;

        return vecRGB;
    }

    float q = _HSL.z < 0.5f ? _HSL.z * (1.0f + _HSL.y) : _HSL.z + _HSL.y - _HSL.z * _HSL.y;
    float p = 2.0f * _HSL.z - q;

    vecRGB.x = GlowMod_UTIL_Hue2RGB(p, q, _HSL.x + (1.0f / 3.0f));
    vecRGB.y = GlowMod_UTIL_Hue2RGB(p, q, _HSL.x);
    vecRGB.z = GlowMod_UTIL_Hue2RGB(p, q, _HSL.x - (1.0f / 3.0f));

    return vecRGB;
}

float GlowMod_UTIL_SyncHUEWithOtherPlayers() {
    for (uint idx = 0; idx < g_a_flHUEs.length(); idx++) {
        if (g_a_flHUEs[idx] != 0.0f) return g_a_flHUEs[idx];
    }
    
    return 0.0f;
}

void GlowMod_DoRainbowGlowLoop(EHandle _Player) {
    if (!_Player) return;
    
    CBaseEntity@ glowEnt = _Player.GetEntity();
    CBasePlayer@ plr = cast<CBasePlayer@>(glowEnt);

    int iPlayerIdx = glowEnt.entindex();
    Vector vecRGB = GlowMod_UTIL_HSL2RGB(Vector(g_a_flHUEs[iPlayerIdx], 0.8, 0.5));

    g_a_flHUEs[iPlayerIdx] = g_a_flHUEs[iPlayerIdx] + 0.015;

    while (g_a_flHUEs[iPlayerIdx] > 1.0f) {
        g_a_flHUEs[iPlayerIdx] = g_a_flHUEs[iPlayerIdx] - 1.0f;
    }
    
    glowEnt.pev.rendercolor.x = 255.0f * vecRGB.x;
    glowEnt.pev.rendercolor.y = 255.0f * vecRGB.y;
    glowEnt.pev.rendercolor.z = 255.0f * vecRGB.z;

    @g_dict_lpfnLoops[iPlayerIdx] = g_Scheduler.SetTimeout("GlowMod_DoRainbowGlowLoop", 0.05, EHandle(_Player));
}

void GlowMod_DoGlowConCmd(CBasePlayer@ _Player, const CCommand@ _Args) {
    if (_Args.ArgC() >= 2 && _Args.ArgC() < 4) {
        string szFirstArg = _Args[1].ToLowercase();
        
        if (szFirstArg == "off" or szFirstArg == "stop") {
            _Player.pev.renderfx = kRenderFxNone;
            
            g_a_flHUEs[_Player.entindex()] = 0.0f;
            CScheduledFunction@ func = g_dict_lpfnLoops[_Player.entindex()];
            if (func !is null && !func.HasBeenRemoved()) {
                g_Scheduler.RemoveTimer(func);
                g_PlayerFuncs.SayText(_Player, "Stopped rainbow glowing\n");
            }
            
            return;
        } else if (szFirstArg == "rainbow") {
            int amount = 1;
        
            if (_Args.ArgC() >= 3) {
                string szAmount = _Args[2].ToLowercase();
                bool isNumeric = true;
                for (uint i = 0; i < szAmount.Length(); i++) {
                    if (!isdigit(szAmount[i])) {
                        isNumeric = false;
                        break;
                    }
                }
                
                if (!isNumeric) {
                    g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, "The passed strength is not numeric, skipping...\n");
                    return;
                }
                
                amount = atoi(szAmount);
                if (amount < 1)
                    amount = 1;
                if (amount > 255)
                    amount = 255;
            }
        
            _Player.pev.renderfx = kRenderFxGlowShell;
            _Player.pev.renderamt = amount;
            
            g_a_flHUEs[_Player.entindex()] = GlowMod_UTIL_SyncHUEWithOtherPlayers();
        
            CScheduledFunction@ func = g_dict_lpfnLoops[_Player.entindex()];
            if (func !is null && !func.HasBeenRemoved()) {
                g_Scheduler.RemoveTimer(func);
            }
            @g_dict_lpfnLoops[_Player.entindex()] = g_Scheduler.SetTimeout("GlowMod_DoRainbowGlowLoop", 0, EHandle(_Player));
            
            return;
        } else {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, '----------------------------------GlowMod Commands----------------------------------\n\n');
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, 'Type ".glow off/.glow stop" to stop glowing.\n');
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, 'Type ".glow <red> <green> <blue> [strength] to start glowing.\n');
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, '\n<> = required. [] = optional.\n');            
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, '\n----------------------------------------------------------------------------------\n');
            
            return;
        }
    }

    if (_Args.ArgC() >= 4) { //.glow 255 128 64
        string szFirstArg = _Args[1].ToLowercase();
        string szSecondArg = _Args[2].ToLowercase();
        string szThirdArg = _Args[3].ToLowercase();
        
        bool isFirstArgNumeric = true;
        for (uint i = 0; i < szFirstArg.Length(); i++) {
            if (!isdigit(szFirstArg[i])) {
                isFirstArgNumeric = false;
                break;
            }
        }
        
        bool isSecondArgNumeric = true;
        for (uint i = 0; i < szSecondArg.Length(); i++) {
            if (!isdigit(szSecondArg[i])) {
                isSecondArgNumeric = false;
                break;
            }
        }
        
        bool isThirdArgNumeric = true;
        for (uint i = 0; i < szThirdArg.Length(); i++) {
            if (!isdigit(szThirdArg[i])) {
                isThirdArgNumeric = false;
                break;
            }
        }
        
        if (!isFirstArgNumeric || !isSecondArgNumeric || !isThirdArgNumeric) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, "The passed colors are wrong, skipping...\n");
            return;
        }
        
        int red = atoi(szFirstArg);
        if (red > 255)
            red = 255;
        int green = atoi(szSecondArg);
        if (green > 255)
            green = 255;
        int blue = atoi(szThirdArg);
        if (blue > 255)
            blue = 255;
            
        int amount = 1;
        if (_Args.ArgC() > 4) {
            string szFourthArg = _Args[4].ToLowercase();
            bool isFourthArgNumeric = true;
            for (uint i = 0; i < szFourthArg.Length(); i++) {
                if (!isdigit(szFourthArg[i])) {
                    isFourthArgNumeric = false;
                    break;
                }
            }
            
            if (!isFourthArgNumeric) {
                g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, "The passed strength is not numeric, skipping...\n");
                return;
            }
            
            amount = atoi(szFourthArg);
            if (amount < 1) //same thing as with 'red' variable lool
                amount = 1;
            if (amount > 255)
                amount = 255;
        }
        
        _Player.pev.renderfx = kRenderFxGlowShell;
        _Player.pev.rendercolor.x = float(red);
        _Player.pev.rendercolor.y = float(green);
        _Player.pev.rendercolor.z = float(blue);
        _Player.pev.renderamt = amount;
    } else {
        g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, '----------------------------------GlowMod Commands----------------------------------\n\n');
        g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, 'Type ".glow off/.glow stop" to stop glowing.\n');
        g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, 'Type ".glow <red> <green> <blue> [strength] to start glowing.\n');
        g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, '\n<> = required. [] = optional.\n');            
        g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTCONSOLE, '\n----------------------------------------------------------------------------------\n');
    }
}

CClientCommand _emote("glow", "GlowMod commands", @CMD_Glow);

void CMD_Glow(const CCommand@ args) {
    string mapname = g_Engine.mapname;
    
    CBasePlayer@ player = g_ConCommandSystem.GetCurrentPlayer();
    
    if (g_Engine.mapname == "ctf_warforts") {
        g_PlayerFuncs.ClientPrint(player, HUD_PRINTCONSOLE, "Unknown command: .glow\n");
        return;
    }
    
    GlowMod_DoGlowConCmd(player, args);
}
