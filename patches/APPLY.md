# YTM patches (Task 8 + Task 10)

From repo root on `feature/ytm-ui-overhaul`:

```bash
git apply patches/player_controls_ytm_mini.patch
git apply patches/player_ui_no_like_embedded.patch
git apply patches/library_filter_chips.patch
git add -A && git commit -m "feat(ytm): mini player chrome + library filter chips" && git push
```

Or one-shot:

```bash
git apply patches/*.patch && git commit -am "feat(ytm): mini player + library chips" && git push
```
