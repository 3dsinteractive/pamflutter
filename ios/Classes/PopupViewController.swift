import AVFoundation
import Flutter
import ImageIO
import UIKit

public class PopupViewController: UIViewController {
    var popupData: [String: Any]?
    var playerLayer: AVPlayerLayer?
    var containerView: UIView?
    var videoPlayer: AVPlayer?
    var result: FlutterResult?
    var logger: PamLogger?

    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionView = UITextView()
    private var descriptionHeight: NSLayoutConstraint?
    private let closeButton = UIButton(type: .system)
    private let actionButton = UIButton(type: .system)
    private let footer = UIStackView()
    private let loading = UIActivityIndicatorView(style: .medium)
    private var imageTask: URLSessionDataTask?
    private var readyObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var mediaSize = CGSize.zero
    private var closing = false
    private var completed = false
    private var isLarge: Bool { popupData?["size"] as? String == "large" }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMedia()
    }

    private func setupUI() {
        let popup = popupData ?? [:]
        view.backgroundColor = isLarge ? UIColor.black.withAlphaComponent(0.7) : .black
        view.accessibilityViewIsModal = true

        // The host and controls are laid out before any media metadata arrives.
        // Only the hidden image/layer changes its inner frame during loading.
        let container = UIView()
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        containerView = container
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        imageView.contentMode = .scaleToFill // Its frame has the media's aspect ratio.
        imageView.alpha = 0
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = isLarge ? 15 : 0
        container.addSubview(imageView)
        loading.sizeToFit()
        loading.color = .white
        loading.hidesWhenStopped = true
        container.addSubview(loading)
        loading.startAnimating()

        closeButton.backgroundColor = .white
        closeButton.tintColor = .black
        closeButton.layer.cornerRadius = 20
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.accessibilityLabel = "Close"
        closeButton.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
        ])

        titleLabel.text = popup["title"] as? String
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        descriptionView.text = popup["description"] as? String
        descriptionView.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .white
        titleLabel.textAlignment = isLarge ? .center : .left
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        descriptionView.textColor = .white
        descriptionView.textAlignment = isLarge ? .center : .left
        descriptionView.backgroundColor = .clear
        descriptionView.isEditable = false
        descriptionView.isSelectable = false
        descriptionView.textContainerInset = .zero
        descriptionView.textContainer.lineFragmentPadding = 0
        // Reserve up to three visible lines; longer descriptions can scroll.
        descriptionHeight = descriptionView.heightAnchor.constraint(equalToConstant: 0)
        descriptionHeight?.isActive = true

        let actionURL = (popup["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        actionButton.isHidden = actionURL.isEmpty
        actionButton.backgroundColor = buttonColor(popup["action_button_color"])
            ?? UIColor(red: 0.36, green: 0.94, blue: 0.85, alpha: 1)
        actionButton.setTitleColor(buttonColor(popup["action_button_text_color"]) ?? .black, for: .normal)
        actionButton.setTitle(popup["action_button_label"] as? String ?? "LEARN MORE..", for: .normal)
        actionButton.layer.cornerRadius = 20
        actionButton.addTarget(self, action: #selector(learnMore), for: .touchUpInside)
        // A hidden arranged subview has zero height; avoid conflicting constraints.
        let actionHeight = actionButton.heightAnchor.constraint(equalToConstant: 44)
        actionHeight.priority = UILayoutPriority(999)
        actionHeight.isActive = true

        footer.axis = .vertical
        footer.spacing = 10
        footer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footer)
        if isLarge {
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(titleLabel)
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
                titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            ])
        } else {
            footer.addArrangedSubview(titleLabel)
        }
        footer.addArrangedSubview(descriptionView)
        footer.addArrangedSubview(actionButton)
        NSLayoutConstraint.activate([
            footer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        if let pixel = popup["tracking_pixel_url"] as? String, let url = URL(string: pixel) {
            let logger = self.logger
            URLSession.shared.dataTask(with: url) { [weak logger] _, response, error in
                DispatchQueue.main.async {
                    logger?.attentionPixelFailed(status: (response as? HTTPURLResponse)?.statusCode, error: error)
                }
            }.resume()
        }
    }

    private func mediaURL(_ key: String) -> URL? {
        guard let text = popupData?[key] as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : URL(string: trimmed)
    }

    private func loadMedia() {
        // Prefer video when both are supplied. The image is a failure fallback,
        // rather than a poster that would visibly change when playback starts.
        if let url = mediaURL("video") {
            loadVideo(url)
        } else {
            loadImage()
        }
    }

    private func loadImage() {
        guard !closing, !completed, let url = mediaURL("image") else {
            loading.stopAnimating()
            return
        }
        let screen = view.window?.screen ?? UIScreen.main
        let maxPixelSize = max(screen.nativeBounds.width, screen.nativeBounds.height)
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            // ImageIO downsamples, applies EXIF orientation and decodes off the UI
            // thread so the first visible frame already has its final dimensions.
            var decoded: UIImage?
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            if error == nil, (200..<300).contains(status), let data = data,
                let source = CGImageSourceCreateWithData(data as CFData, nil),
                let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                ] as CFDictionary)
            {
                decoded = UIImage(cgImage: cgImage)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.closing, !self.completed else { return }
                guard let image = decoded else {
                    self.loading.stopAnimating()
                    return
                }
                self.mediaSize = image.size
                self.imageView.image = image
                self.view.layoutIfNeeded()
                self.layoutMedia()
            }
        }
        imageTask?.resume()
    }

    private func loadVideo(_ url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        let layer = AVPlayerLayer(player: player)
        videoPlayer = player
        playerLayer = layer
        layer.opacity = 0
        layer.videoGravity = .resizeAspect
        layer.cornerRadius = isLarge ? 15 : 0
        layer.masksToBounds = true
        containerView?.layer.addSublayer(layer)
        readyObservation = layer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.layoutMedia() }
        }
        sizeObservation = item.observe(\.presentationSize, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.layoutMedia() }
        }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async { self?.videoFailed() }
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(restartVideo), name: .AVPlayerItemDidPlayToEndTime, object: item)
        player.play()
    }

    private func videoFailed() {
        guard !closing, !completed, videoPlayer != nil else { return }
        releaseVideo()
        mediaSize = .zero
        loadImage()
    }

    private func layoutMedia() {
        guard !closing, !completed, let container = containerView else { return }
        if let item = videoPlayer?.currentItem { mediaSize = item.presentationSize }
        let cover = AttentionMediaLayout.usesCover(media: mediaSize, viewport: view.bounds.size, full: !isLarge)
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let top = (isLarge ? titleLabel.frame.maxY : closeButton.frame.maxY) + 12
        let bottom = footer.frame.minY - 12
        var bounds = CGRect(x: safe.minX + 20, y: top,
                            width: max(0, safe.width - 40), height: max(0, bottom - top))
        if cover {
            bounds = container.bounds
        } else if isLarge {
            let width = min(bounds.width, safe.width * 0.8)
            let height = min(bounds.height, view.bounds.height * 0.6)
            bounds = CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                            width: width, height: height)
        }
        loading.center = CGPoint(x: bounds.midX, y: bounds.midY)
        let frame = AttentionMediaLayout.frame(media: mediaSize, in: bounds, cover: cover)
        guard frame.width > 0, frame.height > 0 else { return }
        UIView.performWithoutAnimation {
            self.imageView.frame = frame
            if self.playerLayer == nil && self.imageView.image != nil {
                self.imageView.alpha = 1
                self.loading.stopAnimating()
            }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer?.frame = frame
        // Reveal only after layout AND the decoded image/first video frame are
        // ready. No guessed ratio, crossfade, or animated layer resizing.
        if let layer = playerLayer {
            if layer.isReadyForDisplay {
                layer.opacity = 1
                loading.stopAnimating()
            }
        }
        CATransaction.commit()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if footer.bounds.width > 0, let font = descriptionView.font {
            let measured = descriptionView.sizeThatFits(
                CGSize(width: footer.bounds.width, height: CGFloat.greatestFiniteMagnitude)).height
            let height = descriptionView.text.isEmpty ? 0 : min(ceil(measured), ceil(font.lineHeight * 3))
            if descriptionHeight?.constant != height {
                descriptionHeight?.constant = height
                view.layoutIfNeeded()
            }
        }
        layoutMedia()
    }

    private func buttonColor(_ value: Any?) -> UIColor? {
        guard let text = value as? String else { return nil }
        let hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil,
            let rgb = UInt32(hex.dropFirst(), radix: 16)
        else { return nil }
        return UIColor(red: CGFloat((rgb >> 16) & 0xff) / 255,
                       green: CGFloat((rgb >> 8) & 0xff) / 255,
                       blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
    }

    @objc private func restartVideo() {
        guard !closing, !completed else { return }
        videoPlayer?.seek(to: .zero)
        videoPlayer?.play()
    }

    private func releaseVideo() {
        readyObservation?.invalidate()
        sizeObservation?.invalidate()
        statusObservation?.invalidate()
        readyObservation = nil
        sizeObservation = nil
        statusObservation = nil
        videoPlayer?.pause()
        videoPlayer = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        NotificationCenter.default.removeObserver(self)
    }

    // Complete only after dismissal, and only once, for every dismissal path.
    func complete(_ value: Any?) {
        guard !completed else { return }
        completed = true
        imageTask?.cancel()
        imageTask = nil
        releaseVideo()
        let callback = result
        result = nil
        callback?(value)
    }

    private func close(with value: Any?) {
        guard !closing, !completed, result != nil else { return }
        closing = true
        imageTask?.cancel()
        videoPlayer?.pause()
        dismiss(animated: true) { self.complete(value) }
    }

    @objc private func learnMore() { close(with: popupData) }
    @objc private func closePopup() { close(with: nil) }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !closing && (isBeingDismissed || presentingViewController == nil) {
            complete(nil)
        }
    }

    deinit {
        imageTask?.cancel()
        videoPlayer?.pause()
        NotificationCenter.default.removeObserver(self)
    }
}
