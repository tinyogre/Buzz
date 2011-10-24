local M = {}; M.__index = M

local function construct(socket)
  local self = setmetatable({
							  cli_headers = {},
							  test='test'
							}, M)
  return self
end
setmetatable(M, {__call = construct})

return M
