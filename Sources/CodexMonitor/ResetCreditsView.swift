import SwiftUI

// 只显示重置卡信息；不会兑换或消耗卡片。
struct ResetCreditsView: View {
    let credits: ResetCredits?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            // 标题和总数共用一行，给卡片明细留出空间。
            HStack {
                Text("重置卡").font(.headline)
                Spacer()
                Text(credits?.availableCount.map { "剩余 \($0) 张" } ?? "剩余：暂无数据")
                    .foregroundStyle(.secondary)
            }
            if let rows = credits?.credits, !rows.isEmpty {
                ForEach(rows) { credit in
                    // 每张卡固定一行，不显示服务返回的营销标题或说明。
                    HStack(spacing: 8) {
                        Text("重置卡 \(credit.id + 1)").font(.subheadline.weight(.medium))
                        Spacer(minLength: 4)
                        Text(credit.expiresAt.map {
                            "有效期至：\($0.formatted(date: .numeric, time: .shortened))"
                        } ?? (credit.expiryKnown ? "无到期限制" : "有效期：暂无数据"))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }
                // 后端明细可能只返回部分卡片，不据此推断其他卡的有效期。
                if let count = credits?.availableCount, rows.count < count {
                    Text("仅显示服务提供的部分明细").font(.caption).foregroundStyle(.secondary)
                }
            } else if credits?.availableCount != 0 {
                Text("有效期：暂无明细").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
