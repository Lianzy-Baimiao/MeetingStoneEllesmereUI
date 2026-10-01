-- Test harness for the installed MeetingStone OptionPanel, not invented setters.
BuildEnv=function() end
L=setmetatable({}, {__index=function(_,key) return key end})
NO_SCAN_WORD=true
MainPanel=main
main.RegisterPanel=function(self,_,panel) panel:SetSize(892,321) end
Addon={NewModule=function(_,frame)
    frame.RegisterMessage=function() end
    return frame
end}
profile={settings={panel=true,uiscale=1.2},minimap={hide=false}}
globalOptions={}; writes={}; libraries={}; registered={}; bindings={MEETINGSTONE_TOGGLE='CTRL-M'}
Profile={}
function Profile:GetCharacterDB() return {profile=profile} end
function Profile:GetGlobalOption(k) return globalOptions[k] end
function Profile:GetSetting(k) return profile.settings[k] end
function Profile:SetSetting(k,v) profile.settings[k]=v; table.insert(writes,{k,v}) end
function Profile:SaveGlobalOption(k,v) globalOptions[k]=v; table.insert(writes,{k,v}); return true end
function Profile:GetShowClassIco() return globalOptions.showclassico end
function Profile:ClearHistory() historyCleared=(historyCleared or 0)+1 end
function Profile:GetSpamWords() return {} end
function Profile:ResetSpamWord() wordsReset=(wordsReset or 0)+1 end
function Profile:ExportSpamWord() return 'exported' end
function Profile:ImportSpamWord(text) importedWords=text end
function Profile:AddSpamWord(value) addedWord=value end
Logic={SendCommand=function() end}
LibStub=function(name) return libraries[name] end
libraries['AceConfigRegistry-3.0']={
    RegisterOptionsTable=function(_,name,options) registered[name]=options end,
    GetOptionsTable=function(_,name,uiType,uiName)
        if not registered[name] then return nil end
        assert(uiType=='dialog', 'unexpected registry uiType')
        assert(type(uiName)=='string' and uiName:match('[A-Za-z]%-[0-9]'), 'registry requires versioned uiName')
        return registered[name]
    end,
}
libraries['AceConfigDialog-3.0']={Open=function(_,name) openedOriginal=name end}
libraries['LibDBIcon-1.0']={Show=function() minimapShown=true end,Hide=function() minimapShown=false end}
C_AddOns={IsAddOnLoaded=function(name) return loadedAddons and loadedAddons[name] end}
function GetBindingKey(name) return bindings[name] end
function GetBindingAction(key) return key=='CTRL-X' and 'OTHER_ACTION' or '' end
function SetBinding(key,action) if action then bindings[action]=key else bindings.MEETINGSTONE_TOGGLE=nil end end
function SaveBindings(set) savedBindingSet=set end
function GetCurrentBindingSet() return 2 end
function C_Timer.NewTimer(_,fn)
    local t={}; function t:Cancel() self.cancelled=true end
    C_Timer.After(0,function() if not t.cancelled then fn() end end)
    return t
end
function GUI:CallWarningDialog(text,_,_,callback) warning=text; reloadCallback=callback end
function GUI:CallMessageDialog(text,callback) confirmation={text=text,callback=callback} end
UIParent=main; ADD='添加'; RESET='重置'; MAX_MEETINGSTONE_SUMMARY_LETTERS=200
local baseCreate=CreateFrame
function CreateFrame(...)
    local f=baseCreate(...)
    function f:SetEnabled(on) if on then self:Enable() else self:Disable() end end
    function f:EnableKeyboard(on) self.keyboard=on end
    function f:EnableMouseWheel(on) self.mousewheel=on end
    function f:UnlockHighlight() end
    function f:SetScale(v) self.scale=v end
    function f:ClearFocus()
        if self.focused then self.focused=nil; self:RunScript('OnEditFocusLost') end
    end
    function f:SetFocus() self.focused=true; self:RunScript('OnEditFocusGained') end
    function f:SetLabel(text)
        self.Label=self.Label or self:CreateFontString(); self.Label:SetText(text)
        self.Label:SetShown(text~='')
    end
    return f
end
main.SetScale=function(self,v) self.scale=v end
libraries['AceGUI-3.0']={Create=function(_,kind)
    local widget={type=kind,frame=CreateFrame('Frame'),callbacks={}}
    widget.frame.obj=widget
    function widget:SetCallback(key,fn) self.callbacks[key]=fn end
    function widget:SetWidth(w) self.frame:SetWidth(w) end
    function widget:SetHeight(h) self.frame:SetHeight(h) end
    function widget:ReleaseChildren() end
    if kind=='Keybinding' then
        widget.button=CreateFrame('Button',nil,widget.frame)
        widget.label=widget.frame:CreateFontString()
        widget.msgframe=CreateFrame('Frame',nil,main); widget.msgframe:Hide()
        function widget:SetLabel(text) self.label:SetText(text) end
        function widget:SetKey(key) self.key=key; self.button:SetText(key or '') end
        function widget:SetDisabled(disabled) self.disabled=disabled; self.button:SetEnabled(not disabled) end
        function widget:Fire(key,value) if self.callbacks[key] then self.callbacks[key](self,key,value) end end
    end
    return widget
end}
local baseClass=GUI.GetClass
function GUI:GetClass(kind)
    if kind=='NumericBox' or kind=='CheckBox' then return baseClass(self,kind) end
    return {New=function(_,parent)
        local f=CreateFrame('Frame',nil,parent)
        f.Text=f:CreateFontString()
        for _,key in ipairs({'SetBgShown','SetItemClass','SetItemHeight','SetItemSpacing','SetSelectMode',
            'SetItemHighlightWithoutChecked','SetTitle','SetCheckBoxLabel','SetMaxLetters','SetErrorHandler',
            'SetItemList','Refresh'}) do f[key]=function() end end
        function f:Open(...) self.openArgs={...} end
        return f
    end}
end
Addon.GetClass=GUI.GetClass

ns.Mark=function() end
