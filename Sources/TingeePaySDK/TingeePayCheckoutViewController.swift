import UIKit
import WebKit

public class TingeePayCheckoutViewController: UIViewController, WKNavigationDelegate {
    
    private let checkoutUrl: URL
    private let themeColor: String?
    
    public weak var delegate: TingeePayCheckoutDelegate?
    
    private var webView: WKWebView!
    private var activityIndicator: UIActivityIndicatorView!
    private var errorLabel: UILabel!
    
    public init(checkoutUrl: URL, themeColor: String? = nil) {
        self.checkoutUrl = checkoutUrl
        self.themeColor = themeColor
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupUI()
        loadPaymentLink()
    }
    
    private func setupUI() {
        // WebView Configuration
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let userController = WKUserContentController()
        
        let jsSource = """
        // Bắt Deep Link từ API Response (fetch & XHR)
        var origFetch = window.fetch;
        window.fetch = async function() {
            var response = await origFetch.apply(this, arguments);
            var clone = response.clone();
            clone.json().then(function(data) {
                if (data && data.data && typeof data.data === 'string' && data.data.includes('://')) {
                    window.webkit.messageHandlers.tingeeObserver.postMessage({'event': 'FETCH_DEEPLINK', 'url': data.data});
                }
            }).catch(function(e) {});
            return response;
        };
        
        var origOpenXHR = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function() {
            this.addEventListener('load', function() {
                try {
                    var data = JSON.parse(this.responseText);
                    if (data && data.data && typeof data.data === 'string' && data.data.includes('://')) {
                        window.webkit.messageHandlers.tingeeObserver.postMessage({'event': 'XHR_DEEPLINK', 'url': data.data});
                    }
                } catch(e) {}
            });
            origOpenXHR.apply(this, arguments);
        };
        
        // Bắt sự kiện Click Download (Tải mã QR)
        var originalClick = HTMLAnchorElement.prototype.click;
        HTMLAnchorElement.prototype.click = function() {
            if (this.hasAttribute('download')) {
                var url = this.href;
                var filename = this.getAttribute('download') || 'qrcode.png';
                if (url.startsWith('blob:')) {
                    var xhr = new XMLHttpRequest();
                    xhr.open('GET', url, true);
                    xhr.responseType = 'blob';
                    xhr.onload = function() {
                        var reader = new FileReader();
                        reader.onloadend = function() {
                            window.webkit.messageHandlers.tingeeObserver.postMessage({'event': 'DOWNLOAD_FILE', 'dataUrl': reader.result, 'filename': filename});
                        }
                        reader.readAsDataURL(xhr.response);
                    };
                    xhr.send();
                    return;
                } else if (url.startsWith('data:')) {
                    window.webkit.messageHandlers.tingeeObserver.postMessage({'event': 'DOWNLOAD_FILE', 'dataUrl': url, 'filename': filename});
                    return;
                } else if (url.startsWith('http')) {
                    window.webkit.messageHandlers.tingeeObserver.postMessage({'event': 'DOWNLOAD_FILE', 'dataUrl': url, 'filename': filename});
                    return;
                }
            }
            originalClick.apply(this, arguments);
        };
        
        document.addEventListener('click', function(e) {
            var a = e.target.closest('a');
            if (a && a.hasAttribute('download')) {
                var url = a.href;
                if (url.startsWith('blob:') || url.startsWith('data:') || url.startsWith('http')) {
                    e.preventDefault();
                    e.stopPropagation();
                    a.click(); // Kích hoạt prototype.click đã bẫy ở trên
                }
            }
        }, true);
        """
        
        let userScript = WKUserScript(source: jsSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        
        // Tiêm cấu hình ở Document Start (0ms Flicker)
        // isEmbedded: Ẩn Header/Footer
        // immediateResult: Bắn event ngay lập tức khi thanh toán xong
        var themeString = ""
        if let color = themeColor {
            themeString = ", theme: { primaryColor: '\(color)' }"
        }
        
        let configScript = WKUserScript(
            source: "window.__TINGEE_CONFIG__ = { isEmbedded: true, immediateResult: false\(themeString) };",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userController.addUserScript(configScript)
        
        userController.add(self, name: "tingeeObserver")
        userController.add(self, name: "TingeeSDKBridge")
        
        webConfiguration.userContentController = userController
        
        // WebView chính
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Ngăn chặn hiệu ứng nảy (bounce) khi scroll kịch trần/đáy, 
        // giúp các thanh bottom bar cố định của Web không bị giật hay đẩy lên.
        webView.scrollView.bounces = false
        // Tắt tự động chèn Safe Area vào Scroll View để Web tự xử lý layout của nó.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // Ẩn thanh cuộn dọc và ngang để giao diện nhìn giống App Native 100%
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(webView)
        
        // Activity Indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        // Error Label
        errorLabel = UILabel()
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Không thể tải trang thanh toán"
        errorLabel.textColor = .red
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        view.addSubview(errorLabel)
        
        // Layout
        let constraints = [
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    private func loadPaymentLink() {
        activityIndicator.startAnimating()
        errorLabel.isHidden = true
        
        let urlRequest = URLRequest(url: checkoutUrl)
        webView.load(urlRequest)
        webView.isHidden = false
        activityIndicator.stopAnimating()
    }
    
    // MARK: - Helper
    private func showAppNotInstalledAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Ứng dụng chưa được cài đặt", message: "Vui lòng cài đặt ứng dụng ngân hàng hoặc ví điện tử để tiếp tục thanh toán.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let urlString = navigationAction.request.url?.absoluteString ?? "NIL_URL"
        let isMain = webView == self.webView
        print("\(isMain ? "🌐" : "🕵️") [Tingee Web Event] Navigation: \(urlString)")
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        // 1. Xử lý Deep Link / Universal Link
        if let scheme = url.scheme?.lowercased() {
            if ["http", "https"].contains(scheme) {
                if let host = url.host, !host.contains("tingee.vn") {
                    // Cứ cho phép WebView tải mọi trang (kể cả dl.vietqr.io)
                    // Nếu là Universal Link, ta thử mở
                    print("🌐 [Tingee Web Event] Thử mở External Link như Universal Link...")
                    UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
                        if success {
                            print("✅ [Tingee Web Event] Đã mở App Ngân hàng qua Universal Link!")
                        }
                    }
                    decisionHandler(.allow)
                    return
                }
            } else if !["about", "blob"].contains(scheme) {
                // App URL Scheme (vd: bidvsmartbanking://, icb://)
                print("[Tingee Web Event] Phát hiện App URL Scheme: \(scheme) -> Thử mở App bên ngoài...")
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:]) { [weak self] success in
                        print("[Tingee Web Event] Gọi UIApplication.open: \(success ? "Thành công" : "Thất bại")")
                        if !success {
                            // Hiện thông báo và reload lại trang
                            self?.showAppNotInstalledAlert()
                            self?.loadPaymentLink()
                        }
                    }
                }
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[Tingee Web Event] didFailProvisionalNavigation: \(error.localizedDescription)")
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("if (typeof window.setTingeeEmbedded === 'function') { window.setTingeeEmbedded(true); }") { _, error in
            if let error = error {
                print("[Tingee Web Event] Không thể gọi setTingeeEmbedded: \(error.localizedDescription)")
            } else {
                print("[Tingee Web Event] Đã gọi window.setTingeeEmbedded(true)")
            }
        }
    }
}

// MARK: - WKUIDelegate
extension TingeePayCheckoutViewController: WKUIDelegate {
    
    public func webViewDidClose(_ webView: WKWebView) {
        delegate?.tingeePayCheckoutDidCancel()
        dismiss(animated: true)
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            print("🪟 [Tingee Web Event] Yêu cầu mở Tab mới: \(url.absoluteString)")
            
            if let scheme = url.scheme?.lowercased() {
                if ["http", "https"].contains(scheme) {
                    UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
                        if !success {
                            // Nếu không mở được App (không phải Universal link), thì mở bằng trình duyệt Safari ngoài luôn cho chắc
                            UIApplication.shared.open(url)
                        }
                    }
                } else if !["about", "blob"].contains(scheme) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
        return nil
    }
}

// MARK: - WKScriptMessageHandler
extension TingeePayCheckoutViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "TingeeSDKBridge", let messageBody = message.body as? String {
            print("📣 [Tingee Web Event] Raw Bridge Message: \(messageBody)")
            
            guard let data = messageBody.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }
            
            if type == "TINGEE_PAYMENT_RESULT" {
                if let payload = json["data"] as? [String: Any] {
                    let statusStr = payload["status"] as? String ?? "unknown"
                    let status = TingeePaymentStatus(rawValue: statusStr) ?? .unknown
                    let result = TingeePaymentResult(
                        status: status,
                        orderId: payload["orderId"] as? String,
                        transactionId: payload["transactionId"] as? String,
                        errorCode: payload["errorCode"] as? String,
                        errorMessage: payload["errorMessage"] as? String
                    )
                    let delegate = self.delegate
                    print("🔔 [Tingee Web Event] Kết quả thanh toán: \(statusStr) - \(result.transactionId ?? "") - \(result.errorMessage ?? "")")
                    self.dismiss(animated: true) {
                        delegate?.tingeePayCheckoutDidFinish(with: result)
                    }
                }
            } else if type == "OPEN_URL" || type == "OPEN_APP", let payload = json["data"] as? [String: Any], let urlString = payload["url"] as? String, let url = URL(string: urlString) {
                // Đón đầu trường hợp Tingee gửi link qua Bridge thay vì redirect!
                print("🌉 [Tingee Web Event] Tingee yêu cầu mở URL qua Bridge: \(urlString)")
                UIApplication.shared.open(url, options: [:]) { [weak self] success in
                    print("🌉 [Tingee Web Event] Mở URL qua Bridge: \(success ? "Thành công" : "Thất bại")")
                    if !success {
                        self?.showAppNotInstalledAlert()
                        self?.loadPaymentLink()
                    }
                }
            }
        } else if message.name == "tingeeObserver", let dict = message.body as? [String: Any] {
            let event = dict["event"] as? String ?? "UNKNOWN"
            let urlString = dict["url"] as? String ?? ""
            print("👁️ [Tingee Web Event] Observer bẫy được sự kiện: \(event) -> URL: \(urlString)")
            
            if (event == "FETCH_DEEPLINK" || event == "XHR_DEEPLINK") && !urlString.isEmpty {
                if let url = URL(string: urlString) {
                    print("🎯 [Tingee Web Event] BẮT ĐƯỢC DEEP LINK TỪ API: \(urlString)")
                    let isHttp = ["http", "https"].contains(url.scheme?.lowercased() ?? "")
                    
                    // Nếu là link HTTP (như dl.vietqr.io), KHÔNG MỞ trực tiếp vì ta sẽ để WebView tự load trang đó.
                    // Nếu là Scheme riêng (momo://, icb://), thử mở luôn.
                    if !isHttp {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(url, options: [:]) { [weak self] success in
                                print("🎯 [Tingee Web Event] Gọi UIApplication.open: \(success ? "Thành công" : "Thất bại")")
                                if !success {
                                    self?.showAppNotInstalledAlert()
                                    self?.loadPaymentLink()
                                }
                            }
                        }
                    }
                }
            } else if event == "DOWNLOAD_FILE" {
                if let dataUrl = dict["dataUrl"] as? String, let filename = dict["filename"] as? String {
                    if dataUrl.hasPrefix("http") {
                        self.downloadAndSaveImage(urlString: dataUrl)
                    } else {
                        self.saveBase64ToPhotos(dataUrl: dataUrl, filename: filename)
                    }
                }
            }
        }
    }
    
    private func downloadAndSaveImage(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Lỗi", message: "Không thể tải ảnh", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Đóng", style: .default))
                    self?.present(alert, animated: true)
                }
                return
            }
            
            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }.resume()
    }
    
    private func saveBase64ToPhotos(dataUrl: String, filename: String) {
        guard let base64String = dataUrl.components(separatedBy: "base64,").last,
              let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
              let image = UIImage(data: imageData) else {
            return
        }
        
        DispatchQueue.main.async {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        let alert = UIAlertController(title: error == nil ? "Thành công" : "Lỗi",
                                      message: error == nil ? "Đã lưu mã QR vào Thư viện ảnh" : "Không thể lưu mã QR: \(error?.localizedDescription ?? "")",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}
