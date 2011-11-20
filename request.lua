local M = {}; M.__index = M

local function construct(socket)
  local self = setmetatable({
							  cli_headers = {},
							  test='test'
							}, M)
  self.lines = {}
  self.data = ''
  return self
end
setmetatable(M, {__call = construct})

function M:parse_request_line(line)
  if not self.method then
	_,_,self.method,self.uri,self.proto = line:find('^([A-Z]*) ([^ ]*) (HTTP/1.%d)$')
	if self.method then
	  self.request_line = line
	  if self.proto and self.proto ~= 'HTTP/1.0' then
		self.socket:write('HTTP/1.1 100 Continue\r\n\r\n')
	  end
	  return true
	else
	  -- HTTP/1.0 maybe?
	  _,_,self.method,self.uri = string.find(line, '^([A-Z]*) ([^ ]*)$')
	  if not self.method then
		-- Nope, just bad
		log('Bad request')
		buzz.error(self, 400, '')
		return nil
	  else
		self.request_line = line
		self.proto = 'HTTP/1.0'
		return true
	  end
	end
  else
	log('Already parsed request line')
	return nil
  end
end

function M:parse_request()
  local lines = self.lines
  if #lines == 0 then
	return false
  end
  if not self:parse_request_line(self.lines[1]) then
	return false
  end
  for l=2,#lines do
	local _,_, header, value = string.find(lines[l], '([^:]*): (.*)')
	if header then
	  self.cli_headers[header:lower()] = value
	else
	  log('error parsing header '..lines[l])
	  return false
	end
  end
  self.valid = true
  return true
end

function M:check_data_complete()
  if not self.cli_headers['content-length'] then
    return true
  end
  if #self.data >= tonumber(self.cli_headers['content-length']) then
    self.data_complete = true
  end
  return self.data_complete
end

function M:add_data(buf)
  self.data = self.data .. buf
  if self.headers_complete then
    self:check_data_complete()
  elseif not self.headers_complete then
	repeat
	  local pos = string.find(self.data, '\r\n')
	  if pos then
		if pos == 1 then
		  self.headers_complete = true
          self:parse_request()
		  self.data = self.data:sub(pos + 2)
          self:check_data_complete()
          return;
		elseif not self.headers_complete then
		  self.lines[#self.lines + 1] = self.data:sub(1, pos - 1)
		  self.data = self.data:sub(pos + 2)
		end
	  end
	until not pos
  end
end

return M
