local Scheduler = {}
Scheduler.__index = Scheduler

local function sortQueue(queue)
	table.sort(queue, function(a, b)
		if a.time == b.time then
			return a.order < b.order
		end

		return a.time < b.time
	end)
end

local function packArgs(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function unpackArgs(args)
	return unpack(args, 1, args.n)
end

function Scheduler.new(config)
	config = config or {}

	return setmetatable({
		_now = 0,
		_queue = {},
		_order = 0,
		_managedThreads = {},
		_runtime = config.runtime,
		_errors = {},
	}, Scheduler)
end

function Scheduler:_enqueue(time: number, kind: string, payload, args)
	self._order += 1

	local item = {
		time = time,
		order = self._order,
		kind = kind,
		payload = payload,
		args = args or packArgs(),
		cancelled = false,
	}

	table.insert(self._queue, item)
	sortQueue(self._queue)

	return item
end

function Scheduler:_resumeThread(thread, args)
	local ok, yielded = coroutine.resume(thread, unpackArgs(args))

	if not ok then
		table.insert(self._errors, yielded)
		error(yielded, 0)
	end

	if coroutine.status(thread) == "dead" then
		self._managedThreads[thread] = nil
		return
	end

	if type(yielded) == "table" and yielded._schedulerToken ~= nil then
		return
	end

	local delay = 0

	if type(yielded) == "number" then
		delay = math.max(yielded, 0)
	end

	self:_enqueue(self._now + delay, "thread", thread, packArgs(delay))
end

function Scheduler:_runItem(item)
	if item.cancelled then
		return
	end

	if item.kind == "thread" then
		self:_resumeThread(item.payload, item.args)
		return
	end

	item.payload(unpackArgs(item.args))
end

function Scheduler:_assertManagedThread(thread, debugReason: string?)
	assert(thread ~= nil, "scheduler waits require a running coroutine")

	if self._managedThreads[thread] then
		return
	end

	if debugReason ~= nil then
		error(`top-level execution yielded while {debugReason}`, 3)
	end

	error("top-level execution yielded", 3)
end

function Scheduler:canYieldCurrentThread(): boolean
	local thread = coroutine.running()

	if thread == nil then
		return false
	end

	return self._managedThreads[thread] == true
end

function Scheduler:spawn(callback, ...)
	local thread = coroutine.create(callback)
	self._managedThreads[thread] = true
	self:_enqueue(self._now, "thread", thread, packArgs(...))
	return thread
end

function Scheduler:defer(callback, ...)
	return self:_enqueue(self._now, "callback", callback, packArgs(...))
end

function Scheduler:delay(seconds: number, callback, ...)
	return self:_enqueue(self._now + math.max(seconds or 0, 0), "callback", callback, packArgs(...))
end

function Scheduler:cancel(handle)
	if handle ~= nil then
		handle.cancelled = true
	end
end

function Scheduler:wait(seconds: number?)
	local duration = math.max(seconds or 0, 0)
	self:_assertManagedThread(coroutine.running(), `waiting for {duration} seconds`)
	return coroutine.yield(duration)
end

function Scheduler:waitForSignal(signal, predicate, timeout: number?, debugReason: string?)
	local thread = coroutine.running()
	local token = {
		_schedulerToken = true,
		debugReason = debugReason,
	}

	self:_assertManagedThread(thread, debugReason)

	local connection
	local timeoutHandle

	connection = signal:Connect(function(...)
		if predicate ~= nil and not predicate(...) then
			return
		end

		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end

		if timeoutHandle ~= nil then
			timeoutHandle.cancelled = true
		end

		self:_enqueue(self._now, "thread", thread, packArgs(...))
	end)

	if timeout ~= nil then
		timeoutHandle = self:delay(timeout, function()
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end

			self:_enqueue(self._now, "thread", thread, packArgs(nil))
		end)
	end

	return coroutine.yield(token)
end

function Scheduler:flush()
	while #self._queue > 0 and self._queue[1].time <= self._now do
		local item = table.remove(self._queue, 1)
		self:_runItem(item)
	end
end

function Scheduler:advance(delta: number)
	local step = math.max(delta or 0, 0)
	self._now += step

	if step > 0 and self._runtime ~= nil and self._runtime._onSchedulerAdvanced ~= nil then
		self._runtime:_onSchedulerAdvanced(step)
	end

	self:flush()
end

function Scheduler:runAll()
	while #self._queue > 0 do
		local nextTime = self._queue[1].time

		if nextTime > self._now then
			self:advance(nextTime - self._now)
		else
			self:flush()
		end
	end
end

function Scheduler:now()
	return self._now
end

function Scheduler:inspect()
	local items = {}

	for _, item in ipairs(self._queue) do
		if not item.cancelled then
			table.insert(items, {
				time = item.time,
				kind = item.kind,
			})
		end
	end

	return items
end

return Scheduler
