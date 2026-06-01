# Accessibility Requirements — 刃响 (Blade Echo)

**Status**: Committed
**Tier**: Standard
**Last Updated**: 2026-06-01
**Target Platforms**: PC (Steam)
**Input Methods**: Keyboard/Mouse + Gamepad (per technical-preferences.md)

---

## Committed Tier: Standard

PC Steam アクションゲームの業界標準的なアクセシビリティ段階。WCAG-AA コントラスト + ゲームパッド完全ナビゲーション + 形状シグナル併用。

**この段階で求められること：**
- 全インタラクティブ要素にキーボード経路あり
- ゲームパッド完全ナビゲーション（メニュー + 戦闘）
- コントラスト WCAG-AA 準拠（通常テキスト 4.5:1、大テキスト 3:1）
- 色のみで情報を伝えない（形状/位置/動きで補強）
- リマップ可能なキーバインディング
- モーション削減オプション（hitpause / 画面振動 / 死亡屏幕アニメーション）

**この段階で求めないこと（将来の Enhanced 段階で検討）：**
- 完全なスクリーンリーダー対応（Godot 4.5+ の AccessKit は将来評価）
- 認定された第三者ツールによるテスト
- 色覚異常モード（自動色変換）

---

## Standard Tier Detailed Requirements

### A-01: キーボードナビゲーション

- 全メニュー画面で **Tab + Enter** で全要素到達可能
- 戦闘中の全アクションがキーマップから到達可能（移動・ジャンプ・格挡・反击・闪避・アタック）
- フォーカス可視化必須：1px ハイライト外框（Art Bible Section 3 倒角ジオメトリと一致）
- Godot 4.6 Dual-Focus システムに留意：`grab_focus()` はキーボード/ゲームパッドのみに影響、マウス hover とは独立

### A-02: ゲームパッド完全ナビゲーション

- メニュー：D-Pad + A/B 確定/キャンセル + Y/X コンテキスト
- 戦闘：標準的なボタン配置（A=ジャンプ、X=格挡、B=闪避、Y=アタック デフォルト、リマップ可）
- Steam Input 推奨（プラットフォーム間で一貫したマッピング）
- ゲームパッドの SDL3 (Godot 4.5+) でクロスプラットフォーム互換性

### A-03: コントラスト

- 通常テキスト（< 18pt）: コントラスト比 **≥ 4.5:1**（WCAG-AA）
- 大テキスト（≥ 18pt または ≥ 14pt 太字）: **≥ 3:1**
- 操作不能なテキスト（例：背景文章）: コントラスト要件免除（ただし装飾でも 3:1 以上を推奨）
- Art Bible の色彩規格と互換性検証必須：
  - 枯骨白 `#C8BFA8` on 虚空墨 `#0D0B1A`: ✅ 11:1（合格）
  - 高亮琥珀金 `#E8941A` on 虚空墨: ✅ 8.5:1（合格）
  - 暗琥珀橙 `#8C5A1A` on 虚空墨: ✅ 4.8:1（合格、境界）

### A-04: 色非依存シグナル

- 攻撃予警（PRE/WINDOW/POST）：色 + 形状（菱形マーカー） + サイズ（窓開時 1.4× 拡大）の **3 重シグナル**（hud-system.md R-TEL-V3）
- HP 临界状態：色 + 闪烁の組合せ（音効果は意図的に追加しない、戦闘集中阻害防止）
- アクション成功/失敗：色 + 形状 + 音響の組合せ

### A-05: キーバインディングのリマップ

- 全 InputMap アクションが設定メニューでリマップ可能
- デフォルトプリセット: PC Standard / Gamepad Standard / Southpaw（ゲームパッド左右反転）
- 設定保存はプラットフォーム標準（Steam Cloud + ローカル ini）

### A-06: モーション削減オプション

設定メニューに「**Reduce Motion**」トグルを追加。ON 時：
- Hitpause（60–80ms）→ 短縮（30ms）または無効
- 画面振動（hit / phase transition）→ 振幅 50% 削減または無効
- 死亡屏幕の RED_FLASH (0.2s) → 黒画面のみに置換（フラッシュ削減）
- Art Bible の Visual/Audio 規格に従う

---

## Verification

### 段階チェックリスト（Pre-Production gate 必須）

- [ ] 全メニューでマウスを使わずに全要素到達できる（キーボードのみテスト）
- [ ] ゲームパッドのみで全メニュー + 戦闘を完了できる
- [ ] コントラスト計算ツールで全 HUD 色対背景 4.5:1 を達成
- [ ] 攻撃予警が色覚異常シミュレーター（Coblis / Color Oracle）で WINDOW 状態を識別可能
- [ ] 設定メニューで全キーマップ変更 + 反映確認
- [ ] Reduce Motion ON 時、hitpause が短縮または無効になる

### Tools

- **Coblis** (https://www.color-blindness.com/coblis-color-blindness-simulator/): 色覚異常シミュレーション
- **WebAIM Contrast Checker** (https://webaim.org/resources/contrastchecker/): コントラスト計算
- **Godot Built-in Profiler**: フォーカスナビゲーション可視化

---

## Out of Scope (Document for Future)

将来検討項目（Enhanced 段階での評価対象）：
- 完全なスクリーンリーダー対応（Godot 4.5+ AccessKit）
- 認定された第三者ツールによるテスト
- 自動色覚異常モード（色変換シェーダー）
- カスタマイズ可能 UI スケーリング（テキスト 200% 拡大）
- 一時停止 / スローモーション（戦闘中アクセシビリティモード）

---

## Related Documents

- [Art Bible](art/art-bible.md) — Section 7.5 死亡屏幕、HUD 色彩規格
- [HUD System GDD](gdd/hud-system.md) — UI Requirements + R-HUD-CHK-04, R-HUD-CHK-05 灰度モード検証
- [Parry/Telegraph System GDD](gdd/parry-telegraph-system.md) — 3 重シグナル要件
- [Interaction Patterns Library](ux/interaction-patterns.md) — パターンごとのアクセシビリティ仕様
- [Technical Preferences](../.claude/docs/technical-preferences.md) — 入力方法と対象プラットフォーム
