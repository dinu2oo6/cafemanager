import SwiftUI

struct JobImportView: View {
    @StateObject private var vm = JobImportViewModel()
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    stateContent
                }
                .padding(AppTheme.padding)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Job Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if case .success = vm.viewState {
                    Button { vm.reset() } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
        }
    }

    // MARK: - State Router

    @ViewBuilder
    private var stateContent: some View {
        switch vm.viewState {
        case .idle:
            if vm.importMode == .url {
                heroSection
                urlInputSection
                orDivider
                manualPasteLink
            } else {
                manualPasteHero
                manualPasteInput
                orDivider
                urlModeLink
            }
        case .loading(let status):
            loadingContent(status: status)
        case .success(let job):
            jobResultContent(job: job)
        case .linkedInDetected:
            linkedInContent
        case .error(let message):
            errorContent(message: message)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.primary)
            }

            Text("Import Job Listing")
                .font(.title2.bold())
                .foregroundColor(AppTheme.textPrimary)

            Text("Paste a job URL to automatically fetch and parse the description")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    // MARK: - URL Input

    private var urlInputSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundColor(AppTheme.secondary)
                    .frame(width: 20)

                TextField("https://example.com/job/...", text: $vm.urlText)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($urlFieldFocused)
                    .submitLabel(.go)
                    .onSubmit { vm.fetchJob() }

                Button {
                    if let clip = UIPasteboard.general.string {
                        vm.urlText = clip
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(AppTheme.primary)
                }
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
            )

            Button {
                urlFieldFocused = false
                vm.fetchJob()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("Fetch Job Details")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primaryGradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: AppTheme.primary.opacity(0.2), radius: 4, y: 2)
            }
            .disabled(vm.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(vm.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

            platformHints
        }
    }

    private var platformHints: some View {
        VStack(spacing: 6) {
            Text("Supported platforms")
                .font(.caption2)
                .foregroundColor(AppTheme.secondary)

            HStack(spacing: 12) {
                ForEach(["Indeed", "Naukri", "Glassdoor", "Careers"], id: \.self) { name in
                    Text(name)
                        .font(.caption2.bold())
                        .foregroundColor(AppTheme.primary.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.primary.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - OR Divider

    private var orDivider: some View {
        HStack {
            Rectangle()
                .fill(AppTheme.secondary.opacity(0.3))
                .frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundColor(AppTheme.secondary)
                .padding(.horizontal, 8)
            Rectangle()
                .fill(AppTheme.secondary.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Manual Paste Link

    private var manualPasteLink: some View {
        Button {
            vm.switchToManualPaste()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard.fill")
                Text("Paste description manually")
            }
            .font(.subheadline)
            .foregroundColor(AppTheme.primary)
        }
    }

    // MARK: - Manual Paste Mode

    private var manualPasteHero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.primary)
            }

            Text("Paste Job Description")
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)

            Text("Copy the job description text and paste it below")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var manualPasteInput: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $vm.pasteText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200, maxHeight: 300)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                    )

                if vm.pasteText.isEmpty {
                    Text("Paste job description here...")
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 12) {
                Button {
                    if let clip = UIPasteboard.general.string {
                        vm.pasteText = clip
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary.opacity(0.1))
                    .foregroundColor(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }

                Button {
                    vm.processManualPaste()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.magnifyingglass")
                        Text("Process")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .disabled(vm.pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(vm.pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
            }
        }
    }

    private var urlModeLink: some View {
        Button {
            vm.switchToURLMode()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                Text("Import from URL instead")
            }
            .font(.subheadline)
            .foregroundColor(AppTheme.primary)
        }
    }

    // MARK: - Loading

    private func loadingContent(status: String) -> some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)

            ProgressView()
                .scaleEffect(1.8)
                .tint(AppTheme.primary)

            VStack(spacing: 8) {
                Text("Fetching Job Details")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Text(status)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondary)
                    .contentTransition(.numericText())
            }

            Spacer().frame(height: 80)
        }
    }

    // MARK: - Success / Result Card

    private func jobResultContent(job: JobDescription) -> some View {
        VStack(spacing: 16) {
            HStack {
                Label(job.fetchMethod, systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.success.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                if let url = job.sourceURL {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("Open")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.primary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(job.title)
                    .font(.title3.bold())
                    .foregroundColor(AppTheme.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    if !job.company.isEmpty {
                        Label(job.company, systemImage: "building.2.fill")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondary)
                    }
                    if !job.location.isEmpty {
                        Label(job.location, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondary)
                    }
                    if let salary = job.salary, !salary.isEmpty {
                        Label(salary, systemImage: "banknote.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.success)
                    }
                }

                if !job.description.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        Text(job.description)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondary)
                            .lineLimit(vm.showFullDescription ? nil : 8)

                        if job.description.count > 300 {
                            Button {
                                withAnimation { vm.showFullDescription.toggle() }
                            } label: {
                                Text(vm.showFullDescription ? "Show Less" : "Show More")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.primary)
                            }
                        }
                    }
                }

                if !job.requirements.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Requirements")
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        let visibleCount = vm.showAllRequirements ? job.requirements.count : min(5, job.requirements.count)
                        ForEach(Array(job.requirements.prefix(visibleCount).enumerated()), id: \.offset) { _, req in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.success)
                                    .font(.caption)
                                    .padding(.top, 2)
                                Text(req)
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.secondary)
                            }
                        }

                        if job.requirements.count > 5 {
                            Button {
                                withAnimation { vm.showAllRequirements.toggle() }
                            } label: {
                                Text(vm.showAllRequirements ? "Show Less" : "Show All (\(job.requirements.count))")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.primary)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.padding)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

            HStack(spacing: 12) {
                Button {
                    vm.copyToClipboard(job.rawContent)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.copiedToClipboard ? "checkmark" : "doc.on.doc")
                        Text(vm.copiedToClipboard ? "Copied!" : "Copy Content")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary.opacity(0.1))
                    .foregroundColor(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }

                Button {
                    vm.reset()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New Import")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
            }
        }
    }

    // MARK: - LinkedIn Detected

    private var linkedInContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }

            Text("LinkedIn Requires Login")
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)

            Text("LinkedIn job listings are behind a login wall and can't be fetched automatically. Copy the job description from LinkedIn and paste it here instead.")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                instructionRow(step: "1", text: "Open the job listing in LinkedIn")
                instructionRow(step: "2", text: "Select and copy the job description")
                instructionRow(step: "3", text: "Paste it here using the button below")
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

            Button {
                vm.switchToManualPaste()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard.fill")
                    Text("Paste Description Instead")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primaryGradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }

            Button { vm.reset() } label: {
                Text("Try a Different URL")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.primary)
            }
        }
    }

    private func instructionRow(step: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(step)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(AppTheme.primary)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()
        }
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(AppTheme.error.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.error)
            }

            Text("Couldn't Fetch Job Details")
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                Button {
                    vm.fetchJob()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primaryGradient)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }

                Button {
                    vm.switchToManualPaste()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard.fill")
                        Text("Paste Description Instead")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppTheme.primary)
                }
            }
        }
    }
}
