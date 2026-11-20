#!/bin/zsh
#
# 출시된 스키마로 만든 SwiftData 저장소를 테스트 리소스로 굽는다.
#
#   scripts/make_store_fixtures.sh
#
# 각 출시 커밋의 `DailyColorLog` 모델 선언(@Model 클래스 본문)을 git에서 **그대로** 꺼내
# macOS 명령줄 도구로 컴파일하고, 그 도구가 기록 몇 개를 넣은 저장소를 만든다.
# 모델 선언 밖의 의존성(HexColor · 팔레트 · 곰)은 저장 형태에 영향이 없어 작은 대역으로 바꾼다.
#
#   v1_0_1.store   1.0 · 1.0.1 (커밋 7f4b457)   date · colors · themePalette
#   v1_1_0.store   1.1.0       (커밋 2485d47)   + poseRawValue
#   future.store   아직 없는 버전 — 앱이 모르는 스키마를 만났을 때를 흉내 낸다
#
# 기록은 Asia/Seoul 자정으로 저장된다(시간대 테스트가 이 사실에 기댄다).
#
set -euo pipefail

ROOT=${0:A:h:h}
OUT="$ROOT/colorlogTests/Fixtures"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

model_block() {   # $1 = commit
    git -C "$ROOT" show "$1:Shared/Models/DailyColorLog.swift" \
        | awk '/^@Model/{p=1} p{print} p&&/^}/{exit}'
}

cat > "$WORK/Stubs.swift" <<'SWIFT'
import Foundation
enum HexColor {
    static func normalized(_ hex: String) -> String? { hex.isEmpty ? nil : hex.uppercased() }
}
enum ColorPalette: String { case pantone; static let `default` = ColorPalette.pantone }
struct Palette { var id: String; static let `default` = Palette(id: "pantone") }
enum BearPose: String, CaseIterable { case sitting }
SWIFT

# $1 = 이름, $2 = 모델 소스, $3 = 기록 후 할 일(Swift 코드)
build_and_run() {
    local dir="$WORK/$1"
    mkdir -p "$dir"
    cp "$WORK/Stubs.swift" "$dir/"
    print -r -- "import Foundation
import SwiftData
$2" > "$dir/Model.swift"
    cat > "$dir/main.swift" <<SWIFT
import Foundation
import SwiftData

let url = URL(fileURLWithPath: CommandLine.arguments[1])
// 출시 앱과 같은 방식: 버전 없는 Schema([DailyColorLog.self])
let schema = Schema([DailyColorLog.self])
let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
let context = ModelContext(container)
let calendar = Calendar.current
let samples: [(Int, [String])] = [
    (1, ["#FF0000", "#00FF00", "#0000FF"]),
    (2, ["#112233", "", ""]),
    (3, ["", "#ABCDEF", ""]),
]
var logs: [DailyColorLog] = []
for (day, colors) in samples {
    let date = calendar.date(from: DateComponents(year: 2025, month: 10, day: day, hour: 15))!
    let log = DailyColorLog(date: date, colors: colors, palette: .default)
    context.insert(log)
    logs.append(log)
}
$3
try context.save()
print("wrote \(url.path)")
SWIFT
    xcrun -sdk macosx swiftc -swift-version 5 -O "$dir/Stubs.swift" "$dir/Model.swift" "$dir/main.swift" -o "$dir/tool"
    rm -f "$OUT/$1.store" "$OUT/$1.store-wal" "$OUT/$1.store-shm"
    TZ=Asia/Seoul "$dir/tool" "$OUT/$1.store"
    # WAL을 본 파일에 합쳐 파일 하나만 리소스로 싣는다.
    sqlite3 "$OUT/$1.store" "PRAGMA wal_checkpoint(TRUNCATE);" > /dev/null
    rm -f "$OUT/$1.store-wal" "$OUT/$1.store-shm"
}

V101=$(model_block 7f4b457)
V110=$(model_block 2485d47)

build_and_run v1_0_1 "$V101" ""
build_and_run v1_1_0 "$V110" '
logs[0].poseRawValue = "waving"
logs[1].poseRawValue = nil
'
# 미래 버전: 필수 속성이 하나 더 있는 스키마
FUTURE=${V110/var poseRawValue: String?/var poseRawValue: String?
    var mood: Int = 0}
build_and_run future "$FUTURE" ""

ls -l "$OUT"
