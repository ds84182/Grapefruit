grapefruit.onOSInit(function(os)
	--provide alternative computer.pushSignal
	function os.sandbox.computer.pushSignal(...)
		computer.pushSignal("_grapefruitpsi",os.bootaddr,...)
	end
end)

grapefruit.eventFilter(function(os,typ,b,...)
	if typ == "_grapefruitpsi" then
		if os.bootaddr ~= b then
			return false
		else
			return false, {...} --return alternative
		end
	end
	return true
end)
