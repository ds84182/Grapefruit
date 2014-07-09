--simple proxy for gpus (making other gpus invisible to a os)
--this will not work if a gpu is attached later :(
--TODO: Proxy keyboards

local taken = {}
taken[grapefruit.gpu.address] = grapefruit
taken[grapefruit.screen] = grapefruit
grapefruit.onOSInit(function(os)
	--find a gpu for it
	for addr, comp in component.list("gpu") do
		if not taken[addr] then
			taken[addr] = os
			local screen
			for addr, comp in component.list("screen") do
				if not taken[addr] then screen = addr taken[addr] = os break end
			end
			os.gpu = addr
			os.screen = screen
			component.invoke(os.gpu,"bind",os.screen)
			component.invoke(os.gpu,"setResolution",51,19)
			break
		end
	end
end)

--this gets called on component.list and component.get
grapefruit.componentFilter(function(os, addr, ctype)
	if ctype == "gpu" then --we handle gpus
		if addr == os.gpu or os.gpu == nil then
			return true --you can also change the component's type and address by passing it through here
		else
			return false
		end
	elseif ctype == "screen" then
		if addr == os.screen or os.screen == nil then
			return true --you can also change the component's type and address by passing it through here
		else
			return false
		end
	end
	return true --for anything else we want it to pass through
end)

grapefruit.eventFilter(function(os,typ,addr,ctype)
	if typ == "component_added" or typ == "component_removed" then
		if ctype == "gpu" then --we handle gpus
			if addr == os.gpu or os.gpu == nil then
				return true --you can also change the component's type and address by passing it through here
			else
				return false
			end
		elseif ctype == "screen" then
			if addr == os.screen or os.screen == nil then
				return true --you can also change the component's type and address by passing it through here
			else
				return false
			end
		end
	end
	return true
end)
