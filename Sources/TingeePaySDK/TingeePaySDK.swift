import UIKit

// MARK: - Payment Status Models
public enum TingeePaymentStatus: String {
    case success = "success"
    case failed = "failed"
    case cancelled = "cancelled"
    case expired = "expired"
    case error = "error"
    case unknown = "unknown"
}

public struct TingeePaymentResult {
    public let status: TingeePaymentStatus
    public let orderId: String?
    public let transactionId: String?
    public let errorCode: String?
    public let errorMessage: String?
    
    public init(status: TingeePaymentStatus, orderId: String? = nil, transactionId: String? = nil, errorCode: String? = nil, errorMessage: String? = nil) {
        self.status = status
        self.orderId = orderId
        self.transactionId = transactionId
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

// MARK: - Delegate Protocol
/// Protocol để nhận các sự kiện phản hồi từ màn hình thanh toán Tingee.
public protocol TingeePayCheckoutDelegate: AnyObject {
    /// Gọi khi giao dịch thanh toán kết thúc (Thành công, Thất bại, Hết hạn, Lỗi).
    /// - Parameter result: Chi tiết kết quả giao dịch từ Tingee.
    func tingeePayCheckoutDidFinish(with result: TingeePaymentResult)
    
    /// Gọi khi người dùng chủ động đóng màn hình thanh toán hoặc ấn nút huỷ trên web.
    func tingeePayCheckoutDidCancel()
    
    /// Gọi khi quá trình khởi tạo hoặc tải trang thanh toán gặp lỗi nội bộ (Ví dụ không có mạng).
    func tingeePayCheckoutDidFail(with error: Error)
}

public enum TingeePayPresentationStyle {
    /// Hiện full toàn màn hình
    case fullScreen
    /// Hiện 1 nửa màn hình từ dưới lên (có thể kéo lên full màn). Chỉ hỗ trợ từ iOS 15 trở lên, iOS 14 sẽ hiện dạng sheet thông thường.
    case bottomSheet
}

public struct TingeePay {
    
    @MainActor
    public static func presentCheckout(
        from viewController: UIViewController,
        checkoutUrl: URL,
        style: TingeePayPresentationStyle = .fullScreen,
        themeColor: String? = nil,
        delegate: TingeePayCheckoutDelegate? = nil
    ) {
        let checkoutVC = TingeePayCheckoutViewController(
            checkoutUrl: checkoutUrl,
            themeColor: themeColor
        )
        checkoutVC.delegate = delegate
        
        switch style {
        case .fullScreen:
            checkoutVC.modalPresentationStyle = .fullScreen
        case .bottomSheet:
            if #available(iOS 15.0, *) {
                if let sheet = checkoutVC.sheetPresentationController {
                    // Cấu hình 2 điểm dừng: nửa màn hình và full màn hình
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                }
            } else {
                checkoutVC.modalPresentationStyle = .pageSheet
            }
        }
        
        viewController.present(checkoutVC, animated: true)
    }
}
