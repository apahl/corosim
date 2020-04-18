import CRaylib
import FileUtils
import Glibc
import Raylib

struct Parameters {
  let population = 75

  // Fraction of the population that is infected at the start of the simulation
  // The program ensures that the simulation starts with at least one infected person
  // So if you want to start the simulation with exactly one infected person,
  //   set this value to 0.0
  let fractionInfected: Float = 0.00

  // Fraction which actually stays at home
  let fractionStationary: Float = 0.75

  // Duration of the infection
  let infectionTime = 25

  // Fraction of the population that is being tested
  let fractionTested: Float = 0.25

  // If the person was tested and is positive it goes into qurantaine after
  //    this amount of days.
  // A person in quarantaine will not infect others
  // Values > infectionTime mean no testing / no Quarantaine
  let quaranAfter = 30

  // Maximum runtime of the simulation in seconds (cycles)
  let simulationTime = 180
}

let parameters = Parameters()

enum Health: Int {
  case normal = 0, infected, healed, quaran
}

let colors: [Health: Color] = [
  .normal: BLUE,
  .infected: RED,
  .healed: GREEN,
  .quaran: VIOLET,
]

struct WindowSize {
  let width: Float = 700.0
  let height: Float = 700.0
}

let wsize = WindowSize()

struct GameConfig {
  let ballRadius: Float = 5.0
  let vertical: Float = 180.0
  let horizontal: Float = 360.0
}

let config = GameConfig()

struct Stats {
  let total, normal, infected, healed: Int
}

// -- BALL ------------------------------------------------
struct Ball {
  var pos: Vector2 = Vector2(x: Float.random(in: 0 ... wsize.width), y: Float.random(in: 0 ... wsize.height))
  var direction: Direction = Direction(
    angle: Float.random(in: 0 ..< 360),
    speed: Float.random(in: 0.0 ... 1.0) < parameters.fractionStationary ? 0 : Float.random(in: 5 ... 15) / 10.0
  )
  var radius: Float = config.ballRadius
  var infectedSince: Int = 0
  var health: Health = Float.random(in: 0.0 ... 1.0) < parameters.fractionInfected ? .infected : .normal
  var wasTested = Float.random(in: 0.0 ... 1.0) < parameters.fractionTested ? true : false

  mutating func reflect(plane: Float) {
    var angle = direction.angle
    angle = plane - angle
    if angle < 0.0 {
      angle = 360.0 + angle
    } else if angle > 360.0 {
      angle = angle - 360.0
    }
    direction.angle = angle
  }

  mutating func updatePos() {
    pos.x += sin(radians(from: direction.angle)) * direction.speed
    pos.y += cos(radians(from: direction.angle)) * direction.speed
  }
}

struct Balls {
  var currentTime: Int = 0
  var list: [Ball]
  var markInfected: Set<Int> = []

  mutating func updateHealth() {
    for idx in list.indices {
      if list[idx].health == .infected {
        if currentTime - list[idx].infectedSince >= parameters.infectionTime {
          list[idx].health = .healed
        } else if list[idx].wasTested, currentTime - list[idx].infectedSince >= parameters.quaranAfter {
          // Put positively tested in quarantine
          list[idx].health = .quaran
          list[idx].direction.speed = 0.0
        }
      } else if list[idx].health == .quaran, currentTime - list[idx].infectedSince >= parameters.infectionTime {
        list[idx].health = .healed
      }
    }
  }

  mutating func updatePos() {
    for idx in list.indices {
      list[idx].updatePos()
      // Bounds check
      if (list[idx].pos.x - list[idx].radius) <= 0
        || (list[idx].pos.x + list[idx].radius) >= wsize.width {
        list[idx].reflect(plane: config.horizontal)
      }
      if (list[idx].pos.y - list[idx].radius) <= 0
        || (list[idx].pos.y + list[idx].radius) >= wsize.height {
        list[idx].reflect(plane: config.vertical)
      }
    }
  }

  mutating func processInfected() {
    for idx in markInfected {
      list[idx].health = .infected
      list[idx].infectedSince = currentTime
    }
    markInfected = []
  }

  // remove mutating return a markInfected list of indices and mutate in a second call
  mutating func checkCollisions() {
    for i in 0 ..< list.count - 1 {
      if list[i].health == .normal {
        for j in i + 1 ..< list.count {
          if list[j].health == .infected, CheckCollisionCircles(list[i].pos, list[i].radius, list[j].pos, list[j].radius) {
            markInfected.insert(i)
          }
        }
      } else if list[i].health == .infected {
        for j in i + 1 ..< list.count {
          if list[j].health == .normal, CheckCollisionCircles(list[i].pos, list[i].radius, list[j].pos, list[j].radius) {
            markInfected.insert(j)
          }
        }
      }
    }
  }

  var stats: Stats {
    var total: Int = 0, normal: Int = 0, infected: Int = 0, healed: Int = 0
    for ball in list {
      total += 1
      switch ball.health {
      case .normal:
        normal += 1
      case .infected, .quaran:
        infected += 1
      case .healed:
        healed += 1
      }
    }
    return Stats(total: total, normal: normal, infected: infected, healed: healed)
  }

  var endSimulation: Bool {
    if currentTime >= parameters.simulationTime {
      return true
    }
    for ball in list {
      if ball.health == .infected || ball.health == .quaran {
        return false
      }
    }
    return true
  }

  func getStats() -> String {
    let curStats = stats
    return (" \(currentTime) \(curStats.total) \(curStats.normal) \(curStats.infected) \(curStats.healed)")
  }

  func draw() {
    for ball in list {
      DrawCircleV(ball.pos, ball.radius, colors[ball.health]!)
    }
  }
}

func createPopulation() -> Balls {
  var balls = Balls(list: [])
  for _ in 1 ... parameters.population {
    balls.list.append(Ball())
  }
  // Make sure that there is at least one infected person in the population
  var isInfected = false
  for idx in balls.list.indices {
    if balls.list[idx].health == .infected {
      isInfected = true
      break
    }
  }
  if !isInfected {
    balls.list[0].health = .infected
  }
  return balls
}

InitWindow(Int32(wsize.width), Int32(wsize.height), "CoroSim")
SetTargetFPS(60)

// sleep(27)
// print("Starting in 3")
// sleep(3)

var currentTime: Int
var balls = createPopulation()

var data: [String] = []
var txt: String
let startTime = getCurrentTime()
var prevTime = 0

print("\nParameters:")
txt = "Pop \(parameters.population) | Inf \(parameters.fractionInfected) | Stat \(parameters.fractionStationary) | InfTime \(parameters.infectionTime) | Tested \(parameters.fractionTested) | QAfter \(parameters.quaranAfter)"
print(txt)
data.append(txt)
txt = "Time | Total | Normal | Infected | Healed"
print(txt)
data.append(txt)
txt = balls.getStats()
print(txt)
data.append(txt)

// -- MAIN GAME LOOP --------------------------------------
while !WindowShouldClose(), !balls.endSimulation {
  BeginDrawing()
  ClearBackground(BLACK)
  balls.draw()
  EndDrawing()
  currentTime = getCurrentTime() - startTime
  balls.currentTime = currentTime
  balls.updateHealth()
  balls.checkCollisions()
  balls.processInfected()
  if currentTime > prevTime {
    prevTime = currentTime
    txt = balls.getStats()
    print(txt)
    data.append(txt)
  }
  balls.updatePos()
}

txt = balls.getStats()
print(txt)
data.append(txt)
CloseWindow()
if writeListToFile(list: data, to: "data.txt") {
  print("Data successfully written.")
} else {
  print("Error during data write.")
}
