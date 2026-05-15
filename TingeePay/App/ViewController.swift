import UIKit
import TingeePaySDK
import CryptoKit

enum TingeeEnvironment {
    case sandbox
    case production
    
    var baseURL: String {
        switch self {
        case .sandbox: return "https://uat-open-api.tingee.vn"
        case .production: return "https://open-api.tingee.vn"
        }
    }
}

// MARK: - App Configuration
/// Định nghĩa cấu hình môi trường và keys.
/// Trong ứng dụng Production thực tế: KHÔNG BAO GIỜ lưu `secret` trong App để tránh rò rỉ bảo mật.
/// Toàn bộ logic tạo Signature nên được xử lý trên Backend của Merchant.
enum TingeeAppConfig {
    static let clientId = "74972a04e7dd7eeaf2c30868cdb5fd6a"
    static let secret = "htIQdfgxq114HvfBKb6gP+WXegFv377SAgktTd4V9Uw="
    static let environment: TingeeEnvironment = .sandbox
}

// MARK: - Request Model (Dành cho App Demo giả lập Backend)
struct TingeePaymentLinkRequest: Codable {
    var merchantId: Int
    var orderId: String?
    var requestId: String
    var amount: Int
    var currency: String
    var expireInMinute: Int
    var description: String
    var orderInfo: String
    var bankBin: String
    var customerInfo: String
    var vaAccountNumber: String
    var returnUrl: String
    var partnerCustomerId: String
    
    init(
        merchantId: Int,
        orderId: String?,
        requestId: String = UUID().uuidString,
        amount: Int,
        currency: String = "VND",
        expireInMinute: Int = 30,
        description: String,
        orderInfo: String,
        bankBin: String,
        customerInfo: String,
        vaAccountNumber: String,
        returnUrl: String,
        partnerCustomerId: String
    ) {
        self.merchantId = merchantId
        self.orderId = orderId
        self.requestId = requestId
        self.amount = amount
        self.currency = currency
        self.expireInMinute = expireInMinute
        self.description = description
        self.orderInfo = orderInfo
        self.bankBin = bankBin
        self.customerInfo = customerInfo
        self.vaAccountNumber = vaAccountNumber
        self.returnUrl = returnUrl
        self.partnerCustomerId = partnerCustomerId
    }
}

// MARK: - Response Model
struct TingeePaymentLinkResponse: Codable {
    let code: String?
    let message: String?
    let data: String?
}

// MARK: - Payment ViewModel
/// ViewModel đảm nhiệm xử lý logic nghiệp vụ thanh toán (tính toán amount, validate, tạo request, và mock gọi mạng).
final class PaymentViewModel {
    
    // MARK: - Outputs (Callbacks)
    var onShowError: ((String) -> Void)?
    var onPresentSDK: ((String) -> Void)?
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
        
        // 2. Giả lập Backend gọi API lên Tingee để lấy checkoutUrl
        simulateBackendCreateLink(request: request) { [weak self] checkoutUrl in
            DispatchQueue.main.async {
                self?.onLoading?(false)
                if let url = checkoutUrl {
                    // 3. Trả checkoutUrl về cho App để mở SDK Tingee
                    self?.onPresentSDK?(url)
                } else {
                    self?.onShowError?("Không thể tạo link thanh toán từ Backend giả lập.")
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    private func simulateBackendCreateLink(request: TingeePaymentLinkRequest, completion: @escaping (String?) -> Void) {
        let (signature, timestamp) = generateMockSignature(for: request)
        
        guard let url = URL(string: TingeeAppConfig.environment.baseURL + "/v1/payment-gateway/create-link") else {
            completion(nil)
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.addValue(TingeeAppConfig.clientId, forHTTPHeaderField: "x-client-id")
        urlRequest.addValue(signature, forHTTPHeaderField: "x-signature")
        urlRequest.addValue(timestamp, forHTTPHeaderField: "x-request-timestamp")
        
        let encoder = JSONEncoder()
        if #available(iOS 13.0, macOS 10.15, *) {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        
        let bodyData = try? encoder.encode(request)
        urlRequest.httpBody = bodyData
        
        // --- LOG REQUEST ---
        print("\n========== [BACKEND MOCK] TINGEE PAY REQUEST ==========")
        print("URL: \(urlRequest.url?.absoluteString ?? "")")
        print("Method: \(urlRequest.httpMethod ?? "")")
        print("Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        if let bodyData = bodyData, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
        print("=======================================================\n")
        // -------------------
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            // --- LOG RESPONSE ---
            print("\n========== [BACKEND MOCK] TINGEE PAY RESPONSE ==========")
            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code: \(httpResponse.statusCode)")
            }
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                print("Response Data: \(dataString)")
            }
            print("========================================================\n")
            // --------------------
            
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            do {
                let apiResponse = try JSONDecoder().decode(TingeePaymentLinkResponse.self, from: data)
                if apiResponse.code == "00" {
                    completion(apiResponse.data)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
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

final class ViewController: UIViewController {
    
    // MARK: - UI Components
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let amountTextField = UITextField()
    
    private let expireLabel = UILabel()
    private let expireTextField = UITextField()
    
    private let descLabel = UILabel()
    private let descTextField = UITextField()
    
    private let inputStackView = UIStackView()
    private let styleSegmentedControl = UISegmentedControl(items: ["Bottom Sheet", "Full Screen"])
    
    private let colorLabel = UILabel()
    private let colorTextField = UITextField()
    private let colorPreviewView = UIView()
    
    private let payButton = UIButton(type: .system)
    
    private let statusTitleLabel = UILabel()
    private let statusValueLabel = UILabel()
    
    // MARK: - Properties
    private let viewModel = PaymentViewModel()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        setupBindings()
    }
    
    // MARK: - Setup UI
    private func setupView() {
        view.backgroundColor = .systemGroupedBackground
        
        // Tap to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.text = "Tạo Đơn Hàng"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        amountLabel.text = "Số tiền thanh toán (VND):"
        amountLabel.font = .systemFont(ofSize: 15, weight: .medium)
        amountLabel.textColor = .secondaryLabel
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        amountTextField.placeholder = "50000"
        amountTextField.keyboardType = .numberPad
        amountTextField.borderStyle = .roundedRect
        amountTextField.font = .systemFont(ofSize: 16, weight: .semibold)
        amountTextField.text = "50000"
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        
        expireLabel.text = "Thời hạn (phút)"
        expireLabel.font = .systemFont(ofSize: 13, weight: .medium)
        expireLabel.textColor = .secondaryLabel
        expireLabel.translatesAutoresizingMaskIntoConstraints = false
        
        expireTextField.placeholder = "30"
        expireTextField.keyboardType = .numberPad
        expireTextField.borderStyle = .roundedRect
        expireTextField.font = .systemFont(ofSize: 16, weight: .semibold)
        expireTextField.text = "30"
        expireTextField.translatesAutoresizingMaskIntoConstraints = false
        
        descLabel.text = "Mô tả"
        descLabel.font = .systemFont(ofSize: 13, weight: .medium)
        descLabel.textColor = .secondaryLabel
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        descTextField.placeholder = "Thanh toan don hang..."
        descTextField.borderStyle = .roundedRect
        descTextField.font = .systemFont(ofSize: 16, weight: .semibold)
        descTextField.text = "Thanh toan don hang test SDK"
        descTextField.translatesAutoresizingMaskIntoConstraints = false
        
        inputStackView.axis = .vertical
        inputStackView.distribution = .fill
        inputStackView.spacing = 16
        inputStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let amountStack = UIStackView(arrangedSubviews: [amountLabel, amountTextField])
        amountStack.axis = .vertical
        amountStack.spacing = 8
        
        let expireStack = UIStackView(arrangedSubviews: [expireLabel, expireTextField])
        expireStack.axis = .vertical
        expireStack.spacing = 8
        
        let descStack = UIStackView(arrangedSubviews: [descLabel, descTextField])
        descStack.axis = .vertical
        descStack.spacing = 8
        
        colorLabel.text = "Màu sắc chủ đạo (Mã HEX)"
        colorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        colorLabel.textColor = .secondaryLabel
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        colorTextField.placeholder = "VD: #ff0000"
        colorTextField.borderStyle = .roundedRect
        colorTextField.font = .systemFont(ofSize: 16, weight: .semibold)
        colorTextField.text = ""
        colorTextField.translatesAutoresizingMaskIntoConstraints = false
        colorTextField.addTarget(self, action: #selector(colorTextChanged), for: .editingChanged)
        
        colorPreviewView.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        colorPreviewView.layer.cornerRadius = 12
        colorPreviewView.layer.borderWidth = 1
        colorPreviewView.layer.borderColor = UIColor.separator.cgColor
        colorPreviewView.backgroundColor = .clear
        
        let rightViewContainer = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 24))
        rightViewContainer.addSubview(colorPreviewView)
        colorPreviewView.center = rightViewContainer.center
        
        colorTextField.rightView = rightViewContainer
        colorTextField.rightViewMode = .always
        
        let colorStack = UIStackView(arrangedSubviews: [colorLabel, colorTextField])
        colorStack.axis = .vertical
        colorStack.spacing = 8
        
        inputStackView.addArrangedSubview(amountStack)
        inputStackView.addArrangedSubview(expireStack)
        inputStackView.addArrangedSubview(descStack)
        inputStackView.addArrangedSubview(colorStack)
        
        styleSegmentedControl.selectedSegmentIndex = 0
        styleSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        payButton.setTitle("Thanh toán", for: .normal)
        payButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        payButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)
        payButton.setTitleColor(.white, for: .normal)
        payButton.layer.cornerRadius = 12
        payButton.translatesAutoresizingMaskIntoConstraints = false
        payButton.addTarget(self, action: #selector(handlePaymentTapped), for: .touchUpInside)
        
        statusTitleLabel.text = "Trạng thái:"
        statusTitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusTitleLabel.textColor = .secondaryLabel
        statusTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        statusValueLabel.text = "Chưa thanh toán"
        statusValueLabel.font = .systemFont(ofSize: 15, weight: .bold)
        statusValueLabel.textColor = .systemGray
        statusValueLabel.numberOfLines = 0
        statusValueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(inputStackView)
        cardView.addSubview(styleSegmentedControl)
        cardView.addSubview(payButton)
        cardView.addSubview(statusTitleLabel)
        cardView.addSubview(statusValueLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            inputStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            inputStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            inputStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            styleSegmentedControl.topAnchor.constraint(equalTo: inputStackView.bottomAnchor, constant: 24),
            styleSegmentedControl.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            styleSegmentedControl.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            styleSegmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            payButton.topAnchor.constraint(equalTo: styleSegmentedControl.bottomAnchor, constant: 24),
            payButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            payButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            payButton.heightAnchor.constraint(equalToConstant: 56),
            
            statusTitleLabel.topAnchor.constraint(equalTo: payButton.bottomAnchor, constant: 24),
            statusTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            
            statusValueLabel.topAnchor.constraint(equalTo: statusTitleLabel.topAnchor),
            statusValueLabel.leadingAnchor.constraint(equalTo: statusTitleLabel.trailingAnchor, constant: 8),
            statusValueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            statusValueLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Setup Bindings (MVVM)
    private func setupBindings() {
        viewModel.onShowError = { [weak self] errorMessage in
            let alert = UIAlertController(title: "Lỗi", message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .default))
            self?.present(alert, animated: true)
        }
        
        viewModel.onLoading = { [weak self] isLoading in
            self?.payButton.isEnabled = !isLoading
            self?.payButton.setTitle(isLoading ? "Đang xử lý..." : "Thanh toán", for: .normal)
            self?.payButton.alpha = isLoading ? 0.6 : 1.0
        }
        
        viewModel.onPresentSDK = { [weak self] checkoutUrlString in
            guard let self = self, let url = URL(string: checkoutUrlString) else { return }
            let style: TingeePayPresentationStyle = self.styleSegmentedControl.selectedSegmentIndex == 0 ? .bottomSheet : .fullScreen
            
            let customColor = self.colorTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let selectedColor: String? = (customColor?.isEmpty == false) ? customColor : nil
            
            TingeePay.presentCheckout(
                from: self,
                checkoutUrl: url,
                style: style,
                themeColor: selectedColor,
                delegate: self
            )
        }
    }
    
    // MARK: - Actions
    @objc private func colorTextChanged() {
        let hex = colorTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if hex.isEmpty {
            colorPreviewView.backgroundColor = .clear
            return
        }
        colorPreviewView.backgroundColor = UIColor(hexString: hex) ?? .clear
    }
    
    @objc private func handlePaymentTapped() {
        dismissKeyboard()
        viewModel.processPayment(
            amountText: amountTextField.text,
            expireText: expireTextField.text,
            descText: descTextField.text
        )
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - TingeePayCheckoutDelegate
extension ViewController: TingeePayCheckoutDelegate {
    
    func tingeePayCheckoutDidFinish(with result: TingeePaymentResult) {
        var message = ""
        var color: UIColor = .systemGray
        
        switch result.status {
        case .success:
            message = "Thành công (Mã: \(result.orderId ?? ""))"
            color = .systemGreen
        case .failed:
            message = "Thất bại (\(result.errorMessage ?? ""))"
            color = .systemRed
        case .expired:
            message = "Đã hết hạn"
            color = .systemOrange
        case .error:
            message = "Lỗi hệ thống"
            color = .systemRed
        case .cancelled:
            message = "Đã huỷ"
            color = .systemGray
        case .unknown:
            message = "Không xác định"
            color = .systemGray
        }
        
        DispatchQueue.main.async {
            self.statusValueLabel.text = message
            self.statusValueLabel.textColor = color
        }
        
        print("✅ [Client App] Nhận kết quả từ SDK: \(message)")
        
        let alert = UIAlertController(title: "Kết quả", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    func tingeePayCheckoutDidCancel() {
        print("❌ [Client App] SDK báo: Người dùng đóng màn hình thanh toán")
    }
    
    func tingeePayCheckoutDidFail(with error: Error) {
        print("⚠️ [Client App] SDK báo lỗi nội bộ: \(error.localizedDescription)")
    }
}

// MARK: - UIColor Extension cho HEX
extension UIColor {
    convenience init?(hexString: String) {
        var chars = Array(hexString.hasPrefix("#") ? hexString.dropFirst() : hexString[...])
        switch chars.count {
        case 3: chars = chars.flatMap { [$0, $0] }
        case 6: break
        case 8: break
        default: return nil
        }
        guard let hexValue = UInt64(String(chars), radix: 16) else { return nil }
        let r, g, b, a: CGFloat
        switch chars.count {
        case 6:
            r = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(hexValue & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(hexValue & 0x000000FF) / 255.0
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
