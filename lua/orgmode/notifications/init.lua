local Date = require('orgmode.objects.date')
local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local utils = require('orgmode.utils')
local NotificationPopup = require('orgmode.notifications.notification_popup')

---@class Notifications
---@field timer table
local Notifications = {}

function Notifications:new()
  local data = {
    timer = nil,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Notifications:start_timer()
  self:stop_timer()
  self.timer = vim.loop.new_timer()
  self:notify(Date.now():start_of('minute'))
  self.timer:start((60 - os.date('%S')) * 1000, 60000, vim.schedule_wrap(function()
    self:notify(Date.now())
  end))
end

function Notifications:stop_timer()
  if self.timer then
    self.timer:close()
    self.timer = nil
  end
end

---@param time Date
function Notifications:notify(time)
  local tasks = self:get_tasks(time)
  local result = {}
  for _, task in ipairs(tasks) do
    utils.concat(result, {string.format('# %s (in %d min.)', task.category, task.minutes), task.line, string.format('%s: %s', task.type, task.time:to_string())})
  end

  if not vim.tbl_isempty(result) then
    NotificationPopup:new({ content = result })
  end
end

function Notifications:cron()
  local tasks = self:get_tasks(Date.now():start_of('minute'))
  for _, task in ipairs(tasks) do
    if type(config.notifications.cron_notifier) == 'function' then
      config.notifications.cron_notifier(task)
    else
      self:_cron_notifier(task)
    end
  end
  vim.cmd[[qall!]]
end

---@param task table
function Notifications:_cron_notifier(task)
  if vim.fn.executable('notify-send') then
    return vim.loop.spawn('notify-send', { args = {
      string.format('%s (in %d min.)\n%s\n%s: %s', task.category, task.minutes, task.line, task.type, task.time:to_string()),
    }})
  end

  if vim.fn.executable('terminal-notifier') then
    return vim.loop.spawn('terminal-notifier', { args = {
      '-title',
      string.format('%s (in %d min.)', task.category, task.minutes),
      '-subtitle',
      task.line,
      '-message',
      string.format('%s: %s', task.type, task.time:to_string())
    }})
  end
end

---@param time Date
function Notifications:get_tasks(time)
  local tasks = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:get_opened_unfinished_headlines()) do
      for _, date in ipairs(headline:get_deadline_and_scheduled_dates()) do
        local reminders = self:_check_reminders(date, time)
        for _, reminder in ipairs(reminders) do
          table.insert(tasks, {
            file = headline.file,
            todo = headline.todo_keyword.value,
            line = headline.line,
            category = headline.category,
            priority = headline.priority,
            title = headline.title,
            tags = headline.tags,
            original_time = date,
            time = reminder.time,
            reminder_type = reminder.reminder_type,
            minutes = reminder.minutes,
            type = date.type,
          })
        end
      end
    end
  end

  return tasks
end

---@param date Date - date to check
---@param time Date - time to check agains
---@returns table|nil
function Notifications:_check_reminders(date, time)
  local result = {}
  local notifications = config.notifications
  if date:is_deadline() and not notifications.deadline_reminder then
    return result
  end
  if date:is_scheduled() and not notifications.scheduled_reminder then
    return result
  end

  if notifications.repeater_reminder_time and date:get_repeater() then
    local repeater_time = date:apply_repeater_until(time)
    local times = utils.ensure_array(notifications.repeater_reminder_time)
    local minutes = repeater_time:diff(time, 'minute')
    if vim.tbl_contains(times, minutes) then
      table.insert(result, { reminder_type = 'repeater', time = repeater_time, minutes = minutes })
    end
  end

  if notifications.deadline_warning_reminder_time and date:is_deadline() and date:get_negative_adjustment() then
    local warning_time = date:with_negative_adjustment()
    local times = utils.ensure_array(notifications.deadline_warning_reminder_time)
    local minutes = warning_time:diff(time, 'minute')
    if vim.tbl_contains(times, minutes) then
      table.insert(result, { reminder_type = 'warning', time = warning_time, minutes = minutes })
    end
  end

  if notifications.reminder_time then
    local times = utils.ensure_array(notifications.reminder_time)
    local minutes = date:diff(time, 'minute')
    if vim.tbl_contains(times, minutes) then
      table.insert(result, { reminder_type = 'time', time = date, minutes = minutes })
    end
  end

  return result
end


return Notifications
