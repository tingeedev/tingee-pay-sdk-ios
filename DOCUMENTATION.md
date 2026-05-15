# Tingee Pay SDK (iOS) - Hướng dẫn Tích hợp (Documentation)

Tài liệu này hướng dẫn cách nhúng (integrate) Tingee Pay SDK vào ứng dụng iOS Native (Swift) của bạn để hỗ trợ thanh toán qua Cổng thanh toán Tingee.

---

## 1. Cài đặt (Installation)

SDK được đóng gói dưới dạng **Swift Package**. 

1. Mở Xcode, chọn File -> Add Packages...
2. Nhập URL của kho lưu trữ Tingee Pay SDK.
3. Trong phần quy tắc phiên bản (Dependency Rule), chọn `Up to Next Major Version` hoặc trỏ vào nhánh cụ thể tuỳ vào cấu hình dự án của bạn.
4. Bấm "Add Package" và đảm bảo SDK được liên kết (linked) vào target của ứng dụng.

---

## 2. Cấu hình quyền (Info.plist)

Vì SDK có tính năng tải mã QR Code thanh toán về Thư viện Ảnh của thiết bị, bạn **bắt buộc** phải khai báo quyền thêm ảnh vào thư viện trong file `Info.plist` của App.

Thêm đoạn mã sau vào `Info.plist`:
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Ứng dụng cần quyền lưu mã QR vào thư viện ảnh để bạn có thể mở lại khi thanh toán.</string>
```

---

## 3. Cách sử dụng (Usage)

### 3.1. Import thư viện
Tại màn hình nơi bạn thực hiện thanh toán (Ví dụ `CheckoutViewController.swift`), import thư viện:
```swift
import TingeePaySDK
```

### 3.2. Khởi tạo và Gọi giao diện thanh toán
Khi có link thanh toán (được tạo ra từ API phía Backend của bạn), hãy gọi hàm `TingeePay.presentCheckout` để bật giao diện thanh toán.

```swift
// Giả sử checkoutUrlString là URL nhận được từ Backend
guard let url = URL(string: checkoutUrlString) else { return }

TingeePay.presentCheckout(
    from: self,                           // ViewController hiện tại
    checkoutUrl: url,                     // Link thanh toán Tingee
    style: .bottomSheet,                  // Tuỳ chọn hiển thị: .bottomSheet hoặc .fullScreen
    themeColor: "#ff0000",                // (Tuỳ chọn) Đổi màu chủ đạo theo mã HEX
    delegate: self                        // (Tuỳ chọn) Kế thừa TingeePayCheckoutDelegate để nhận kết quả
)
```

**Các tham số quan trọng:**
- `style`: 
  - `.bottomSheet`: Hiển thị dạng trượt từ dưới lên (Hỗ trợ 2 nấc: nửa màn hình và full màn hình trên iOS 15+).
  - `.fullScreen`: Hiển thị chiếm toàn bộ màn hình.
- `themeColor`: Truyền mã màu HEX (ví dụ `"#1e3d1c"`). Nếu truyền `nil`, hệ thống sẽ sử dụng màu mặc định của Tingee.

---

## 4. Xử lý kết quả trả về (Callbacks)

Để nhận biết người dùng đã thanh toán thành công hay huỷ bỏ, ViewController của bạn cần kế thừa protocol `TingeePayCheckoutDelegate`.

```swift
extension CheckoutViewController: TingeePayCheckoutDelegate {
    
    // 1. Nhận kết quả trạng thái thanh toán (Thành công / Thất bại / Hết hạn)
    func tingeePayCheckoutDidFinish(with result: TingeePaymentResult) {
        /*
        result.status có thể là các enum:
        - .success: Giao dịch thành công
        - .failed: Giao dịch thất bại
        - .expired: Mã giao dịch/QR đã hết hạn
        - .cancelled: Người dùng chủ động huỷ
        - .error: Lỗi từ hệ thống
        */
        
        if result.status == .success {
            print("Đã thanh toán thành công mã đơn: \(result.orderId ?? "")")
            // Show Alert hoặc chuyển sang màn hình Success
        } else {
            print("Thanh toán không thành công. Lý do: \(result.errorMessage ?? "")")
        }
    }
    
    // 2. Gọi khi người dùng ấn nút "X" trên UI để tắt SDK
    func tingeePayCheckoutDidCancel() {
        print("Người dùng đã đóng SDK.")
    }
    
    // 3. Gọi khi SDK gặp lỗi nội bộ không thể load được trang thanh toán
    func tingeePayCheckoutDidFail(with error: Error) {
        print("Lỗi hệ thống SDK: \(error.localizedDescription)")
    }
}
```

> **Lưu ý:** Hàm `tingeePayCheckoutDidFinish` chỉ được gọi **sau khi** giao diện SDK đã hoàn tất hiệu ứng trượt/đóng (Dismissed) 100%. Nhờ đó, bạn hoàn toàn có thể an tâm bật một Alert hay chuyển màn hình (Push Navigation) ngay lập tức mà không lo lỗi xung đột giao diện (Already Presenting Error).

---

## 5. Tính năng tự động của SDK
SDK đã được lập trình để xử lý ngầm các tính năng sau, lập trình viên không cần viết thêm code:
1. Tự động bẫy bắt các Deep Link / Universal Link để bật App Ngân Hàng (Momo, VCB, BIDV...).
2. Bắt lỗi người dùng chưa cài App ngân hàng để Show Alert cảnh báo.
3. Tự động chặn hành vi mở các Popup/Tab mới và mở chúng trên trình duyệt Safari nếu cần thiết.
4. Tải Ảnh QR: Bẫy các nút tải mã QR và tải tự động qua Base64/Fetch để lưu vào Thư viện ảnh.
