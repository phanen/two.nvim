---@diagnostic disable: invisible
local n = require('nvim-test.helpers')
local Screen = require('nvim-test.screen')
local exec_lua = n.exec_lua

-- `make luals` to download ${3rd} (not bundled in emmyluals?)
describe('swap', function()
  local screen --- @type test.screen
  before_each(function()
    n.clear()
    screen = Screen.new(30, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.NvimLightGrey4 },
    })
    exec_lua(function()
      vim.opt.rtp:append('.')
      vim.keymap.set({ 'n', 'x' }, 'gs', require('two').swap, { expr = true })
    end)
  end)

  it('one-line chunk', function()
    n.api.nvim_buf_set_lines(0, 0, -1, true, {
      'aaaaaaabbbbbbbb',
      'foo + bar + baz',
      'c ddddddddddddd',
    })

    n.feed('gstbfbgs$')
    screen:expect({
      grid = [[
        bbbbbbbb^aaaaaaa               |
        foo + bar + baz               |
        c ddddddddddddd               |
        {1:~                             }|
                                      |
      ]],
    })

    n.feed('jgsiw^gsegse$gsiw')
    screen:expect({
      grid = [[
        bbbbbbbbaaaaaaa               |
        baz + foo + ^bar               |
        c ddddddddddddd               |
        {1:~                             }|
                                      |
      ]],
    })

    n.feed('kgsTb2j^gsl')
    screen:expect({
      grid = [[
        bbbbbbbbcaaa                  |
        baz + foo + bar               |
        ^aaaa ddddddddddddd            |
        {1:~                             }|
                                      |
      ]],
    })
  end)

  it('work well with unicode', function()
    n.api.nvim_buf_set_lines(0, 0, -1, true, {
      'あああ 你好',
      '🧑‍🌾❤️❤️❤️❤️❤️❤️❤️❤️❤️❤️ ❤️',
      '😂😂😂😂😂😂😂😂😂😂😂',
    })
    n.feed('2gslwgs2l')
    screen:expect {
      grid = [[
        你好あ ^ああ                   |
        🧑‍🌾❤️❤️❤️❤️❤️❤️❤️❤️❤️❤️ ❤️     |
        😂😂😂😂😂😂😂😂😂😂😂        |
        {1:~                             }|
                                      |
      ]],
    }
  end)

  it('should not index out of range when force charwise', function()
    n.api.nvim_buf_set_lines(0, 0, -1, true, {
      'aaaaaaaaa',
      '我我我我我',
      'bbbbbbbbbb',
    })
    n.feed('$gsvjjgsvj')
    screen:expect {
      grid = [[
        aaaaaaaa我                    |
        bbbbbbbb^a                     |
        我我我我bb                    |
        {1:~                             }|
                                      |
      ]],
    }
  end)
end)
