# Hướng dẫn Kiểm thử (Testing Guide) - Tingee Pay SDK (iOS)

Tài liệu này cung cấp danh sách các Test Case (kịch bản kiểm thử) dành cho QC/Tester để nghiệm thu các tính năng của Tingee Pay SDK trên nền tảng iOS.

---

## 1. Môi trường & Chuẩn bị
- **Thiết bị:** Kiểm tra trên máy ảo (Simulator) và ít nhất 1 thiết bị thật (iPhone/iPad) chạy iOS 14+ và iOS 15+.
- **App Test:** Mở ứng dụng Demo `TingeePay.xcodeproj` có sẵn trong thư mục SDK.
- **Tiền quyết:** Chắc chắn thiết bị thật có cài sẵn ít nhất 1 ứng dụng Ngân hàng (VD: Momo, BIDV, Vietcombank...) để test tính năng Deep Link. Trên Simulator sẽ không có sẵn App Ngân hàng.

---

## 2. Kịch bản Kiểm thử (Test Cases)

### Test Case 1: Hiển thị giao diện (Presentation Styles)
- **Mục đích:** Đảm bảo SDK có thể hiển thị linh hoạt dưới dạng Bottom Sheet hoặc Full Screen.
- **Các bước:**
  1. Mở ứng dụng Demo.
  2. Tại mục tuỳ chọn, chọn **"Bottom Sheet"** -> Ấn "Thanh toán".
  3. Đóng SDK.
  4. Chọn **"Full Screen"** -> Ấn "Thanh toán".
- **Kết quả mong đợi:** 
  - (2) SDK trượt từ dưới lên, chiếm 1/2 màn hình. Có thể vuốt lên để mở full, hoặc vuốt xuống để đóng. Chỉ áp dụng cho iOS 15+. Với iOS 14 sẽ mở sheet theo giao diện mặc định.
  - (4) SDK mở chiếm toàn bộ màn hình, không có khoảng hở để vuốt đóng.

### Test Case 2: Truyền thông số đơn hàng & Tuỳ biến màu sắc (Theme Customization)
- **Mục đích:** Đảm bảo App Demo có thể truyền đúng các thông số động (Số tiền, Thời hạn, Mô tả) lên Tingee API và SDK nhận đúng màu chủ đạo tự định nghĩa.
- **Các bước:**
  1. Mở ứng dụng Demo.
  2. Nhập thông số tuỳ ý vào các ô: **"Số tiền"**, **"Thời hạn"**, **"Mô tả"**.
  3. Tại ô **"Màu sắc chủ đạo (Mã HEX)"**, nhập thử mã màu bất kỳ (VD: `#ff0000` cho Đỏ, `#000000` cho Đen). Quan sát xem vòng tròn Preview bên cạnh có đổi màu đúng hay không.
  4. Bấm "Thanh toán".
- **Kết quả mong đợi:** 
  - Giao diện trang thanh toán Tingee hiển thị đúng Số tiền, Mô tả và Thời gian hết hạn mã QR như đã nhập.
  - Màu sắc nút bấm/tiêu đề đổi thành màu tương ứng vừa nhập (VD: màu đỏ `#ff0000`). Nếu để trống ô nhập màu, giao diện sẽ dùng màu mặc định của Tingee. Không có hiện tượng "nháy trang" (flicker) lúc load web.

### Test Case 3: Trả kết quả Thanh toán & Đóng mượt mà
- **Mục đích:** Kiểm tra luồng đóng SDK không bị Crash do xung đột UI và App nhận đúng trạng thái.
- **Các bước:**
  1. Mở SDK, load trang thanh toán.
  2. Ấn nút Back/Huỷ trên giao diện Tingee Web (để tạo trạng thái `cancelled`).
- **Kết quả mong đợi:** 
  - SDK tự động trượt xuống đóng lại.
  - Sau khi SDK đóng xong 100%, App Demo mới bật lên một Alert thông báo: "Kết quả: Đã huỷ". Không bị văng app, không có log đỏ lỗi "already presenting".

### Test Case 4: Nhận diện App Ngân hàng (Deep Link) - Trường hợp CÓ App
- **Mục đích:** Kiểm tra SDK tự động gọi Deep Link để mở App Ngân hàng.
- **Các bước (Trên máy thật):**
  1. Chọn phương thức thanh toán bằng 1 App ngân hàng (VD: Momo hoặc quét mã QR bằng App Ngân hàng).
  2. Đảm bảo máy đã cài Momo.
- **Kết quả mong đợi:** Điện thoại tự động bật popup yêu cầu chuyển hướng, sau đó mở thành công ứng dụng Momo.

### Test Case 5: Xử lý khi KHÔNG có App Ngân hàng
- **Mục đích:** Bắt lỗi và thông báo cho người dùng khi máy không cài app ngân hàng đó.
- **Các bước (Trên Simulator hoặc Máy thật chưa cài App):**
  1. Chọn phương thức thanh toán bằng App (VD: BIDV SmartBanking, iPay...).
- **Kết quả mong đợi:** 
  - App không bị lỗi văng.
  - SDK tự động văng ra một Alert thông báo: *"Ứng dụng chưa được cài đặt. Vui lòng cài đặt..."*.
  - Khi tắt Alert, trang web tự động tải lại (Reload) hoặc vẫn giữ nguyên trang thanh toán.

### Test Case 6: Tải Ảnh QR (Download Image)
- **Mục đích:** Kiểm tra việc lưu mã QR bằng Javascript Bridge trên iOS.
- **Các bước:**
  1. Mở màn hình chứa mã QR VietQR trên trang thanh toán.
  2. Bấm nút "Tải mã QR" (Nút bấm là thẻ `<a download>`).
- **Kết quả mong đợi:** 
  - Lần đầu tiên bấm: Hệ thống hỏi quyền truy cập "Thêm ảnh vào Thư viện". Bấm "Cho phép".
  - Hiển thị Alert "Thành công - Đã lưu mã QR vào thư viện ảnh".
  - Mở ứng dụng Photos (Ảnh) của thiết bị và kiểm tra xem ảnh QR đã được lưu chưa.

---

## 3. Các điểm lưu ý đặc biệt dành cho Dev & Tester
1. **Universal Link vs Custom Scheme:** Tingee đôi lúc trả về Custom Scheme (`momo://`, `icb://`) và đôi lúc trả về Universal Link (`https://...`). SDK đã xử lý bắt cả 2 trường hợp tại hàm `decidePolicyFor navigationAction` cũng như theo dõi sự kiện mạng `fetch/XHR`.
2. **Quyền Photos:** Phải đảm bảo file `Info.plist` của App tích hợp có chứa key `NSPhotoLibraryAddUsageDescription` nếu không app sẽ bị Crash khi bấm nút Tải ảnh. (Đã cấu hình sẵn trong Demo App).
