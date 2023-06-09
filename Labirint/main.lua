local PriorityQueue = require('priority-queue')

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local enemyKD = 0

local player = {
  scores = 0
}

local eat = {

}

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

local world

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

local function drawPosEat(x, y, r)
  local posX, posY = drawPos(x, y)
  return posX + UI.bw / 2, posY + UI.bh / 2
end

local function aStarSearch(world)
  local start = world.map[world.player.y][world.player.x]
  for x = 1, #world.map[1] do
    for y = 1, #world.map do
      world.map[y][x].visited = false
      --[[ world.map[y][x].from = nil ]]
      world.map[y][x].costGot = 0
      print(world.map[y][x].from)
    end
  end
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
    if cur.x == world.target.x and cur.y == world.target.y then
      return false
    end

    local nlist = neighbors(world.map, cur)
    for _, n in ipairs(nlist) do
      local newCost = n.cost + (cur.costGot or 0)
      if n.visited ~= true or newCost < (n.costGot or 0) then
        n.visited = true
        n.from = cur
        n.costGot = newCost
        local priority = newCost + l1(world.target, n)
        queue:Add(n, -priority)
      end
    end

    return true
  end

  return { next = next }
end
local mas1 = {}
local mas = {}
local function backPath(world)
  mas1 = {}
  local cur = world.map[world.target.y][world.target.x]
  local done = false
  local path = {}
  while not done do
    table.insert(path, cur)
    table.insert(mas1, cur)
    local prev = cur.from
    if prev.from == nil then
      done = true
    else
      cur = prev
    end
  end
  world.path = path
end


function love.load()
  world = parseWorld(mapData)
  search = aStarSearch(world)
end

local searchkd = 0
local kd       = 0;
local time     = 0
local hasNext  = true
local k        = 2
local w        = 1
function love.update(dt)
  for i, j in ipairs(eat) do
    if j.x == world.player.x and j.y == world.player.y then
      player.scores = player.scores + 100
      DeleteEl(i, eat)
    end
  end
  function DeleteEl(pos, arr)
    if (arr ~= nil) then
      arr[pos], arr[#arr] = arr[#arr], arr[pos]
      table.remove(arr, #arr)
    end
  end

  if world.map[1] then
    if w == 1 then
      for i = 1, 5 do
        local x = love.math.random(1, #world.map[1])
        local y = love.math.random(1, #world.map)
        if world.map[y][x].type ~= TYPE.WALL then
          local tar = { x = x, y = y }
          table.insert(eat, tar)
        end
      end
      w = w + 1
    end
  end

  if hasNext then
    hasNext = search.next()
    if not hasNext then
      search = aStarSearch(world)
      mas = mas1
      k = 2
      backPath(world)
      hasNext = true
    end
  end

  if enemyKD > 0 then
    enemyKD = enemyKD - dt
  end
  if kd > 0 then
    kd = kd - dt
  end


  if enemyKD <= 0 and mas[k] ~= nil then
    world.target.x = mas[k].x
    world.target.y = mas[k].y
    enemyKD = 0.3
    k = k + 1
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
end

local floorImage = love.graphics.newImage("Floor.jpg")
local kripWall = love.graphics.newImage("krip.jpg")
local apple = love.graphics.newImage("apple.jpg")

function love.draw()
  for y, line in ipairs(world.map) do
    for x, cell in ipairs(line) do
      local bx, by = drawPos(x, y)
      if cell.type == TYPE.FLOOR then
        love.graphics.draw(floorImage, bx, by)
      else
        love.graphics.draw(kripWall, bx, by)
      end
    end
  end
  local px, py = drawPosCircle(world.player.x, world.player.y, UI.pr)
  love.graphics.setColor(1, 0, 1)
  love.graphics.circle('fill', px, py, UI.pr)
  local tx, ty = drawPosCircle(world.target.x, world.target.y, UI.tr)
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle('fill', tx, ty, UI.tr)
  love.graphics.setColor(256, 256, 256)
  love.graphics.print("Your score = " .. tostring(player.scores))
  love.graphics.setColor(255, 255, 0)
  for _, j in ipairs(eat) do
    local kx, ky = drawPosEat(j.x, j.y, UI.pr)

    love.graphics.circle('fill', kx, ky, UI.tr - 3)
  end
  love.graphics.setColor(255, 255, 255)
end
