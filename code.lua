-- settings
musicMuted = false
sfxMuted = false

-- sprite IDs for numbers
digitSpriteIDs = {}

-- turns left
turnCount = 0
lastTurn = 0
turn = true

--       1   2   ...
turns = {17, 39, 17, 14, 21, 50, 23, 31, 41} -- turns per level
levelNames = {"1. One at a time", "3. Locked Out", "4. Down the Waterspout", "7. Hurtful", "6. Sheltered", "8. Break Away", "2. Enter the Dungeon", "5. Roundabout", "9. The Road Not Taken"}
textDisplay = nil -- top right for level name
textDisplayFaded = false

-- The levels are stored on the tilemap, but needed to be reordered due to difficult spikes
-- The tilemap editor cannot move blocks of sprites, so they are ordered here instead
levelOrder = {1, 7, 2, 3, 8, 5, 4, 6, 9}

completedLevels = 0

-- whether or not current item is highlighted. Flashes when attempting to use invalid item
itemSelectorHighlight = false

-- tiles of the current level
tiles = {}

-- stores the locations of keys/doors/arrows separately
keyDoorPairs = {
  keys = {},
  doors = {} -- indexed by colorOffset
}
arrows = {
  dirs = {},  --   0       N
              -- 3   1   W   E
              --   2       S
  tiles = {},
  used = {}
}

particles = {}

coroutines = {}

-- store the time between frames
deltaTime = 1

player =
{
  -- called on spawn/restart
  init =
    function()
      player.health = 2
      -- player.tilePos = currentSpawnTile
      player.tilePos[1] = currentSpawnTile[1]
      player.tilePos[2] = currentSpawnTile[2]
      player.pos = {player.tilePos[1] * 16, player.tilePos[2] * 16}
	  
	  -- get rid of items
      for k in pairs (player.itemStack) do player.itemStack[k] = nil end
    end
  ,

  setHealth =
    function(hp)
      player.health = hp
      if hp <= 0 then player.willDie = true end
    end
  ,

  state = 0,
  
  -- inventory (LIFO)
  itemStack = {},
  pushItem =
    function(item)
      if #player.itemStack < 8 then table.insert(player.itemStack, item) end
    end
  ,
  popItem =
    function()
      return #player.itemStack > 0 and table.remove(player.itemStack)
    end
  ,
  peekItem =
    function()
      return #player.itemStack > 0 and player.itemStack[#player.itemStack]
    end
  ,

  -- current position in pixels (16 per tile)
  pos = {0, 0},
  -- current tile
  tilePos = {0, 0},

  setTilePos =
    function(x, y)
      player.pos[1] = 16 * x
      player.pos[2] =  16 * y
      player.tilePos[1] = x
      player.tilePos[2] = y
      player.newPos[1] = x
      player.newPos[2] = y
    end
  ,

  -- these values and functions make sure actions happen in the correct order
  -- 1. check if player is being forced to move, if so disable player input
  -- 2. check if player is going to win, if so complete the level
  -- 3. move to new position
  -- 4. if the player is going to die, die
  -- 5. otherwise, swap the fires, reduce the turn count by 1, and kill the player if the # of turns remaining <= 0
  newPos = {0, 0},
  didTurn = false,
  willDie = false,
  willWin = false,
  beingForced = false,
  willBeForced = false,
  colorShift = 0,
  completelyFrozen = false,

  startTurn =
    function()
      player.newPos[1] = player.tilePos[1]
      player.newPos[2] = player.tilePos[2]
      player.didTurn = false
      player.willDie = false
      player.willWin = false
    end
  ,

  act =
    function()
      if player.beingForced or player.completelyFrozen then return end
      if player.willBeForced then player.beingForced = true ; player.willBeForced = false end
      if player.willWin then player.setTilePos(player.newPos[1], player.newPos[2]) ; CompleteLevel() return end
      if player.newPos[1] ~= player.tilePos[1] or player.newPos[2] ~= player.tilePos[2] then player.setTilePos(player.newPos[1], player.newPos[2]) end
      if player.willDie then player.setTilePos(player.newPos[1], player.newPos[2]) ; SwapFires() ; PlayerDied() return end
      if player.didTurn then
        SwapFires()
        turnCount = turnCount - 1
        if turnCount <= 0 then PlayerDied() end
      end
    end
  ,

  forceMove =
    function(x, y)

      if player.completelyFrozen then return end

      local targetx = player.tilePos[1] + x
      local targety = player.tilePos[2] + y

      if not (targetx < 0 or targety < 0 or targetx > 11 or targety > 11) then
        local targetTile = GetTileAt(targetx, targety)

        player.attemptInteract(targetx, targety)
        player.didTurn = false

        if (not IsSolid(targetTile)) and not IsCheese(targetTile) then

          if not IsEnemy(targetTile) then player.setTilePos(targetx, targety) end

        end
      end
    end
  ,

  move =
    function(x, y)
      
      if player.beingForced or player.completelyFrozen then return end

      local targetx = player.tilePos[1] + x
      local targety = player.tilePos[2] + y
      if not (targetx < 0 or targety < 0 or targetx > 11 or targety > 11) then
        local targetTile = GetTileAt(targetx, targety)
		
        player.attemptInteract(targetx, targety)

        if (not IsSolid(targetTile)) and not IsCheese(targetTile) then

            if not IsEnemy(targetTile) and not IsKey(targetTile) then player.newPos[1] = targetx ; player.newPos[2] = targety ; player.didTurn = true end

        end

      end

    end

  ,
  attemptInteract =
    function(x, y)
      local check = GetTileAt(x, y)

      -- item 
      if IsItem(check) then
        -- player.pushItem(check)
        -- TempRemoveTileAt(x, y)

        -- PlaySfx(7)

      -- enemy
      elseif IsEnemy(check) then
        player.didTurn = true

        local item = player.peekItem()

        -- has weapon, kill enemy
        if item and IsWeapon(item) then
          TempRemoveTileAt(x, y)
          player.popItem()

          PlaySfx(10)
          DrawParticle(x * 16, y * 16, 76, 350)

        -- no weapon, hurt player and push enemy if tile empty
        else
          if player.health > 1 then PlaySfx(8) end
		  
          local a = 2 * x - player.tilePos[1]
          local b = 2 * y - player.tilePos[2]

          if IsEmpty(GetTileAt(a, b)) then
            tiles[a][b] = check
            TempRemoveTileAt(x, y)
          end
          player.setHealth(player.health - 1)
          DrawParticle(player.newPos[1] * 16, player.newPos[2] * 16 - 8, 160, 200)
        end

	  -- breakable wall
      elseif IsBreakable(check) then
		-- if we have a pickaxe, break the wall
        local item = player.peekItem()
        if item then
          if IsPick(item) then
            player.didTurn = true
            TempRemoveTileAt(x, y)
            player.popItem()
            DrawParticle(x * 16, y * 16, 76, 350)
            PlaySfx(12)

            for r = 0, 11, 1 do
              for c = 0, 11, 1 do
                local id = tiles[c][r]
                if id == 68 then
                  if (player.tilePos[1] == c) and (player.tilePos[2] == r) then
                    if player.health > 1 then PlaySfx(13) ; DrawParticle(x * 16, y * 16 - 8, 160, 200) end
                    player.setHealth(player.health - 1)
                  end
                end
              end
            end
		
		  -- if we have a non-pickaxe item, then flash the indicator
          else
            PlaySfx(14)
            itemSelectorHighlight = true
            DoAfterTime(500, function() itemSelectorHighlight = false end)
            DoAfterTime(1000, function() itemSelectorHighlight = true end)
            DoAfterTime(1500, function() itemSelectorHighlight = false end)
          end

        end
          

      -- cheese
      elseif IsCheese(check) then
        player.didTurn = false
        player.willWin = true
        player.newPos[1] = x
        player.newPos[2] = y

      -- key
      elseif IsKey(check) then
        player.didTurn = true
        for offset, tile in pairs(keyDoorPairs.keys) do
          if(tile[1] == x and tile[2] == y) then
            PlaySfx(9)
            TempRemoveTileAt(x, y)
            local d = keyDoorPairs.doors[offset]
            TempRemoveTileAt(d[1], d[2])
            table.remove(keyDoorPairs.keys, offset)
            table.remove(keyDoorPairs.doors, offset)
            break
          end
        end
        
      -- if going onto inactive fire, take dmg because it will be active when we move onto it
      elseif ((check == 68) and not player.beingForced) or ((check == 70) and player.beingForced) then

        if player.health > 1 then PlaySfx(13) ; DrawParticle(x * 16, y * 16 - 8, 160, 200) end
        player.setHealth(player.health - 1)

      -- arrow
      else
        local aI = GetArrowIndexAtPosition(x, y)
        if not aI then return end
        local dir = DirToVector(arrows.dirs[aI])
        if arrows.used[aI] then return end
        player.willBeForced = true
        PlaySfx(15)
        arrows.used[aI] = true

        DoAfterTime(100, function()
          player.forceMove(dir[1], dir[2])
          player.beingForced = false
          player.act()
        end
        )
      
      end

    end
}

currentLevel = 1
currentSpawnTile = {0, 0}

-- input
allowUp = true
allowRight = true
allowDown = true
allowLeft = true
allowA = true
allowB = true

screenRect = nil

selectedChoice = 0
mainMenuChoices = {} -- play, levelselect, options, exit?
optionsChoices = {} -- mute sfx, music

currentInputState = 1 -- 0: game, 1: main menu, 2: options, 3: level select, 4: end

endScreenOrbitAngle = 0

currentAudioChannel = 1 -- swap audio channels to have multiple sounds at once

function Init()
    -- Here we are manually changing the background color
  BackgroundColor(0)

  mainMenuChoices = {StartGame, OpenLevelSelect, OpenOptions, ExitGame} -- play, levelselect, options, exit?
  optionsChoices = {MuteSfx, MuteMusic}

  -- read the save data. on standalone builds the saves don't work(?)
  local saveData = {
    ReadSaveData("sfxMuted", false) == "true",
    ReadSaveData("musicMuted", false) == "true",
    tonumber(ReadSaveData("completedLevels", 0))
  }

  sfxMuted = saveData[1]
  musicMuted = saveData[2]
  completedLevels = saveData[3]

  local display = Display()

  screenRect = NewRect(0, 0, display.x, display.y - 32)

  -- clear tiles
  for r = 0, 11, 1 do
    tiles[r] = {}
    for c = 0, 11, 1 do
      tiles[r][c] = 192
    end
  end

  digitSpriteIDs = {104, 106, 108, 110, 134, 136, 138, 140, 142}
  digitSpriteIDs[0] = 102
  turns[0] = 999

  OpenMainMenu()

end

function StartGame()

  currentInputState = 0
  LoadLevel(currentLevel)
  player.init()
end

function OpenMainMenu()

  DoAfterTime(100, function() if SongData().playing == 0 then PlayMusic(0, true) end end)
  selectedChoice = 0
  currentInputState = 1

end

function OpenLevelSelect()

  selectedChoice = 1
  currentInputState = 3
end

function OpenOptions()

  selectedChoice = 0
  currentInputState = 2
end

-- this just crashes the game. there doesn't seem to be a way to close standalone builds
function ExitGame()
  local a = nil >= 1
end

function GoToEndScreen()
  StopSong()
  DoAfterTime(400, function() if SongData().playing == 0 then PlayMusic(1, true) end end)
  currentInputState = 4
end

function MuteSfx()
  sfxMuted = not sfxMuted
end

function MuteMusic()
  musicMuted = not musicMuted
  if musicMuted then StopSong()
  else PlayMusic(0, true) end
end

function Update(timeDelta)

  deltaTime = timeDelta


  player.startTurn()

  for i in pairs(coroutines) do coroutine.resume(coroutines[i]) end

  -- Input. Only handle on button pressed down

  if Button(Buttons.Up, InputState.Released) then allowUp = true end
  if Button(Buttons.Right, InputState.Released) then allowRight = true end
  if Button(Buttons.Down, InputState.Released) then allowDown = true end
  if Button(Buttons.Left, InputState.Released) then allowLeft = true end
  if Button(Buttons.A, InputState.Released) then allowA = true end
  if Button(Buttons.B, InputState.Released) then allowB = true end


  if allowUp and Button(Buttons.Up) then UpPressed()
  elseif allowRight and Button(Buttons.Right) then RightPressed()
  elseif allowDown and Button(Buttons.Down) then DownPressed()
  elseif allowLeft and Button(Buttons.Left) then LeftPressed()

  elseif allowA and Button(Buttons.A) then APressed()

  elseif allowB and Button(Buttons.B) then BPressed()
  end

  if currentInputState == 0 then player.act() end
  if currentInputState == 4 then endScreenOrbitAngle = (endScreenOrbitAngle + 1) % 360 end

end

-- input functions
-- state: 0- movement, 1- mainmenu, 2- options, 
function UpPressed()

  allowUp = false
  local state = currentInputState
  if state == 0 then
    player.move(0, -1)
  return end

  PlaySfx(17)

  if state == 1 then
    selectedChoice = mod(selectedChoice - 1, 4)

  return end

  if state == 3 then
    if completedLevels < 1 then return end
    selectedChoice = selectedChoice - 1
    if selectedChoice < 1 then selectedChoice = math.min(completedLevels + 1, #levelNames) end
    if selectedChoice > math.min(completedLevels + 1, #levelNames) then selectedChoice = 1 end

  return end

end

function LeftPressed()

  allowLeft = false
  local state = currentInputState
  if state == 0 then
    player.move(-1, 0)
  return end

  PlaySfx(17)
  
  if state == 2 then
    selectedChoice = mod(selectedChoice - 1, 2)
  return end

end

function DownPressed()
  
  allowDown = false
  local state = currentInputState
  if state == 0 then
    player.move(0, 1)
  return end

  PlaySfx(17)
  
  if state == 1 then
    selectedChoice = mod(selectedChoice + 1, 4)

  return end

  if state == 3 then
    if completedLevels < 1 then return end
    selectedChoice = selectedChoice + 1
    if selectedChoice < 1 then selectedChoice = math.min(completedLevels + 1, #levelNames) end
    if selectedChoice > math.min(completedLevels + 1, #levelNames) then selectedChoice = 1 end

  return end
  
end

function RightPressed()
  
  allowRight = false
  local state = currentInputState
  if state == 0 then
    player.move(1, 0)
  return end

  PlaySfx(17)

  if state == 2 then
    selectedChoice = mod(selectedChoice + 1, 2)
  return end

end

function APressed()

  allowA = false
  local state = currentInputState

  -- pickup item if there is one
  if state == 0 then
    if player.completelyFrozen then return end
    allowA = false
    local check = GetTileAt(player.tilePos[1], player.tilePos[2])
    if IsItem(check) then
      player.pushItem(check)
      TempRemoveTileAt(player.tilePos[1], player.tilePos[2])

      PlaySfx(7)
      turnCount = turnCount - 1
      SwapFires()
      lastTurn = turnCount
    end
  return end

  PlaySfx(17)

  -- confirm
  if state == 1 then
    mainMenuChoices[selectedChoice + 1]()

  return end
  
  if state == 2 then
    if selectedChoice == 0 then MuteSfx()
    else MuteMusic() end
  return end

  if state == 3 then
    if selectedChoice < 1 then return end
    currentLevel = selectedChoice
    StartGame()

  return end

  if state == 4 then
    StopSong()
    OpenMainMenu()
  return end

end

function BPressed()

  allowB = false
  local state = currentInputState
  if state == 0 then
    LoadLevel(currentLevel)
  return end

  if state == 2 or state == 3 then
    OpenMainMenu()
    PlaySfx(17)
  end

  if state == 4 then
    StopSong()
    OpenMainMenu()

  end

end


function Draw()

  Clear()

  -- end screen
  if currentInputState == 4 then
  
    --the end text
    DrawSpriteBlock(1248, 37, 14, 15, 2)
    DrawSpriteBlock(2, 88, 112, 2, 2)
	
    --circling cheeses
    for i = 0, 5, 1 do
      DrawSpriteBlock(0, 88 + 24 * math.cos(math.rad(endScreenOrbitAngle + 60 * i)), 112 + 24 * math.sin(math.rad(endScreenOrbitAngle + 60 * i)), 2, 2)
    end

    DrawText("X/C: Continue", 44, 192, DrawMode.SpriteAbove, "medium", 15)

  return end

  --options menu
  if currentInputState == 2 then

    --muting sfx/music
    DrawText("Options", 68, 8, DrawMode.SpriteAbove, "large", 15)
    DrawSpriteBlock(2, 88, 20, 2, 2)

    DrawText("Controls:", 60, 82, DrawMode.SpriteAbove, "large", 15)
    DrawText("Arrow Keys: Move", 30, 92, DrawMode.SpriteAbove, "large", 15) -- 36
    DrawText("X: Pickup/Confirm", 30, 102, DrawMode.SpriteAbove, "large", 15) -- 28
    DrawText("C: Restart/Back", 30, 112, DrawMode.SpriteAbove, "large", 15) -- 80

	-- draw box around selected
    DrawRect(66 + selectedChoice * 40, 44, 20, 20, 5)

    DrawSpriteBlock((sfxMuted) and 204 or 172, 68, 46, 2, 2)
    DrawSpriteBlock((musicMuted) and 206 or 174, 108, 46, 2, 2)

    return
  end

  -- level select
  if currentInputState == 3 then

    --title, box, numbers
    DrawText("Level Select", 48, 8, DrawMode.SpriteAbove, "large", 15)
    DrawSpriteBlock(0, 88, 20, 2, 2)

    if selectedChoice > 0 then DrawRect(90, 30 + 16 * selectedChoice, 10, 12, 5) end

    for i in pairs(levelNames) do
      DrawText(i, 92, 32 + 16 * i, DrawMode.SpriteAbove, "large", (i <= completedLevels + 1) and 15 or 5)
    end

    DrawText("X: Confirm", 56, 192, DrawMode.SpriteAbove, "large", 15)
    DrawText("C: Back", 68, 202, DrawMode.SpriteAbove, "large", 15)

    return
  end

  -- main menu
  if currentInputState == 1 then
    
    -- draw background/Buttons
    DrawSpriteBlock(224, 0, 0, 12, 16)
    DrawSpriteBlock(480, 96, 0, 12, 16)

    DrawSpriteBlock(736 + 128 * (selectedChoice), 48, 144, 12, 8)

    return
  end



  -- draw level
  -- draw arrows
  for i = 1, #arrows.tiles, 1 do
    local arrowInfo = GetArrowInfoFromIndex(i)
    -- DrawSpriteBlock(arrowInfo[1], arrowInfo[2], arrowInfo[3], 2, 2, arrowInfo[4], arrowInfo[5], DrawMode.Sprite, (SamePos(player.tilePos, {arrowInfo[2], arrowInfo[3]})) and 5 or 0)
    DrawSpriteBlock(arrowInfo[1], arrowInfo[2] * 16, arrowInfo[3] * 16, 2, 2, false, false, DrawMode.Sprite, (arrowInfo[4]) and 5 or 0)

  end

  -- draw other tiles
  for r = 0, 11, 1 do
    for c = 0, 11, 1 do
      if tiles[c][r] == -1 or tiles[c][r] == 192 then goto continue end
      DrawSpriteBlock(tiles[c][r], 16 * c, 16 * r, 2, 2)

      ::continue::
    end
  end


  -- draw player
  DrawSpriteBlock(2, player.pos[1], player.pos[2], 2, 2, false, false, DrawMode.Sprite, player.colorShift)

  -- draw hp
  for hp = 1, 2, 1 do
    if player.health < 0 then break end
    if hp <= player.health then
      DrawSpriteBlock(12, -16 + 16 * hp, 198, 2, 2)
    end
  end

  -- draw inventory
  DrawTilemap(0, 192, 24, 4, 192, 0)
  for i, v in ipairs(player.itemStack) do if(IsItem(v)) then  DrawSpriteBlock(v, 50 + 22 * i, 198, 2, 2) end end

  -- box the current item
  if #player.itemStack > 0 then DrawSpriteBlock(4, 50 + 22 * #player.itemStack, 198, 2, 2, false, false, DrawMode.Sprite, itemSelectorHighlight and 1 or 0) end

  -- turns left
  local turnDigits = SeparateDigits(turnCount)
  local dOffset = 0
  for i = #turnDigits, 1, -1 do
    DrawSpriteBlock(digitSpriteIDs[turnDigits[i]], 32 + dOffset, 198, 2, 2, false, false, DrawMode.Sprite)
    dOffset = dOffset + 16
  end

  -- particles
  for i, v in pairs(particles) do
    DrawSpriteBlock(v[3], v[1], v[2], 2, 2, false, false, DrawMode.Sprite, 0, true, false, screenRect)
  end

  -- level name display
  if textDisplay then
    --background
    DrawRect(0, 0, #textDisplay * 8 + 4, 12, (textDisplayFaded) and 0 or 5)

    --text
    DrawText(textDisplay, 2, 2, DrawMode.Sprite, "large", (textDisplayFaded) and 5 or 15)

  end


end


function LoadLevel(level)

  -- if level > levels then do end screen
  if level > #levelNames then

    GoToEndScreen()

  return end

  currentLevel = level

  -- make sure to load the actual level (see comment above, Line 19)
  level = levelOrder[level]

  LoadTilemapOfLevel(level)

  player.setTilePos(currentSpawnTile[1], currentSpawnTile[2])
  player.init()

  turnCount = turns[level]
  lastTurn = 0
  textDisplay = levelNames[level]

  DoAfterTime(2500, function() textDisplayFaded = true end)
  DoAfterTime(2750, function() textDisplayFaded = false ; textDisplay = nil end)

end

function ResetInventory()

  for k in pairs (player.itemStack) do player.itemStack[k] = nil end

end

function GetTileAt(x, y)

  -- return Tile(2 * x, 2 * y).spriteID
  return tiles[x][y]

end

function IsSolid(id)
  return id == 34 or id == 64 or id == 46
end

function IsItem(id)
  return id == 14 or id == 32 or id == 66 or id == 74
end

function IsEnemy(id)
  return id == 38 or id == 40 or id == 42 or id == 44
end

function IsWeapon(id)
  return id == 32 or id == 74
end

function IsPick(id)
  return id == 66 or id == 14
end

function IsCheese(id)
  return id == 0
end

function IsKey(id)
  return id == 36
end

function IsDoor(id)
  return id == 34
end

function IsBreakable(id)
  return id == 64
end

function IsFire(id)
  return id == 68 or id == 70
end

function IsArrow(id)
  return id == 162 or id == 164 or id == 166 or id == 168
end

function IsEmpty(id)
  return id == 192 or id == -1 or id == 78
end

function SwapFires()

  turn = not turn
  -- swap fires
  for r = 0, 11, 1 do
    for c = 0, 11, 1 do
      local id = tiles[c][r]
      if IsFire(id) then
        tiles[c][r] = (id == 70) and 68 or 70

      end
    end
  end

end

-- not used. This actually sets the tile on the tilemap itself
function SetTileAt(x, y, tileID)

  local offset = 24 * currentLevel

  Tile(2 * x, 2 * y + offset, tileID)
  Tile(2 * x + 1, 2 * y + 1 + offset, tileID + 1)
  Tile(2 * x , 2 * y + 1 + offset, tileID + 16)
  Tile(2 * x + 1, 2 * y + offset, tileID + 17)

  tiles[x][y] = tileID

end

-- not used
function ClearTileAt(x, y)

  SetTileAt(x, y, 192)

end

-- clear a tile. This is reset when the tilemap is loaded again
function  TempRemoveTileAt(x, y)

  tiles[x][y] = 192

end

function LoadTilemapOfLevel(level)

  -- currentLevel = level
  local offset = 24 * level

  -- clear items/clear tiles
  ResetInventory()
  
  arrows.dirs = {}
  arrows.tiles = {}
  arrows.used = {}
  keyDoorPairs.keys = {}
  keyDoorPairs.doors = {}


  for r = 0, 11, 1 do
    for c = 0, 11, 1 do
      tiles[c][r] = 192
      local t = Tile(2 * c, 2 * r + offset)

      if t.spriteID == -1 then
        t.spriteID = 192

	  -- originally meant to support multiple keys/doors. However, it turns out that sprites can't be color shifted in the tilemap editor
      elseif IsKey(t.spriteID) then
        keyDoorPairs.keys[t.colorOffset] = {c, r}
      end

	  -- set the player spawn space
      if t.spriteID == 2 then
        TempRemoveTileAt(c, r)
        currentSpawnTile = {c, r}
        player.setTilePos(c, r)

      elseif IsArrow(t.spriteID) then
        table.insert(arrows.dirs, math.floor((t.spriteID - 162) / 2))
        table.insert(arrows.tiles, {c, r})
        table.insert(arrows.used, false)

      else
        tiles[c][r] = t.spriteID

      end
    end
  end

  for r = 0, 11, 1 do
    for c = 0, 11, 1 do
      local t = Tile(2 * c, 2 * r + offset)
      local key = keyDoorPairs.keys[t.colorOffset]
      if IsDoor(t.spriteID) and key then keyDoorPairs.doors[t.colorOffset] = {c, r} end
    end
  end

end

function PlayerDied()

  PlaySfx(11)
  player.state = -1

  player.colorShift = 6
  player.completelyFrozen = true

  DoAfterTime(250, function() player.colorShift = 0 ; player.completelyFrozen = false ; LoadLevel(currentLevel) end)

end

function CompleteLevel()

  if currentLevel > completedLevels then completedLevels = completedLevels + 1 end

  currentLevel = currentLevel + 1
  -- play animation/sound
  PlaySfx(6)
  SimulateBlast(player.pos[1], player.pos[2])

  DoAfterTime(1000, function() LoadLevel(currentLevel) end)

end

function GetArrowIndexAtPosition(x, y)
  for i, v in pairs(arrows.tiles) do
    if(x == v[1]) and y == v[2] then
      return i
    end
  end
  return nil
end

-- spriteID, x, y, already been used or not
function GetArrowInfoFromIndex(ind) 
  local ret = {}
  
  ret[1] = arrows.dirs[ind] * 2 + 162
  ret[2] = arrows.tiles[ind][1]
  ret[3] = arrows.tiles[ind][2]
  ret[4] = arrows.used[ind]

  return ret
end

function DirToVector(dir)
  if dir == 0 then return {0, -1} end
  if dir == 1 then return {1, 0} end
  if dir == 2 then return {0, 1} end
  if dir == 3 then return {-1, 0} end
  return {0, 0}
end

function DrawParticle(x, y, spriteID, lifetime)

  local this = #particles + 1
  particles[this] = {x, y, spriteID}

  DoAfterTime(lifetime,
    function()
      if particles[this] then particles[this] = nil end
    end
  )

  return this

end

function DoAfterTime(delay, func)

  table.insert(coroutines, coroutine.create(
    function()
      local t = 0
      while t < delay do
        t = t + deltaTime
        coroutine.yield()
      end
      func()
    end
  ))

end

function SeparateDigits(num)
  local digits = {}
  local count = 1
  
  while num > 9 do
    digits[count] = num % 10
    count = count + 1
    num = math.floor(num / 10)
  end
  digits[count] = num

  return digits
end

function SamePos(a, b)
  return (a[1] == b[1]) and a[2] == b[2]
end

function SimulateBlast(x, y)
  local sprite = 0 --cheese
  local time = 1000
  local count = time

  local p = {{x - 4, y}, {x - 2, y}, {x + 2, y}, {x + 4, y}}
  local pI = {}
  for i in pairs(p) do
    pI[i] = DrawParticle(p[i][1], p[i][2], sprite, time)
  end

  local speedX = {-.3, -.1, .1, .3}
  local speedY = -1

local c = coroutine.create(
  function()
    while count > 0 do
      for i = 1, 4, 1 do
        particles[pI[i]][1] = math.max(0, math.min(particles[pI[i]][1] + speedX[i], 176)) -- x
        particles[pI[i]][2] = particles[pI[i]][2] + speedY -- y

      end

      speedY = speedY + 0.05
      count = count - deltaTime

      coroutine.yield()
    end
  end
)

table.insert(coroutines, c)

end

function PlaySfx(id)
  if sfxMuted then return end
  PlaySound(id, currentAudioChannel)
  currentAudioChannel = currentAudioChannel + 1
  if currentAudioChannel > 4 then currentAudioChannel = 1 end
end

function PlayMusic(id, loop)
  if musicMuted then return end
  StopSong()
  PlaySong(id, loop)
end

function mod(x, m)
  return (x % m + m) % m
end

--on shutdown, save sfx/music settings, completedLevels
function Shutdown()

  WriteSaveData("sfxMuted", (sfxMuted) and "true" or "false")
  WriteSaveData("musicMuted", (musicMuted) and "true" or "false")
  WriteSaveData("completedLevels", completedLevels)

end