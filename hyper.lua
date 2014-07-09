grapefruit = {}

local evc = {}
do
	function evc.newEvent(name)
		local events = {}
		grapefruit[name] = function(func) events[#events+1] = func end
		grapefruit[name.."_events"] = events
	end
end

evc.newEvent "onOSInit"
evc.newEvent "componentFilter"
evc.newEvent "eventFilter"

grapefruit.signal = nil

function grapefruit.sandbox(_os)
	local sandbox
	sandbox = {
	  assert = assert,
	  error = error,
	  getmetatable = getmetatable,
	  ipairs = ipairs,
	  load = function(ld, source, mode, env)
		return load(ld, source, mode, env or sandbox)
	  end,
	  next = next,
	  pairs = pairs,
	  pcall = pcall,
	  rawequal = rawequal,
	  rawget = rawget,
	  rawlen = rawlen,
	  rawset = rawset,
	  select = select,
	  setmetatable = setmetatable,
	  tonumber = tonumber,
	  tostring = tostring,
	  type = type,
	  _VERSION = "Lua 5.2",
	  _HYPERVISOR = "Grapefruit",
	  xpcall = xpcall,

	  coroutine = {
		create = coroutine.create,
		resume = function(coro,...)
			local ra = {coroutine.resume(coro,...)}
			if ra[1] then
				while true do
					if not ra[2] then
						--passthrough
						return ra[1],table.unpack(ra,3,#ra)
					elseif ra[2] == "yth" then --yield to hypervisor
						coroutine.yield("yth")
					end
					ra = {coroutine.resume(coro,...)}
				end
			else
				return table.unpack(ra)
			end
		end,
		running = coroutine.running,
		status = coroutine.status,
		wrap = coroutine.wrap,
		yield = function(...)
			coroutine.yield(nil,...)
		end
	  },

	  string = {
		byte = string.byte,
		char = string.char,
		dump = string.dump,
		find = string.find,
		format = string.format,
		gmatch = string.gmatch,
		gsub = string.gsub,
		len = string.len,
		lower = string.lower,
		match = string.match,
		rep = string.rep,
		reverse = string.reverse,
		sub = string.sub,
		upper = string.upper
	  },

	  table = {
		concat = table.concat,
		insert = table.insert,
		pack = table.pack,
		remove = table.remove,
		sort = table.sort,
		unpack = table.unpack
	  },

	  math = {
		abs = math.abs,
		acos = math.acos,
		asin = math.asin,
		atan = math.atan,
		atan2 = math.atan2,
		ceil = math.ceil,
		cos = math.cos,
		cosh = math.cosh,
		deg = math.deg,
		exp = math.exp,
		floor = math.floor,
		fmod = math.fmod,
		frexp = math.frexp,
		huge = math.huge,
		ldexp = math.ldexp,
		log = math.log,
		max = math.max,
		min = math.min,
		modf = math.modf,
		pi = math.pi,
		pow = math.pow,
		rad = math.rad,
		random = math.random,
		randomseed = math.randomseed,
		sin = math.sin,
		sinh = math.sinh,
		sqrt = math.sqrt,
		tan = math.tan,
		tanh = math.tanh
	  },

	  bit32 = {
		arshift = bit32.arshift,
		band = bit32.band,
		bnot = bit32.bnot,
		bor = bit32.bor,
		btest = bit32.btest,
		bxor = bit32.bxor,
		extract = bit32.extract,
		replace = bit32.replace,
		lrotate = bit32.lrotate,
		lshift = bit32.lshift,
		rrotate = bit32.rrotate,
		rshift = bit32.rshift
	  },

	  io = nil, -- in lib/io.lua

	  os = {
		clock = os.clock,
		date = os.date,
		difftime = os.difftime,
		time = os.time,
	  },

	  debug = {
		traceback = debug.traceback
	  },

	  checkArg = checkArg
	}
	sandbox._G = sandbox
	return sandbox
end

function grapefruit.createOS(bootaddr)
	grapefruit.log("Loading os "..bootaddr)
	local os = {}
	os.sandbox = grapefruit.sandbox(os)
	
	os.sandbox.computer = {}
	for i, v in pairs(computer) do os.sandbox.computer[i] = v end
	function os.sandbox.computer.getBootAddress()
		return bootaddr
	end
	
	local function isSignalAccepted(signal)
		for i, v in pairs(grapefruit.eventFilter_events) do
			local s, alt = v(os,table.unpack(signal))
			if not s then
				if alt == nil then
					return false
				else
					for i=1, #signal do signal[i] = nil end
					for i, v in pairs(alt) do
						signal[i] = v
					end
					return true
				end
			end
		end
		return true
	end
	
	local function yieldToHypervisor()
		coroutine.yield("yth")
	end
	
	function os.sandbox.computer.pullSignal(timeout)
		local deadline = computer.uptime() +
			(type(timeout) == "number" and timeout or math.huge)
		repeat
			yieldToHypervisor()
			local signal = grapefruit.signal
			if signal[1] and isSignalAccepted(signal) then
				return table.unpack(signal, 1, #signal)
			end
		until computer.uptime() >= deadline
	end
	
	local function isComponentAvailable(address)
		local t = component.type(address)
		for i, v in pairs(grapefruit.componentFilter_events) do
			if not v(os,address,t) then return false end
		end
		return true
	end
	
	os.sandbox.component = {}
	for i, v in pairs(component) do
		os.sandbox.component[i] = function(address,...)
			checkArg(1, address, "string")
			address = isComponentAvailable(address) and address or ""
			return v(address,...)
		end
	end
	
--[[	function os.sandbox.component.proxy(address,...)
		coroutine.yield()
		checkArg(1, address, "string")
		address = isComponentAvailable(address) and address or ""
		local proxy = v(address,...)
		if proxy then
			local np = {}
			for i, v in pairs(proxy) do
				if type(v) == "function" then
					np[i] = function(...)
						coroutine.yield()
						return v(...)
					end
				else
					np[i] = v
				end
			end
			return np
		end
		return proxy
	end]]
	--now for list
	function os.sandbox.component.list(...)
		local iter = component.list(...)
		return function(...)
			local addr,typ = iter(...)
			while addr and (not isComponentAvailable(addr,typ)) do
				addr,typ = iter(...)
			end
			return addr, typ
		end
	end
	
	os.sandbox.unicode = {}
	for i, v in pairs(unicode) do os.sandbox.unicode[i] = v end
	
	os.bootaddr = bootaddr
	os.boot = component.proxy(bootaddr)
	local hvfh = os.boot.open("init.lua","r")
	local s,e = load(function()
		return os.boot.read(hvfh,math.huge)
	end,nil,nil,os.sandbox)
	os.boot.close(hvfh)
	if s then
		os.init = s
	else
		os.init = function()
			if os.gpu then
				os.gpu.set(1,1,e)
			end
		end
	end
	for _,f in pairs(grapefruit.onOSInit_events) do
		f(os)
	end
	os.coro = coroutine.create(os.init)
	grapefruit.log(tostring(os.sandbox.computer))
	return os
end

--TODO: Proxy computer.pushSignal
function grapefruit.run(bootfs,gpu,screen,log)
	grapefruit.gpu = gpu
	grapefruit.screen = screen
	grapefruit.log = log
	
	--load scripts
	for _,i in ipairs(bootfs.list("scripts")) do
		local hvfh = bootfs.open("scripts/"..i,"r")
		local s,e = load(function()
			return bootfs.read(hvfh,math.huge)
		end,nil,nil,os.sandbox)
		bootfs.close(hvfh)
		if s then s,e = pcall(s) end
		if not s then
			log("Error when loading script "..i)
			log(e)
			while true do computer.pullSignal() end
		end
	end
	
	local oslist = {}
	oslist[#oslist+1] = grapefruit.createOS("dafaae5c-ed01-4ef8-92b7-631bc3d3fa88")
	oslist[#oslist+1] = grapefruit.createOS("decb182d-8de2-4b29-b0eb-87d7bf816ac4")
	computer.pushSignal("init")
	while true do
		grapefruit.signal = {computer.pullSignal(0)}
		for i, v in ipairs(oslist) do
			local s,e = coroutine.resume(v.coro,"osyield")
			if not s then
				log(e)
				while true do computer.pullSignal() end
			end
		end
	end
end
