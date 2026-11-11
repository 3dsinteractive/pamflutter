import AVFoundation
import Flutter
import UIKit

public class PopupViewController: UIViewController {

    var popupData: [String: Any]?
    var playerLayer: AVPlayerLayer?
    var containerView: UIView?
    var videoPlayer: AVPlayer?
    var result: FlutterResult?
    var logger: PamLogger?
    private var closing = false

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        guard let popup = popupData else { return }

        // อ่านค่าจาก popupData
        let title = popup["title"] as? String
        let description = popup["description"] as? String
        let image = popup["image"] as? String
        let video = popup["video"] as? String
        let size = popup["size"] as? String
        let trackingPixelUrl = popup["tracking_pixel_url"] as? String

        // ส่ง Tracking Pixel ไปยัง Server
        if let url = URL(string: trackingPixelUrl ?? "") {
            let logger = self.logger
            URLSession.shared.dataTask(with: url) { [weak logger] _, response, error in
                DispatchQueue.main.async {
                    logger?.attentionPixelFailed(
                        status: (response as? HTTPURLResponse)?.statusCode, error: error)
                }
            }.resume()
        }

        // พื้นหลังสีดำโปร่งแสง
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)

        // Container View สำหรับแสดง Popup
        containerView = UIView()
        containerView!.backgroundColor = .clear
        containerView!.layer.cornerRadius = 15
        containerView!.layer.masksToBounds = true
        containerView!.clipsToBounds = true
        containerView!.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView!)

        // กำหนดขนาด popup ตาม size
        if size == "large" {
            NSLayoutConstraint.activate([
                containerView!.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
                containerView!.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
                containerView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView!.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            ])
        } else {
            NSLayoutConstraint.activate([
                containerView!.topAnchor.constraint(equalTo: view.topAnchor),
                containerView!.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                containerView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
        }

        // Description Label
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.textColor = .white
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descriptionLabel)

        if size == "large" {
            descriptionLabel.textAlignment = .center
            NSLayoutConstraint.activate([
                descriptionLabel.topAnchor.constraint(
                    equalTo: containerView!.bottomAnchor, constant: 10),
                descriptionLabel.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor, constant: 20),
                descriptionLabel.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor, constant: -20),
            ])
        } else {
            descriptionLabel.textAlignment = .left
            NSLayoutConstraint.activate([
                descriptionLabel.bottomAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -70),
                descriptionLabel.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor, constant: 20),
                descriptionLabel.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor, constant: -20),
            ])
        }

        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        if size == "large" {
            titleLabel.textAlignment = .center
            NSLayoutConstraint.activate([
                titleLabel.bottomAnchor.constraint(
                    equalTo: containerView!.topAnchor, constant: -10),
                titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            ])
        } else {
            titleLabel.textAlignment = .left
            NSLayoutConstraint.activate([
                titleLabel.bottomAnchor.constraint(
                    equalTo: descriptionLabel.topAnchor, constant: -10),
                titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            ])
        }

        // รองรับการแสดง Image หรือ Video
        if let imageUrl = image, let url = URL(string: imageUrl) {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            containerView!.addSubview(imageView)
            imageView.contentMode = .scaleAspectFill
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(
                    equalTo: containerView!.widthAnchor, multiplier: 1.0),
                imageView.heightAnchor.constraint(
                    equalTo: containerView!.heightAnchor, multiplier: 1.0),
                imageView.centerXAnchor.constraint(equalTo: containerView!.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: containerView!.centerYAnchor),
            ])

            DispatchQueue.global().async {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }
        }

        if let videoUrl = video, let url = URL(string: videoUrl) {
            videoPlayer = AVPlayer(url: url)
            playerLayer = AVPlayerLayer(player: videoPlayer!)
            playerLayer!.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
            containerView!.layer.addSublayer(playerLayer!)
            videoPlayer!.play()
        }

        // Close Button
        let closeButton = UIButton(type: .system)
        closeButton.backgroundColor = .white
        closeButton.layer.cornerRadius = 20
        //let icon = UIImage(systemName: "xmark")  // ไอคอน "X"

        if #available(iOS 13.0, *) {
            let icon = UIImage(systemName: "xmark")  // ใช้ SF Symbol บน iOS 13+
            closeButton.setImage(icon, for: .normal)
        } else {
            // ใช้ตัวอักษร ✖️ แทนรูปภาพ
            closeButton.setTitle("✖️", for: .normal)
            closeButton.setTitleColor(.black, for: .normal) // เปลี่ยนสีให้ตรงกับ UI
        }

        closeButton.tintColor = .black  // สีของไอคอน
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        closeButton.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        if size == "large" {
            NSLayoutConstraint.activate([
                closeButton.heightAnchor.constraint(equalToConstant: 40),
                closeButton.widthAnchor.constraint(equalToConstant: 40),
                closeButton.topAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                closeButton.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -30),
            ])
        } else {
            NSLayoutConstraint.activate([
                closeButton.heightAnchor.constraint(equalToConstant: 40),
                closeButton.widthAnchor.constraint(equalToConstant: 40),
                closeButton.topAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                closeButton.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            ])
        }

        // Close Button
        let info = UIButton(type: .system)
        let actionURL = (popup["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        info.isHidden = actionURL.isEmpty
        info.backgroundColor = UIColor(red: 0.36, green: 0.94, blue: 0.85, alpha: 1.0)
        info.setTitleColor(.black, for: UIControl.State.normal)
        info.layer.cornerRadius = 20
        info.setTitle("LEARN MORE..", for: .normal)
        if let text = popup["action_button_label"] as? String {
            info.setTitle(text, for: .normal)
        }
        if let color = buttonColor(popup["action_button_color"]) {
            info.backgroundColor = color
        }
        if let color = buttonColor(popup["action_button_text_color"]) {
            info.setTitleColor(color, for: .normal)
        }
        info.addTarget(self, action: #selector(learnMore), for: .touchUpInside)
        info.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(info)

        NSLayoutConstraint.activate([
            info.heightAnchor.constraint(equalToConstant: 40),
            info.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            info.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            info.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartVideo),
            name: .AVPlayerItemDidPlayToEndTime,
            object: videoPlayer?.currentItem
        )
    }

    private func buttonColor(_ value: Any?) -> UIColor? {
        guard let text = value as? String else { return nil }
        let hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil,
            let rgb = UInt32(hex.dropFirst(), radix: 16)
        else { return nil }
        return UIColor(
            red: CGFloat((rgb >> 16) & 0xff) / 255,
            green: CGFloat((rgb >> 8) & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: 1
        )
    }

    @objc private func restartVideo() {
        videoPlayer?.seek(to: .zero)
        videoPlayer?.play()
    }

    public override func viewDidLayoutSubviews() {
        playerLayer?.frame = containerView?.bounds ?? CGRect.zero
    }

    // Complete only after dismissal, and only once, for every dismissal path.
    func complete(_ value: Any?) {
        let callback = result
        result = nil
        videoPlayer?.pause()
        NotificationCenter.default.removeObserver(self)
        callback?(value)
    }

    private func close(with value: Any?) {
        guard !closing, result != nil else { return }
        closing = true
        videoPlayer?.pause()
        dismiss(animated: true) { self.complete(value) }
    }

    @objc private func learnMore() {
        close(with: popupData)
    }

    @objc private func closePopup() {
        close(with: nil)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !closing && (isBeingDismissed || presentingViewController == nil) {
            complete(nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
