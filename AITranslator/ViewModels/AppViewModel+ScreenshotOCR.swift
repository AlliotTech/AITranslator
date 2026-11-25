import AppKit
import Foundation

// MARK: - 截图 OCR 流程
extension AppViewModel {
    /// 触发截图选区 → OCR → 自动填入输入框。
    /// 运行中再次触发 = 取消当前选区/请求。
    func captureScreenshotOCR() {
        guard !isScreenshotOCRRunning else {
            ocrTask?.cancel()
            screenshotCapturer.cancelPending()
            return
        }

        guard preferences.translationProvider == .openAI else {
            showToast(L10n.tr("ocr.error.requiresOpenAI", lang: preferences.appLanguage))
            return
        }
        guard preferences.isBaseURLValid, preferences.isAPIKeyValid else {
            showToast(L10n.tr("ocr.error.invalidConfig", lang: preferences.appLanguage))
            return
        }

        isScreenshotOCRRunning = true
        ocrTask = Task { [weak self] in
            await self?.runScreenshotOCR()
            guard let self else { return }
            self.isScreenshotOCRRunning = false
            self.ocrTask = nil
        }
    }

    private func runScreenshotOCR() async {
        do {
            let image = try await screenshotCapturer.captureSelection()

            guard !Task.isCancelled else { return }
            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw ScreenshotOCRClient.OCRError.imageEncodingFailed
            }

            let ocrModel = preferences.ocrModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = try await ocrClient.recognize(
                imageData: pngData,
                mimeType: "image/png",
                baseURL: preferences.baseURL,
                apiKey: preferences.apiKey,
                model: ocrModel.isEmpty ? preferences.model : ocrModel,
                proxy: preferences.proxySettings,
                userAgent: preferences.customUserAgentHeader
            )

            guard !Task.isCancelled else { return }
            onInputChanged(text)
            scheduleDetectionAfterPaste()
            focusInputToken &+= 1
            showToast(L10n.tr("toast.ocr.done", lang: preferences.appLanguage))
        } catch is CancellationError {
            showToast(L10n.tr("toast.ocr.cancelled", lang: preferences.appLanguage))
        } catch let error as ScreenshotCaptureError {
            let key: String
            switch error {
            case .screenRecordingPermissionDenied: key = "ocr.error.permission"
            case .noDisplay: key = "ocr.error.noDisplay"
            case .cancelled: key = "toast.ocr.cancelled"
            }
            showToast(L10n.tr(key, lang: preferences.appLanguage))
        } catch {
            showToast(L10n.tr("toast.ocr.failure.prefix", lang: preferences.appLanguage) + error.localizedDescription)
        }
    }
}
