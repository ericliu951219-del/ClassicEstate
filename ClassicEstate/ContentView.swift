import SwiftUI

// 使用傳統 ObservableObject，讓設定狀態也能在不同 Xcode 版本編譯。
@MainActor
final class SetupState: ObservableObject {
    @Published var count = 2
    @Published var names = ["玩家 1", "玩家 2", "玩家 3", "玩家 4"]
    @Published var rule: EndRule = .bankruptcy
    @Published var rounds = 10
    @Published var showRules = false
    @Published var confirmRestart = false
}

struct ContentView: View {
    @StateObject private var game = GameModel()
    @StateObject private var settings = SetupState()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !game.active { setup }
                    else if game.finished { results }
                    else { playArea }
                }
                .padding()
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background(LinearGradient(colors: [Color(.systemGroupedBackground), Color.green.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .tint(Color(red: 0.15, green: 0.38, blue: 0.29))
            .navigationTitle("大富翁")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("規則", systemImage: "book") { settings.showRules = true }
                }
                if game.active {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("重新設定") { settings.confirmRestart = true }
                    }
                }
            }
            .sheet(isPresented: $settings.showRules) {
                NavigationStack {
                    ScrollView { Text(Self.rules).padding().frame(maxWidth: 650, alignment: .leading) }
                        .navigationTitle("遊戲規則")
                        .toolbar { Button("完成") { settings.showRules = false } }
                }
            }
            .confirmationDialog("結束本局並返回設定？本局進度將清除。", isPresented: $settings.confirmRestart, titleVisibility: .visible) {
                Button("返回設定", role: .destructive) { game.active = false }
                Button("取消", role: .cancel) { }
            }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("CLASSIC ESTATE", systemImage: "sparkles")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                    Spacer()
                    Image(systemName: "crown.fill")
                }
                .foregroundStyle(Color(red: 0.91, green: 0.79, blue: 0.52))

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("大富翁")
                            .font(.system(.largeTitle, design: .serif, weight: .heavy))
                        Text("好運上桌，地產之旅開始。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(red: 0.91, green: 0.79, blue: 0.52).opacity(0.8))
                        .accessibilityHidden(true)
                }
                HStack(spacing: 8) {
                    Label("2–4 人", systemImage: "person.2.fill")
                    Text("・")
                    Label("24 格", systemImage: "square.grid.3x3.fill")
                    Text("・")
                    Text("同樂桌遊")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [Color(red: 0.10, green: 0.27, blue: 0.21), Color(red: 0.22, green: 0.43, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.78, green: 0.65, blue: 0.38), lineWidth: 1))
            .shadow(color: .black.opacity(0.16), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("玩家設定", systemImage: "person.2.fill")
                        .font(.headline)
                    Spacer()
                    Text("01").font(.caption.bold()).foregroundStyle(.secondary)
                }
                Text("邀請朋友，一起坐上牌桌")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("玩家人數", selection: $settings.count) {
                    ForEach(2...4, id: \.self) { Text("\($0) 位玩家").tag($0) }
                }
                .pickerStyle(.segmented)
                ForEach(0..<settings.count, id: \.self) { index in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(game.colors[index], in: Circle())
                        TextField("玩家 \(index + 1)", text: $settings.names[index])
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: settings.names[index]) { _, value in
                                if value.count > 16 { settings.names[index] = String(value.prefix(16)) }
                            }
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("選擇結束條件", systemImage: "flag.checkered")
                        .font(.headline)
                    Spacer()
                    Text("02").font(.caption.bold()).foregroundStyle(.secondary)
                }
                Text("決定這場地產競賽如何分出勝負")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(EndRule.allCases, id: \.self) { rule in
                    Button {
                        settings.rule = rule
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: rule == .bankruptcy ? "chart.line.downtrend.xyaxis" : "clock.fill")
                                .font(.headline)
                                .frame(width: 38, height: 38)
                                .background(settings.rule == rule ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.rawValue).font(.subheadline.bold())
                                Text(rule == .bankruptcy
                                     ? "第一位玩家破產時結束，其餘玩家依總資產排名。"
                                     : "每位在場玩家完成一次回合算一輪；只剩一人時提前結束。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: settings.rule == rule ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(settings.rule == rule ? Color.green : Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(settings.rule == rule ? Color.green.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(settings.rule == rule ? Color.green : Color.secondary.opacity(0.2), lineWidth: settings.rule == rule ? 2 : 1))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(settings.rule == rule ? .isSelected : [])
                }
                if settings.rule == .rounds {
                    Stepper("共 \(settings.rounds) 輪", value: $settings.rounds, in: 1...50)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }

            Label("起始現金 $1,500・通過起點 +$200", systemImage: "banknote")
                .font(.subheadline)
            Text("現金不足即破產；無抵押、交易或拍賣。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                game.start(count: settings.count, names: settings.names, rule: settings.rule, rounds: settings.rounds)
            } label: {
                Label("開始遊戲", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.72, green: 0.60, blue: 0.34).opacity(0.5), lineWidth: 1))
    }

    private var playArea: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("現在輪到").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(game.players[game.current].name).font(.title2.bold())
                    if game.rule == .rounds {
                        Text("第 \(game.completedRounds + 1) / \(game.roundLimit) 輪")
                    } else { Text("第 \(game.completedRounds + 1) 輪・首位破產即結束") }
                }
                Spacer()
                Text("\(game.current + 1)")
                    .font(.title3.bold()).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(game.colors[game.current], in: Circle())
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(game.colors[game.current].opacity(0.5), lineWidth: 1))
            EstateBoardView(board: game.board, players: game.players, current: game.current, colors: game.colors)
            VStack(spacing: 12) {
                Label("本回合", systemImage: "sparkles")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 18) {
                    Image(systemName: "die.face.\(game.dice[0]).fill")
                    Image(systemName: "die.face.\(game.dice[1]).fill")
                }.font(.system(size: 44)).foregroundStyle(game.colors[game.current])
                    .accessibilityLabel("骰子 \(game.dice[0]) 和 \(game.dice[1])")
                Text(game.message)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                if game.players[game.current].jailTurns > 0 {
                    Text("在監獄：下次擲出雙數即可前進，否則停留一回合。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack {
                    Button("擲兩顆骰子") { game.roll() }
                        .disabled(game.hasRolled).buttonStyle(.borderedProminent)
                    if game.canBuy {
                        Button("購買土地") { game.buy() }.buttonStyle(.bordered)
                    }
                    Button("結束回合") { game.endTurn() }
                        .disabled(!game.hasRolled).buttonStyle(.bordered)
                    }
                    VStack {
                        Button("擲兩顆骰子") { game.roll() }
                            .disabled(game.hasRolled).buttonStyle(.borderedProminent)
                        if game.canBuy {
                            Button("購買土地") { game.buy() }.buttonStyle(.bordered)
                        }
                        Button("結束回合") { game.endTurn() }
                            .disabled(!game.hasRolled).buttonStyle(.bordered)
                    }
                }.controlSize(.large)
            }.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.72, green: 0.60, blue: 0.34).opacity(0.35), lineWidth: 1))
            playerCards
            if game.hasRolled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("我的土地・升級").font(.headline)
                    Text("再次停在自有土地時可升級一次，等級無上限。租金 = 基本租金 ×（等級 + 1）。")
                        .font(.caption).foregroundStyle(.secondary)
                    let owned = game.board.filter { $0.owner == game.current }
                    if owned.isEmpty { Text("目前沒有土地。") }
                    ForEach(owned) { cell in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(cell.name)・\(cell.level) 級")
                                Text("租金 $\(cell.rent)｜升級 $\(cell.upgradeCost)").font(.caption)
                            }
                            Spacer()
                            Button("升級") { game.upgrade(cell.id) }
                                .disabled(!game.canUpgrade(cell.id)).buttonStyle(.bordered)
                        }
                    }
                }.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.72, green: 0.60, blue: 0.34).opacity(0.35), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("遊戲紀錄", systemImage: "clock.arrow.circlepath").font(.headline)
                ForEach(Array(game.history.prefix(30).enumerated()), id: \.offset) { _, entry in
                    Text(entry).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.72, green: 0.60, blue: 0.34).opacity(0.35), lineWidth: 1))
        }
    }

    private var playerCards: some View {
        VStack(spacing: 8) {
            ForEach(game.players) { player in
                HStack {
                    Circle().fill(game.colors[player.id]).frame(width: 12, height: 12)
                    VStack(alignment: .leading) {
                        Text("\(player.id + 1). \(player.name)\(player.bankrupt ? "（破產）" : "")").bold()
                        Text("現金 $\(player.cash)｜總資產 $\(game.score(player.id))")
                            .font(.subheadline)
                    }
                    Spacer()
                    if player.jailTurns > 0 { Image(systemName: "lock.fill") }
                    if player.id == game.current && !game.finished { Text("本回合").font(.caption).foregroundStyle(.secondary) }
                }.padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(player.id == game.current ? game.colors[player.id].opacity(0.7) : Color.secondary.opacity(0.15), lineWidth: player.id == game.current ? 2 : 1))
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("遊戲結束", systemImage: "trophy.fill").font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(Color(red: 0.65, green: 0.48, blue: 0.16))
            Text(game.finishReason)
            Text("未破產者優先，依總資產排名；資產相同為並列。")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(Array(game.ranking.enumerated()), id: \.element.id) { index, player in
                HStack {
                    let firstSame = game.ranking.firstIndex { $0.bankrupt == player.bankrupt && game.score($0.id) == game.score(player.id) } ?? index
                    Text("#\(firstSame + 1)").font(.title2.bold()).foregroundStyle(game.colors[player.id])
                    VStack(alignment: .leading) {
                        Text(player.name).font(.headline)
                        Text(player.bankrupt ? "已破產" : "現金 $\(player.cash)")
                    }
                    Spacer()
                    Text("$\(game.score(player.id))").font(.title3.bold())
                }
            }
            Text("總資產 = 現金 + 土地原價 + 已投入升級費用。")
                .font(.caption).foregroundStyle(.secondary)
            Text(game.message).font(.subheadline)
            Button("再玩一局・返回設定") { game.active = false }.buttonStyle(.borderedProminent)
        }.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.72, green: 0.60, blue: 0.34).opacity(0.5), lineWidth: 1))
    }

    static let rules = """
    1. 2–4 位真人共用裝置，每人起始現金 $1,500，從 0 號起點出發。

    2. 每回合擲兩顆骰子，順時針移動。雙數不加開回合。經過或抵達起點領 $200；被送進監獄不領取。

    3. 抵達無主土地可購買或略過；抵達他人土地自動付租。購買後再次停在自有土地時，可升級該土地一次，等級沒有上限；購買當次不可升級。每級費用為地價，基本租金為地價的 40%，實際租金為基本租金乘以（等級 + 1）。

    4. 機會格隨機發生獎金、費用、前往起點、入獄、前進 3 格，或與其他未破產玩家各支付或收取 $100。玩家間的款項依座位順序處理；付款不足時依破產規則處理，遊戲結束時停止付款。前進後再次處理落點。稅格支付 $120；免費停車沒有額外效果。

    5. 入獄後位於 6 號格。下次擲骰若為雙數，立即出獄並移動；否則停留該回合，下回合恢復自由。自然走到監獄只是探訪。

    6. 現金不足支付即破產：剩餘現金交給債權玩家或銀行，土地及升級收歸銀行。沒有抵押、出售、交易、拍賣或房屋組色限制。

    7. 首位破產模式：有人破產立即結束。指定輪數模式：每位仍在場玩家依序完成一次回合為一輪，監獄停留也計入；破產玩家退出。指定輪數完成或只剩一位未破產玩家時結束。

    8. 按「結束回合」換下一位。最後一回合仍可購買，或在符合條件時升級，按下結束回合後結算。總資產為現金、土地原價與升級投入費用總和；未破產者優先，再依資產排名，資產相同並列。

    """
}


private struct EstateBoardView: View {
    let board: [BoardCell]
    let players: [Player]
    let current: Int
    let colors: [Color]

    var body: some View {
        ScrollView(.horizontal) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.12, green: 0.29, blue: 0.23))
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { column in
                                if let index = cellIndex(row: row, column: column) {
                                    EstateCellView(
                                        cell: board[index],
                                        players: players.filter { $0.position == index && !$0.bankrupt },
                                        currentPosition: players[current].position,
                                        colors: colors
                                    )
                                } else {
                                    Color.clear.frame(maxWidth: .infinity, minHeight: 76)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                VStack(spacing: 10) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 38))
                    Text("大富翁")
                        .font(.system(.title, design: .serif, weight: .bold))
                    Text("CLASSIC ESTATE")
                        .font(.caption.weight(.semibold))
                        .tracking(3)
                    Image(systemName: "sparkles")
                }
                .foregroundStyle(Color(red: 0.90, green: 0.80, blue: 0.56))
                .accessibilityHidden(true)
            }
            .frame(minWidth: 560)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.72, green: 0.60, blue: 0.34), lineWidth: 3))
        }
        .scrollIndicators(.visible)
    }

    private func cellIndex(row: Int, column: Int) -> Int? {
        if row == 0 { return column }
        if column == 6 { return 6 + row }
        if row == 6 { return 18 - column }
        if column == 0 { return 24 - row }
        return nil
    }
}

private struct EstateCellView: View {
    let cell: BoardCell
    let players: [Player]
    let currentPosition: Int
    let colors: [Color]

    private var symbol: String {
        switch cell.kind {
        case .go: "arrow.forward.circle.fill"
        case .land: "house.fill"
        case .chance: "questionmark.diamond.fill"
        case .jail: "lock.fill"
        case .tax: "banknote.fill"
        case .parking: "parkingsign.circle.fill"
        case .goToJail: "figure.walk"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("\(cell.id)").font(.caption2)
                Spacer(minLength: 0)
                Image(systemName: symbol).font(.caption2)
            }
            Text(cell.name)
                .font(.caption2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if cell.kind == .land {
                if cell.owner != nil {
                    Text("租\(cell.rent) · L\(cell.level)").font(.caption2)
                        .lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Text("$\(cell.price)").font(.caption2.weight(.medium))
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(players) { player in
                    Text("\(player.id + 1)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(colors[player.id], in: Circle())
                }
            }
            .frame(minHeight: 16)
        }
        .padding(5)
        .frame(maxWidth: .infinity, minHeight: 76)
        .foregroundStyle(Color(red: 0.16, green: 0.22, blue: 0.18))
        .background(Color(red: 0.97, green: 0.94, blue: 0.84), in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .top) {
            if let owner = cell.owner {
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[owner])
                    .frame(height: 4)
                    .padding(.horizontal, 3)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(currentPosition == cell.id ? Color(red: 0.77, green: 0.55, blue: 0.17) : .clear, lineWidth: 3))
        .accessibilityElement(children: .combine)
    }
}
