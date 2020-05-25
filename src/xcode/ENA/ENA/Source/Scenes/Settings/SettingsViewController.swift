//
//  SettingsViewController.swift
//  ENA
//
//  Created by Tikhonov, Aleksandr on 28.04.20.
//  Copyright © 2020 SAP SE. All rights reserved.
//

import ExposureNotification
import UIKit
import MessageUI

protocol SettingsViewControllerDelegate: AnyObject {
    typealias Completion = (ExposureNotificationError?) -> Void

    func settingsViewController(
        _ controller: SettingsViewController,
        setExposureManagerEnabled enabled: Bool,
        then completion: @escaping Completion
    )
}

final class SettingsViewController: UITableViewController {
    var exposureManagerEnabled = false {
        didSet {
            notificationSettingsController?.exposureManagerEnabled = exposureManagerEnabled
        }
    }
    private weak var notificationSettingsController: ExposureNotificationSettingViewController?
    private weak var delegate: SettingsViewControllerDelegate?

    let store: Store

    let tracingSegue = "showTracing"
    let resetSegue = "showReset"

    let settingsViewModel = SettingsViewModel.model

    init?(coder: NSCoder, store: Store, exposureManagerEnabled: Bool, delegate: SettingsViewControllerDelegate) {
        self.store = store
        self.delegate = delegate
        self.exposureManagerEnabled = exposureManagerEnabled
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        navigationItem.title = AppStrings.Settings.navigationBarTitle
        navigationController?.navigationBar.prefersLargeTitles = true

        setupView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == resetSegue, let vc = segue.destination as? ResetViewController {
            vc.delegate = self
        }
    }

    @IBSegueAction
    func createExposureNotificationSettingViewController(coder: NSCoder) -> ExposureNotificationSettingViewController? {
        return ExposureNotificationSettingViewController(coder: coder, exposureManagerEnabled: exposureManagerEnabled, delegate: self)
    }

    @objc
    private func willEnterForeground() {
        checkTracingStatus()
        notificationSettings()
    }

    private func setupView() {
        // We disable all app store checks to make testing a little bit easier.
//        #if !APP_STORE
            let tap = UITapGestureRecognizer(target: self, action: #selector(sendLogFile))
            tap.numberOfTapsRequired = 3
            view.addGestureRecognizer(tap)
//        #endif

        checkTracingStatus()
        notificationSettings()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: UIApplication.shared
        )
    }

    private func checkTracingStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.settingsViewModel.tracing.state = self.exposureManagerEnabled ? self.settingsViewModel.tracing.stateActive : self.settingsViewModel.tracing.stateInactive
            self.tableView.reloadData()
        }
    }

    private func notificationSettings() {
        let currentCenter = UNUserNotificationCenter.current()

        currentCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            guard let self = self else { return }

            if let error = error {
                log(message: "Error while requesting notifications permissions: \(error.localizedDescription)")
                self.settingsViewModel.notifications.setState(state: false)
                return
            }

            if granted {
                self.settingsViewModel.notifications.setState(state: true)
            } else {
                self.settingsViewModel.notifications.setState(state: false)
            }

            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    private func setExposureManagerEnabled(_ enabled: Bool, then: @escaping SettingsViewControllerDelegate.Completion) {
        delegate?.settingsViewController(self, setExposureManagerEnabled: enabled, then: then)
    }
}

// MARK: UITableViewDataSource, UITableViewDelegate
extension SettingsViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Sections.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = Sections.allCases[section]

        switch section {
        case .reset:
            return 40
        case .tracing, .notifications:
            return 20
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let section = Sections.allCases[section]

        switch section {
        case .tracing:
            return AppStrings.Settings.tracingDescription
        case .notifications:
            return AppStrings.Settings.notificationDescription
        case .reset:
            return AppStrings.Settings.resetDescription
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footerView = view as? UITableViewHeaderFooterView else { return }

        let section = Sections.allCases[section]

        switch section {
        case .reset:
            footerView.textLabel?.textAlignment = .center
        case .tracing, .notifications:
            footerView.textLabel?.textAlignment = .left
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Sections.allCases[indexPath.section]

        switch section {
        case .tracing:
            return configureMainCell(indexPath: indexPath, model: settingsViewModel.tracing)
        case .notifications:
            return configureMainCell(indexPath: indexPath, model: settingsViewModel.notifications)
        case .reset:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.reset.rawValue, for: indexPath) as? ResetTableViewCell else {
                fatalError("No cell for reuse identifier.")
            }

            cell.titleLabel.text = settingsViewModel.reset

            return cell
        }
    }

    func configureMainCell(indexPath: IndexPath, model: SettingsViewModel.Main) -> MainSettingsTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.main.rawValue, for: indexPath) as? MainSettingsTableViewCell else {
            fatalError("No cell for reuse identifier.")
        }

        cell.configure(model: model)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = Sections.allCases[indexPath.section]

        switch section {
        case .tracing:
            performSegue(withIdentifier: tracingSegue, sender: nil)
        case .notifications:
            guard
                let settingsURL = URL(string: UIApplication.openSettingsURLString),
                UIApplication.shared.canOpenURL(settingsURL) else {
                    return
            }
            UIApplication.shared.open(settingsURL)
        case .reset:
            performSegue(withIdentifier: resetSegue, sender: nil)
        }

        tableView.deselectRow(at: indexPath, animated: false)
    }
}

extension SettingsViewController: ResetDelegate {
    func reset() {
        store.isOnboarded = false
        if store.dateLastExposureDetection != nil {
            store.dateLastExposureDetection = nil
        }
    }
}

extension SettingsViewController: ExposureNotificationSettingViewControllerDelegate {
    func exposureNotificationSettingViewController(_ controller: ExposureNotificationSettingViewController, setExposureManagerEnabled enabled: Bool, then completion: @escaping (ExposureNotificationError?) -> Void) {
        setExposureManagerEnabled(enabled, then: completion)
    }
}

extension SettingsViewController: ViewControllerUpdatable {
    func updateUI() {
        checkTracingStatus()
        notificationSettingsController?.updateUI()
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    @objc
    func sendLogFile() {
        let alert = UIAlertController(title: "Send Log", message: "", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Please enter email"
        }

        let action = UIAlertAction(title: "Send Log File", style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }

            guard let emailText = alert.textFields?[0].text else {
                return
            }

            if !MFMailComposeViewController.canSendMail() {
                return
            }

            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = strongSelf
            composeVC.setToRecipients([emailText])
            composeVC.setSubject("Log File")

            guard let logFile = appLogger.getLoggedData() else {
                return
            }
            composeVC.addAttachmentData(logFile, mimeType: "txt", fileName: "Log")

            self?.present(composeVC, animated: true, completion: nil)
        }

        alert.addAction(action)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

enum Sections: CaseIterable {
    case tracing
    case notifications
    case reset
}

enum ReuseIdentifier: String {
    case main = "mainSettings"
    case reset = "resetSettings"
}
