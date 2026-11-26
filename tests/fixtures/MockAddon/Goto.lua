-- Lua 5.1 rejects goto; LuaJIT accepts it.
for i = 1, 3 do
    if i == 2 then goto continue end
    ::continue::
end
