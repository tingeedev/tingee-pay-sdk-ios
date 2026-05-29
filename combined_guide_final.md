# TÀI LIỆU HƯỚNG DẪN TÍCH HỢP TINGEE PAY SDK

**Nền tảng hỗ trợ:** iOS & Android

---

## PHẦN 1: DÀNH CHO IOS

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
## PHẦN 2: DÀNH CHO ANDROID

# Hướng dẫn tích hợp TingeePay SDK (AAR)

SDK hỗ trợ **Android API 24+**, ngôn ngữ **Kotlin/Java**.

---

## 1. Thêm file AAR vào dự án

1. Sao chép file `tingeepaysdk-release.aar` vào thư mục `app/libs/` của dự án (tạo thư mục nếu chưa có).

2. Mở file `app/build.gradle.kts` (hoặc `app/build.gradle`) và thêm dependency:

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(files("libs/tingeepaysdk-release.aar"))

    // Các dependency bắt buộc của SDK
    implementation("androidx.appcompat:appcompat:1.3.0")
    implementation("com.google.android.material:material:1.6.1")
    implementation("androidx.constraintlayout:constraintlayout:2.0.0")
    implementation("androidx.activity:activity:1.8.0")
}
```

> **Lưu ý:** Nếu dự án bạn dùng `build.gradle` (Groovy), cú pháp tương đương là:
> ```groovy
> implementation files('libs/tingeepaysdk-release.aar')
> ```

3. Sync lại project (**File → Sync Project with Gradle Files**).

---

## 2. Khai báo Internet Permission

Trong `AndroidManifest.xml` của app, đảm bảo đã có quyền INTERNET:

```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET" />
    ...
</manifest>
```

---

## 3. Khởi động SDK

SDK cung cấp hai phương thức để mở màn hình thanh toán. Bạn cần chuẩn bị sẵn **`paymentUrl`** (URL thanh toán lấy từ API của bên bạn) và **`returnUrl`** (URL/deeplink bạn đã đăng ký với cổng thanh toán) trước khi gọi SDK.

### 3.1. Cách 1 – Mở SDK và lắng nghe kết quả (khuyến nghị)

Dùng `ActivityResultLauncher` để nhận kết quả thanh toán trả về.

**Bước 1:** Đăng ký launcher trong `Activity`:

```kotlin
private val paymentResultLauncher = registerForActivityResult(
    ActivityResultContracts.StartActivityForResult()
) { result ->
    if (result.resultCode == Activity.RESULT_OK) {
        val data = result.data

        val status         = data?.getStringExtra("EXTRA_PAYMENT_STATUS")
        val orderId        = data?.getStringExtra("EXTRA_ORDER_ID")
        val transactionCode  = data?.getStringExtra("EXTRA_TRANSACTION_CODE")
        val errorCode      = data?.getStringExtra("EXTRA_ERROR_CODE")
        val errorMessage   = data?.getStringExtra("EXTRA_ERROR_MESSAGE")
        val rawJson        = data?.getStringExtra("EXTRA_PAYMENT_DATA_JSON")

        when (status) {
            "success"   -> { /* Thanh toán thành công */ }
            "failed"    -> { /* Thanh toán thất bại */ }
            "cancelled" -> { /* Người dùng hủy giao dịch */ }
            "expired"   -> { /* Mã thanh toán hết hạn */ }
            "error"     -> { /* Lỗi hệ thống */ }
        }
    } else {
        // Người dùng đóng màn hình SDK mà không có kết quả
    }
}
```

**Bước 2:** Mở SDK khi đã có `paymentUrl`:

```kotlin
val intent = TingeePaySDK.createIntent(
    context      = this,
    paymentUrl   = paymentUrl,   // URL thanh toán từ API của bạn
    returnUrl    = returnUrl,    // returnUrl đã đăng ký với cổng thanh toán
    isEmbedded   = true,         // true: ẩn header/footer của cổng (khuyến nghị)
    immediateResult = true,      // true: bắn event ngay khi thanh toán xong
    primaryColor = "#1E88E5",    // Màu chủ đạo (hex). null = dùng màu mặc định của cổng
    isFullScreen = true          // true: full màn hình | false: bottom sheet (nửa màn hình)
)
paymentResultLauncher.launch(intent)
```

---

### 3.2. Mở SDK từ Fragment

Khi gọi SDK từ **Fragment**, cách làm tương tự Activity với hai lưu ý quan trọng:

1. **`registerForActivityResult` phải được khai báo như property** (ngoài `onViewCreated`), không được gọi bên trong listener hay sau `onStart()`.
2. **Dùng `requireContext()`** thay vì `this` khi tạo Intent.

```kotlin
class CheckoutFragment : Fragment() {

    // ✅ Khai báo như property — KHÔNG đặt trong onViewCreated
    private val paymentResultLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val data = result.data

            val status        = data?.getStringExtra("EXTRA_PAYMENT_STATUS")
            val orderId       = data?.getStringExtra("EXTRA_ORDER_ID")
            val transactionCode = data?.getStringExtra("EXTRA_TRANSACTION_CODE")
            val errorCode     = data?.getStringExtra("EXTRA_ERROR_CODE")
            val errorMessage  = data?.getStringExtra("EXTRA_ERROR_MESSAGE")
            val rawJson       = data?.getStringExtra("EXTRA_PAYMENT_DATA_JSON")

            when (status) {
                "success"   -> { /* Thanh toán thành công */ }
                "failed"    -> { /* Thanh toán thất bại */ }
                "cancelled" -> { /* Người dùng hủy giao dịch */ }
                "expired"   -> { /* Mã thanh toán hết hạn */ }
                "error"     -> { /* Lỗi hệ thống */ }
            }
        } else {
            // Người dùng đóng màn hình SDK mà không có kết quả
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        btnPay.setOnClickListener {
            val intent = TingeePaySDK.createIntent(
                context         = requireContext(), // ✅ dùng requireContext() thay vì this
                paymentUrl      = paymentUrl,
                returnUrl       = returnUrl,
                isEmbedded      = true,
                immediateResult = true,
                primaryColor    = "#1E88E5",
                isFullScreen    = true
            )
            paymentResultLauncher.launch(intent) // ✅ launch trong click listener thì được
        }
    }
}
```

> ⚠️ **Lưu ý:** Không được gọi `registerForActivityResult(...)` bên trong `onViewCreated()`, `onResume()`, hay bất kỳ callback nào khác — chỉ được khai báo ở cấp property của Fragment. Nếu vi phạm, app sẽ ném `IllegalStateException` ở runtime.

---

## 4. Mô tả tham số

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `context` | `Context` | — | Context của Activity đang gọi |
| `paymentUrl` | `String` | — | **Bắt buộc.** URL thanh toán lấy từ API của bạn |
| `returnUrl` | `String?` | `null` | URL/deeplink bạn đã truyền lên API khi tạo payment |
| `isEmbedded` | `Boolean` | `true` | `true`: ẩn header/footer của cổng thanh toán Tingee |
| `immediateResult` | `Boolean` | `true` | `true`: SDK bắn kết quả ngay khi cổng thanh toán trả về |
| `primaryColor` | `String?` | `null` | Màu chủ đạo dạng hex, ví dụ `"#E53935"`. `null` = màu mặc định của cổng |
| `isFullScreen` | `Boolean` | `true` | `true`: toàn màn hình. `false`: Bottom Sheet (chiếm ~50% màn hình) |

---

## 5. Kết quả trả về từ SDK

Khi thanh toán hoàn tất, SDK gọi `setResult(RESULT_OK, intent)` và `finish()`. Dữ liệu được đính kèm trong `Intent` với các key sau:

| Key                       | Kiểu | Mô tả |
|---------------------------|---|---|
| `EXTRA_PAYMENT_STATUS`    | `String` | Trạng thái: `success` / `failed` / `cancelled` / `expired` / `error` |
| `EXTRA_ORDER_ID`          | `String` | Mã đơn hàng |
| `EXTRA_TRANSACTION_CODE`  | `String` | Mã giao dịch từ cổng thanh toán |
| `EXTRA_ERROR_CODE`        | `String` | Mã lỗi (nếu có) |
| `EXTRA_ERROR_MESSAGE`     | `String` | Thông báo lỗi (nếu có) |
| `EXTRA_PAYMENT_DATA_JSON` | `String` | Toàn bộ payload JSON gốc từ cổng thanh toán |

> **Lưu ý:** Nếu người dùng tự đóng màn hình SDK mà chưa thanh toán, `resultCode` sẽ là `RESULT_CANCELED` (không phải `RESULT_OK`) và không có dữ liệu kèm theo.

---

## 6. Chế độ hiển thị (`isFullScreen`)

| Giá trị | Giao diện |
|---|---|
| `true` *(mặc định)* | Toàn màn hình – che phủ toàn bộ app |
| `false` | Bottom Sheet – hiện từ dưới lên, chiếm ~50% chiều cao màn hình. Người dùng có thể kéo xuống để đóng |

---

## 7. Ví dụ hoàn chỉnh

```kotlin
class CheckoutActivity : AppCompatActivity() {

    private val paymentResultLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val status = result.data?.getStringExtra("EXTRA_PAYMENT_STATUS")
            val orderId = result.data?.getStringExtra("EXTRA_ORDER_ID")

            when (status) {
                "success" -> showToast("Thanh toán thành công! Mã đơn: $orderId")
                "failed"  -> showToast("Thanh toán thất bại.")
                "cancelled" -> showToast("Giao dịch đã bị hủy.")
                "expired" -> showToast("Giao dịch đã hết hạn.")
                else -> showToast("Có lỗi xảy ra.")
            }
        } else {
            showToast("Người dùng đóng màn hình thanh toán.")
        }
    }

    private fun openPaymentScreen(paymentUrl: String, returnUrl: String) {
        val intent = TingeePaySDK.createIntent(
            context         = this,
            paymentUrl      = paymentUrl,
            returnUrl       = returnUrl,
            isEmbedded      = true,
            immediateResult = true,
            primaryColor    = "#1E88E5",
            isFullScreen    = true
        )
        paymentResultLauncher.launch(intent)
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}
```

---

## 8. Yêu cầu hệ thống

| Mục | Yêu cầu |
|---|---|
| Android SDK tối thiểu | **API 24** (Android 7.0) |
| Target SDK | API 36 |
| Java compatibility | Java 11 |
| Internet | Bắt buộc |
| Ngôn ngữ | Kotlin hoặc Java |

---

## 9. Lưu ý quan trọng

- **`paymentUrl`** phải là URL hợp lệ được lấy từ backend của bạn. SDK không tự gọi API tạo payment — đây là trách nhiệm của app tích hợp.
- **`returnUrl`** phải trùng với giá trị bạn đã dùng khi tạo payment ở backend để cổng thanh toán có thể redirect đúng về app sau khi hoàn tất.
- Đảm bảo thiết bị có kết nối Internet. SDK hiển thị màn hình lỗi tự động nếu URL không tải được.
- Nếu người dùng muốn thanh toán qua **app ngân hàng** (deeplink), SDK sẽ tự động chuyển hướng sang app tương ứng. Nếu thiết bị chưa cài app đó, SDK hiển thị dialog thông báo và cho phép thử lại.
- SDK tự động dọn dẹp WebView khi đóng để tránh memory leak — bạn không cần xử lý thêm.
