--!native
--!strict
local Janitor = require(script.Parent.janitor)

type LinkableObject = {
	[string]: (...any) -> nil;
	Destroy: ((any) -> ())?;
}

local function createLinker(object: LinkableObject?)
	object = object or {}
	assert(typeof(object) == "table")
	
	local janitor = Janitor.new()
	local function updateLinks(): nil
		for name: string, fn in pairs(object) do
			if typeof(fn) ~= "function" then continue end
			if not name:match("_") then continue end

			local serviceName, eventName = table.unpack(name:split("_"))
			local success, service = pcall(function()
				return game:GetService(`{serviceName}Service`)
			end)

			if not success then
				local success, newService = pcall(function()
					return game:GetService(serviceName)
				end)

				assert(success, `Could not find service "{serviceName}" or "{serviceName}Service"!`)
				service = newService
			end

			(janitor.Add :: any)(janitor, service[eventName]:Connect(function(...)
				fn(object, ...)
			end))
		end
		return
	end
	
	local destroyObject = object.Destroy
	function object:Destroy()
		if destroyObject then
			destroyObject(self)
		end
		(janitor.Destroy :: any)(janitor)
	end
	
	updateLinks()
	return setmetatable(object, {
		__newindex = function(_, key, value)
			(janitor.Cleanup :: any)(janitor)
			object[key] = value
			updateLinks()
		end
	})
end

return createLinker