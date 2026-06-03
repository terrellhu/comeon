# Tech Debt Register

Tracked advisory deviations and known issues from story completion reviews.
Each entry includes the date, story, description, and source story path.

---

- **2026-06-03** (HitpauseManager Autoload + Runtime Verification): `trigger_hitpause(duration <= 0.0)` 입력 방어 코드 없음 — 음수 duration 전달 시 `_active=true` 고착으로 `Engine.time_scale=0` 영구 지속 가능. 호출자 책임으로 간주하나, 명시적 assert 또는 clamp 추가 권장. — tracked from `production/epics/retry-context/story-002-hitpause-manager-autoload.md`
- **2026-06-03** (HitpauseManager Autoload + Runtime Verification): GUT 테스트 `test_time_scale_set_to_zero_on_trigger`에서 `trigger_hitpause(999.0)` await 없이 호출로 SceneTreeTimer가 잔류해 "8 unfreed children" 경고 발생. 기능 영향 없으나 CI 로그 노이즈. 테스트 재설계 또는 주석 추가로 의도 명시 권장. — tracked from `production/epics/retry-context/story-002-hitpause-manager-autoload.md`
