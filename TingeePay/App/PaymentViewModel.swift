import Foundation
import CryptoKit
import TingeePaySDK

// MARK: - App Configuration
/// Định nghĩa cấu hình môi trường và keys.
/// Trong ứng dụng Production thực tế: KHÔNG BAO GIỜ lưu `secret` trong App để tránh rò rỉ bảo mật.
/// Toàn bộ logic tạo Signature nên được xử lý trên Backend của Merchant.
enum TingeeAppConfig {
    static let clientId = "74972a04e7dd7eeaf2c30868cdb5fd6a"
    static let secret = "htIQdfgxq114HvfBKb6gP+WXegFv377SAgktTd4V9Uw="
    static let environment: TingeeEnvironment = .sandbox
}

// MARK: - Payment ViewModel
/// ViewModel đảm nhiệm xử lý logic nghiệp vụ thanh toán (tính toán amount, validate, tạo request, và mock gọi mạng).
final class PaymentViewModel {
    
    // MARK: - Outputs (Callbacks)
    var onShowError: ((String) -> Void)?
    var onPresentSDK: ((TingeePayClient, TingeePaymentLinkRequest, String, String) -> Void)?
    var onLoading: ((Bool) -> Void)?
    
    // MARK: - Inputs
    func processPayment(amountText: String?, expireText: String?, descText: String?) {
        let trimmedAmount = amountText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let expireInMinute = Int(expireText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "30") ?? 30
        let description = descText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Thanh toán đơn hàng App"
        
        guard let amount = Int(trimmedAmount), amount > 0 else {
            onShowError?("Vui lòng nhập số tiền thanh toán hợp lệ (lớn hơn 0).")
            return
        }
        
        onLoading?(true)
        
        // 1. Tạo dữ liệu Request
        let request = TingeePaymentLinkRequest(
            merchantId: 01,
            orderId: "INV\(Int(Date().timeIntervalSince1970))",
            amount: amount,
            expireInMinute: expireInMinute,
            description: description,
            orderInfo: "Đơn hàng từ App Mobile",
            bankBin: "970436",
            customerInfo: "Nguyen Van A",
            vaAccountNumber: "VQRQAAUNF0356",
            returnUrl: "tingeemerchant://return",
            partnerCustomerId: "CUS_001"
        )
        
        // 2. Giả lập gọi Backend để lấy Chữ ký (Signature)
        let (signature, timestamp) = generateMockSignature(for: request)
        
        // 3. Khởi tạo Client và đẩy cho View hiển thị SDK
        let client = TingeePayClient(environment: TingeeAppConfig.environment, clientId: TingeeAppConfig.clientId)
        onPresentSDK?(client, request, signature, timestamp)
    }
    
    // MARK: - Private Helpers
    
    /// Giả lập Backend sinh chữ ký HMAC SHA512 theo tài liệu của Tingee.
    /// - Parameter request: Object request gửi lên Tingee.
    /// - Returns: Tuple gồm chuỗi mã hoá (signature) và thời gian (timestamp).
    private func generateMockSignature(for request: TingeePaymentLinkRequest) -> (signature: String, timestamp: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmssSSS"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        let timestamp = dateFormatter.string(from: Date())
        
        let encoder = JSONEncoder()
        if #available(iOS 13.0, macOS 10.15, *) {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        
        let payloadData = (try? encoder.encode(request)) ?? Data()
        let payloadString = String(data: payloadData, encoding: .utf8) ?? ""
        
        let dataToSign = "\(timestamp):\(payloadString)"
        let keyData = Data(TingeeAppConfig.secret.utf8)
        let key = SymmetricKey(data: keyData)
        
        let signatureData = HMAC<SHA512>.authenticationCode(for: Data(dataToSign.utf8), using: key)
        let signature = Data(signatureData).map { String(format: "%02x", $0) }.joined()
        
        return (signature, timestamp)
    }
}
