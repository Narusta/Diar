import SwiftUI

struct JournalEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var manager: DataManager
    
    @State private var journalTitle: String = ""
    @State private var journalText: String = ""
    @State private var selectedFont: UIFont = .systemFont(ofSize: 16)
    @State private var isBold = false
    @State private var isItalic = false
    @State private var isStrikethrough = false
    @State private var isMonospace = false
    @State private var selectedColor: Color = .black
    @State private var selectedBackground: BackgroundTheme = .dark
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isShowingMoodPicker = false
    @State private var selectedMood: MoodOption?
    @State private var currentDate = Date()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingFormatMenu = false
    @State private var showingFormattingToolbar = false
    @State private var isShowingDrawing = false
    @State private var isShowingBackgroundPicker = false
    @State private var lines: [DrawingLine] = []
    @State private var textAlignment: NSTextAlignment = .left
    @State private var isStarred: Bool = false
    @State private var showExportMenu = false
    @State private var selectedEntry: JournalEntry?
    
    // Tool States
    @State private var activeToolbar: ToolbarType = .none
    @State private var isDrawing = false
    @State private var currentDrawingLine = DrawingLine(points: [], color: .black, width: 2)
    @State private var drawingLines: [DrawingLine] = []
    @State private var selectedTool: DrawingTool = .pen
    @State private var strokeWidth: CGFloat = 2
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, yyyy"
        return formatter
    }()
    
    init(entry: JournalEntry? = nil) {
        if let entry = entry {
            _selectedEntry = State(initialValue: entry)
            _journalText = State(initialValue: entry.text ?? "")
            if let date = entry.date {
                _currentDate = State(initialValue: date)
            }
        }
        // Initialize with empty text, will be updated in onAppear
        _journalText = State(initialValue: "")
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                GeometryReader { geometry in
                    ZStack {
                        if let imageName = selectedBackground.imageName {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .ignoresSafeArea()
                        } else {
                            Color(colorScheme == .dark ? .black : .systemBackground)
                                .ignoresSafeArea()
                        }
                    }
                }
                
                VStack {
                    // Navigation Bar
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
                                .imageScale(.large)
                        }
                        
                        Spacer()
                        
                        Text(dateFormatter.string(from: currentDate))
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: saveJournal) {
                            Text("Save")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        // Add Export Button
                        Button(action: {
                            showExportMenu = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                                .imageScale(.large)
                        }
                        .actionSheet(isPresented: $showExportMenu) {
                            ActionSheet(
                                title: Text("Export Options"),
                                message: Text("Choose how to share your journal entry"),
                                buttons: [
                                    .default(Text("Print")) {
                                        let formatting = JournalFormatting(
                                            fontSize: selectedFont.pointSize,
                                            isBold: isBold,
                                            isItalic: isItalic,
                                            isStrikethrough: isStrikethrough,
                                            isMonospace: isMonospace,
                                            textColor: selectedColor.toUIColor(),
                                            textAlignment: textAlignment
                                        )
                                        if let pdfData = manager.exportEntry(
                                            selectedEntry ?? createTemporaryEntry(),
                                            withBackground: selectedBackground,
                                            formatting: formatting
                                        ) {
                                            let printController = UIPrintInteractionController.shared
                                            let printInfo = UIPrintInfo(dictionary: nil)
                                            printInfo.jobName = "Journal Entry"
                                            printInfo.outputType = .general
                                            printController.printInfo = printInfo
                                            printController.printingItem = pdfData
                                            printController.present(animated: true)
                                        }
                                    },
                                    .default(Text("Share")) {
                                        let formatting = JournalFormatting(
                                            fontSize: selectedFont.pointSize,
                                            isBold: isBold,
                                            isItalic: isItalic,
                                            isStrikethrough: isStrikethrough,
                                            isMonospace: isMonospace,
                                            textColor: selectedColor.toUIColor(),
                                            textAlignment: textAlignment
                                        )
                                        let rootView = UIView()
                                        manager.shareEntry(
                                            selectedEntry ?? createTemporaryEntry(),
                                            withBackground: selectedBackground,
                                            formatting: formatting,
                                            from: rootView
                                        )
                                    },
                                    .cancel()
                                ]
                            )
                        }
                    }
                    .padding()
                    
                    // Main Content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Title Field
                            TextField("Title", text: $journalTitle)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            // Text Editor
                            CustomTextEditor(
                                text: $journalText,
                                font: selectedFont,
                                textColor: colorScheme == .dark ? .white : .black,
                                backgroundColor: .clear,
                                textAlignment: textAlignment
                            )
                            .frame(maxWidth: .infinity, minHeight: geometry.size.height * 0.6)
                            .padding(.horizontal)
                            
                            // Selected Image
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    selectedImage = nil
                                }) {
                                    Text("Remove Image")
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
                                        .cornerRadius(8)
                                }
                                .padding(.top, 8)
                            }
                            
                            Spacer()
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Bottom Toolbar
                    VStack(spacing: 0) {
                        if showingFormattingToolbar {
                            formattingToolbar
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        }
                        
                        HStack(spacing: 25) {
                            Button(action: {
                                isShowingBackgroundPicker = true
                            }) {
                                Image(systemName: "square.fill.text.grid.1x2")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Image(systemName: "photo")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            
                            // Star button
                            Button(action: {
                                isStarred.toggle()
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }) {
                                Image(systemName: isStarred ? "star.fill" : "star")
                                    .foregroundColor(isStarred ? .yellow : Color("LightColor"))
                                    .imageScale(.large)
                            }
                            
                            Button(action: {
                                isShowingMoodPicker = true
                            }) {
                                if let mood = selectedMood {
                                    mood.displayIcon
                                } else {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    showingFormattingToolbar.toggle()
                                }
                            }) {
                                Image(systemName: "textformat")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                // List action
                            }) {
                                Image(systemName: "list.star")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 30)
                        .padding(.vertical)
                        .background(Color(red: 0.1, green: 0.12, blue: 0.25))
                        .cornerRadius(15)
                        .shadow(radius: 3)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Alert"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $isShowingMoodPicker) {
                MoodSelectorView(selectedMood: $selectedMood, isPresented: $isShowingMoodPicker)
            }
            .sheet(isPresented: $isShowingDrawing) {
                DrawingView(isPresented: $isShowingDrawing)
            }
            .sheet(isPresented: $isShowingBackgroundPicker) {
                BackgroundPickerView(selectedBackground: $selectedBackground, isPresented: $isShowingBackgroundPicker)
            }
        }
        .onAppear {
            if selectedEntry == nil {
                journalText = manager.newEntryText
                
                // Extract title if present
                if !journalText.isEmpty {
                    if let titleRange = journalText.range(of: "✨ "),
                       let titleEndRange = journalText.range(of: " ✨", range: titleRange.upperBound..<journalText.endIndex) {
                        let titleStart = journalText.index(titleRange.upperBound, offsetBy: 0)
                        let titleEnd = titleEndRange.lowerBound
                        journalTitle = String(journalText[titleStart..<titleEnd])
                    }
                }
                
                // Clear manager text after using
                manager.newEntryText = ""
            }
        }
    }
    
    private var formattingToolbar: some View {
        HStack(spacing: 20) {
            Button(action: {
                isBold.toggle()
                updateFont()
            }) {
                Image(systemName: "bold")
                    .font(.system(size: 16))
                    .foregroundColor(isBold ? .accentColor : .primary)
            }
            
            Button(action: {
                isItalic.toggle()
                updateFont()
            }) {
                Image(systemName: "italic")
                    .font(.system(size: 16))
                    .foregroundColor(isItalic ? .accentColor : .primary)
            }
            
            Button(action: {
                isStrikethrough.toggle()
                updateFont()
            }) {
                Image(systemName: "strikethrough")
                    .font(.system(size: 16))
                    .foregroundColor(isStrikethrough ? .accentColor : .primary)
            }
            
            Button(action: {
                isMonospace.toggle()
                updateFont()
            }) {
                Text("AA")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isMonospace ? .accentColor : .primary)
            }
            
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
                .frame(width: 25)
            
            Divider()
                .frame(height: 20)
                .background(Color.primary.opacity(0.2))
            
            Menu {
                Button(action: { textAlignment = .left }) {
                    HStack {
                        Image(systemName: "text.alignleft")
                        Text("Left")
                    }
                }
                Button(action: { textAlignment = .center }) {
                    HStack {
                        Image(systemName: "text.aligncenter")
                        Text("Center")
                    }
                }
                Button(action: { textAlignment = .right }) {
                    HStack {
                        Image(systemName: "text.alignright")
                        Text("Right")
                    }
                }
                Button(action: { textAlignment = .justified }) {
                    HStack {
                        Image(systemName: "text.justify")
                        Text("Justified")
                    }
                }
            } label: {
                Image(systemName: getAlignmentIcon())
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                addBulletPoint()
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                addNumberedList()
            }) {
                Image(systemName: "list.number")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 4)
    }
    
    private func saveJournal() {
        guard !journalTitle.isEmpty else {
            alertMessage = "Please enter a title for your journal entry"
            showAlert = true
            return
        }
        
        // Create the entry using the DataManager's saveEntry function
        var images: [UIImage] = []
        if let selectedImage = selectedImage {
            images.append(selectedImage)
        }
        
        // Create attributed string with title and text
        let titleWithoutHash = journalTitle.hasPrefix("#") ? String(journalTitle.dropFirst()) : journalTitle
        let fullText = """
        \(titleWithoutHash.trimmingCharacters(in: .whitespaces))
        
        \(journalText)
        """
        
        manager.saveEntry(
            text: fullText,
            moodLevel: selectedMood?.level.rawValue ?? 0,  // Use the actual mood level
            moodText: selectedMood?.title ?? "",
            reasons: [],  // No reasons selected in this simple editor
            images: images,
            isStarred: isStarred
        )
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func updateFont() {
        var traits: UIFontDescriptor.SymbolicTraits = []
        
        if isBold {
            traits.insert(.traitBold)
        }
        if isItalic {
            traits.insert(.traitItalic)
        }
        
        if isMonospace {
            selectedFont = .monospacedSystemFont(ofSize: 16, weight: isBold ? .bold : .regular)
        } else {
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                .withSymbolicTraits(traits) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            selectedFont = UIFont(descriptor: descriptor, size: 16)
        }
    }
    
    private func addBulletPoint() {
        guard let textView = UIApplication.shared.windows.first?.rootViewController?.view.subviews.first(where: { $0 is UITextView }) as? UITextView else {
            journalText += "\n• "
            return
        }
        
        let bullet = "\n• "
        let selectedRange = textView.selectedRange
        
        // Get the current typing attributes and text color
        var attributes = textView.typingAttributes
        attributes[.foregroundColor] = UIColor(selectedColor)
        
        // Create attributed string for the bullet
        let bulletAttributedString = NSMutableAttributedString(string: bullet, attributes: attributes)
        
        // Insert the bullet point
        let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        mutableAttributedString.insert(bulletAttributedString, at: selectedRange.location)
        
        // Update text view
        textView.attributedText = mutableAttributedString
        textView.typingAttributes = attributes
        
        // Move cursor to end of bullet
        textView.selectedRange = NSRange(location: selectedRange.location + bullet.count, length: 0)
        
        // Update binding
        journalText = textView.text
    }
    
    private func addNumberedList() {
        guard let textView = UIApplication.shared.windows.first?.rootViewController?.view.subviews.first(where: { $0 is UITextView }) as? UITextView else {
            let lines = journalText.components(separatedBy: .newlines)
            let nextNumber = lines.count + 1
            journalText += "\n\(nextNumber). "
            return
        }
        
        // Count existing numbered items
        var number = 1
        let lines = textView.text.components(separatedBy: .newlines)
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).range(of: "^\\d+\\.", options: .regularExpression) != nil {
                number += 1
            }
        }
        
        let selectedRange = textView.selectedRange
        let numberedItem = "\n\(number). "
        
        // Get the current typing attributes and text color
        var attributes = textView.typingAttributes
        attributes[.foregroundColor] = UIColor(selectedColor)
        
        // Create attributed string for the numbered item
        let numberedAttributedString = NSMutableAttributedString(string: numberedItem, attributes: attributes)
        
        // Insert the numbered item
        let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        mutableAttributedString.insert(numberedAttributedString, at: selectedRange.location)
        
        // Update text view
        textView.attributedText = mutableAttributedString
        textView.typingAttributes = attributes
        
        // Move cursor to end of numbered item
        textView.selectedRange = NSRange(location: selectedRange.location + numberedItem.count, length: 0)
        
        // Update binding
        journalText = textView.text
    }
    
    @ViewBuilder
    var toolbarContent: some View {
        switch activeToolbar {
        case .format:
            FormatToolbar(
                selectedFont: $selectedFont,
                selectedColor: $selectedColor
            )
        case .background:
            BackgroundToolbar(selectedTheme: $selectedBackground)
        case .draw:
            DrawingToolbar(
                isDrawing: $isDrawing,
                selectedTool: $selectedTool,
                strokeWidth: $strokeWidth
            )
        case .emoji:
            EmojiToolbar()
        case .image:
            ImageToolbar(showingImagePicker: $showingImagePicker)
        case .mood:
            Button(action: { isShowingMoodPicker = true }) {
                Text("Select Mood")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        case .none:
            EmptyView()
        }
    }
    
    private func getAlignmentIcon() -> String {
        switch textAlignment {
        case .left:
            return "text.alignleft"
        case .center:
            return "text.aligncenter"
        case .right:
            return "text.alignright"
        case .justified:
            return "text.justify"
        default:
            return "text.alignleft"
        }
    }
    
    // Add helper function to create a temporary entry from current state
    private func createTemporaryEntry() -> JournalEntry {
        let context = manager.container.viewContext
        let entry = JournalEntry(context: context)
        entry.id = UUID().uuidString
        entry.text = journalText
        entry.date = currentDate
        return entry
    }
}

// MARK: - Mood Selector View
struct MoodSelectorView: View {
    @Binding var selectedMood: MoodOption?
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(MoodLevel.allCases) { level in
                    Section(header: Text("Level \(level.rawValue)")) {
                        ForEach(level.moodOptions, id: \.self) { option in
                            Button(action: {
                                selectedMood = MoodOption(title: option, level: level)
                                isPresented = false
                            }) {
                                HStack {
                                    Image(systemName: getMoodIcon(for: option))
                                        .foregroundColor(level.chartColor)
                                        .font(.title2)
                                    Text(option)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedMood?.title == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Select Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func getMoodIcon(for mood: String) -> String {
        switch mood.lowercased() {
        case "angry": return "flame.fill"
        case "anxious": return "tornado"
        case "disgusted": return "hand.thumbsdown.fill"
        case "embarrassed": return "face.smiling"
        case "fearful": return "exclamationmark.triangle.fill"
        case "frustrated": return "exclamationmark.triangle"
        case "annoyed": return "bolt.horizontal.fill"
        case "insecure": return "lock.fill"
        case "jealous": return "eye.fill"
        case "lonely": return "person.fill"
        case "nervous": return "waveform.path.ecg"
        case "sad": return "cloud.rain.fill"
        case "awkward": return "person.fill.questionmark"
        case "bored": return "hourglass"
        case "busy": return "clock.fill"
        case "confused": return "questionmark.circle.fill"
        case "desire": return "heart.fill"
        case "impatient": return "timer"
        case "tired": return "moon.zzz.fill"
        case "appreciated": return "hand.thumbsup.fill"
        case "calm": return "leaf.fill"
        case "curious": return "magnifyingglass"
        case "grateful": return "gift.fill"
        case "inspired": return "lightbulb.fill"
        case "motivated": return "bolt.fill"
        case "satisfied": return "checkmark.seal.fill"
        case "brave": return "shield.fill"
        case "confident": return "person.fill.checkmark"
        case "creative": return "paintbrush.fill"
        case "excited": return "sparkles"
        case "free": return "bird.fill"
        case "happy": return "face.smiling.fill"
        case "love": return "heart.circle.fill"
        case "proud": return "star.fill"
        case "respected": return "crown.fill"
        default: return "questionmark"
        }
    }
}

// MARK: - Mood Option Type
struct MoodOption: Equatable {
    let title: String
    let level: MoodLevel
    
    var displayIcon: some View {
        Image(systemName: getMoodIcon())
            .foregroundColor(level.chartColor)
            .font(.title2)
    }
    
    private func getMoodIcon() -> String {
        switch title.lowercased() {
        case "angry": return "flame.fill"
        case "anxious": return "tornado"
        case "disgusted": return "hand.thumbsdown.fill"
        case "embarrassed": return "face.smiling"
        case "fearful": return "exclamationmark.triangle.fill"
        case "frustrated": return "exclamationmark.triangle"
        case "annoyed": return "bolt.horizontal.fill"
        case "insecure": return "lock.fill"
        case "jealous": return "eye.fill"
        case "lonely": return "person.fill"
        case "nervous": return "waveform.path.ecg"
        case "sad": return "cloud.rain.fill"
        case "awkward": return "person.fill.questionmark"
        case "bored": return "hourglass"
        case "busy": return "clock.fill"
        case "confused": return "questionmark.circle.fill"
        case "desire": return "heart.fill"
        case "impatient": return "timer"
        case "tired": return "moon.zzz.fill"
        case "appreciated": return "hand.thumbsup.fill"
        case "calm": return "leaf.fill"
        case "curious": return "magnifyingglass"
        case "grateful": return "gift.fill"
        case "inspired": return "lightbulb.fill"
        case "motivated": return "bolt.fill"
        case "satisfied": return "checkmark.seal.fill"
        case "brave": return "shield.fill"
        case "confident": return "person.fill.checkmark"
        case "creative": return "paintbrush.fill"
        case "excited": return "sparkles"
        case "free": return "bird.fill"
        case "happy": return "face.smiling.fill"
        case "love": return "heart.circle.fill"
        case "proud": return "star.fill"
        case "respected": return "crown.fill"
        default: return "questionmark"
        }
    }
}

// MARK: - Color Conversion
extension Color {
    func toUIColor() -> UIColor {
        if #available(iOS 14.0, *) {
            return UIColor(self)
        } else {
            let components = self.components()
            return UIColor(red: components.r, green: components.g, blue: components.b, alpha: components.a)
        }
    }
    
    private func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let scanner = Scanner(string: self.description.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        
        let result = scanner.scanHexInt64(&hexNumber)
        if result {
            r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000ff) / 255
        }
        return (r, g, b, a)
    }
}

// Supporting Types
enum ToolbarType: CaseIterable {
    case format, background, draw, emoji, image, mood, none
    
    var icon: String {
        switch self {
        case .format: return "toolbar_text"
        case .background: return "toolbar_background"
        case .draw: return "toolbar_star"
        case .emoji: return "toolbar_mood"
        case .image: return "toolbar_image"
        case .mood: return "toolbar_list"
        case .none: return ""
        }
    }
}

struct DrawingLine: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var width: CGFloat
    
    init(points: [CGPoint], color: Color, width: CGFloat) {
        self.points = points
        self.color = color
        self.width = width
    }
}

enum DrawingTool {
    case pen, marker, eraser
}

enum BackgroundTheme {
    case plain, nature, gradient1, gradient2, dark
    
    var color: Color {
        switch self {
        case .plain: return .white
        case .nature: return .clear
        case .gradient1: return .clear
        case .gradient2: return .clear
        case .dark: return .black
        }
    }
    
    var imageName: String? {
        switch self {
        case .plain: return nil
        case .nature: return "bg_nature"
        case .gradient1: return "bg_mountains"
        case .gradient2: return "bg_abstract"
        case .dark: return nil
        }
    }
}

// Toolbar Components
struct FormatToolbar: View {
    @Binding var selectedFont: UIFont
    @Binding var selectedColor: Color
    
    var body: some View {
        HStack {
            // Font picker
            Menu {
                Button("System Font") { selectedFont = .systemFont(ofSize: 16) }
                Button("Monospace") { selectedFont = .monospacedSystemFont(ofSize: 16, weight: .regular) }
            } label: {
                Image(systemName: "textformat")
            }
            
            // Color picker
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
        }
        .padding(.horizontal)
    }
}

struct BackgroundToolbar: View {
    @Binding var selectedTheme: BackgroundTheme
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach([BackgroundTheme.plain, .nature, .gradient1, .gradient2, .dark], id: \.self) { theme in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.color)
                        .frame(width: 60, height: 60)
                        .onTapGesture {
                            selectedTheme = theme
                        }
                }
            }
            .padding()
        }
    }
}

struct DrawingToolbar: View {
    @Binding var isDrawing: Bool
    @Binding var selectedTool: DrawingTool
    @Binding var strokeWidth: CGFloat
    
    var body: some View {
        HStack {
            Toggle("Draw", isOn: $isDrawing)
            
            Picker("Tool", selection: $selectedTool) {
                Text("Pen").tag(DrawingTool.pen)
                Text("Marker").tag(DrawingTool.marker)
                Text("Eraser").tag(DrawingTool.eraser)
            }
            
            Slider(value: $strokeWidth, in: 1...10)
        }
        .padding()
    }
}

struct EmojiToolbar: View {
    let emojis = ["😊", "😢", "😍", "🎉", "💕", "🌟"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(emojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 30))
                        .padding(8)
                }
            }
            .padding()
        }
    }
}

struct ImageToolbar: View {
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        Button(action: { showingImagePicker = true }) {
            Label("Add Image", systemImage: "photo")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}

// Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let textColor: UIColor
    let backgroundColor: UIColor
    var textAlignment: NSTextAlignment = .left
    let placeholder: String = "Diary Entry"
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.allowsEditingTextAttributes = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.textAlignment = textAlignment
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        if text.isEmpty {
            textView.text = placeholder
            textView.textColor = UIColor.gray.withAlphaComponent(0.6)
        } else {
            textView.text = text
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if the text changed or it's a placeholder
        if text.isEmpty && !uiView.isFirstResponder {
            uiView.text = placeholder
            uiView.textColor = UIColor.gray.withAlphaComponent(0.6)
        } else if uiView.text == placeholder && !text.isEmpty {
            uiView.text = text
            uiView.textColor = textColor
        } else if uiView.text != text && uiView.text != placeholder {
            uiView.text = text
        }
        
        // Update font and color if they changed
        if uiView.font != font {
            uiView.font = font
        }
        if uiView.textColor != textColor && uiView.text != placeholder {
            uiView.textColor = textColor
        }
        
        // Update alignment if it changed
        if uiView.textAlignment != textAlignment {
            uiView.textAlignment = textAlignment
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder, textColor: textColor)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        let placeholder: String
        let textColor: UIColor
        
        init(text: Binding<String>, placeholder: String, textColor: UIColor) {
            self.text = text
            self.placeholder = placeholder
            self.textColor = textColor
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == placeholder {
                textView.text = ""
                textView.textColor = textColor
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = placeholder
                textView.textColor = UIColor.gray.withAlphaComponent(0.6)
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}

extension UIResponder {
    private static weak var _currentFirstResponder: UIResponder?
    
    static func current() -> UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }
    
    @objc private func findFirstResponder(_ sender: Any) {
        UIResponder._currentFirstResponder = self
    }
}

// Drawing View
struct DrawingView: View {
    @Binding var isPresented: Bool
    @State private var currentLine: DrawingLine?
    @State private var lines: [DrawingLine] = []
    @State private var selectedColor: Color = .black
    @State private var lineWidth: CGFloat = 3
    
    var body: some View {
        NavigationView {
            VStack {
                // Using UIKit drawing view for iOS 14 compatibility
                DrawingCanvasRepresentable(lines: $lines, currentLine: $currentLine, selectedColor: selectedColor, lineWidth: lineWidth)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                let point = value.location
                                if currentLine == nil {
                                    currentLine = DrawingLine(points: [point], color: selectedColor, width: lineWidth)
                                } else {
                                    currentLine?.points.append(point)
                                }
                            }
                            .onEnded { _ in
                                if let line = currentLine {
                                    lines.append(line)
                                    currentLine = nil
                                }
                            }
                    )
                
                HStack {
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                    
                    Slider(value: $lineWidth, in: 1...10)
                }
                .padding()
            }
            .navigationTitle("Drawing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct DrawingCanvasRepresentable: UIViewRepresentable {
    @Binding var lines: [DrawingLine]
    @Binding var currentLine: DrawingLine?
    let selectedColor: Color
    let lineWidth: CGFloat
    
    func makeUIView(context: Context) -> DrawingCanvas {
        let canvas = DrawingCanvas()
        canvas.backgroundColor = .clear
        return canvas
    }
    
    func updateUIView(_ uiView: DrawingCanvas, context: Context) {
        uiView.lines = lines
        uiView.currentLine = currentLine
        uiView.setNeedsDisplay()
    }
}

class DrawingCanvas: UIView {
    var lines: [DrawingLine] = []
    var currentLine: DrawingLine?
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Draw completed lines
        for line in lines {
            context.setStrokeColor(UIColor(line.color).cgColor)
            context.setLineWidth(line.width)
            
            for (i, point) in line.points.enumerated() {
                if i == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
            }
            context.strokePath()
        }
        
        // Draw current line
        if let line = currentLine {
            context.setStrokeColor(UIColor(line.color).cgColor)
            context.setLineWidth(line.width)
            
            for (i, point) in line.points.enumerated() {
                if i == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
            }
            context.strokePath()
        }
    }
}

// Background Picker View
struct BackgroundPickerView: View {
    @Binding var selectedBackground: BackgroundTheme
    @Binding var isPresented: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private let sections = [
        (title: "Colors", items: [
            BackgroundItem(name: "White", color: Color.white, theme: .plain),
            BackgroundItem(name: "Light Gray", color: Color(UIColor.systemGray6), theme: .nature),
            BackgroundItem(name: "Cream", color: Color(red: 0.96, green: 0.95, blue: 0.93), theme: .gradient1),
            BackgroundItem(name: "Light Blue", color: Color(red: 0.9, green: 0.95, blue: 1.0), theme: .gradient2),
            BackgroundItem(name: "Black", color: Color.black, theme: .dark)
        ]),
        (title: "Illustrations", items: [
            BackgroundItem(name: "Abstract", imageName: "bg_abstract", theme: .gradient2)
        ])
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sections.indices, id: \.self) { sectionIndex in
                    Section(header: Text(sections[sectionIndex].title)) {
                        let columns = horizontalSizeClass == .regular ? [GridItem(.adaptive(minimum: 150))] : [GridItem(.adaptive(minimum: 100))]
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(sections[sectionIndex].items, id: \.name) { item in
                                BackgroundItemView(item: item, isSelected: selectedBackground == item.theme)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedBackground = item.theme
                                        isPresented = false
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Choose Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct BackgroundItem {
    let name: String
    var color: Color?
    var imageName: String?
    let theme: BackgroundTheme
}

struct BackgroundItemView: View {
    let item: BackgroundItem
    let isSelected: Bool
    
    var body: some View {
        VStack {
            ZStack {
                if let color = item.color {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                        .aspectRatio(932/430, contentMode: .fit)
                        .frame(height: 80)
                } else if let imageName = item.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(height: 80)
                }
            }
            
            Text(item.name)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}
