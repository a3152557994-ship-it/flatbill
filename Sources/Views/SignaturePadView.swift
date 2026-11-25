import SwiftUI
import UIKit

struct SignaturePadView: View {
    let title: String
    let existingData: Data?
    let onSave: (Data?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var canvasSize: CGSize = CGSize(width: 340, height: 180)

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text(L10n.t("Sign with your finger inside the box below.", "请在下方签字区内手写签名。"))
                    .font(.subheadline)
                    .foregroundStyle(FlatTheme.muted)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(FlatTheme.border, lineWidth: 1.5)
                        )

                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(FlatTheme.border)
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 34)
                    }

                    if strokes.isEmpty && currentStroke.isEmpty, let existingData, let uiImg = UIImage(data: existingData) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFit()
                            .padding(16)
                            .opacity(0.65)
                    }

                    GeometryReader { geo in
                        Canvas { ctx, _ in
                            for stroke in strokes + [currentStroke] {
                                guard stroke.count > 1 else { continue }
                                var path = Path()
                                path.move(to: stroke[0])
                                for pt in stroke.dropFirst() {
                                    path.addLine(to: pt)
                                }
                                ctx.stroke(path, with: .color(FlatTheme.ink), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    canvasSize = geo.size
                                    currentStroke.append(value.location)
                                }
                                .onEnded { _ in
                                    if !currentStroke.isEmpty {
                                        strokes.append(currentStroke)
                                        currentStroke = []
                                    }
                                }
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .frame(height: 210)
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        strokes.removeAll()
                        currentStroke.removeAll()
                        onSave(nil)
                        dismiss()
                    } label: {
                        Label(L10n.t("Clear Saved", "清除签名"), systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        strokes.removeAll()
                        currentStroke.removeAll()
                    } label: {
                        Label(L10n.t("Redraw", "重写"), systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 18)
            .background(FlatTheme.paper.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Save", "保存")) {
                        if let rendered = renderPNG() {
                            onSave(rendered)
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(strokes.isEmpty)
                }
            }
        }
    }

    private func renderPNG() -> Data? {
        let size = CGSize(width: max(300, canvasSize.width), height: max(160, canvasSize.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let img = renderer.image { ctx in
            ctx.cgContext.setStrokeColor(UIColor(red: 0.08, green: 0.11, blue: 0.15, alpha: 1).cgColor)
            ctx.cgContext.setLineWidth(3.0)
            ctx.cgContext.setLineCap(.round)
            ctx.cgContext.setLineJoin(.round)
            for stroke in strokes where stroke.count > 1 {
                ctx.cgContext.beginPath()
                ctx.cgContext.move(to: stroke[0])
                for pt in stroke.dropFirst() {
                    ctx.cgContext.addLine(to: pt)
                }
                ctx.cgContext.strokePath()
            }
        }
        return img.pngData()
    }
}
