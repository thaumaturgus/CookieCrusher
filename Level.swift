import Foundation

let NumColumns = 9
let NumRows = 9
let NumLevels = 4 // Excluding Level_0.json

class Level {
  
  // keeps track of where the Cookies are
  private var cookies = Array2D<Cookie>(columns: NumColumns, rows: NumRows)
  
  // layout of the level
  private var tiles = Array2D<Tile>(columns: NumColumns, rows: NumRows)
  
  // determine whether the player can make a certain swap, if the board needs to be shuffled,
  // and to generate hints
  private var possibleSwaps = Set<Swap>()

  var targetScore = 0
  var maximumMoves = 0
  
  // second chain gets twice its regular score, the third chain three times, etc.
  private var comboMultiplier = 0
  
  
  // create a level by loading it from a file
  init(filename: String) {
    guard let dictionary = Dictionary<String, AnyObject>.loadJSONFromBundle(filename) else { return }
    // one element for each row of the level, each describing the columns in that row
    guard let tilesArray = dictionary["tiles"] as? [[Int]] else { return }
    
    for (row, rowArray) in tilesArray.enumerate() {
      // in Sprite Kit (0,0) is at the bottom of the screen
      let tileRow = NumRows - row - 1
      
      for (column, value) in rowArray.enumerate() {
        if value == 1 {
          tiles[column, tileRow] = Tile()
        }
      }
    }
    
    targetScore = dictionary["targetScore"] as! Int
    maximumMoves = dictionary["moves"] as! Int
  }
  
  
  func shuffle() -> Set<Cookie> {
    var set: Set<Cookie>
    repeat {
      set = createInitialCookies()      
      detectPossibleSwaps()
    } while possibleSwaps.count == 0
    
    return set
  }
  
  private func createInitialCookies() -> Set<Cookie> {
    var set = Set<Cookie>()
    
    for row in 0..<NumRows {
      for column in 0..<NumColumns {
        
        if tiles[column, row] != nil {
          
          var cookieType: CookieType
          repeat {
            cookieType = CookieType.random()
          } while
            (column >= 2 &&
              cookies[column - 1, row]?.cookieType == cookieType &&
              cookies[column - 2, row]?.cookieType == cookieType) ||
            (row >= 2 &&
              cookies[column, row - 1]?.cookieType == cookieType &&
              cookies[column, row - 2]?.cookieType == cookieType)
          
          let cookie = Cookie(column: column, row: row, cookieType: cookieType)
          cookies[column, row] = cookie
          
          set.insert(cookie)
        }
      }
    }
    return set
  }
  
  
  func tileAtColumn(column: Int, row: Int) -> Tile? {
    assert(column >= 0 && column < NumColumns)
    assert(row >= 0 && row < NumRows)
    return tiles[column, row]
  }
  
  func cookieAtColumn(column: Int, row: Int) -> Cookie? {
    assert(column >= 0 && column < NumColumns)
    assert(row >= 0 && row < NumRows)
    return cookies[column, row]
  }
  
  func isPossibleSwap(swap: Swap) -> Bool {
    return possibleSwaps.contains(swap)
  }
  
  private func hasChainAtColumn(column: Int, row: Int) -> Bool {
    let cookieType = cookies[column, row]!.cookieType
    
    // horizontal chain check
    var horzLength = 1
    
    // left
    var i = column - 1

    while i >= 0 && cookies[i, row]?.cookieType == cookieType {
      i -= 1
      horzLength += 1
    }
    
    // right
    i = column + 1
    while i < NumColumns && cookies[i, row]?.cookieType == cookieType {
      i += 1
      horzLength += 1
    }
    if horzLength >= 3 { return true }
    
    // vertical chain check
    var vertLength = 1
    
    // down
    i = row - 1
    while i >= 0 && cookies[column, i]?.cookieType == cookieType {
      i -= 1
      vertLength += 1
    }
    
    // up
    i = row + 1
    while i < NumRows && cookies[column, i]?.cookieType == cookieType {
      i += 1
      vertLength += 1
    }
    return vertLength >= 3
  }
  
  
  // swaps the positions of the two cookies from the Swap object
  func performSwap(swap: Swap) {
    let columnA = swap.cookieA.column
    let rowA = swap.cookieA.row
    let columnB = swap.cookieB.column
    let rowB = swap.cookieB.row
    
    cookies[columnA, rowA] = swap.cookieB
    swap.cookieB.column = columnA
    swap.cookieB.row = rowA
    
    cookies[columnB, rowB] = swap.cookieA
    swap.cookieA.column = columnB
    swap.cookieA.row = rowB
  }
  
  func detectPossibleSwaps() {
    var set = Set<Swap>()
    
    for row in 0..<NumRows {
      for column in 0..<NumColumns {
        if let cookie = cookies[column, row] {
          
          if column < NumColumns - 1 {
            
            if let other = cookies[column + 1, row] {
              // swap
              cookies[column, row] = other
              cookies[column + 1, row] = cookie
              
              if hasChainAtColumn(column + 1, row: row) ||
                hasChainAtColumn(column, row: row) {
                set.insert(Swap(cookieA: cookie, cookieB: other))
              }
              
              // swap back
              cookies[column, row] = cookie
              cookies[column + 1, row] = other
            }
          }
          
          if row < NumRows - 1 {
            
            if let other = cookies[column, row + 1] {
              cookies[column, row] = other
              cookies[column, row + 1] = cookie
              
              if hasChainAtColumn(column, row: row + 1) ||
                hasChainAtColumn(column, row: row) {
                set.insert(Swap(cookieA: cookie, cookieB: other))
              }
              
              cookies[column, row] = cookie
              cookies[column, row + 1] = other
            }
          }
        }
      }
    }
    
    possibleSwaps = set
  }
  
  private func calculateScores(chains: Set<Chain>) {
    // 3-chain is 60 pts, 4-chain is 120, 5-chain is 180, etc.
    for chain in chains {
      chain.score = 60 * (chain.length - 2) * comboMultiplier
      comboMultiplier += 1
    }
  }
  
  // called at the start of every new turn.
  func resetComboMultiplier() {
    comboMultiplier = 1
  }
  
  
  // Detecting Matches
  
  private func detectHorizontalMatches() -> Set<Chain> {
    var set = Set<Chain>()
    
    for row in 0..<NumRows {
      var column = 0
      while column < NumColumns-2 {
        if let cookie = cookies[column, row] {
          let matchType = cookie.cookieType
          
          if cookies[column + 1, row]?.cookieType == matchType &&
             cookies[column + 2, row]?.cookieType == matchType {
            
            let chain = Chain(chainType: .Horizontal)
            repeat {
              chain.addCookie(cookies[column, row]!)
              column += 1
            } while column < NumColumns && cookies[column, row]?.cookieType == matchType
            
            set.insert(chain)
            continue
          }
        }
        
        column += 1
      }
    }
    return set
  }
  
  private func detectVerticalMatches() -> Set<Chain> {
    var set = Set<Chain>()
    
    for column in 0..<NumColumns {
      var row = 0
      while row < NumRows-2 {
        if let cookie = cookies[column, row] {
          let matchType = cookie.cookieType
          
          if cookies[column, row + 1]?.cookieType == matchType &&
            cookies[column, row + 2]?.cookieType == matchType {
            
            let chain = Chain(chainType: .Vertical)
            repeat {
              chain.addCookie(cookies[column, row]!)
              row += 1
            } while row < NumRows && cookies[column, row]?.cookieType == matchType
            
            set.insert(chain)
            continue
          }
        }
        row += 1
      }
    }
    return set
  }
  
  func removeMatches() -> Set<Chain> {
    let horizontalChains = detectHorizontalMatches()
    let verticalChains = detectVerticalMatches()
    
    removeCookies(horizontalChains)
    removeCookies(verticalChains)
    
    calculateScores(horizontalChains)
    calculateScores(verticalChains)
    
    return horizontalChains.union(verticalChains)
  }
  
  private func removeCookies(chains: Set<Chain>) {
    for chain in chains {
      for cookie in chain.cookies {
        cookies[cookie.column, cookie.row] = nil
      }
    }
  }
  
  
  // Detecting Holes
  
  func fillHoles() -> [[Cookie]] {
    var columns = [[Cookie]]()       // you can also write this Array<Array<Cookie>>
    
    for column in 0..<NumColumns {
      var array = [Cookie]()
      for row in 0..<NumRows {
        
        // tile at this position but no cookie means there's a hole
        if tiles[column, row] != nil && cookies[column, row] == nil {
          
          // scan upward
          for lookup in (row + 1)..<NumRows {
            if let cookie = cookies[column, lookup] {
              // swap that cookie with the hole
              cookies[column, lookup] = nil
              cookies[column, row] = cookie
              cookie.row = row
              
              array.append(cookie)
              
              break
            }
          }
        }
      }
      
      if !array.isEmpty {
        columns.append(array)
      }
    }
    return columns
  }
  
  func topUpCookies() -> [[Cookie]] {
    var columns = [[Cookie]]()
    var cookieType: CookieType = .Unknown
    
    for column in 0..<NumColumns {
      var array = [Cookie]()
      
      var row = NumRows - 1
      while row >= 0 && cookies[column, row] == nil {
        if tiles[column, row] != nil {
          
          // randomly create a new cookie type
          var newCookieType: CookieType
          repeat {
            newCookieType = CookieType.random()
          } while newCookieType == cookieType
          cookieType = newCookieType
          
          let cookie = Cookie(column: column, row: row, cookieType: cookieType)
          cookies[column, row] = cookie
          array.append(cookie)
        }
        
        row -= 1
      }
      
      if !array.isEmpty {
        columns.append(array)
      }
    }
    return columns
  }
  
}