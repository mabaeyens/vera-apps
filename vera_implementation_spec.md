# 🛠️ Project Vera: Technical Implementation Specification

## 📌 1. Project Identity & Vision

* **Name:** Vera (part of the *Mira* ecosystem).
* **Core Concept:** A "Reading-First" Markdown viewer and editor for the Apple ecosystem (iOS/mac macOS).
* **Philosophy:** **Zero Configuration.** No "Vaults," no "Projects." Vera is a transparent window into the user's **iCloud Drive**.
* **Target User:** Users who want to browse and edit their existing `.md` files without the overhead of database-driven apps (like Obsidian).

---

## 🏗️ 2. Technical Architecture

### 📂 A. The iCloud Scanner (Data Layer)

The app must implement a recursive file system crawler.

* **Scope:** `FileManager` scanning the user's iCloud Container.
* **Strict Filter:** Only index files with the `.md` extension. Ignore all others (`.txt`, `.pdf`, etc.).
* **Hierarchy:** Must preserve the folder tree. The UI must support expandable/collapsible nodes.
* **Identity:** Handle duplicate filenames (e.g., `backlog.md`) by using their unique relative paths from the iCloud root.
* **Cloud-Awareness:**
  * Check `ubiquitousItemDownloadingStatusKey`.
  * If a file is "Cloud-only," display a "Download" icon.
  * On selection, trigger `FileManager.startDownloadingUbiquitousItem(at:)`.

### 🧠 B. The Interaction Engine (The "Smart" Core)

The app operates in two mutually exclusive states: `ViewingMode` and `EditingMode`.

#### **State 1: ViewingMode (Default)**

* **UI:** High-fidelity Markdown rendering (using `AttributedString`).
* **Interaction:**
  * `Single Tap`: Select/Focus a specific block (paragraph, header, list item).
  * `Double Tap` or `Edit Button`: Triggers the transition to `EditingMode`.

#### **State 2: EditingMode (On-Demand)**

* **UI:** A `TextEditor` or `UITextView` displaying raw Markdown.
* **The "Smart Anchor" Logic (Critical):**
  * **Requirement:** When transitioning from `ViewingMode` $\to$ `EditingMode`, the app must perform a **Coordinate-to-Offset Mapping**.
  * **Algorithm:**
        1. Capture the `CGPoint` of the user's tap in the rendered view.
        2. Map that point to the specific character index (offset) in the underlying raw string.
        3. Programmatically scroll the `TextEditor` to that line and place the cursor (`selectedRange`) at that exact offset.
  * **UX Goal:** The user should feel they are "entering" the text they just tapped.

### 🗺️ C. The Atlas (The Interactive Cheat Sheet)

A retractable drawer containing an interactive Markdown toolkit.

* **Mechanism: "Tap-to-Insert"**.
* **Logic:** Selecting a syntax element (e.g., `**`) must inject the syntax into the `EditingMode` buffer and automatically place the cursor between the delimiters (e.g., `****|`).
* **Categories:**
  * *Basics* (Headers, Bold, Italic, Lists).
  * *Structure* (Blockquotes, Code blocks, Task lists).
  * *Media* (Links, Image syntax, Footnotes).
  * *Advanced* (Table templates, LaTeX/Math triggers).

### 👁️ D. The Preview (Real-time Rendering)

* **Split-View (macOS/iPadOS):** `NavigationSplitView` (Sidebar: File Tree | Center: Editor/Viewer | Right: Atlas/Preview).
* **Overlay/Layer (iOS):** A toggleable layer or sheet to preview the rendered output.

---

## 🎨 3. UI/UX Specifications

* **Platform:** SwiftUI (Multiplatform).
* **Layout (macOS/iPadOS):** `NavigationSplitView` (Sidebar: File Tree | Center: Editor/Viewer | Right: Atlas/Preview).
* **Layout (iOS):** Stacked navigation. (File List $\to$ Document View $\to$ Bottom Sheet for Atlas).
* **Design Language:** Minimalist, "Zen" mode. High whitespace, typography-focused, no unnecessary buttons.

---

## 🚀 4. Implementation Roadmap (Phase-by-Phase)

### **Phase 1: The Foundation (File Access)**

1. Set up a Multiplatform SwiftUI project.
2. Implement `FileManager` recursive scanner for `.md` files in iCloud.
3. Build the Sidebar with expandable folder/file hierarchy.
4. Implement the "Cloud-to-Local" download trigger.

### **Phase 2: The Viewing/Editing Engine**

1. Implement `ViewingMode` using `AttributedString` for Markdown.
2. Implement `EditingMode` using `TextEditor`.
3. **Develop the Coordinate Mapping algorithm** (The "Smart Anchor" logic).
4. Implement the transition logic (Double-tap to edit, Button to return to view).

### **Phase 3: The Atlas & Polish**

1. Build the "Atlas" Drawer.
2. Implement the "Tap-to-Insert" logic for all syntax elements.
3. Add syntax highlighting for the `EditingMode`.
4.*Final Polish:* Auto-save implementation and UI/UX refinement.
