local dlg = Dialog("Stacked Sprite Visualizer") -- dialog window
local frameCount = 8 -- total number of frames in the final stack
local saveName = "StackedSprite" -- generated stack file name
local stackFinalFrame = 1 -- the frame we set to active after we generate
local originalStartingFrame = app.activeFrame.frameNumber -- the frame the base sprite is currently on
local fakeEmptyColor = app.pixelColor.rgba(255, 255, 255, 1) -- a barely noticeable "empty" pixel
local emptyFrames = 0 -- the total number of empty frames we populate and then undo at the end
local celCount = 0 -- the number of frames in the bsae sprite
local startSprite = app.activeSprite -- a reference to the base sprite
local destSprite = nil -- a reference to the destination sprite (generated stack)
local lastBuiltSprite = nil -- a reference to the last base sprite we generated on
local allSpriteFrames = {} -- a table that holds all the rotated animations

-- resets the changing state variables
function resetState()
  stackFinalFrame = 1
  emptyFrames = 0
  celCount = 0
  -- check if we're focusing on the base sprite or stack
  if app.activeSprite.filename == saveName and lastBuiltSprite == nil then
    startSprite = app.activeSprite
  elseif app.activeSprite.filename == saveName then
    startSprite = lastBuiltSprite
    app.activeSprite = startSprite
  else
    startSprite = app.activeSprite
    originalStartingFrame = app.activeFrame.frameNumber
  end
  destSprite = nil
  allSpriteFrames = {}
end

-- empty cels must be filled or they aren't indexable
function replaceAllEmptyFramesWithFakePixel()
  for i,frame in ipairs(app.activeSprite.frames) do
    app.activeFrame = i
    if not app.activeImage then
      emptyFrames = emptyFrames + 1
      local addedCel = app.activeSprite:newCel(app.activeLayer, i)
      local addedImage = Image(app.activeSprite.width, app.activeSprite.height)
      addedImage:drawPixel(0, 0, fakeEmptyColor)
      addedCel.image = addedImage
    end
  end
end

-- celCount refers to the number of frames in the base sprite
function getCelCount()
  local totalCels = 0
  for i,cel in ipairs(app.activeLayer.cels) do
    totalCels = totalCels + 1
  end
  return totalCels
end

-- if a stack file exists, modify it so it looks like the base sprite. otherwise, duplicate the base sprite
function setupDestinationSprite()
  for i,sprite in ipairs(app.sprites) do
    if sprite.filename == saveName then
      destSprite = sprite
      app.activeSprite = destSprite
      stackFinalFrame = app.activeFrame
      local midpoint = Point(startSprite.width / 2, startSprite.height / 2)
      midpoint = Point(0, 0)
      app.command.CanvasSize{ ui=false, bounds=Rectangle(midpoint.x, midpoint.y, startSprite.width, startSprite.height) }

      local existingCelCount = 0
      for i,cel in ipairs(destSprite.cels) do
        existingCelCount = existingCelCount + 1
      end
      app.activeFrame = 1
      for i=1, existingCelCount - 1 do
        app.command.RemoveFrame()
      end
      for i=1, celCount-1 do
        app.command.NewFrame()
      end

      for j,startCel in ipairs(startSprite.cels) do
        local destCel = destSprite.cels[j]
        destCel.image = Image(startCel.image)
        destCel.position = startCel.position
      end
      app.activeFrame = 1
    end
  end

  if destSprite == nil then
    destSprite = Sprite(app.activeSprite)
    destSprite.filename = saveName
  end
end

-- prepare the destination sprite with empty frames for duplicated animations
function addEmptyFrames()
  for i=1, celCount*(frameCount-1) do
    app.command.NewFrame()
  end
end

-- make a bunch of replicas of the base spritesheet, to be rotated later
function duplicateSpritesheetToNewFrames()
  for i=1, celCount do
    local baseIndex = celCount * (frameCount-1) + i
    local baseCel = destSprite.cels[baseIndex]
    for j=1, frameCount-1 do
      local copyIndex = ((j - 1) * celCount) + i
      local copyCel = destSprite.cels[copyIndex]
      copyCel.image = Image(baseCel.image)
      copyCel.position = baseCel.position
    end
  end
end

-- rotate all of the duplicate sprite animations
function rotateSprites()
  for i=1, frameCount do
    local angleRotation = (360/frameCount) * (i - 1)
    for j=1, celCount do
      local nextFrameIndex = ((i-1) * celCount) + j
      app.activeFrame = nextFrameIndex
      app.command.MaskAll()
      app.command.Rotate{target="mask", angle=angleRotation}
      app.command.DeselectMask()
      if app.activeImage:isEmpty() then
        local fillerCel = app.activeSprite:newCel(app.activeLayer, nextFrameIndex)
        local fillerPixelImage = Image(app.activeSprite.width, app.activeSprite.height)
        fillerPixelImage:drawPixel(0, 0, fakeEmptyColor)
        fillerCel.image = fillerPixelImage
      end
    end
  end
end

-- need to make the canvas taller to accommodate for the y-offset
function expandSpriteHeight()
  app.command.CanvasSize{ ui=false, top=celCount }
end

-- put every rotated animation in a table
function populateSpritesheet()
  for i,currentCel in ipairs(destSprite.cels) do
    allSpriteFrames[i] = currentCel.image
  end
end

-- make a bunch of copies of the rotated animations
function duplicateLayers()
  for i=1, celCount-1 do
    app.command.DuplicateLayer()
  end
end

-- move each rotated animation into its own layer
function mapSpriteFramesToLayers()
  for currentFrame=1, frameCount do
    for currentLayer=1, celCount do
      app.activeLayer = destSprite.layers[currentLayer]
      app.activeFrame = currentFrame
      local spritesheetIndex = (currentFrame-1) * celCount + currentLayer
      local spritesheetImage = allSpriteFrames[spritesheetIndex]
      app.activeCel.image = spritesheetImage
      app.activeCel.position = Point(spritesheetImage.cel.position.x, spritesheetImage.cel.position.y - currentLayer)
    end
  end
end

-- count the number of frames in the final sprite
function getTotalDestFrames()
  local totalDestFrames = 0
  for i,frame in ipairs(app.activeSprite.frames) do
    totalDestFrames = totalDestFrames + 1
  end
  return totalDestFrames
end

-- remove all frames except for the final animation
function removeExcessFrames()
  local destFrameCount = getTotalDestFrames()
  app.activeFrame = frameCount + 1
  for i=1, destFrameCount-frameCount do
    app.command.RemoveFrame()
  end
end

-- undo those empty pixels we added to the base sprite
function undoStartingSprite()
  app.activeSprite = startSprite
  lastBuiltSprite = startSprite
  for i=1, emptyFrames*2 do
    app.command.Undo()
  end
  app.command.Undo() -- undos flattening
  app.activeFrame = originalStartingFrame
end

-- focus on either the generated stack or back to the base sprite
function setFinalSpriteFocus()
  if dlg.data.autoplayAnimation then
    app.activeSprite = destSprite
    app.command.PlayAnimation()
  end
  if not dlg.data.openStack then
    app.activeSprite = startSprite
  else
    app.activeSprite = destSprite
  end
end

-- flatten the layers, set frame durations, and set the active frame
function setupDestFrames()
  destSprite:flatten()
  for i,frame in ipairs(destSprite.frames) do
    frame.duration = (dlg.data.frameDuration * 50) / 1000.0
  end
  if dlg.data.alwaysResetFrame then
    app.activeFrame = 1
  else
    app.activeFrame = stackFinalFrame
  end
end

-- generates the stacked sprite
function generateStack()
  resetState()
  startSprite:flatten()
  replaceAllEmptyFramesWithFakePixel()
  celCount = getCelCount()
  setupDestinationSprite()
  addEmptyFrames()
  duplicateSpritesheetToNewFrames()
  rotateSprites()
  expandSpriteHeight()
  populateSpritesheet()
  duplicateLayers()
  mapSpriteFramesToLayers()
  removeExcessFrames()
  setupDestFrames()

  app.command.DeselectMask()

  undoStartingSprite()
  setFinalSpriteFocus()
end

-- sets the frameCount variable when changed in the dialog
function updateFrameCount()
  frameCount = powOfTwo(dlg.data.frameCount)
end

-- recursive 2^x function
function powOfTwo(power)
  if power == 0 then
    return 1
  end
  return 2 * powOfTwo(power - 1)
end

-- creates the dialog and waits for input
function main()
  dlg:separator{ text="Parameters" }
  dlg:slider{ id="frameCount", label="Frame count (2^x)", min=0, max=6, value=3, onchange=updateFrameCount }
  dlg:slider{ id="frameDuration", label="Frame duration (*50ms)", min=1, max=8, value=4 }
  dlg:separator{ text="Render" }
  dlg:check{ id="alwaysResetFrame", label="Start at first frame", selected=false, focus=false }
  dlg:check{ id="autoplayAnimation", label="Autoplay animation", selected=true, focus=false }
  dlg:check{ id="openStack", label="Open file", selected=true, focus=false }
  dlg:check{ id="focusPlaceholder", label="Focus placeholder", selected=true, visible=false, focus=true }
  dlg:button{ text="Generate Stack", onclick=generateStack, hexpand=true, focus=false }
  dlg:show{ wait=false }
end

main()
