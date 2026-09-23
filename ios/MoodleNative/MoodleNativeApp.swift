import SwiftUI
#if targetEnvironment(macCatalyst)
import UIKit
#endif

@main
struct MoodleNativeApp: App {
    @State private var selectedTab: RootTab = AppLaunchConfiguration.current.initialSelectedTab

    var body: some Scene {
        WindowGroup {
            #if targetEnvironment(macCatalyst)
            MacTabKeySuppressingHost {
                ContentView(selectedTab: $selectedTab)
            }
            #else
            ContentView(selectedTab: $selectedTab)
            #endif
        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1120, height: 760)
        .windowResizability(.automatic)
        .commands {
            SidebarCommands()
            CommandGroup(after: .sidebar) {
                Divider()
                ForEach(Array(RootTab.allCases.enumerated()), id: \.element) { index, tab in
                    Button(tab.titleKey) {
                        selectedTab = tab
                    }
                    .keyboardShortcut(
                        KeyEquivalent(Character(String(index + 1))),
                        modifiers: .command
                    )
                }
            }
        }
        #endif
    }
}

#if targetEnvironment(macCatalyst)
/// Mac Catalyst automatically builds a Tab loop from UIKit focus groups (sidebar, detail
/// navigation stack, toolbar, and so on). SwiftUI's per-view `focusable(false)` and
/// `focusEffectDisabled()` do not remove those container-level groups, so decorative group labels
/// can still receive a focus halo. The app does not use Tab navigation, so consume bare Tab and
/// Shift-Tab at the root responder while preserving normal Tab behavior during text entry.
private struct MacTabKeySuppressingHost<Content: View>: UIViewControllerRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> MacTabKeySuppressingViewController {
        MacTabKeySuppressingViewController(rootView: AnyView(content))
    }

    func updateUIViewController(
        _ uiViewController: MacTabKeySuppressingViewController,
        context: Context
    ) {
        uiViewController.update(rootView: AnyView(content))
    }
}

private final class MacTabKeySuppressingViewController: UIViewController {
    private let hostingController: UIHostingController<AnyView>

    init(rootView: AnyView) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    override var keyCommands: [UIKeyCommand]? {
        let tab = UIKeyCommand(
            input: "\t",
            modifierFlags: [],
            action: #selector(suppressTabKey)
        )
        tab.wantsPriorityOverSystemBehavior = true

        let reverseTab = UIKeyCommand(
            input: "\t",
            modifierFlags: [.shift],
            action: #selector(suppressTabKey)
        )
        reverseTab.wantsPriorityOverSystemBehavior = true

        return [tab, reverseTab]
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(suppressTabKey) {
            return containsTextInputFirstResponder(in: view) == false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    func update(rootView: AnyView) {
        hostingController.rootView = rootView
    }

    @objc private func suppressTabKey() {}

    private func containsTextInputFirstResponder(in view: UIView) -> Bool {
        if view.isFirstResponder, view is UITextInput {
            return true
        }
        return view.subviews.contains(where: containsTextInputFirstResponder)
    }
}
#endif
