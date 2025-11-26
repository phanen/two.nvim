---@diagnostic disable: invisible
local n = require('nvim-test.helpers')
local Screen = require('nvim-test.screen')
local exec_lua = n.exec_lua
describe('misc', function()
  local screen --- @type test.screen
  before_each(function()
    n.clear()
    screen = Screen.new(30, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.NvimLightGrey4 },
    })
    exec_lua(function() vim.opt.rtp:append('.') end)
  end)
  it('sort', function()
    exec_lua(function()
      vim.keymap.set({ 'n', 'x' }, 'gs', require('two').sort, { expr = true })
      vim.api.nvim_buf_set_lines(0, 0, -1, true, {
        'aaaaaaabbbbbbbb',
        'foo + bar + baz',
        'c ddddddddddddd',
      })
    end)
    n.feed('gsG')
    screen:expect {
      grid = [[
        ^aaaaaaabbbbbbbb               |
        c ddddddddddddd               |
        foo + bar + baz               |
        {1:~                             }|
                                      |
      ]],
    }
    n.feed('u')
  end)
end)
