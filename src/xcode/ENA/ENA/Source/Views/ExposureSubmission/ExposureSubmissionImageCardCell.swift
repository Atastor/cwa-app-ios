//
// Corona-Warn-App
//
// SAP SE and all other contributors
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import Foundation
import UIKit

@IBDesignable
class ExposureSubmissionImageCardCell: UITableViewCell {
	@IBOutlet var cardView: UIView!
	@IBOutlet var titleLabel: ENALabel!
	@IBOutlet var descriptionLabel: ENALabel!
	@IBOutlet var illustrationView: UIImageView!

	private var highlightView: UIView!

	override func setHighlighted(_ highlighted: Bool, animated: Bool) {
		super.setHighlighted(highlighted, animated: animated)

		highlightView?.isHidden = !highlighted
	}

	override func prepareForInterfaceBuilder() {
		super.prepareForInterfaceBuilder()

		guard nil != cardView else { return }
		setup()
	}

	override func awakeFromNib() {
		super.awakeFromNib()

		setup()
	}

	private func setup() {
		selectionStyle = .none

		cardView.layer.cornerRadius = 16

		highlightView?.removeFromSuperview()
		highlightView = UIView(frame: bounds)
		highlightView.isHidden = !isHighlighted
		highlightView.backgroundColor = .enaColor(for: .listHighlight)
		highlightView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		cardView.addSubview(highlightView)

		updateIllustration(for: traitCollection)
	}

	func configure(title: String, description: String, attributedDescription: NSAttributedString? = nil, image: UIImage?, accessibilityIdentifier: String?) {
		titleLabel.text = title
		descriptionLabel.text = description
		illustrationView?.image = image

		if let attributedDescription = attributedDescription {
			let attributedText = NSMutableAttributedString(attributedString: attributedDescription)
			descriptionLabel.attributedText = attributedText
		}
		self.accessibilityIdentifier = accessibilityIdentifier
	}

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		updateIllustration(for: traitCollection)
	}

	private func updateIllustration(for traitCollection: UITraitCollection) {
		if traitCollection.preferredContentSizeCategory >= .accessibilityLarge {
			illustrationView.superview?.isHidden = true
		} else {
			illustrationView.superview?.isHidden = false
		}
	}
}
