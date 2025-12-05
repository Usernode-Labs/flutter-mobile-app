This guide is designed to provide an LLM (such as generic coding agents, GitHub Copilot, or a custom agent) with the context and instructions necessary to successfully navigate, build, and run the mobile application described in the transcript.

---

# 🚀 Zero-to-Build (Android on macOS + Pixel_9a emulator)

1. **Prereqs**
    - Tool versions (match README prerequisites): Flutter 3.35.7 (bundled Dart), Rust stable 1.70+, JDK 17, Android NDK 25.2+ (current path below uses 26.1), Xcode for iOS (optional here).
    - Set NDK path (add to shell profile):  
      `export ANDROID_NDK_HOME=/Users/lukasimrich/Library/Android/sdk/ndk/26.1.10909125`
    - Get Flutter deps: `flutter pub get`
    - Confirm tools and Android targets: `flutter doctor -v` and `rustup target add aarch64-linux-android`
    - Repo layout: `../flutter-mobile-app` and `../usernode` as siblings.
    - Update `../usernode` to `main` and pull latest (mobile expects that).
2. **Install FRB codegen matching usernode’s pinned rev**
    ```bash
    cd ../usernode
    FRB_REV=$(grep -m1 'flutter_rust_bridge =' crates/usernode/Cargo.toml | sed -E 's/.*rev = \"([^\"]+)\".*/\1/')
    cargo install flutter_rust_bridge_codegen \
      --git https://github.com/Usernode-Labs/flutter_rust_bridge \
      --rev "$FRB_REV" \
      --force
    cd -  # back to flutter-mobile-app
    ```
3. **Generate FRB bindings (only if Rust API changed)**
    ```bash
    flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml
    ```
    Outputs land in `lib/src/rust/**` and are git-ignored.
4. **Start the Pixel 9a emulator**
    ```bash
    nohup /Users/lukasimrich/Library/Android/sdk/emulator/emulator \
      -avd Pixel_9a -netdelay none -netspeed full >/tmp/emulator.log 2>&1 &
    /Users/lukasimrich/Library/Android/sdk/platform-tools/adb wait-for-device
    ```
    AVD files live in `~/.android/avd` and stay local (nothing to commit).
5. **Run the app (internal flavor)**
    ```bash
    ANDROID_NDK_HOME=/Users/lukasimrich/Library/Android/sdk/ndk/26.1.10909125 \
    flutter run -d emulator-5554 --flavor internal
    ```
6. **(Optional) Pre-fetch barretenberg prebuilt to avoid flaky downloads**
    ```bash
    mkdir -p ../usernode/target/bb-prebuilt/bb-v1.1.9/aarch64-linux-android
    curl -L --retry 5 --retry-delay 2 --continue-at - \
      -o ../usernode/target/bb-prebuilt/bb-v1.1.9/aarch64-linux-android/barretenberg-bb-v1.1.9-aarch64-linux-android.tar.gz \
      https://github.com/Usernode-Labs/aztec-packages/releases/download/bb-v1.1.9/barretenberg-bb-v1.1.9-aarch64-linux-android.tar.gz
    ```

# 📱 Mobile App & Embedded Node: LLM Developer Guide

## 1\. Project Overview & Architecture

-   **Type:** Mobile application (Android & iOS) with an embedded blockchain node.
-   **Core Stack:**
    -   **Frontend:** Flutter (Dart).
    -   **Backend/Node:** Rust (compiled as a static library, e.g., `lib cryptomo app.a`).
    -   **Bridge:** Flutter Rust Bridge (FRB) connects Dart UI to Rust logic.
-   **Architecture Pattern:** Feature-based structure in `lib`.
    -   **Navigation:** `go_router`.
    -   **State Management:** `riverpod`.
-   **Initialization:** App entry point is `/lib/main.dart`. It calls `RestBackendService instance init` to start the embedded node.

## 2\. Environment Setup (Mac OS Focus)

The LLM should verify the following environment prerequisites before attempting builds:

### Required Tools

-   **Flutter SDK** (includes Dart SDK).
-   **Rust Toolchain**.
-   **Java Development Kit (JDK):** Required for Android builds.
-   **Xcode:** Required for iOS builds.
-   **VS Code:** Recommended IDE (requires Flutter/Dart extensions).

### Directory Structure

**Critical:** The repositories must be cloned to the same directory level on the local machine for relative paths to resolve correctly.

```text
/workspace
  ├── fl_mobile_app       # The Flutter application
  └── user_node           # The Rust node repository
```

### Configuration Files

-   **Dependencies:** Defined in `pipscyl`.
-   **Local Env:** Copy `.example` to create local configuration files (do not commit these).
-   **CI/CD variables:** Managed via GitHub Secrets (mapped to build args in CI).

## 3\. The Build Process

The build chain is integrated. Running Flutter triggers the Rust build automatically.

### Step 1: Install Dependencies

1.  Run `flutter doctor -v` to confirm SDKs and pathing.
2.  **Troubleshooting Tip:** If `cargo build` fails on Mac regarding libraries, ensure Xcode is pointing to the correct development libraries.

### Step 2: Flutter Rust Bridge (FRB) Setup

-   **Version:** Do not use the standard generic FRB. You must install the **modified version** from the project's specific repository to ensure compatibility.
-   **Generating Bindings:**
    -   **Command:** `flutter rust bridge code generate` (run inside the mobile app directory).
    -   **Trigger:** Only run this when the Rust node exposes new functions or types.
    -   **Process:** Scans the `user node` crate -\> generates Dart bindings -\> links types.

### Step 3: Execution

-   **Command:** `flutter run`
    -   **Behavior:** This compiles the Rust node, links it, builds the Flutter app, and deploys to the selected device/simulator.
-   **Debugging:** Use VS Code "Run/Debug". Supports visual debugging (clicking UI highlights code).

## 4\. Key Implementation Details

### Metrics & Background Services

-   **Metrics Service:** Client (mobile) sends data to `topo chain` backend (PostgreSQL/Redis).
    -   **Frequency:** Defaults to 5 seconds (configurable).
    -   **Data:** Battery, network topology, node metrics, permissions.
-   **Background Execution:**
    -   **Android:** Uses "Exact Alarm" permission to check block slot timings (Note: High friction for App Store approval).
    -   **Wake Lock:** Prevents CPU throttling.
    -   **Foreground Service:** Android only.
    -   **Notifications:** Used to keep the app alive; status refreshes every 3 seconds.

### Internationalization (i18n)

-   Translation files define labels.
-   Default: English.
-   Naming convention: `app_RB` (e.g., for Spanish).

## 5\. Deployment & CI/CD

-   **Platform:** GitHub Actions.
-   **Workflow:**
    1.  Feature branch -\> PR to `develop`.
    2.  **PR Event:** Triggers syntax checks, linting, and tests.
    3.  **Merge to Develop:** Triggers `build and deploy` workflow.
        -   Builds Android/iOS binaries.
        -   Publishes to Google Play (Internal/Alpha/Beta) and TestFlight.
        -   Tags the `develop` branch.
-   **Secrets:** All environment variables for release are stored in GitHub Secrets.

## 6\. LLM Self-Correction & "Agents" Mode

-   **Context File:** Look for `agents.md` in the project root. This file contains specific specifications for LLMs (Codex/Claude) to understand the project constraints.
-   **Safety:** When using Claude or advanced agents, use "Planning Mode" (`shift tab` in some interfaces) to prevent the LLM from modifying code files unexpectedly during Q\&A.

---

FULL TRANSCRIPT

Salah Nait Mouloud gave Lukas Imrich and Evan Shapiro a comprehensive project overview, covering the project and code structure, the use of Flutter and Rust with the Flutter Rust Bridge for bindings, environment setup for Mac OS, and the CI/CD workflow via GitHub actions for building and releasing the mobile application. Discussions with Lukas Imrich focused on the metrics service architecture, documentation, and the intricacies of background block production strategies, including concerns about App Store approval for the "exact alarm" permission used on Android. Salah Nait Mouloud also shared their methods for leveraging Large Language Models for development, and Evan Shapiro confirmed fixing an issue during the `cargo build` step related to Xcode development libraries.
Details
Notes Length: Standard
Initial Check-in and Status Update Salah Nait Mouloud and Lukas Imrich began the meeting, with Lukas Imrich mentioning that their days were currently "boring" due to a lack of activity. Salah Nait Mouloud informed Lukas Imrich that they would be starting as a mobile developer in the next hour and planned to show them how to obtain information using code, without relying on others (00:00:00). Evan Shapiro joined the meeting, and confirmed they liked the last apartment they viewed (00:01:22).
Personal Update on Child's Tooth Injury Salah Nait Mouloud apologized for not answering a previous question from Lukas Imrich and provided an update on their child's broken tooth. Salah Nait Mouloud explained that half of the tooth was still inside, and they were concerned about infection, but the child was not currently experiencing pain. They mentioned having a dentist appointment scheduled for the following day at 5:00 p.m (00:02:37).
Meeting Agenda and Project Overview Salah Nait Mouloud presented the meeting agenda, which included understanding the project structure, framework usage, application interaction with the embedded mobile node, and generation of bindings. Other topics included internationalization, environment setup, testing procedures on devices and simulators, CI workflow via GitHub actions, the metric service for tracking background production, and the use of Large Language Models (LLM) for self-service (00:04:28). Salah Nait Mouloud expressed the belief that the best way to learn is by doing, suggesting the identification of two or three tasks (00:05:59).
Project Structure and GitHub Workflow Salah Nait Mouloud provided a high-level overview of the project structure, noting the main branches are `develop` and `main`. They explained that new features should be worked on in a new branch, followed by a pull request to `develop` (00:07:11). GitHub actions, defined in GitHub workflows, are triggered by events like pull requests to check syntax, linting, and run tests (00:08:18).
Flutter and Environment Specifics The Flutter framework supports multiple environments, including Android, iOS, Linux, Mac OS, web, and Windows, although the application is currently only tested on Android and iOS. Salah Nait Mouloud noted that even with Flutter, manual configurations are sometimes necessary for specific Operating Systems (OS), such as managing permissions in the `Android.xml` manifest for Android (00:09:27). Key folders include `assets` for static content, `docs`, `fastlane` for iOS signing and publishing, `scripts`, and `test` (00:10:37).
Code Structure and Dependencies The `rust builder` tool is used to create bindings between Flutter and the Rust component. The main repository for code is the `lib` repository, structured in a feature-based way (00:11:56). Configuration files include `.example` for local variables, which should not be committed, and `pipscyl` for defining project dependencies (00:13:13). Translation files, such as the initial English one, define labels and translations, and new languages require creating corresponding files (e.g., `app_RB` for Spanish) (00:14:26) (00:17:05).
Flutter Framework and Node Connection Flutter, maintained by Google, uses the programming language Dart and abstracts away the complexity of iOS and Android development. The application entry point is `/lib/main.dart`, where initialization and the call to `RestBackendService instance init` occur, starting the node (00:19:56). The node is compiled as a library (e.g., `lib cryptomo app.a`) and embedded into the Flutter application (00:21:14). Other exposed functions, like `get status` or `get meool`, are called via the `rust backend service instance` (00:22:49).
Flutter Rust Bridge (FRB) and Bindings Salah Nait Mouloud explained the role of the Flutter Rust Bridge (FRB) in connecting the Flutter UI (Dart) and the Rust backend (user node). The FRB scans the functions exposed by the Rust node and generates the equivalent Dart bindings, creating a bridge between the app and Rust (00:25:41). The user node crate is scanned by the FRB to detect types and functions to be consumed by the mobile application, and any binding changes on the user node require corresponding updates in the mobile app (00:28:18).
Application Setup and Navigation The current navigation flow involves starting at the splash screen, moving to onboarding, and then to the main screen (00:30:57). The app uses `go router` to define routes, such as `/splash`. For state management, the application utilizes `river pod` (00:32:04).
Environment Setup for Development Salah Nait Mouloud outlined the necessary environment setup steps for Evan Shapiro on Mac OS, which include installing the Flutter SDK (which includes the Dart SDK), the Rust toolchain, and the Java Development Kit (JDK) for Android development. It is also necessary to install the Flutter Rust Bridge code generation tool (00:33:10). Both the `fl mobile app` and `user node` repositories must be cloned to the same level on the local laptop (00:34:26).
Troubleshooting the Cargo Build Step Evan Shapiro mentioned encountering a failure during the `cargo build` step but subsequently found a fix, which involved ensuring their Xcode was pointing to the correct development libraries, and the build then finished (00:34:26). Salah Nait Mouloud suggested Evan Shapiro execute `flutter doctor -v` to confirm the environment is correctly set up after installing the Flutter and Dart SDK (00:37:46).
Installing FRB and Generating Bindings Salah Nait Mouloud provided the command to install their modified version of the Flutter Rust Bridge (FRB) from their repository, which was done to ensure full compatibility with their environment (00:39:09). They explained that the `flutter rust bridge code generate` command, executed inside the mobile app directory, scans the user node crate and generates the bindings, which only needs to be run when there is a binding change on the user node (00:40:17).
Building and Running the Project To build the project, running `flutter run` will build the entire chain, including the user node, behind the scenes (00:43:45). Salah Nait Mouloud demonstrated that `flutter run` scans for connected devices and simulators, allowing the developer to select a target device to build and run the application (00:44:48). They also showed how to run the app from Visual Studio Code using the run/debug section, which enables visual debugging where clicking on an app component highlights the corresponding code (00:48:47).
Testing with Simulators and CI/CD Workflow To test on iOS simulators, a developer can access the simulator via Xcode's "Open Developer Tool" menu. For Android simulators, Android Studio is required (00:52:31). Salah Nait Mouloud detailed the Continuous Integration (CI) process using GitHub actions, which are triggered by creating a pull request (00:54:09). Merging a pull request to `develop` triggers the `build and deploy` action, which sets up environments, builds the Android and iOS apps, and publishes the builds to Google Play and TestFlight, then tags the `develop` branch (00:55:23).
Mobile Application Release Process Salah Nait Mouloud reviewed the release process for the mobile application, noting that 95% of the process is handled by GitHub actions, with the remaining few steps requiring manual intervention. They explained the current internal testing group in TestFlight, which includes the `user node labs team`, and stated that a new group would need to be created for alpha testing, mirroring the structure in Google Play which offers internal, closed (alpha), and open (beta) testing (00:59:46). Salah Nait Mouloud invited Lukas Imrich to lead this process with them supervising to master the release flow (01:01:01).
Metrics Service Architecture and Implementation Salah Nait Mouloud detailed the metrics service, which consists of a client within the mobile application and a server/API. The client code is responsible for sending metrics to the server, and the service is initiated within `lib/main` of the application (01:02:06). The metrics are sent to the backend, which is implemented in a repository called `topo chain` and uses a PostgreSQL database and Redis for caching, managed by Docker (01:04:53).
Metrics Service Configuration and Data The metric service typically executes at a frequency of 5 seconds, though this interval can be configured in a configuration file (01:03:26). Salah Nait Mouloud mentioned that the metrics being sent were currently failing and needed checking for network connectivity issues (01:02:06). The collected information, including network topology, nodes, and node metrics, is displayed on the server side. An example of the full range of metrics the client can send, such as battery, network, permissions, and foreground service data, is available under `docs/metrics/full-example` (01:03:26).
Documentation and Clarity for Metrics Salah Nait Mouloud discussed efforts to clarify confusing metrics, particularly those related to battery, power, and permissions, due to naming differences and feature availability between Android and iOS. They implemented tooltips on the display that explain what a metric is, what it means for Android, and what it means for iOS, including stating "not applicable" if necessary (01:06:39). They also added a table detailing what each metric means and its availability on both iOS and Android (01:10:27).
Utilizing Large Language Models (LLMs) for Development Salah Nait Mouloud shared their method for using LLMs in development, recommending the use of an `agents.md` file in the project root for specifications, which they noted works for Codex and Code (01:10:27). They also highlighted the command-line clients for ChatGPT (Codex) and Claude, which allow for interactive mode within the project to ask questions about code structure or project functionality. Salah Nait Mouloud cautioned that some LLMs might modify project files when asked a question, suggesting the use of Claude's "planning mode" (accessible via `shift tab`) to prevent unintended code changes (01:11:53).
Deployment Notifications and Resource Tracking Salah Nait Mouloud mentioned the existing deployment channel on Discord for new build notifications and announced plans to add a direct link to Google Play in those notifications for easier access (01:14:48). They also addressed resource tracking, noting that monitoring resource usage like memory, CPU, and frame speed is possible within development environments like VS Code and Xcode, which can highlight resource-intensive parts of the application (01:18:18).
Resource Collection using Metrics Collector Salah Nait Mouloud distinguished two ways of monitoring resources: development environment tools and collecting data directly from the device via the metrics collector and sending it to `topo chain` (01:20:03). They confirmed that battery collection is already implemented, including battery level and state (charging or not) (01:21:06). However, they have not yet implemented collection for other resource usage metrics due to the collection process consuming device resources, and they plan to seek assistance from the team on this (01:20:03).
Background Block Production and Permissions Salah Nait Mouloud updated the background block production page to be more explanatory, including adding a 3-second refresh for permissions and the foreground keep-alive status, ensuring system settings changes are reflected in the app interface (01:23:32). They clarified specific metrics displayed, such as "power save" being calculated if the battery is below 20% and the "exact alarm" used on Android for background processes to check block slot timings (01:25:00). Salah Nait Mouloud clarified that the "exact alarm" mechanism currently checks the status but is intended to eventually initiate fast sync, block production, and then stop the node (01:26:24).
Wake Lock and Foreground Service Salah Nait Mouloud discussed the functionality of the `wake lock`, which is understood to prevent the phone from restricting CPU usage for the application, and its relation to the `keep live` feature. They also noted that the `foreground service` is only applicable to Android (01:27:44). Regarding the `notification permission` and `notification enabled` states, Salah Nait Mouloud agreed with Lukas Imrich that the duplication is confusing and they will likely remove one of the metrics, as they are currently tracking system-level notification state and application-level notification state, both of which are now refreshed every 3 seconds (01:28:56) (01:31:44).
Background Block Production Strategy Salah Nait Mouloud explained that the foreground service implementation for Android is designed to check the node status at a given slot, which aligns with the future goal of fast syncing and block production. They mentioned adding an option to keep the app in the foreground continuously as a separate workstream (01:32:45). Lukas Imrich suggested adding a strategy selector to compare different background execution methods, but Salah Nait Mouloud cautioned that the alternative, `alarm manager`, is unreliable, potentially leading to significant delays (01:33:54). They advised Lukas Imrich to test the current implementation and share immediate feedback (01:35:07).
App Store Approval Concerns for Exact Alarm Permissions Lukas Imrich raised a concern about the required "exact alarm" permissions, suggesting that App Store approval might require the app to be classified as a calendar or alarm clock application. Salah Nait Mouloud acknowledged this as a valid concern that could lead to friction and potential delays of weeks during the submission process to Google Play and the App Store (01:35:07). Lukas Imrich noted that for the current test net environment, and given the possibility of enabling side-loading later, they can continue with the current path (01:36:31).
Managing Variables in GitHub Actions Salah Nait Mouloud highlighted the use of GitHub Secrets to manage variables for environment configuration files, specifically mentioning steps in the Android and iOS builds that retrieve variables from GitHub Secrets (01:37:48). They stressed that any future changes to these variables should be managed within the repository's "Secrets and variables" section under "actions" (01:37:48).
Suggested next steps
Salah Nait Mouloud will provide a few pieces of advice to Lukas Imrich regarding LLM usage to help him not rely on the group for answers.
Salah Nait Mouloud will ping Evan Shapiro later regarding the necessary extensions for Visual Studio.
Salah Nait Mouloud will share a configuration file that Evan Shapiro has to put in Visual Studio for the run or debug section.
Salah Nait Mouloud will share the command line in Discord for installing the flutter rest bridge from the repository and generating the bindings.
Salah Nait Mouloud will identify two to three tasks that the group can do for the scope of the testnet.
Salah Nait Mouloud will add the link to the Google Play store directly to the new build notification in Discord's deployment channel.
Salah Nait Mouloud will check if someone in the team is available to implement the resource collection for the mobile app.
Salah Nait Mouloud will fix the incorrect reporting of the balance.
Salah Nait Mouloud will update the notification display by removing one of the two identical notification status colors and keeping only the 'notification' status.
Salah Nait Mouloud will align what will be next after Evan finishes the current task.
The group will test the current build and share immediate feedback whenever issues are encountered.
You should review Gemini's notes to make sure they're accurate. Get tips and learn how Gemini takes notes
Please provide feedback about using Gemini to take notes in a short survey.
