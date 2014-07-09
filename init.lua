local bootAddress = computer.getBootAddress()
local bootfs = component.proxy(bootAddress)

local gpu,screen
for addr, comp in component.list("gpu") do
	gpu = component.proxy(addr)
	screen = component.list("screen")()
	gpu.bind(screen)
	local w,h = gpu.getResolution()
	gpu.fill(1, 1, w,h, " ")
	break
end
gpu.setResolution(51,19)

--default config
_LOGTOSCREEN = true

local line = 1
local logfile = bootfs.open("hyper.log","w")
local function log(x)
	if gpu and _LOGTOSCREEN then
		gpu.set(1,line,x)
		line = line+1
	end
	bootfs.write(logfile,x.."\n")
end

if bootfs.exists("conf") then
	local lds = ""
	local iof = bootfs.open("conf","r")
	while true do
		local b = bootfs.read(iof,math.huge)
		if not b then break end
		lds = lds..b
	end
	bootfs.close(iof)
	
	for key, value in (lds.."\n"):gmatch("([A-Z0-9]-)%s(.-)\n") do
		log(key..", "..value)
		_ENV["_"..key] = assert(load("return "..value))()
	end
end

log "BasicOS loaded into memory"
log "Loading Grapefruit Hypervisor"

local hvfh = bootfs.open("hyper.lua","r")
local gr = ""
while true do
	local b = bootfs.read(hvfh,math.huge)
	if b then gr = gr..b else break end
end
local s,e = load(gr)
bootfs.close(hvfh)
log(tostring(e))
if s then s,e = xpcall(s,function() log(debug.traceback()) end) end
if not s then
	log("Error when loading Hypervisor")
	log(e)
	while true do computer.pullSignal() end
end

log "Hypervisor Loaded"

grapefruit.run(bootfs,gpu,screen,log)
