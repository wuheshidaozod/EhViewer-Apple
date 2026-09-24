//
//  ReaderPageMenu.swift
//  ehviewer apple
//
//  阅读器的单页操作 — 对齐 Android GalleryActivity.showPageDialog
//
//  Android 长按页面会弹一个四项菜单：刷新本页 / 分享 / 保存 / 保存到…
//  iOS 端此前一项都没有：一张图加载坏了只能退出重进，想留一张也没有出口。
//

import SwiftUI
import Photos
import UniformTypeIdentifiers
import ImageIO

#if os(iOS)
import UIKit
#endif

/// 把一张图存进相册。
///
/// 只申请「仅添加」权限（PHAccessLevel.addOnly）——保存图片不需要读取用户
/// 的整个相册，要了也是多余的权限面。
@MainActor
enum ReaderImageSaver {
    #if os(iOS)

    /// 从原始字节里认出真实的图片格式 (UTType)，而不是不管三七二十一当 PNG 存。
    /// 保存原图时这份 Data 很可能本来就是 JPEG——当 PNG 重新包一层没有意义，
    /// 还平白多一次编码。识别不出来才退回 PNG。
    private static func detectUTType(_ data: Data) -> UTType {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeID = CGImageSourceGetType(source) else { return .png }
        return UTType(typeID as String) ?? .png
    }

    /// 保存原始字节到相册 — 保存动作走的应该是这个，而不是把已经解码/
    /// 可能重采样过的 UIImage 再编码回去一次。
    /// 只申请「仅添加」权限；用 PHAssetCreationRequest 直接把字节写进去，
    /// 不经过 PHAssetChangeRequest.creationRequestForAsset(from:)——那个 API
    /// 接收裸 UIImage 时会自己重新编码，画质不保真 (见下面 saveToPhotos(_:))。
    static func saveToPhotos(data: Data) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            EhToast.failure("没有相册权限")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = detectUTType(data).identifier
                request.addResource(with: .photo, data: data, options: options)
            }
            EhToast.success("已保存到相册")
        } catch {
            EhToast.failure("保存失败")
        }
    }

    /// 兜底路径：拿不到原始字节（没开"下载原图"，或者这一页没有原图直链）时，
    /// 退回把阅读器里当前显示的这张图存下来。
    static func saveToPhotos(_ image: UIImage) async {
        // 之前这里用 PHAssetChangeRequest.creationRequestForAsset(from: image)，
        // 传入的是解码后的 UIImage 对象。PhotoKit 对这种"裸 UIImage"输入
        // 不保证按位保存——内部会重新编码（通常是有损 JPEG），画质明显低于
        // "存储到文件"那条路径（image.pngData() 直接无损落盘）。
        // 改成先取 PNG Data，再走上面同一个基于 Data 的保存函数，
        // 两条路径落地的字节就完全一致了。
        guard let data = image.pngData() else {
            EhToast.failure("图片数据无效")
            return
        }
        await saveToPhotos(data: data)
    }

    /// 写成临时文件，交给系统分享/存储面板 — 原始字节版本。
    /// 对齐 Android 的 page_menu_share 与 page_menu_save_to。
    static func temporaryFile(data: Data, gid: Int64, page: Int) -> URL? {
        let ext = detectUTType(data).preferredFilenameExtension ?? "jpg"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(gid)-\(page + 1).\(ext)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 兜底路径：没有原始字节时，退回把当前显示的这张图写成临时文件。
    static func temporaryFile(for image: UIImage, gid: Int64, page: Int) -> URL? {
        guard let data = image.pngData() else { return nil }
        return temporaryFile(data: data, gid: gid, page: page)
    }
    #endif
}

// 分享面板复用 LogExportView.swift 里已有的 ShareSheet，不再写第二份。

/// 分享面板要展示的临时文件。用 Identifiable 驱动 .sheet(item:)，
/// 这样文件准备好之后面板才弹出来，不会出现空白面板。
struct ReaderShareItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// 应用屏幕方向锁定。对齐 Android setRequestedOrientation：
/// 0=跟随系统 / 1=竖屏 / 2=横屏。
///
/// 权威值是 AppSettings.screenRotation，AppDelegate 的
/// supportedInterfaceOrientationsFor 已经在读它。这里只负责让系统**立刻**
/// 重新问一次并转过去——不然设置改了要等下一次转屏才生效。
@MainActor
func applyScreenRotation(_ mode: Int) {
    #if os(iOS)
    let mask: UIInterfaceOrientationMask
    switch mode {
    case 1:  mask = .portrait
    case 2:  mask = .landscape
    default: mask = .allButUpsideDown
    }
    guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
    else { return }
    scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    #endif
}
