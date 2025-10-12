---@diagnostic disable: duplicate-doc-field, duplicate-set-field, duplicate-doc-alias, unused-local, undefined-field
local fn, api, lsp = vim.fn, vim.api, vim.lsp

local u = {
  key = require('two.key'),
  opfunc = require('two.opfunc'),
}

---START INJECT two.lua

local M = {}

---@type opfunc.handler
local swap = function(linewise, start_pos, end_pos)
  ---@param a lsp.Position
  ---@param b lsp.Position
  ---@return 1|0|-1
  local cmp_pos = function(a, b)
    if a.line == b.line and a.character == b.character then return 0 end
    if a.line < b.line or a.line == b.line and a.character < b.character then return -1 end
    return 1
  end

  ---@param a lsp.Range
  ---@param b lsp.Range
  ---@return 1|0|-1
  local cmp_range = function(a, b)
    local rv = cmp_pos(a.start, b.start)
    return rv ~= 0 and rv or cmp_pos(a.start, b.start)
  end

  local buf = api.nvim_get_current_buf()
  local swap_cancel = function()
    u.opfunc.cancel(buf)
    vim.b.swap_save = nil
    return true
  end

  ---@param edits [lsp.TextEdit, lsp.TextEdit]
  local function do_swap(edits)
    if cmp_pos(edits[1].range['end'], edits[2].range['end']) >= 0 then
      edits = { edits[2] }
    elseif cmp_pos(edits[1].range['end'], edits[2].range.start) > 0 then
      edits = {}
    end
    lsp.util.apply_text_edits(edits, vim._resolve_bufnr(0), 'utf-8')
    swap_cancel()
  end

  ---@type lsp.TextEdit
  local edit = (function()
    local lines = fn.getregion(fn.getpos "'[", fn.getpos "']", { type = linewise and 'V' or 'v' })
    if linewise then lines[#lines + 1] = '' end
    return {
      newText = table.concat(lines, '\r\n'),
      range = {
        start = {
          line = start_pos[1] - 1,
          character = linewise and 0 or start_pos[2],
        },
        ['end'] = {
          line = linewise and end_pos[1] or end_pos[1] - 1,
          character = linewise and 0 or end_pos[2] + vim.str_utf_end(
            api.nvim_buf_get_lines(0, end_pos[1] - 1, end_pos[1], true)[1],
            end_pos[2] + 1
          ) + 1,
        },
      },
    }
  end)()

  if not vim.b.swap_save then
    u.opfunc.mark_region(linewise, swap_cancel)
    vim.b.swap_save = edit
    return
  end

  local edits = { edit, vim.b.swap_save }
  table.sort(edits, function(a, b) return cmp_range(a.range, b.range) <= 0 end)
  edits[1].newText, edits[2].newText = edits[2].newText, edits[1].newText
  do_swap(edits)
end

---@type opfunc.handler
local diff = function(linewise, _, _)
  local buf = api.nvim_get_current_buf()
  local diff_cancel = function()
    u.opfunc.cancel(buf)
    vim.g.diff_save = nil
    return true
  end

  local lines = fn.getregion(fn.getpos "'[", fn.getpos "']", { type = linewise and 'V' or 'v' })

  if not vim.g.diff_save then
    u.opfunc.mark_region(linewise, diff_cancel)
    vim.g.diff_save = lines
    return
  end

  local side_by_side = true
  if side_by_side then
    local ft = vim.bo[buf].ft
    local create_buf = function(lines0)
      local buf0 = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf0, 0, -1, false, lines0)
      vim.bo[buf0].ft = ft
      vim.bo[buf0].bufhidden = 'wipe'
      return buf0
    end
    local buf1 = create_buf(lines)
    local buf2 = create_buf(vim.g.diff_save)
    vim.cmd(([[tabnew | b %s | vert sb %s | windo diffthis]]):format(buf1, buf2))
    diff_cancel()
    return
  end

  local newbuf = api.nvim_create_buf(false, true)
  local text = vim.split( ---@diagnostic disable-next-line: deprecated
    (vim.text.diff or vim.diff)(table.concat(lines, '\n'), table.concat(vim.g.diff_save, '\n')) --[[@as string]],
    '\n'
  )
  api.nvim_buf_set_lines(newbuf, 0, -1, false, text)
  vim.bo[newbuf].ft = 'diff'
  api.nvim_open_win(newbuf, true, {
    relative = 'win',
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    row = math.floor((vim.o.lines - vim.o.lines * 0.8) / 2),
    col = math.floor((vim.o.columns - vim.o.columns * 0.8) / 2),
    style = 'minimal',
    border = _G.border,
  })
  diff_cancel()
end

M.swap = function() return u.opfunc.run(swap) end

M.diff = function() return u.opfunc.run(diff) end

return M