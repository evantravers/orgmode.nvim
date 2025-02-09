local mock = require('luassert.mock')
local File = require('orgmode.parser.file')
local Date = require('orgmode.objects.date')

describe('Org file', function()
  it('should properly add new properties to a section', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(true)
    local section = parsed:get_section(1)
    section:add_properties({ CATEGORY = 'testing' })
    assert.stub(api.nvim_call_function).was_called_with(
      'append',
      { 2, {
        '  :PROPERTIES:',
        '  :CATEGORY: testing',
        '  :END:',
      } }
    )
    mock.revert(api)
  end)

  it('should properly append to existing properties', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :END:',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[3])
    local section = parsed:get_section(1)
    section:add_properties({ CUSTOM_ID = '1' })
    assert.stub(api.nvim_call_function).was.called_with('append', { 3, '  :CUSTOM_ID: 1' })
    mock.revert(api)
  end)

  it('should properly update existing property', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :END:',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[3])
    local section = parsed:get_section(1)
    section:add_properties({ CATEGORY = 'Newvalue' })
    assert.stub(api.nvim_call_function).was.called_with('setline', { 4, '  :CATEGORY: Newvalue' })
    mock.revert(api)
  end)

  it('should add closed date to section if it does not exist', function()
    local now = Date.now():to_string()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    local section = parsed:get_section(1)
    section:add_closed_date()
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      'DEADLINE: <2021-05-10 11:00> CLOSED: [' .. now .. ']',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00> CLOSED: [' .. now .. ']',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    section = parsed:get_section(1)
    local no_result = section:add_closed_date()
    assert.are.same(nil, no_result)
    mock.revert(api)
  end)

  it('should remove closed date from section if it exists', function()
    local now = Date.now():to_string()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00> CLOSED: [' .. now .. ']',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    local section = parsed:get_section(1)
    local result = section:remove_closed_date()
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      'DEADLINE: <2021-05-10 11:00>',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    section = parsed:get_section(1)
    result = section:remove_closed_date()
    assert.are.same(nil, result)

    lines = {
      '* TODO Test orgmode :WORK:',
      'CLOSED: [' .. now .. ']',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    section = parsed:get_section(1)
    api.nvim_get_current_buf.returns(4)
    section:remove_closed_date()
    assert.stub(api.nvim_call_function).was.called_with('deletebufline', { 4, 2 })
    mock.revert(api)
  end)

  it('should add and update deadline date', function()
    local deadline_date = Date.from_string('2021-08-18 Wed')
    local lines = {
      '* TODO Test orgmode :WORK:',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(true)
    local section = parsed:get_section(1)
    local result = section:add_deadline_date(deadline_date)
    assert.are.same(true, result)
    assert.stub(api.nvim_call_function).was.called_with('append', {
      1,
      '  DEADLINE: <2021-08-18 Wed>',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed>',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    section = parsed:get_section(1)
    api.nvim_call_function.returns('  DEADLINE: <2021-08-18 Wed>')
    result = section:add_deadline_date(deadline_date:add({ day = 2 }))
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      '  DEADLINE: <2021-08-20 Fri>',
    })
    mock.revert(api)
  end)

  it('should add and update scheduled date', function()
    local scheduled_date = Date.from_string('2021-08-18 Wed')
    local lines = {
      '* TODO Test orgmode :WORK:',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(true)
    local section = parsed:get_section(1)
    local result = section:add_scheduled_date(scheduled_date)
    assert.are.same(true, result)
    assert.stub(api.nvim_call_function).was.called_with('append', {
      1,
      '  SCHEDULED: <2021-08-18 Wed>',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed>',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    section = parsed:get_section(1)
    result = section:add_scheduled_date(scheduled_date:add({ day = 2 }))
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      '  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-20 Fri>',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-18 Wed>',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    section = parsed:get_section(1)
    api.nvim_call_function.returns('  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-18 Wed>')
    result = section:add_scheduled_date(scheduled_date:add({ day = 4 }))
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      '  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-22 Sun>',
    })
    mock.revert(api)
  end)

  it('should change the priority when it already exists', function()
    local lines = { '* TODO [#A] Item with priority' }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[1])

    local section = parsed:get_section(1)
    section:set_priority('B')
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      1,
      '* TODO [#B] Item with priority',
    })
    assert.are.same(section.priority, 'B')

    mock.revert(api)
  end)

  it('should change add a priority when it does not exist', function()
    local lines = { '* TODO Item with priority' }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[1])

    local section = parsed:get_section(1)
    section:set_priority('A')
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      1,
      '* TODO [#A] Item with priority',
    })
    assert.are.same(section.priority, 'A')

    mock.revert(api)
  end)

  it('should remove a priority if called with an space', function()
    local lines = { '* TODO [#A] Item with priority' }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[1])

    local section = parsed:get_section(1)
    section:set_priority(' ')
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      1,
      '* TODO Item with priority',
    })
    assert.are.same(section.priority, '')

    mock.revert(api)
  end)

  it('should remove a priority if called with an empty string', function()
    local lines = { '* TODO [#A] Item with priority' }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[1])

    local section = parsed:get_section(1)
    section:set_priority('')
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      1,
      '* TODO Item with priority',
    })
    assert.are.same(section.priority, '')

    mock.revert(api)
  end)
end)
