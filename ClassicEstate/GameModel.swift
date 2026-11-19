import SwiftUI

enum EndRule: String, CaseIterable {
    case bankruptcy = "首位玩家破產"
    case rounds = "指定完整輪數"
}

enum CellKind { case go, land, chance, jail, tax, parking, goToJail }

struct BoardCell: Identifiable {
    let id: Int
    let name: String
    let kind: CellKind
    var price: Int = 0
    var baseRent: Int = 0
    var owner: Int? = nil
    var level: Int = 0
    var upgradeCost: Int { price }
    var rent: Int { baseRent * (level + 1) }
}

struct Player: Identifiable {
    let id: Int
    var name: String
    var cash = 1500
    var position = 0
    var jailTurns = 0
    var bankrupt = false
}

@MainActor
final class GameModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var board: [BoardCell] = []
    @Published var active = false
    @Published var finished = false
    @Published var current = 0
    @Published var dice = [1, 1]
    @Published var hasRolled = false
    @Published private(set) var upgradeOpportunity: Int?
    @Published var completedRounds = 0
    @Published var message = "歡迎來到大富翁！"
    @Published var history: [String] = []
    @Published var finishReason = ""
    var rule: EndRule = .bankruptcy
    var roundLimit = 10
    let goBonus = 200
    let colors: [Color] = [.blue, .orange, .purple, .pink]

    func start(count: Int, names: [String], rule: EndRule, rounds: Int) {
        self.rule = rule
        roundLimit = rounds
        players = (0..<count).map { index in
            let name = names[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return Player(id: index, name: name.isEmpty ? "玩家 \(index + 1)" : name)
        }
        board = Self.makeBoard()
        current = 0
        completedRounds = 0
        hasRolled = false
        upgradeOpportunity = nil
        finished = false
        dice = [1, 1]
        history = []
        finishReason = ""
        active = true
        log("遊戲開始！由\(players[0].name)先擲骰。")
    }

    static func makeBoard() -> [BoardCell] {
        let names = ["起點", "松林路", "機會", "楓葉路", "所得稅", "湖畔路", "監獄／探訪", "海風路", "機會", "港灣路", "珊瑚路", "星光路", "免費停車", "山城路", "機會", "雲頂路", "市政稅", "天空路", "前往監獄", "月光路", "機會", "銀河路", "太陽路", "皇冠路"]
        var result: [BoardCell] = []
        for index in 0..<24 {
            if index == 0 { result.append(BoardCell(id: index, name: names[index], kind: .go)) }
            else if index == 6 { result.append(BoardCell(id: index, name: names[index], kind: .jail)) }
            else if index == 12 { result.append(BoardCell(id: index, name: names[index], kind: .parking)) }
            else if index == 18 { result.append(BoardCell(id: index, name: names[index], kind: .goToJail)) }
            else if index == 2 || index == 8 || index == 14 || index == 20 { result.append(BoardCell(id: index, name: names[index], kind: .chance)) }
            else if index == 4 || index == 16 { result.append(BoardCell(id: index, name: names[index], kind: .tax)) }
            else {
                let price = 100 + (index / 6) * 80 + (index % 6) * 10
                result.append(BoardCell(id: index, name: names[index], kind: .land, price: price, baseRent: price * 2 / 5))
            }
        }
        return result
    }

    func log(_ text: String) {
        message = text
        history.insert(text, at: 0)
    }

    var canBuy: Bool {
        if !active || finished || !hasRolled { return false }
        let cell = board[players[current].position]
        if cell.kind == .land && cell.owner == nil && players[current].cash >= cell.price { return true }
        return false
    }

    func buy() {
        if !canBuy { return }
        let position = players[current].position
        players[current].cash -= board[position].price
        board[position].owner = current
        log("\(players[current].name)以 $\(board[position].price)買下\(board[position].name)。")
    }

    func canUpgrade(_ index: Int) -> Bool {
        if !active || finished || !hasRolled || !board.indices.contains(index) { return false }
        let cell = board[index]
        if cell.owner == current && upgradeOpportunity == index && players[current].cash >= cell.upgradeCost { return true }
        return false
    }

    func upgrade(_ index: Int) {
        if !canUpgrade(index) { return }
        players[current].cash -= board[index].upgradeCost
        board[index].level += 1
        upgradeOpportunity = nil
        log("\(players[current].name)升級\(board[index].name)至 \(board[index].level) 級。")
    }

    func roll() {
        if !active || finished || hasRolled { return }
        hasRolled = true
        dice = [Int.random(in: 1...6), Int.random(in: 1...6)]
        let name = players[current].name
        log("\(name)擲出 \(dice[0]) + \(dice[1])。")
        if players[current].jailTurns > 0 {
            if dice[0] == dice[1] {
                players[current].jailTurns = 0
                log("\(name)擲出雙數，立即出獄並前進。")
            } else {
                players[current].jailTurns -= 1
                log("\(name)未擲出雙數，本回合留在監獄；下回合恢復自由。")
                return
            }
        }
        move(steps: dice[0] + dice[1])
        resolveLanding()
    }

    func move(steps: Int) {
        let destination = players[current].position + steps
        if destination >= board.count {
            players[current].cash += goBonus
            log("\(players[current].name)通過起點，領取 $\(goBonus)。")
        }
        players[current].position = destination % board.count
    }

    func resolveLanding() {
        let cell = board[players[current].position]
        if cell.kind == .land {
            if let owner = cell.owner {
                if owner == current {
                    upgradeOpportunity = cell.id
                    log("抵達自己的\(cell.name)，可升級這塊土地一次。")
                }
                else { pay(cell.rent, to: owner, reason: "\(cell.name)租金") }
            } else { log("抵達\(cell.name)：售價 $\(cell.price)，可購買或略過。") }
        } else if cell.kind == .chance { chance() }
        else if cell.kind == .tax { pay(120, to: nil, reason: "稅金") }
        else if cell.kind == .goToJail { sendToJail() }
        else if cell.kind == .jail { log("探訪監獄，無須停留。") }
        else if cell.kind == .parking { log("免費停車，休息一下。") }
        else { log("抵達起點，通過獎金已領取。") }
    }

    func chance() {
        let event = Int.random(in: 0...6)
        if event == 0 {
            players[current].cash += 150
            log("機會：獲得獎金 $150！")
        } else if event == 1 { pay(100, to: nil, reason: "機會：道路維護費") }
        else if event == 2 {
            players[current].position = 0
            players[current].cash += goBonus
            log("機會：前往起點並領取 $200。")
        } else if event == 3 { sendToJail() }
        else if event == 4 {
            log("機會：前進 3 格。")
            move(steps: 3)
            resolveLanding()
        } else if event == 5 {
            log("機會：向其他每位玩家支付 $100。")
            for offset in 1..<players.count {
                let recipient = (current + offset) % players.count
                if !players[recipient].bankrupt {
                    pay(100, to: recipient, reason: "機會費用")
                    if players[current].bankrupt || finished { break }
                }
            }
        } else {
            log("機會：其他每位玩家向\(players[current].name)支付 $100。")
            for offset in 1..<players.count {
                let payer = (current + offset) % players.count
                if !players[payer].bankrupt {
                    pay(100, to: current, reason: "機會費用", from: payer)
                    if finished { break }
                }
            }
        }
    }

    func sendToJail() {
        players[current].position = 6
        players[current].jailTurns = 1
        log("\(players[current].name)進入監獄！下次擲骰若非雙數，停留一回合。")
    }

    func pay(_ amount: Int, to creditor: Int?, reason: String, from payer: Int? = nil) {
        let debtor = payer ?? current
        let available = players[debtor].cash
        if available >= amount {
            players[debtor].cash -= amount
            if let creditor { players[creditor].cash += amount }
            log("\(players[debtor].name)支付\(reason) $\(amount)。")
        } else {
            if let creditor { players[creditor].cash += available }
            players[debtor].cash = 0
            players[debtor].bankrupt = true
            // 課堂版：無抵押或出售；現金不足即破產，土地回收銀行。
            for index in board.indices {
                if board[index].owner == debtor {
                    board[index].owner = nil
                    board[index].level = 0
                }
            }
            log("\(players[debtor].name)無法支付\(reason) $\(amount)，支付剩餘 $\(available)後破產。土地由銀行收回。")
            let survivors = players.filter { !$0.bankrupt }.count
            if rule == .bankruptcy { endGame("出現首位破產玩家，遊戲結束。") }
            else if survivors <= 1 { endGame("只剩一位未破產玩家，提前結束。") }
        }
    }

    func endTurn() {
        if !active || finished || !hasRolled { return }
        var next = current + 1
        // 一輪是每個仍在場玩家依座位順序完成一次回合，監獄停留也算。
        if next >= players.count {
            next = 0
            completedRounds += 1
        }
        while players[next].bankrupt {
            next += 1
            if next >= players.count {
                next = 0
                completedRounds += 1
            }
        }
        if rule == .rounds && completedRounds >= roundLimit {
            endGame("已完成 \(roundLimit) 輪。")
            return
        }
        current = next
        upgradeOpportunity = nil
        hasRolled = false
        log("輪到\(players[current].name)擲骰。")
    }

    func score(_ id: Int) -> Int {
        var total = players[id].cash
        for cell in board {
            if cell.owner == id { total += cell.price + cell.level * cell.upgradeCost }
        }
        return total
    }

    var ranking: [Player] {
        players.sorted { a, b in
            if a.bankrupt != b.bankrupt { return !a.bankrupt }
            if score(a.id) != score(b.id) { return score(a.id) > score(b.id) }
            return a.id < b.id
        }
    }

    func endGame(_ reason: String) {
        finishReason = reason
        finished = true
    }
}
