//
//  StoreWriteLock.swift
//  colorlog (앱 · 위젯 공용)
//
//  앱과 위젯(인텐트)이 같은 저장소에 쓰는 순간을 한 줄로 세운다.
//
//  두 프로세스는 각자 SwiftData 컨테이너를 들고 있어 서로의 쓰기를 모른다.
//  같은 날의 첫 기록을 거의 동시에 만들면 둘 다 '없음'을 보고 새 레코드를 넣고,
//  `#Unique(date)`의 upsert가 나중에 저장한 쪽의 `colors` 배열로 통째로 덮는다
//  → 먼저 고른 자리의 색이 사라진다. 앱이 오래 들고 있던(낡은) 객체로 저장할 때도 같다.
//
//  그래서 쓰기는 (1) 저장소 옆 잠금 파일로 프로세스 사이에서 한 번에 하나만,
//  (2) 잠근 뒤에 저장소에서 최신 자리 값을 다시 읽어 그 위에 한 자리만 바꿔 저장한다.
//

import Darwin
import Foundation
import OSLog

nonisolated private let lockLogger = Logger(subsystem: "com.colorlog", category: "store")

nonisolated enum StoreWriteLock {

    /// 이만큼 기다려도 못 잡으면 잠금 없이 쓴다. 잠금을 쥔 프로세스가 멈춰 있어도
    /// 앱이 얼어붙지 않게 하기 위해서다(그 경우만 예전과 같은 경쟁이 남는다).
    static let timeout: Duration = .seconds(2)

    /// `storeURL` 옆의 잠금 파일(`<store>.writelock`)을 잡고 `body`를 실행한다.
    /// 메모리 저장소(프리뷰 · 테스트)처럼 파일이 없으면 그냥 실행한다.
    static func withLock<T>(for storeURL: URL?, _ body: () throws -> T) rethrows -> T {
        guard let storeURL, storeURL.isFileURL, storeURL.path != "/dev/null" else { return try body() }
        let lockPath = storeURL.path + ".writelock"
        let fd = open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard fd >= 0 else {
            lockLogger.error("쓰기 잠금 파일을 열지 못함(errno \(errno)) — 잠금 없이 쓴다")
            return try body()
        }
        defer { close(fd) }   // 닫으면 잠금도 풀린다. 프로세스가 죽어도 커널이 푼다.

        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        var locked = false
        while true {
            if flock(fd, LOCK_EX | LOCK_NB) == 0 { locked = true; break }
            guard errno == EWOULDBLOCK || errno == EINTR, clock.now < deadline else { break }
            usleep(5_000)
        }
        if !locked { lockLogger.error("쓰기 잠금을 2초 안에 잡지 못함 — 잠금 없이 쓴다") }
        defer { if locked { flock(fd, LOCK_UN) } }
        return try body()
    }
}
