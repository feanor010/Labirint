local PriorityQueue = require('priority-queue')

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local enemyKD = 0

local TYPE = {
  FLOOR = 0,
  WATER = 1,
  WALL = 100,
}

local symbols = {
  floor = string.byte('_'),
  wall = string.byte('#'),
  water = string.byte('^'),
  player = string.byte('@'),
  target = string.byte('>'),
  newline = string.byte('\n')
}

local mapData = trim [[
  ______________________
  #__________>___#____
  #_####_________####_
  #______#____________
  #____#_#_______#____
  ######_#_______#####
  ____________________
  ####_#####__########
  ####_#####__########
  ####_##_______######
  _________#_#________
  _#_#######_#######_#
  _#_#________#____#_#
  _#____#_____#____#_#
  _#_####_____###__#_#
  _@__________________
]]



local function l1(src, dst)
  -- l1 метрика aka Манхеттенское расстояние
  return math.abs(src.x - dst.x) + math.abs(src.y - dst.y)
end

local function parseWorld(data)
  local map = {}
  local playerPos = nil
  local targetPos = nil

  local x = 1
  local y = 1

  table.insert(map, {}) -- first line

  for i = 1, #data do
    local cell = data:byte(i)

    if cell == symbols.newline then
      y = y + 1
      x = 1
      table.insert(map, {})
    else
      if cell == symbols.player then
        playerPos = { x = x, y = y }
        table.insert(map[y], { id = i, cost = 1, x = x, y = y, type = TYPE.FLOOR })
      elseif cell == symbols.target then
        targetPos = { x = x, y = y }
        table.insert(map[y], { id = i, cost = 1, x = x, y = y, type = TYPE.FLOOR })
      elseif cell == symbols.wall then
        table.insert(map[y], { id = i, cost = -1, x = x, y = y, type = TYPE.WALL })
      elseif cell == symbols.water then
        table.insert(map[y], { id = i, cost = 3, x = x, y = y, type = TYPE.WATER })
      else
        table.insert(map[y], { id = i, cost = 1, x = x, y = y, type = TYPE.FLOOR })
      end
      x = x + 1
    end
  end

  return { map = map, player = playerPos, target = targetPos }
end

local function neighbors(map, pos)
  local candidates = {
    { x = pos.x - 1, y = pos.y },
    { x = pos.x,     y = pos.y - 1 },
    { x = pos.x + 1, y = pos.y },
    { x = pos.x,     y = pos.y + 1 },
  }
  local result = {}
  local width = #map[1]
  local height = #map
  for _, candidate in ipairs(candidates) do
    if (candidate.x >= 1 and candidate.y >= 1 and candidate.x <= width and candidate.y <= height) then
      local cell = map[candidate.y][candidate.x]
      if cell.cost >= 0 then
        table.insert(result, cell)
      end
    end
  end
  return result
end

local world = nil
local search = nil
local UI = {
  bw = 32,
  bh = 32,
  pr = 12,
  tr = 12,
  dr = 4,
  padding = 2,
}

local function drawPos(x, y)
  local posX = x * (UI.bw + UI.padding)
  local posY = y * (UI.bh + UI.padding)
  return posX, posY
end

local function drawPosCircle(x, y, r)
  local posX, posY = drawPos(x, y)
  return posX + UI.bw / 2, posY + UI.bh / 2
end
local path = {}
local function aStarSearch(world)
  path = {}
  local start = world.map[world.target.y][world.target.x]
  start.visited = true
  start.from = nil
  start.costGot = 0

  local queue = PriorityQueue.new()
  queue:Add(start, 0)

  local function next()
    if queue:Size() < 1 then
      return false
    end

    local cur = queue:Pop()

    -- ранний выход
    if cur.x == world.player.x and cur.y == world.player.y then
      return false
    end

    local nlist = neighbors(world.map, cur)
    for _, n in ipairs(nlist) do
      local newCost = n.cost + (cur.costGot or 0)
      if n.visited ~= true or newCost < (n.costGot or 0) then
        n.visited = true
        table.insert(path, n)
        n.from = cur
        n.costGot = newCost
        local priority = newCost + l1(world.player, n)
        queue:Add(n, -priority)
      end
    end

    return true
  end

  return { next = next, path = path }
end


function love.load()
  world = parseWorld(mapData)
end

local searchkd = 0
local kd = 0;
local time = 0
local hasNext = true

function love.update(dt)
  if searchkd <= 0 then
    search = aStarSearch(world)
    searchkd = 5
  else
    searchkd = searchkd - dt
  end
  --[[  if world.path ~= nil then
    for k, n in world.path do
      world.target.x = n.x
      world.target.y = n.y
    end
  end ]]
  local cel = #search.path

  if enemyKD > 0 then
    enemyKD = enemyKD - dt
  end
  if kd > 0 then
    kd = kd - dt
  else
    if path[cel] ~= nil and enemyKD <= 0
    then
      world.target.x = path[cel].x
      world.target.y = path[cel].y
      cel = cel - 1
      enemyKD = 0.3
    end
  end


  if love.keyboard.isDown("right") and kd <= 0 then
    if world.player.x + 1 > #world.map[1] then
      world.player.x = 1
    elseif world.map[world.player.y][world.player.x + 1].type == TYPE.FLOOR then
      world.player.x = world.player.x + 1;
      kd = 0.2
    end
  elseif love.keyboard.isDown("up") and kd <= 0 then
    if world.player.y - 1 < 1 then
      world.player.y = #world.map
    elseif world.map[world.player.y - 1][world.player.x].type == TYPE.FLOOR then
      world.player.y = world.player.y - 1;
      kd = 0.2
    end
  elseif love.keyboard.isDown("down") and kd <= 0 then
    if world.player.y + 1 > #world.map then
      world.player.y = 1
    elseif world.map[world.player.y + 1][world.player.x].type == TYPE.FLOOR then
      world.player.y = world.player.y + 1;
      kd = 0.2
    end
  elseif love.keyboard.isDown("left") and kd <= 0 then
    if world.player.x - 1 < 1 then
      world.player.x = #world.map[1]
    elseif world.map[world.player.y][world.player.x - 1].type == TYPE.FLOOR then
      world.player.x = world.player.x - 1;
      kd = 0.2
    end
  end

  if hasNext then
    hasNext = search.next()
  end
end

local floorImage = love.graphics.newImage("Floor.jpg")
local kripWall = love.graphics.newImage("krip.jpg")

function love.draw()
  for y, line in ipairs(world.map) do
    for x, cell in ipairs(line) do
      local bx, by = drawPos(x, y)
      if cell.type == TYPE.FLOOR then
        if cell.visited == true then
          love.graphics.setColor(0, 0.3, 0)
        else
          love.graphics.setColor(0, 1, 0)
        end
      elseif cell.type == TYPE.WATER then
        if cell.visited == true then
          love.graphics.setColor(0, 0, 0.3)
        else
          love.graphics.setColor(0, 0, 1)
        end
      else
        love.graphics.setColor(1, 0, 0)
      end

      love.graphics.rectangle('fill', bx, by, UI.bw, UI.bh)
    end
  end

  local px, py = drawPosCircle(world.player.x, world.player.y, UI.pr)
  love.graphics.setColor(1, 0, 1)
  love.graphics.circle('fill', px, py, UI.pr)

  local tx, ty = drawPosCircle(world.target.x, world.target.y, UI.tr)
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle('fill', tx, ty, UI.tr)

  if world.path ~= nil then
    for _, d in ipairs(world.path) do
      local dx, dy = drawPosCircle(d.x, d.y, UI.dr)
      love.graphics.setColor(1, 1, 1)
      love.graphics.circle('fill', dx, dy, UI.dr)
    end
  end
end
