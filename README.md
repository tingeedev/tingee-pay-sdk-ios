# Tingee SDK for iOS

> SDK chính thức tích hợp cổng thanh toán **Tingee** cho iOS

[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-orange)](https://swift.org/package-manager/)
[![iOS](https://img.shields.io/badge/iOS-14.0%2B-blue)](https://developer.apple.com/ios/)

---

## Cài đặt

### Swift Package Manager (SPM)

1. Mở dự án của bạn trên Xcode.
2. Chọn **File** > **Add Packages...** (hoặc **Add Package Dependencies...**).
3. Nhập URL của kho lưu trữ Github chứa TingeePay SDK.
4. Chọn quy tắc phiên bản (Up to Next Major Version) và nhấn **Add Package**.

---

### XCFramework (Tích hợp thủ công)

Nếu bạn muốn tích hợp SDK dưới dạng thư viện nhị phân đã biên dịch sẵn:

1. Tải về thư mục `TingeePaySDK.xcframework`.
2. Kéo và thả thư mục `TingeePaySDK.xcframework` vào dự án Xcode của bạn (chọn **Copy items if needed** và **Create groups**).
3. Chọn target ứng dụng của bạn, đi tới tab **General**.
4. Tại mục **Frameworks, Libraries, and Embedded Content**, tìm `TingeePaySDK.xcframework` và cấu hình là **Embed & Sign**.

---

### XCFramework (Tích hợp thủ công)

Nếu bạn muốn tích hợp SDK dưới dạng thư viện nhị phân đã biên dịch sẵn:

1. Tải về thư mục `TingeePaySDK.xcframework`.
2. Kéo và thả thư mục `TingeePaySDK.xcframework` vào dự án Xcode của bạn (chọn **Copy items if needed** và **Create groups**).
3. Chọn target ứng dụng của bạn, đi tới tab **General**.
4. Tại mục **Frameworks, Libraries, and Embedded Content**, tìm `TingeePaySDK.xcframework` và cấu hình là **Embed & Sign**.

---

## Cấu hình

Để SDK hoạt động trơn tru (đặc biệt là tính năng Tải mã QR), bạn **bắt buộc** phải cấu hình file `Info.plist` của ứng dụng.

Mở `Info.plist` dưới dạng Source Code và thêm cấu hình sau để xin quyền lưu mã QR vào Thư viện ảnh:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Ứng dụng cần quyền để lưu mã QR thanh toán vào thư viện ảnh của bạn.</string>
```

---

## Bắt đầu nhanh

Tại ViewController nơi bạn muốn gọi thanh toán, import SDK:

```swift
import TingeePaySDK

class CheckoutViewController: UIViewController {

    func openPayment(checkoutUrlString: String) {
        guard let checkoutUrl = URL(string: checkoutUrlString) else { return }
        
        // Gọi SDK để hiển thị thanh toán
        TingeePay.presentCheckout(
            from: self, 
            checkoutUrl: checkoutUrl, 
            style: .bottomSheet, // Hoặc .fullScreen
            delegate: self
        )
    }
}


```

---

## Dành cho SwiftUI

Đối với SwiftUI, cách tốt nhất là **khai báo một lần** (viết một wrapper `UIViewControllerRepresentable`) để tái sử dụng toàn bộ dự án thay vì xử lý rời rạc.

```swift
import SwiftUI
import TingeePaySDK

struct TingeePayView: UIViewControllerRepresentable {
    let checkoutUrl: URL
    var themeColor: String? = nil
    var style: TingeePayStyle = .fullSceen
    var onFinished: ((TingeePaymentResult) -> Void)?
    var onCancelled: (() -> Void)?

    class Coordinator: NSObject, TingeePayCheckoutDelegate {
        var parent: TingeePayView
        
        init(parent: TingeePayView) {
            self.parent = parent
        }
        
        func tingeePayCheckoutDidFinish(with result: TingeePaymentResult) {
            parent.onFinished?(result)
        }
        
        func tingeePayCheckoutDidCancel() {
            parent.onCancelled?()
        }
        
        func tingeePayCheckoutDidFail(with error: Error) {
            print("Lỗi tải trang thanh toán: \(error.localizedDescription)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> TingeePayCheckoutViewController {
        let vc = TingeePayCheckoutViewController(checkoutUrl: checkoutUrl, themeColor: themeColor, style: style)
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: TingeePayCheckoutViewController, context: Context) {}
}
```

Cách dùng trong file giao diện của bạn:

```swift
struct ContentView: View {
    @State private var showPayment = false
    let checkoutUrl = URL(string: "https://pay.tingee.vn/your-order-id")!
    
    var body: some View {
        Button("Thanh toán Tingee") {
            showPayment = true
        }
        .sheet(isPresented: $showPayment) {
            TingeePayView(
                checkoutUrl: checkoutUrl, 
                themeColor: "#FF5733",
                style: .fullScreen, // Hoặc .bottomSheet
                onFinished: { result in
                    print("Kết quả: \(result.status.rawValue)")
                    showPayment = false
                },
                onCancelled: {
                    print("Đã huỷ")
                    showPayment = false
                }
            )
        }
    }
}
```

---

## Lắng nghe kết quả (dành cho UIKit)

Kế thừa protocol `TingeePayCheckoutDelegate` để nhận các sự kiện:

```swift
extension CheckoutViewController: TingeePayCheckoutDelegate {
    
    /// Sự kiện: Thanh toán kết thúc (Thành công, Lỗi, Hết hạn...)
    func tingeePayCheckoutDidFinish(with result: TingeePaymentResult) {
        print("Trạng thái: \(result.status.rawValue)")
        print("Mã đơn hàng: \(result.orderId ?? "")")
        
        switch result.status {
        case .success:
            print("Thanh toán thành công!")
        case .failed,:
            print("Lỗi thanh toán: \(result.errorMessage ?? "")")
        case .cancelled:
            print("Giao dịch đã bị huỷ.")
        case .expired:
            print("Đơn hàng đã hết hạn thanh toán.")
        case .error:
            print("Lỗi hệ thống.")
        }
    }
    
    /// Sự kiện: Người dùng chủ động bấm Đóng / Huỷ hoặc vuốt tắt màn hình thanh toán
    func tingeePayCheckoutDidCancel() {
        print("Người dùng đã thoát màn hình thanh toán.")
    }
    
    /// Sự kiện: Lỗi phát sinh trong quá trình tải SDK (Ví dụ: Mất mạng, sai URL...)
    func tingeePayCheckoutDidFail(with error: Error) {
        print("Lỗi khởi tạo màn hình thanh toán: \(error.localizedDescription)")
    }
}
```

---

## Mô hình dữ liệu

### `TingeePaymentResult`

| Thuộc tính | Kiểu | Mô tả |
|---|---|---|
| `status` | `TingeePaymentStatus` | Trạng thái cuối cùng của giao dịch. |
| `orderId` | `String?` | Mã đơn hàng (Mã mà hệ thống của bạn gửi cho Tingee). |

> **`TingeePaymentStatus`** bao gồm: `.success`, `.failed`, `.cancelled`, `.expired`, `.error`.

---

## Xử lý sự cố

**1. Bấm "Tải mã QR" không có phản hồi:**
- Cần chắc chắn bạn đã thêm key `NSPhotoLibraryAddUsageDescription` vào `Info.plist`. Lần đầu tiên bấm tải, hệ điều hành sẽ hiển thị popup xin quyền.

**2. Test trên môi trường Sandbox:**
- SDK Mobile tự động chuyển môi trường dựa vào URL. Nếu `checkoutUrl` bắt đầu bằng URL Sandbox của Tingee, SDK sẽ tự hiểu và hiển thị giao diện Sandbox.

---