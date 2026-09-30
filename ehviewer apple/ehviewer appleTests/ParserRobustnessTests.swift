//
//  ParserRobustnessTests.swift
//  ehviewer appleTests
//
//  服务器返回错误页、限流页或页面改版时，解析器必须优雅降级，不能崩溃。
//  SwiftSoup 的 child(_:) 越界会直接崩进程而不是抛错，所以这里喂的都是
//  "结构不完整"的 HTML：这些用例只要能跑完就算通过，崩溃即失败。
//

import Testing
import Foundation
import EhParser

struct ParserRobustnessTests {

    @Test func archiverWithEmptyPageDoesNotCrash() {
        for isEx in [false, true] {
            let data = ArchiveParser.parseArchiver("", isExHentai: isEx)
            #expect(data.originalUrl == nil)
        }
    }

    /// 表格行存在，但行内第一个子节点没有子元素——旧代码的
    /// child(0).child(0) 会在这里越界崩溃
    @Test func archiverWithHollowRowsDoesNotCrash() {
        let html = """
        <html><body><div></div><div></div><div>funds</div>
        <div><div><div></div><form></form><div></div></div>
        <div><div></div><form></form><div></div></div></div>
        </body></html>
        """
        for isEx in [false, true] {
            _ = ArchiveParser.parseArchiver(html, isExHentai: isEx)
        }
    }

    @Test func forumsParserThrowsInsteadOfCrashing() {
        #expect(throws: Error.self) {
            try ForumsParser.parseProfileUrl("<html><body><div id=\"userlinks\"></div></body></html>")
        }
        #expect(throws: Error.self) {
            try ForumsParser.parseProfileUrl("<html><body>nothing here</body></html>")
        }
    }

    @Test func profileParserWithHollowNameDoesNotCrash() {
        let html = "<html><body><div id=\"profilename\"></div><p></p><p></p></body></html>"
        _ = try? ProfileParser.parse(html)
    }
}
