import SpriteKit

class GameScene: SKScene {
  
  var level: Level!
  
  let TileWidth: CGFloat = 32.0
  let TileHeight: CGFloat = 36.0
  
  let gameLayer = SKNode()
  let cookiesLayer = SKNode()
  let tilesLayer = SKNode()
  let cropLayer = SKCropNode()
  let maskLayer = SKNode()
  
  var swipeFromColumn: Int?
  var swipeFromRow: Int?
  
  var swipeHandler: ((Swap) -> ())?
  
  // drawn on top of the cookie that the player is trying to swap
  var selectionSprite = SKSpriteNode()
  
  let swapSound = SKAction.playSoundFileNamed("Chomp.wav", waitForCompletion: false)
  let invalidSwapSound = SKAction.playSoundFileNamed("Error.wav", waitForCompletion: false)
  let matchSound = SKAction.playSoundFileNamed("Ka-Ching.wav", waitForCompletion: false)
  let fallingCookieSound = SKAction.playSoundFileNamed("Scrape.wav", waitForCompletion: false)
  let addCookieSound = SKAction.playSoundFileNamed("Drip.wav", waitForCompletion: false)
  
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder) is not used in this app")
  }
  
  override init(size: CGSize) {
    super.init(size: size)
    
    anchorPoint = CGPoint(x: 0.5, y: 0.5)
    
    let background = SKSpriteNode(imageNamed: "Background")
    background.size = size
    addChild(background)
    
    gameLayer.hidden = true
    addChild(gameLayer)
    
    let layerPosition = CGPoint(
      x: -TileWidth * CGFloat(NumColumns) / 2,
      y: -TileHeight * CGFloat(NumRows) / 2)
    
    tilesLayer.position = layerPosition
    gameLayer.addChild(tilesLayer)
    
    gameLayer.addChild(cropLayer)
    
    // mask layer determines which part of the cookiesLayer is visible
    maskLayer.position = layerPosition
    cropLayer.maskNode = maskLayer
    
    cookiesLayer.position = layerPosition
    cropLayer.addChild(cookiesLayer)
    
    swipeFromColumn = nil
    swipeFromRow = nil
    
    let _ = SKLabelNode(fontNamed: "GillSans-BoldItalic")
  }
  
  
  
  func addTiles() {
    for row in 0..<NumRows {
      for column in 0..<NumColumns {
        if level.tileAtColumn(column, row: row) != nil {
          let tileNode = SKSpriteNode(imageNamed: "MaskTile")
          tileNode.size = CGSize(width: TileWidth, height: TileHeight)
          tileNode.position = pointForColumn(column, row: row)
          maskLayer.addChild(tileNode)
        }
      }
    }
    
    // tile pattern is drawn between the level tiles; extra column and row
    for row in 0...NumRows {
      for column in 0...NumColumns {
        
        let topLeft     = (column > 0) && (row < NumRows)
          && level.tileAtColumn(column - 1, row: row) != nil
        let bottomLeft  = (column > 0) && (row > 0)
          && level.tileAtColumn(column - 1, row: row - 1) != nil
        let topRight    = (column < NumColumns) && (row < NumRows)
          && level.tileAtColumn(column, row: row) != nil
        let bottomRight = (column < NumColumns) && (row > 0)
          && level.tileAtColumn(column, row: row - 1) != nil
        
        let value = Int(topLeft) | Int(topRight) << 1 | Int(bottomLeft) << 2 | Int(bottomRight) << 3
        
        // 0 (no tiles), 6 and 9 (two opposite tiles) are not drawn
        if value != 0 && value != 6 && value != 9 {
          let name = String(format: "Tile_%ld", value)
          let tileNode = SKSpriteNode(imageNamed: name)
          tileNode.size = CGSize(width: TileWidth, height: TileHeight)
          var point = pointForColumn(column, row: row)
          point.x -= TileWidth/2
          point.y -= TileHeight/2
          tileNode.position = point
          tilesLayer.addChild(tileNode)
        }
      }
    }
  }
  
  func addSpritesForCookies(cookies: Set<Cookie>) {
    for cookie in cookies {
      let sprite = SKSpriteNode(imageNamed: cookie.cookieType.spriteName)
      sprite.size = CGSize(width: TileWidth, height: TileHeight)
      sprite.position = pointForColumn(cookie.column, row: cookie.row)
      cookiesLayer.addChild(sprite)
      cookie.sprite = sprite
      
      sprite.alpha = 0
      sprite.xScale = 0.5
      sprite.yScale = 0.5
      
      sprite.runAction(
        SKAction.sequence([
          SKAction.waitForDuration(0.25, withRange: 0.5),
          SKAction.group([
            SKAction.fadeInWithDuration(0.25),
            SKAction.scaleTo(1.0, duration: 0.25)
            ])
          ]))
    }
  }
  
  func removeAllCookieSprites() {
    cookiesLayer.removeAllChildren()
  }
  
  
  // converts a column,row pair into a CGPoint that is relative to the cookieLayer
  func pointForColumn(column: Int, row: Int) -> CGPoint {
    return CGPoint(
      x: CGFloat(column)*TileWidth + TileWidth/2,
      y: CGFloat(row)*TileHeight + TileHeight/2)
  }
  
  func convertPoint(point: CGPoint) -> (success: Bool, column: Int, row: Int) {
    if point.x >= 0 && point.x < CGFloat(NumColumns)*TileWidth &&
      point.y >= 0 && point.y < CGFloat(NumRows)*TileHeight {
      return (true, Int(point.x / TileWidth), Int(point.y / TileHeight))
    } else {
      return (false, 0, 0)  // invalid location
    }
  }
  
  
  // Cookie Swapping
  
  func trySwapHorizontal(horzDelta: Int, vertical vertDelta: Int) {
    let toColumn = swipeFromColumn! + horzDelta
    let toRow = swipeFromRow! + vertDelta
    
    // ignore past the edge of the grid
    guard toColumn >= 0 && toColumn < NumColumns else { return }
    guard toRow >= 0 && toRow < NumRows else { return }
    
    if let toCookie = level.cookieAtColumn(toColumn, row: toRow),
       let fromCookie = level.cookieAtColumn(swipeFromColumn!, row: swipeFromRow!),
       let handler = swipeHandler {
         let swap = Swap(cookieA: fromCookie, cookieB: toCookie)
         handler(swap)
    }
  }
  
  func showSelectionIndicatorForCookie(cookie: Cookie) {
    if selectionSprite.parent != nil {
      selectionSprite.removeFromParent()
    }
    
    if let sprite = cookie.sprite {
      let texture = SKTexture(imageNamed: cookie.cookieType.highlightedSpriteName)
      selectionSprite.size = CGSize(width: TileWidth, height: TileHeight)
      selectionSprite.runAction(SKAction.setTexture(texture))
      
      sprite.addChild(selectionSprite)
      selectionSprite.alpha = 1.0
    }
  }
  
  func hideSelectionIndicator() {
    selectionSprite.runAction(SKAction.sequence([
      SKAction.fadeOutWithDuration(0.3),
      SKAction.removeFromParent()]))
  }
  
  
  func animateSwap(swap: Swap, completion: () -> ()) {
    let spriteA = swap.cookieA.sprite!
    let spriteB = swap.cookieB.sprite!
    
    spriteA.zPosition = 100
    spriteB.zPosition = 90
    
    let duration: NSTimeInterval = 0.3
    
    let moveA = SKAction.moveTo(spriteB.position, duration: duration)
    moveA.timingMode = .EaseOut
    spriteA.runAction(moveA, completion: completion)
    
    let moveB = SKAction.moveTo(spriteA.position, duration: duration)
    moveB.timingMode = .EaseOut
    spriteB.runAction(moveB)
    
    runAction(swapSound)
  }
  
  func animateInvalidSwap(swap: Swap, completion: () -> ()) {
    let spriteA = swap.cookieA.sprite!
    let spriteB = swap.cookieB.sprite!
    
    spriteA.zPosition = 100
    spriteB.zPosition = 90
    
    let duration: NSTimeInterval = 0.2
    
    let moveA = SKAction.moveTo(spriteB.position, duration: duration)
    moveA.timingMode = .EaseOut
    
    let moveB = SKAction.moveTo(spriteA.position, duration: duration)
    moveB.timingMode = .EaseOut
    
    spriteA.runAction(SKAction.sequence([moveA, moveB]), completion: completion)
    spriteB.runAction(SKAction.sequence([moveB, moveA]))
    
    runAction(invalidSwapSound)
  }
  
  func animateMatchedCookies(chains: Set<Chain>, completion: () -> ()) {
    for chain in chains {
      animateScoreForChain(chain)
      
      for cookie in chain.cookies {
        
        // Cookie object part of two chains is removed once
        if let sprite = cookie.sprite {
          if sprite.actionForKey("removing") == nil {
            let scaleAction = SKAction.scaleTo(0.1, duration: 0.3)
            scaleAction.timingMode = .EaseOut
            sprite.runAction(SKAction.sequence([scaleAction, SKAction.removeFromParent()]),
                             withKey:"removing")
          }
        }
      }
    }
    runAction(matchSound)
    runAction(SKAction.waitForDuration(0.3), completion: completion)
  }
  
  func animateFallingCookies(columns: [[Cookie]], completion: () -> ()) {
    var longestDuration: NSTimeInterval = 0
    for array in columns {
      for (idx, cookie) in array.enumerate() {
        let newPosition = pointForColumn(cookie.column, row: cookie.row)
        
        let delay = 0.05 + 0.15*NSTimeInterval(idx)
        
        let sprite = cookie.sprite!   // sprite always exists at this point
        
        let duration = NSTimeInterval(((sprite.position.y - newPosition.y) / TileHeight) * 0.1)
        longestDuration = max(longestDuration, duration + delay)
        
        let moveAction = SKAction.moveTo(newPosition, duration: duration)
        moveAction.timingMode = .EaseOut
        sprite.runAction(
          SKAction.sequence([
            SKAction.waitForDuration(delay),
            SKAction.group([moveAction, fallingCookieSound])]))
      }
    }
    
    // wait until all the cookies have fallen down
    runAction(SKAction.waitForDuration(longestDuration), completion: completion)
  }
  
  func animateNewCookies(columns: [[Cookie]], completion: () -> ()) {
    var longestDuration: NSTimeInterval = 0
    
    for array in columns {
      
      let startRow = array[0].row + 1
      
      for (idx, cookie) in array.enumerate() {        
        let sprite = SKSpriteNode(imageNamed: cookie.cookieType.spriteName)
        sprite.size = CGSize(width: TileWidth, height: TileHeight)
        sprite.position = pointForColumn(cookie.column, row: startRow)
        cookiesLayer.addChild(sprite)
        cookie.sprite = sprite
        
        let delay = 0.1 + 0.2 * NSTimeInterval(array.count - idx - 1)
        
        // calculate duration based on far the cookie has to fall
        let duration = NSTimeInterval(startRow - cookie.row) * 0.1
        longestDuration = max(longestDuration, duration + delay)
        
        let newPosition = pointForColumn(cookie.column, row: cookie.row)
        let moveAction = SKAction.moveTo(newPosition, duration: duration)
        moveAction.timingMode = .EaseOut
        sprite.alpha = 0
        sprite.runAction(
          SKAction.sequence([
            SKAction.waitForDuration(delay),
            SKAction.group([
              SKAction.fadeInWithDuration(0.05),
              moveAction,
              addCookieSound])
            ]))
      }
    }
    
    runAction(SKAction.waitForDuration(longestDuration), completion: completion)
  }
  
  func animateScoreForChain(chain: Chain) {
    // midpoint of the chain
    let firstSprite = chain.firstCookie().sprite!
    let lastSprite = chain.lastCookie().sprite!
    let centerPosition = CGPoint(
      x: (firstSprite.position.x + lastSprite.position.x)/2,
      y: (firstSprite.position.y + lastSprite.position.y)/2 - 8)
    
    let scoreLabel = SKLabelNode(fontNamed: "GillSans-BoldItalic")
    scoreLabel.fontSize = 16
    scoreLabel.text = String(format: "%ld", chain.score)
    scoreLabel.position = centerPosition
    scoreLabel.zPosition = 300
    cookiesLayer.addChild(scoreLabel)
    
    let moveAction = SKAction.moveBy(CGVector(dx: 0, dy: 3), duration: 0.7)
    moveAction.timingMode = .EaseOut
    scoreLabel.runAction(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
  }
  
  func animateGameOver(completion: () -> ()) {
    let action = SKAction.moveBy(CGVector(dx: 0, dy: -size.height), duration: 0.3)
    action.timingMode = .EaseIn
    gameLayer.runAction(action, completion: completion)
  }
  
  func animateBeginGame(completion: () -> ()) {
    gameLayer.hidden = false
    gameLayer.position = CGPoint(x: 0, y: size.height)
    let action = SKAction.moveBy(CGVector(dx: 0, dy: -size.height), duration: 0.3)
    action.timingMode = .EaseOut
    gameLayer.runAction(action, completion: completion)
  }
  
  
  override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
    guard let touch = touches.first else { return }
    // convert the touch location to a point relative to the cookiesLayer
    let location = touch.locationInNode(cookiesLayer)
    
    let (success, column, row) = convertPoint(location)
    if success {
      if let cookie = level.cookieAtColumn(column, row: row) {
        swipeFromColumn = column
        swipeFromRow = row
        showSelectionIndicatorForCookie(cookie)
      }
    }
  }
  
  override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
    guard swipeFromColumn != nil else { return }
    
    guard let touch = touches.first else { return }
    let location = touch.locationInNode(cookiesLayer)
    
    let (success, column, row) = convertPoint(location)
    if success {
      var horzDelta = 0, vertDelta = 0
      if column < swipeFromColumn! {          // swipe left
        horzDelta = -1
      } else if column > swipeFromColumn! {   // swipe right
        horzDelta = 1
      } else if row < swipeFromRow! {         // swipe down
        vertDelta = -1
      } else if row > swipeFromRow! {         // swipe up
        vertDelta = 1
      }
      
      // only try swapping when the user swiped into a new square
      if horzDelta != 0 || vertDelta != 0 {
        trySwapHorizontal(horzDelta, vertical: vertDelta)
        hideSelectionIndicator()
        
        swipeFromColumn = nil
      }
    }
  }
  
  override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
    if selectionSprite.parent != nil && swipeFromColumn != nil {
      hideSelectionIndicator()
    }
    
    swipeFromColumn = nil
    swipeFromRow = nil
  }
  
  override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
    if let touches = touches {
      touchesEnded(touches, withEvent: event)
    }
  }
  
}