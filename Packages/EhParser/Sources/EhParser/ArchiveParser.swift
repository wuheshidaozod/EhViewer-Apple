import Foundation
import EhModels

// MARK: - 归档解析器 (对应 Android ArchiveParser.java)

public enum ArchiveParser {

    // MARK: 正则

    /// H@H 下载表单 or 参数
    private static let formRegex = try! NSRegularExpression(
        pattern: #"<form id="hathdl_form" action="[^"]*?or=([^="]*?)" method="post">"#
    )

    /// 归档条目: res ID + 名称
    private static let archiveRegex = try! NSRegularExpression(
        pattern: #"<a href="[^"]*" onclick="return do_hathdl\('([0-9]+|org)'\)">([^<]+)</a>"#
    )

    /// 归档下载链接
    private static let downloadUrlRegex = try! NSRegularExpression(
        pattern: #"href="(.*)">Click Here To Start Downloading"#
    )

    // MARK: - 解析归档列表 (对应 Android ArchiveParser.parse)

    /// 返回 (or 参数, [(res ID, 名称)])
    public static func parse(_ body: String) throws -> ArchiveListResult {
        let nsBody = body as NSString
        let fullRange = NSRange(location: 0, length: nsBody.length)

        // 提取 or 参数
        var paramOr = ""
        if let match = formRegex.firstMatch(in: body, range: fullRange),
           let range = Range(match.range(at: 1), in: body) {
            paramOr = String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 提取归档条目
        var archives: [(String, String)] = []
        for match in archiveRegex.matches(in: body, range: fullRange) {
            if let resRange = Range(match.range(at: 1), in: body),
               let nameRange = Range(match.range(at: 2), in: body) {
                let res = String(body[resRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let name = String(body[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                archives.append((res, name))
            }
        }

        return ArchiveListResult(paramOr: paramOr, archives: archives)
    }

    // MARK: - 解析归档详情 (对应 Android ArchiveParser.parseArchiver)

    public static func parseArchiver(_ body: String, isExHentai: Bool = false) -> ArchiverData {
        var data = ArchiverData()

        do {
            let doc = try SwiftSoup.parse(body)

            // DOM 结构: html > head > body > div
            // E-Hentai 和 ExHentai 的 body 子节点索引不同
            // ⚠️ Bug: 原来这里是 try doc.body()!——一旦服务器返回的不是正常的
            // 归档页（错误页、限流页、Sad Panda 拦截页等没有 <body> 的响应），
            // force-unwrap 失败是运行时直接崩溃，不是 Swift 错误，不会被下面
            // 的 catch 接住，跟整段代码"解析失败就静默返回空数据"的设计初衷
            // （对齐 Android catch (Exception) ignore）正好相反。改成 guard
            // 提前返回，走同一条"优雅降级"路径。
            guard let bodyEl = try doc.body() else { return data }

            let children = bodyEl.children()
            if isExHentai {
                // ExHentai: bodyElement.child(0) = funds, child(1) = table
                guard children.size() > 1 else { return data }
                data.funds = try children.get(0).text()

                let table = children.get(1)
                let rows = table.children()
                if rows.size() >= 2 {
                    // Original
                    let original = rows.get(0)
                    if let cost = original.safeChild(0)?.safeChild(0),
                       let form = original.safeChild(1),
                       let size = original.safeChild(2)?.safeChild(0) {
                        data.originalCost = try cost.text()
                        data.originalUrl = try form.attr("action")
                        data.originalSize = try size.text()
                    }
                    // Resample
                    let resample = rows.get(1)
                    if let cost = resample.safeChild(0)?.safeChild(0),
                       let form = resample.safeChild(1),
                       let size = resample.safeChild(2)?.safeChild(0) {
                        data.resampleCost = try cost.text()
                        data.resampleUrl = try form.attr("action")
                        data.resampleSize = try size.text()
                    }
                }
            } else {
                // E-Hentai: bodyElement.child(2) = funds, child(3) = table
                guard children.size() > 3 else { return data }
                data.funds = try children.get(2).text()

                let table = children.get(3)
                let rows = table.children()
                if rows.size() >= 2 {
                    let original = rows.get(0)
                    if let cost = original.safeChild(0)?.safeChild(0),
                       let form = original.safeChild(1),
                       let size = original.safeChild(2)?.safeChild(0) {
                        data.originalCost = try cost.text()
                        data.originalUrl = try form.attr("action")
                        data.originalSize = try size.text()
                    }
                    let resample = rows.get(1)
                    if let cost = resample.safeChild(0)?.safeChild(0),
                       let form = resample.safeChild(1),
                       let size = resample.safeChild(2)?.safeChild(0) {
                        data.resampleCost = try cost.text()
                        data.resampleUrl = try form.attr("action")
                        data.resampleSize = try size.text()
                    }
                }
            }
        } catch {
            // 静默失败，对应 Android catch (Exception ignore)
        }

        return data
    }

    // MARK: - 解析归档下载链接 (对应 Android ArchiveParser.parseArchiverDownloadUrl)

    public static func parseArchiverDownloadUrl(_ body: String) -> String? {
        let nsBody = body as NSString
        let fullRange = NSRange(location: 0, length: nsBody.length)
        guard let match = downloadUrlRegex.firstMatch(in: body, range: fullRange),
              let range = Range(match.range(at: 1), in: body) else {
            return nil
        }
        return String(body[range])
    }
}

// SwiftSoup import
import SwiftSoup
