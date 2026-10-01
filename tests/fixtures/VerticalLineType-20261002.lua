-- Native LibClass type checks plus the skin class lookup, read-only excerpts.

local Class, Object = {}, {}

function Object:GetSuper()
    return self._Meta.__super
end

function Object:GetType()
    return self._Meta.__type
end

function Object:IsType(class)
    if not self.GetType then
        return false
    end
    if not Class:IsClass(class) then
        return false
    end
    if self:GetType() == class then
        return true
    end
    local super = self:GetSuper()
    return super and super:IsType(class) or false
end

function Class:IsClass(value)
    if self ~= Class then
        error([[Usage: Class:IsClass(value)]], 2)
    end
    if type(value) ~= 'table' then
        return false
    end
    local _Meta = rawget(value, '_Meta')
    if not _Meta then
        return false
    end
    return _Meta.__type == value
end

function ns.GetClass(name)                      -- NetEaseGUI widgets
    if not ns.GUI then return end
    local ok, c = pcall(ns.GUI.GetClass, ns.GUI, name)
    return ok and c or nil
end

function AttachVerticalLineClass(class, frame)
    class._Meta = { __type=class }
    frame._Meta = { __type=class }
    for name, fn in pairs(Object) do class[name]=fn; frame[name]=fn end
end
