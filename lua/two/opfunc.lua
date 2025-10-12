local api = vim.api
---START INJECT opfunc.lua

local M = {}

---@alias opfunc.mode "char"|"line"|"block"
---@alias opfunc.pos [integer, integer]
---@alias opfunc.handler fun(linewise: boolean, start_pos: opfunc.pos, end_pos: opfunc.pos)

local ns = api.nvim_create_namespace('u.opfunc')
local hl = { name = 'OpfuncRegion', link = 'Search' }
api.nvim_set_hl(0, hl.name, { link = hl.link, default = true })

M.state = {
  op = nil, ---@type opfunc.handler?
  cancel_callback = nil, ---@type function?
}

---@param mode opfunc.mode
---@return boolean, opfunc.pos, opfunc.pos
local get_context = function(mode)
  if mode == 'block' then error('[opfunc] blockwise unsupported') end
  local linewise = mode == 'line'
  local start_pos, end_pos = api.nvim_buf_get_mark(0, '['), api.nvim_buf_get_mark(0, ']')
  return linewise, start_pos, end_pos
end

---@param buf integer
M.cancel = function(buf)
  api.nvim_buf_clear_namespace(buf or 0, ns, 0, -1)
  u.key.pop(ns, 'n', '<esc>')
end

---@param linewise boolean
---@param callback function
M.mark_region = function(linewise, callback)
  local cancel = M.state.cancel_callback
  if cancel then cancel() end -- handle pending cancel cb
  M.state.cancel_callback = callback
  vim.hl.range(0, ns, hl.name, "'[", "']", {
    regtype = linewise and 'V' or 'v',
    inclusive = true,
  })
  u.key.push(ns, 'n', '<esc>', callback)
  api.nvim_buf_attach(0, false, { on_lines = callback })
end

---@param mode opfunc.mode
function M.opfunc(mode)
  local op = M.state.op
  if op then op(get_context(mode)) end
end

_G._U_OPFUNC = M.opfunc

---@param op opfunc.handler
---@return string
function M.run(op)
  local motion = api.nvim_get_mode().mode:match('[vV\022]') and '`<' or ''
  M.state.op = op
  if vim.o.opfunc ~= 'v:lua._U_OPFUNC' then vim.o.opfunc = 'v:lua._U_OPFUNC' end
  return 'g@' .. motion
end

return M