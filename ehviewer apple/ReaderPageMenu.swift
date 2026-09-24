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
    static func saveToPhotos(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            EhToast.failure("没有相册权限")
            return
        }
        // 之前这里用 PHAssetChangeRequest.creationRequestForAsset(from: image)，
        // 传入的是解码后的 UIImage 对象。PhotoKit 对这种"裸 UIImage"输入
        // 不保证按位保存——内部会重新编码（通常是有损 JPEG），画质明显低于
        // "存储到文件"那条路径（image.pngData() 直接无损落盘）。
        // 改成先取 PNG Data，再用 PHAssetCreationRequest 把原始字节写进相册，
        // 这样两条路径保存的是完全相同的数据，不再有画质差异。
        guard let data = image.pngData() else {
            EhToast.failure("图片数据无效")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = UTType.png.identifier
                request.addResource(with: .photo, data: data, options: options)
            }
            EhToast.success("已保存到相册")
        } catch {
            EhToast.failure("保存失败")
        }
    }

    /// 写成临时文件，交给系统分享/存储面板。
    /// 对齐 Android 的 page_menu_share 与 page_menu_save_to。
    static func temporaryFile(for image: UIImage, gid: Int64, page: Int) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(gid)-\(page + 1).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
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
