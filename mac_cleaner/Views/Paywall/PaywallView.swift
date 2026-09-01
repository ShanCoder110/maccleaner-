//
//  PaywallView.swift
//  mac_cleaner
//

import SwiftUI
import StoreKit
import AppKit

private enum PaywallPlanKind: String, CaseIterable {
    case monthly
    case annual
    case lifetime

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .lifetime: return "Lifetime"
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var planKind: PaywallPlanKind = .monthly
    @State private var appeared = false
    @State private var shimmer = false
    @State private var featureVisible: [Bool] = Array(repeating: false, count: 5)

    private var selectedProduct: Product? {
        switch planKind {
        case .monthly:
            return subscription.monthlyProduct
        case .annual:
            return subscription.yearlyProduct
        case .lifetime:
            return subscription.lifetimeProduct
        }
    }

    private var isCurrentPlan: Bool {
        guard let activeProductID = subscription.activeProductID else { return false }
        switch planKind {
        case .monthly:
            return activeProductID == SubscriptionStore.monthlyProductID
        case .annual:
            return activeProductID == SubscriptionStore.yearlyProductID
        case .lifetime:
            return activeProductID == SubscriptionStore.lifetimeProductID
        }
    }

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("internaldrive", "Space Cleaner", "Clear caches plus named Apple, developer, and AI data"),
        ("doc.on.doc", "Large Files", "Find oversized files across granted folders"),
        ("square.3.layers.3d", "Space Lens", "Visualize where storage is going"),
        ("tray", "Orphans", "Spot leftovers with no matching app"),
        ("trash", "Clean Junk", "One-tap junk cleanup from Smart Scan"),
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar

                HStack(alignment: .top, spacing: AppSpacing.xxl) {
                    leftColumn
                        .frame(maxWidth: .infinity, alignment: .leading)

                    rightColumn
                        .frame(width: 360)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.bottom, AppSpacing.xxl)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
            }
        }
        .frame(minWidth: 880, idealWidth: 960, minHeight: 560, idealHeight: 620)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appeared = true
            }
            for index in features.indices {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.1 + Double(index) * 0.06)) {
                    featureVisible[index] = true
                }
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                shimmer = true
            }
            Task { await subscription.refresh() }
        }
    }

    private var topBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)

            Text(AppLegal.displayName)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.md)

            IconButton(systemName: "xmark", size: 32, iconSize: 12, help: "Close") {
                dismiss()
            }
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.background,
                    AppColors.accentMuted.opacity(0.45),
                    AppColors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppColors.accent.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 48)
                .offset(x: -220, y: -180)
                .scaleEffect(appeared ? 1 : 0.6)

            Circle()
                .fill(AppColors.info.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: 280, y: 200)
                .scaleEffect(appeared ? 1 : 0.6)
        }
        .ignoresSafeArea()
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Everything you need to clean deeper")
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Smart Scan, Applications, and Duplicates stay free. Pro unlocks the tools below.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    featureRow(feature, index: index)
                }
            }
        }
    }

    private func featureRow(_ feature: (icon: String, title: String, subtitle: String), index: Int) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColors.surface)
                    .frame(width: 42, height: 42)
                Image(systemName: feature.icon)
                    .foregroundStyle(AppColors.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(feature.subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.success)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.surface.opacity(0.92))
        )
        .opacity(featureVisible[index] ? 1 : 0)
        .offset(x: featureVisible[index] ? 0 : -14)
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            planSwitch

            planSummaryCard
                .animation(.spring(response: 0.4, dampingFraction: 0.78), value: planKind)

            ctaBlock

            legalFooter
        }
        .padding(AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xxxl, style: .continuous)
                .fill(AppColors.surface.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xxxl, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        )
        .appShadow(AppShadow.card)
    }

    private var planSwitch: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Choose your plan")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 0) {
                ForEach(PaywallPlanKind.allCases, id: \.self) { kind in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            planKind = kind
                        }
                    } label: {
                        Text(kind.title)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(planKind == kind ? .white : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                    .fill(planKind == kind ? AppColors.accent : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppColors.controlFillSecondary)
            )

            if showsTrialBadge {
                StatusBadge(title: "3-day free trial included", style: .info, icon: "gift.fill")
            }
        }
    }

    private var showsTrialBadge: Bool {
        (planKind == .monthly || planKind == .annual) && subscription.isEligibleForIntroOffer
    }

    private var planSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(priceLabel)
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())
                Spacer()
                if isCurrentPlan {
                    StatusBadge(title: "Current Plan", style: .success, icon: "checkmark.circle.fill")
                } else {
                    switch planKind {
                    case .monthly:
                        StatusBadge(title: "Flexible", style: .neutral)
                    case .annual:
                        StatusBadge(title: "Popular", style: .info)
                    case .lifetime:
                        StatusBadge(title: "Best value", style: .success)
                    }
                }
            }

            Text(planSubtitle)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if subscription.products.isEmpty {
                Text(subscription.isLoading ? "Loading plans…" : "Plans are temporarily unavailable. Try Restore Purchases or check back shortly.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .fill(isCurrentPlan ? AppColors.success.opacity(0.15) : AppColors.accentMuted.opacity(0.55))
        )
    }

    private var priceLabel: String {
        PaywallPricing.label(for: selectedProduct)
    }

    private var planSubtitle: String {
        switch planKind {
        case .monthly:
            if subscription.isEligibleForIntroOffer {
                return "Billed monthly after a 3-day free trial. Cancel anytime in Apple Subscriptions."
            }
            return "Full Pro access, billed every month. Cancel anytime."
        case .annual:
            if subscription.isEligibleForIntroOffer {
                return "Billed yearly after a 3-day free trial. Cancel anytime in Apple Subscriptions."
            }
            return "Full Pro access, billed once a year. Cancel anytime."
        case .lifetime:
            return "One-time purchase. Keep Pro forever — no renewals."
        }
    }

    private var ctaBlock: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                Task { @MainActor in
                    if isCurrentPlan {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            NSWorkspace.shared.open(url)
                        }
                        return
                    }
                    guard let product = selectedProduct else { return }
                    let ok = await subscription.purchase(product)
                    if ok {
                        // Force-dismiss via binding; Environment dismiss can fail while
                        // the system StoreKit sheet is still tearing down.
                        appState.handlePaywallPurchaseSuccess()
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isCurrentPlan ? [
                                    AppColors.textSecondary,
                                    AppColors.textSecondary.opacity(0.85)
                                ] : [
                                    AppColors.accent,
                                    AppColors.accent.opacity(0.85),
                                    AppColors.info
                                ],
                                startPoint: shimmer ? .leading : .trailing,
                                endPoint: shimmer ? .trailing : .leading
                            )
                        )
                        .frame(height: 48)

                    HStack(spacing: AppSpacing.sm) {
                        if subscription.isLoading && !isCurrentPlan {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(ctaTitle)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled((!isCurrentPlan && selectedProduct == nil) || (!isCurrentPlan && subscription.isLoading))
            .opacity((!isCurrentPlan && selectedProduct == nil) ? 0.55 : 1)
            .appShadow(AppShadow.button)

            SecondaryButton(title: "Restore Purchases", size: .compact) {
                Task { @MainActor in
                    await subscription.restore()
                    if subscription.isPro {
                        appState.handlePaywallPurchaseSuccess()
                    }
                }
            }

            if let error = subscription.purchaseError {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ctaTitle: String {
        if isCurrentPlan {
            return "Manage Subscription"
        }
        if subscription.isPro {
            switch planKind {
            case .monthly:
                return "Switch to Monthly"
            case .annual:
                return "Switch to Annual"
            case .lifetime:
                return "Upgrade to Lifetime"
            }
        }
        switch planKind {
        case .monthly:
            return subscription.isEligibleForIntroOffer ? "Start 3-Day Free Trial" : "Continue with Monthly"
        case .annual:
            return subscription.isEligibleForIntroOffer ? "Start 3-Day Free Trial" : "Continue with Annual"
        case .lifetime:
            return "Unlock Lifetime Pro"
        }
    }

    private var legalFooter: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Link("Privacy Policy", destination: AppLegal.hostedPrivacyPolicyURL)
                Text("·")
                    .foregroundStyle(AppColors.textTertiary)
                Link("Terms of Use", destination: AppLegal.termsOfUseURL)
                Text("·")
                    .foregroundStyle(AppColors.textTertiary)
                Link("Support", destination: AppLegal.supportMailtoURL)
            }
            .font(AppTypography.captionMedium)
            .foregroundStyle(AppColors.accent)

            Text(planKind == .lifetime
                 ? "Lifetime is a one-time charge to your Apple ID. Restore purchases on any Mac signed into the same Apple ID."
                 : "Payment is charged to your Apple ID. Subscriptions renew automatically unless canceled at least 24 hours before the period ends.")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
