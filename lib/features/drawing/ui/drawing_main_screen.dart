import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/extensions/int_ext.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../../shared/components/feedback_link_widget.dart';
import '../../../core/config/drawing_config.dart';
import '../domain/drawing_model.dart';
import '../domain/drawing_settings.dart';

// ══════════════════════════════════════════════════════════
// ペアエントリ
//
// 同じモデル名を持つアセットを DrawingConfig.categories の定義順にまとめた
// 再生単位。単独の場合は models.length == 1。
// ペア内のソート順は DrawingConfig.categorySortIndex に従う。
// ══════════════════════════════════════════════════════════
class _PairEntry {
  /// ペア内のモデルリスト（DrawingConfig.categories の定義順）
  final List<DrawingModel> models;

  const _PairEntry(this.models);

  bool get hasPair => models.length >= 2;
  DrawingModel get first => models[0];
}

// ══════════════════════════════════════════════════════════
// X秒ドローイング メイン画面
//
// タイマーカウントダウン・ポーズ自動切り替えを行う本体画面。
// ── コントロール ──
//   [前へ]  前のモデルに戻る（最初のモデルでは非活性）
//   [一時停止/再開]  タイマーを停止・再開する
//   [次へ]  次のモデルに進む（ループなし・最後のモデルでは非活性）
// ══════════════════════════════════════════════════════════
class DrawingMainScreen extends StatefulWidget {
  final DrawingSettings settings;

  const DrawingMainScreen({super.key, required this.settings});

  @override
  State<DrawingMainScreen> createState() => _DrawingMainScreenState();
}

class _DrawingMainScreenState extends State<DrawingMainScreen> {
  late final int _durationSec;
  late final bool _loop;
  late final bool _shuffle;
  late final int _maxWorkTimeSec; // 0 = 無制限

  // ── プレイリスト ────────────────────────────────────────
  // ループ時に周ごとに再シャッフルできるよう、元のモデルリストを保持する
  late final List<DrawingModel> _sourceModels;

  late List<DrawingModel> _playlist;
  late List<bool> _isPairTransition;

  // 前の周のプレイリスト（ループ+前へ で正しく戻れるよう保持）
  // null = 前の周は存在しない（最初の周）
  List<DrawingModel>? _prevPlaylist;
  List<bool>? _prevIsPairTransition;

  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isCounting = true;
  bool _isFinished = false;
  bool _isTimeUp = false; // 最大作業時間超過による終了
  bool _isShowingLabel = false;
  bool _isLabelFadingOut = false; // フェードアウト中フラグ（後半0.2秒）
  int _countdown = AppValues.drawingCountdownSec;

  int _remaining = 0;
  int _pausedRemaining = 0;
  DateTime? _slideStartTime;

  // 最大作業時間：スライドショー稼働中の経過秒数を管理する
  // Timer.periodicの累積ではなくDateTimeベースで計算することでドリフトを防ぐ
  //
  // _workStartTime  : 現在の稼働区間の開始時刻（一時停止・再開のたびに更新）
  // _workPausedSec  : 過去に稼働した区間の合計秒数（一時停止時に加算）
  // workElapsedSec  : getter で _workPausedSec + 現在区間の経過秒数を返す
  DateTime? _workStartTime;
  int _workPausedSec = 0;

  // 現在の画像が表示された時点の作業経過秒数。
  // ボタン切り替え時にここまで巻き戻すことで、途中切り替え分をなかったことにする。
  int _slideStartWorkElapsed = 0;
  Timer? _workElapsedTimer;

  Timer? _countdownTimer;
  Timer? _slideshowTimer;
  Timer? _remainingTimer;
  Timer? _labelTimer;

  // 画像のピンチ拡大縮小用コントローラー。
  // 画像切り替え時に reset() してズーム状態を初期化する。
  final TransformationController _transformationController =
      TransformationController();

  DrawingModel get _currentModel => _playlist[_currentIndex];
  bool get _currentIsPairTransition => _isPairTransition[_currentIndex];

  int get _computedRemaining {
    if (_slideStartTime == null) return _durationSec;
    final elapsed = DateTime.now().difference(_slideStartTime!).inSeconds;
    return (_durationSec - elapsed).clamp(0, _durationSec);
  }

  /// 稼働中の経過秒数（DateTimeベース・ドリフトしない）
  int get _workElapsedSec {
    final base = _workPausedSec;
    final start = _workStartTime;
    if (start == null) return base;
    return base + DateTime.now().difference(start).inSeconds;
  }

  // ── プレイリスト構築 ─────────────────────────────────────
  // 1. モデル名でグループ化してペアを作る
  // 2. ペア単位でシャッフル or 登録順を適用
  // 3. ペア内は DrawingConfig.categories の定義順に固定
  // 4. フラットに展開してペア内遷移フラグを付与
  static ({List<DrawingModel> playlist, List<bool> isPairTransition})
      _buildPlaylist(List<DrawingModel> models, bool shuffle) {
    // モデル名でグループ化
    final Map<String, List<DrawingModel>> grouped = {};
    for (final m in models) {
      grouped.putIfAbsent(m.modelName, () => []).add(m);
    }

    // ペアエントリを生成（ペア内は DrawingConfig.categorySortIndex 順にソート）
    final pairs = grouped.values.map((list) {
      list.sort((a, b) => DrawingConfig.categorySortIndex(a.categoryId)
          .compareTo(DrawingConfig.categorySortIndex(b.categoryId)));
      return _PairEntry(list);
    }).toList();

    // ペア単位でシャッフル or 登録順
    if (shuffle) {
      pairs.shuffle(Random());
    } else {
      final indexMap = {for (int i = 0; i < models.length; i++) models[i]: i};
      pairs.sort(
          (a, b) => (indexMap[a.first] ?? 0).compareTo(indexMap[b.first] ?? 0));
    }

    // フラット展開してペア内遷移フラグを付与
    final playlist = <DrawingModel>[];
    final isPairTransition = <bool>[];
    for (final pair in pairs) {
      for (int i = 0; i < pair.models.length; i++) {
        playlist.add(pair.models[i]);
        isPairTransition.add(i > 0); // 2枚目以降はペア内遷移
      }
    }

    return (playlist: playlist, isPairTransition: isPairTransition);
  }

  @override
  void initState() {
    super.initState();
    _durationSec = widget.settings.durationSec;
    _loop = widget.settings.loop;
    _shuffle = widget.settings.shuffle;
    _maxWorkTimeSec = widget.settings.maxWorkTimeSec;
    _sourceModels = List.of(widget.settings.selectedModels);
    _remaining = _durationSec;
    _pausedRemaining = _durationSec;

    final result = _buildPlaylist(_sourceModels, _shuffle);
    _playlist = result.playlist;
    _isPairTransition = result.isPairTransition;

    _startCountdown();
    // 最大作業時間の積算タイマーはスライドショー開始時に起動する
  }

  // ── 最大作業時間超過 ───────────────────────────────────
  void _onTimeUp() {
    if (!mounted || _isFinished || _isTimeUp) return;
    _stopWorkElapsedTimer(); // null リセットも行う
    _slideshowTimer?.cancel();
    _remainingTimer?.cancel();
    _labelTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isTimeUp = true;
    });
  }

  // ── 作業経過タイマー起動 ──────────────────────────────
  // 稼働区間の開始時刻を記録し、1秒ごとに超過チェックと再描画を行う。
  // 実際の経過秒数は _workElapsedSec getter が DateTimeベースで計算するので
  // Timer.periodicのドリフトはカウントに影響しない。
  void _startWorkElapsedTimer() {
    if (_maxWorkTimeSec == 0) return; // 無制限は不要
    _workElapsedTimer?.cancel();
    _workStartTime = DateTime.now(); // この区間の開始時刻を記録
    _workElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // 超過チェックはgetterの値（DateTimeベース）で行う
      if (_workElapsedSec >= _maxWorkTimeSec) {
        _onTimeUp();
        return;
      }
      setState(() {}); // バッジ表示を毎秒更新
    });
  }

  // ── 作業経過タイマー停止 ──────────────────────────────
  // 停止時に稼働した秒数を _workPausedSec に加算し、_workStartTime をリセットする
  void _stopWorkElapsedTimer() {
    _workElapsedTimer?.cancel();
    _workElapsedTimer = null; // isActive チェックの誤判定を防ぐためnullにリセット
    // 今の区間で稼働した分を蓄積し、次の再開時の基準をリセット
    if (_workStartTime != null) {
      _workPausedSec += DateTime.now().difference(_workStartTime!).inSeconds;
      _workStartTime = null;
    }
  }

  // ── 開始カウントダウン ──────────────────────────────────
  void _startCountdown() {
    final countdownStart = DateTime.now();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      // DateTimeベースで残り秒数を計算（ドリフト防止）
      final elapsed = DateTime.now().difference(countdownStart).inSeconds;
      final remaining = AppValues.drawingCountdownSec - elapsed;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _countdown = 0;
          _isCounting = false;
          _isPlaying = true;
        });
        _showLabelThenStart();
      } else {
        setState(() => _countdown = remaining);
      }
    });
  }

  // ── 残り時間タイマーを指定秒数からリセット・再開 ─────────
  void _restartRemainingTimer({int? from}) {
    _remainingTimer?.cancel();
    final startSec = from ?? _durationSec;
    _slideStartTime = DateTime.now().subtract(
      Duration(seconds: _durationSec - startSec),
    );
    setState(() => _remaining = startSec);

    _remainingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _computedRemaining);
    });
  }

  // ── 0.5秒モデル名ラベルを表示してからスライド開始 ────────
  // [skipLabel] がtrueの場合（ペア内遷移・手動ボタン操作）はラベルをスキップ
  // 前半 300ms: 完全表示 → 後半 200ms: フェードアウト → スライド開始
  //
  // ラベル表示中（計 500ms）は最大作業時間タイマーを停止する。
  // これにより、画像切り替えカウントダウンと最大作業時間カウントダウンの
  // 起算点が一致し、ラベル表示のたびに生じていたズレを防ぐ。
  void _showLabelThenStart({bool skipLabel = false}) {
    _labelTimer?.cancel();
    if (skipLabel) {
      _startSlideshow();
      return;
    }
    // ラベル表示開始と同時に最大作業時間タイマーを一時停止
    _stopWorkElapsedTimer();
    setState(() {
      _isShowingLabel = true;
      _isLabelFadingOut = false;
    });
    // 300ms後にフェードアウト開始
    _labelTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _isLabelFadingOut = true);
      // さらに200ms後にラベルを非表示にしてスライド開始
      _labelTimer = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() {
          _isShowingLabel = false;
          _isLabelFadingOut = false;
        });
        _startSlideshow();
      });
    });
  }

  // ── スライドショー開始（フル秒数から） ──────────────────
  void _startSlideshow() {
    _slideshowTimer?.cancel();
    _restartRemainingTimer();
    // 作業タイマーを起動（または再開）する。
    // ・初回呼び出し時は新規起動。
    // ・_showLabelThenStart() 経由の場合はラベル表示中に停止済みなので再起動。
    // ・ボタン切り替え（skipLabel=true）経由では停止していないので null チェックで
    //   二重起動を防ぐ。いずれも _stopWorkElapsedTimer() が null にリセット済みの
    //   ため、null チェック一本で全ケースを正しくハンドルできる。
    if (_workElapsedTimer == null) {
      _startWorkElapsedTimer();
    }
    // 画像切り替え時にピンチズームをリセットして次の画像をフル表示する
    _transformationController.value = Matrix4.identity();
    // この画像の表示開始時点の作業経過を記録（ボタン切り替え時の巻き戻し基準）
    _slideStartWorkElapsed = _workElapsedSec;
    _slideshowTimer = Timer.periodic(
      Duration(seconds: _durationSec),
      (_) => _advanceSlide(),
    );
  }

  // ── 自動で次のモデルに進む ──────────────────────────────
  void _advanceSlide() {
    final isLast = _currentIndex >= _playlist.length - 1;

    if (isLast) {
      if (_loop) {
        // 周が変わる前に現在のプレイリストを前周として退避（前へ で戻れるようにする）
        final savedPlaylist = List<DrawingModel>.of(_playlist);
        final savedTransition = List<bool>.of(_isPairTransition);
        // 周が変わるごとに再シャッフルしてプレイリストを再構築
        final result = _buildPlaylist(_sourceModels, _shuffle);
        setState(() {
          _prevPlaylist = savedPlaylist;
          _prevIsPairTransition = savedTransition;
          _playlist = result.playlist;
          _isPairTransition = result.isPairTransition;
          _currentIndex = 0;
        });
        _pausedRemaining = _durationSec;
        _slideshowTimer?.cancel();
        _showLabelThenStart();
      } else {
        _slideshowTimer?.cancel();
        _remainingTimer?.cancel();
        setState(() {
          _isPlaying = false;
          _remaining = 0;
          _isFinished = true;
        });
      }
      return;
    }

    setState(() => _currentIndex++);
    _slideshowTimer?.cancel();
    _showLabelThenStart(skipLabel: _currentIsPairTransition);
  }

  // ── 一時停止 ───────────────────────────────────────────
  void _pause() {
    _slideshowTimer?.cancel();
    _remainingTimer?.cancel();
    _stopWorkElapsedTimer(); // 一時停止中は作業時間を進めない
    _pausedRemaining = _computedRemaining;
    setState(() => _isPlaying = false);
  }

  // ── 再開 ───────────────────────────────────────────────
  void _resume() {
    setState(() => _isPlaying = true);
    _restartRemainingTimer(from: _pausedRemaining);
    _startWorkElapsedTimer(); // 一時停止から再開するので作業タイマーも再開
    _slideshowTimer?.cancel();
    _slideshowTimer = Timer(
      Duration(seconds: _pausedRemaining),
      () {
        if (!mounted) return;
        _advanceSlide();
      },
    );
  }

  // ── 最初から ───────────────────────────────────────────
  void _restart() {
    _stopWorkElapsedTimer(); // null リセットも行う
    _slideshowTimer?.cancel();
    _remainingTimer?.cancel();
    // 再スタート時は再シャッフルしてプレイリストを再構築
    final result = _buildPlaylist(_sourceModels, _shuffle);
    setState(() {
      _prevPlaylist = null; // 前周履歴もリセット
      _prevIsPairTransition = null;
      _playlist = result.playlist;
      _isPairTransition = result.isPairTransition;
      _currentIndex = 0;
      _isFinished = false;
      _isTimeUp = false;
      _workPausedSec = 0; // 経過秒数リセット
      _workStartTime = null;
      _slideStartWorkElapsed = 0;
      _isPlaying = true;
    });
    _showLabelThenStart();
  }

  // ── 前のモデルへ ───────────────────────────────────────
  // ループ+シャッフル時：先頭で「前へ」を押したら周をまたいで1つ前に戻る
  // 前周のプレイリストが退避済みであれば復元し、なければ新規ビルドする
  void _prev() {
    _slideshowTimer?.cancel();
    // ボタン切り替え：この画像を見た時間をなかったことにするため、
    // 作業経過をこの画像が表示された時点（_slideStartWorkElapsed）に巻き戻す。
    _workPausedSec = _slideStartWorkElapsed;
    _workStartTime = DateTime.now(); // 巻き戻し後の稼働区間を即開始
    _pausedRemaining = _durationSec;
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    } else if (_loop) {
      // 先頭で前へ → 前周の最後に戻る
      // 退避済みプレイリストがあればそれを復元（シャッフルが変わらない）
      // なければ最初の周なので新規ビルド
      final prevP = _prevPlaylist;
      final prevT = _prevIsPairTransition;
      if (prevP != null && prevT != null) {
        setState(() {
          _playlist = prevP;
          _isPairTransition = prevT;
          _prevPlaylist = null;
          _prevIsPairTransition = null;
          _currentIndex = _playlist.length - 1;
        });
      } else {
        // 最初の周の先頭で前へ → ループ折り返し（新規ビルド）
        final result = _buildPlaylist(_sourceModels, _shuffle);
        setState(() {
          _playlist = result.playlist;
          _isPairTransition = result.isPairTransition;
          _currentIndex = _playlist.length - 1;
        });
      }
    } else {
      return; // ループなし先頭は何もしない
    }
    if (_isPlaying) _showLabelThenStart(skipLabel: true);
  }

  // ── 次のモデルへ ───────────────────────────────────────
  void _next() {
    final isLast = _currentIndex >= _playlist.length - 1;
    if (isLast && !_loop) return;
    _slideshowTimer?.cancel();
    // ボタン切り替え：この画像を見た時間をなかったことにするため、
    // 作業経過をこの画像が表示された時点（_slideStartWorkElapsed）に巻き戻す。
    _workPausedSec = _slideStartWorkElapsed;
    _workStartTime = DateTime.now(); // 巻き戻し後の稼働区間を即開始
    _pausedRemaining = _durationSec;
    if (isLast && _loop) {
      // 周が変わる前に現在のプレイリストを前周として退避（前へ で戻れるようにする）
      final savedPlaylist = List<DrawingModel>.of(_playlist);
      final savedTransition = List<bool>.of(_isPairTransition);
      final result = _buildPlaylist(_sourceModels, _shuffle);
      setState(() {
        _prevPlaylist = savedPlaylist;
        _prevIsPairTransition = savedTransition;
        _playlist = result.playlist;
        _isPairTransition = result.isPairTransition;
        _currentIndex = 0;
      });
    } else {
      setState(() => _currentIndex++);
    }
    if (_isPlaying) _showLabelThenStart(skipLabel: true);
  }

  @override
  void dispose() {
    _stopWorkElapsedTimer(); // null リセットも行う
    _countdownTimer?.cancel();
    _slideshowTimer?.cancel();
    _remainingTimer?.cancel();
    _labelTimer?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ループ時は先頭でも「前へ」を有効にする（前周末尾へ戻る）
    final bool isFirst = !_loop && _currentIndex == 0;
    final bool isLast = !_loop && _currentIndex == _playlist.length - 1;

    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.drawingMainTitle,
        backgroundColor: AppColors.theme,
      ),
      body: Column(
        children: [
          // ── 画像表示エリア ────────────────────────────────
          Expanded(
            child: _isCounting
                ? Center(child: _StartCountdownDisplay(countdown: _countdown))
                : (_isFinished || _isTimeUp)
                    ? Center(
                        child: _EndScreen(
                          totalCount: _playlist.length,
                          isTimeUp: _isTimeUp,
                          onRestart: _restart,
                        ),
                      )
                    : _isShowingLabel
                        ? Center(
                            child: _ModelNameLabelDisplay(
                              modelName: _currentModel.modelName,
                              isFadingOut: _isLabelFadingOut,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final double areaW = constraints.maxWidth;
                              final double areaH = constraints.maxHeight;
                              // 600px未満をスマホ縦画面として縦レイアウトに切り替え
                              final bool isNarrow = areaW < 600;

                              // パネル幅：全体幅の10%、80〜160px
                              final double panelW =
                                  (areaW * 0.16).clamp(110.0, 240.0);
                              // タイマーサイズ：パネル幅の75%
                              final double timerSize =
                                  (panelW * 0.80).clamp(70.0, 150.0);
                              // 外余白
                              final double outerPad =
                                  (areaW * AppValues.outerPadRatio).clamp(
                                      AppValues.outerPadMin,
                                      AppValues.outerPadMax);
                              // 内余白（パネルと画像の間）
                              final double innerPad =
                                  (areaW * 0.015).clamp(6.0, 16.0);

                              if (isNarrow) {
                                // ══ 縦レイアウト（スマホ縦画面）══
                                // 上段：モデル情報パネル（左）＋タイマー（右）横並び
                                // 下段：画像をフル幅表示
                                final double narrowTimerSize =
                                    (areaW * 0.18).clamp(50.0, 85.0);
                                // タイマー幅＋左右パディングを除いた残り幅をパネルに割り当てる
                                final double narrowPanelW =
                                    (areaW - narrowTimerSize - 90 - 12 * 2 - 8)
                                        .clamp(100.0, areaW * 0.75);
                                return Column(
                                  children: [
                                    // 上段
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          _ModelInfoPanel(
                                            model: _currentModel,
                                            loop: _loop,
                                            shuffle: widget.settings.shuffle,
                                            maxWorkTimeSec: _maxWorkTimeSec,
                                            workElapsedSec: _workElapsedSec,
                                            panelW: narrowPanelW,
                                          ),
                                          const Spacer(),
                                          _CircularCountdownTimer(
                                            remaining: _remaining,
                                            durationSec: _durationSec,
                                            isPaused: !_isPlaying,
                                            size: narrowTimerSize,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 下段：画像フル幅
                                    Expanded(
                                      child: InteractiveViewer(
                                        transformationController:
                                            _transformationController,
                                        minScale: 1.0,
                                        maxScale: 5.0,
                                        clipBehavior: Clip.hardEdge,
                                        child: Image.asset(
                                          _currentModel.path,
                                          fit: BoxFit.contain,
                                          width: areaW,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              // ══ 横レイアウト（PC・タブレット）══
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: outerPad),
                                  // ── 左帯：モデル情報パネル ──────
                                  SizedBox(
                                    width: panelW,
                                    height: areaH,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _ModelInfoPanel(
                                          model: _currentModel,
                                          loop: _loop,
                                          shuffle: widget.settings.shuffle,
                                          maxWorkTimeSec: _maxWorkTimeSec,
                                          workElapsedSec: _workElapsedSec,
                                          panelW: panelW,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: innerPad),
                                  // ── 中央：モデル画像 ────────────
                                  Expanded(
                                    child: InteractiveViewer(
                                      transformationController:
                                          _transformationController,
                                      minScale: 1.0,
                                      maxScale: 5.0,
                                      clipBehavior: Clip.hardEdge,
                                      child: Image.asset(
                                        _currentModel.path,
                                        fit: BoxFit.contain,
                                        height: areaH,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: innerPad),
                                  // ── 右帯：タイマー ──────────────
                                  SizedBox(
                                    width: panelW,
                                    height: areaH,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _CircularCountdownTimer(
                                          remaining: _remaining,
                                          durationSec: _durationSec,
                                          isPaused: !_isPlaying,
                                          size: timerSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: outerPad),
                                ],
                              );
                            },
                          ),
          ),

          if (!_isCounting && !_isFinished && !_isTimeUp) ...[
            // ── ページ数 ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${_currentIndex + 1} / ${_playlist.length}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),

            // ── ドットインジケーター（20枚以下のみ） ──────
            if (_playlist.length <= AppValues.drawingDotIndicatorMaxCount)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: List.generate(
                    _playlist.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentIndex ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentIndex
                            ? AppColors.theme
                            : _isPairTransition[i]
                                ? AppColors.themeLight
                                : AppColors.themeBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

            // ── コントロールボタン ──────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                AppValues.controlRowPadding,
                0,
                AppValues.controlRowPadding +
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: isFirst ? null : _prev,
                    icon: const Icon(Icons.skip_previous),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isFirst ? Colors.grey.shade300 : AppColors.theme,
                      foregroundColor: Colors.white,
                      iconSize: 32,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: _isPlaying ? _pause : _resume,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.theme,
                      foregroundColor: Colors.white,
                      iconSize: 36,
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: isLast ? null : _next,
                    icon: const Icon(Icons.skip_next),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isLast ? Colors.grey.shade300 : AppColors.theme,
                      foregroundColor: Colors.white,
                      iconSize: 32,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 左帯：モデル情報パネル（カテゴリ・モデル名・作者・バッジ）
// ══════════════════════════════════════════════════════════
class _ModelInfoPanel extends StatelessWidget {
  final DrawingModel model;
  final bool loop;
  final bool shuffle;

  /// 最大作業時間（秒）。0 = 無制限。
  final int maxWorkTimeSec;

  /// 現在の作業経過秒数（スライドショー稼働中のみ加算）。
  final int workElapsedSec;
  final double panelW;

  const _ModelInfoPanel({
    required this.model,
    required this.loop,
    required this.shuffle,
    required this.maxWorkTimeSec,
    required this.workElapsedSec,
    required this.panelW,
  });

  @override
  Widget build(BuildContext context) {
    final double catFontSize = (panelW * 0.12).clamp(9.0, 15.0);
    final double nameFontSize = (panelW * 0.20).clamp(14.0, 26.0);
    final double authFontSize = (panelW * 0.12).clamp(9.0, 15.0);
    final double badgeFontSize = (panelW * 0.10).clamp(8.0, 13.0);
    final double badgeIconSize = (panelW * 0.12).clamp(9.0, 14.0);
    final double spacing = (panelW * 0.03).clamp(2.0, 5.0);
    final double badgeSpacing = (panelW * 0.04).clamp(3.0, 6.0);
    final double maxTextW = panelW - 8;

    // ノート風デザイン定数
    const Color noteBg = Color(0xFFFFFDE7); // クリーム（黄みがかった白）
    const Color noteRuleLine = Color(0xFFBBDEFB); // 薄青の横罫線
    const Color noteMargin = Color(0xFFEF9A9A); // 赤のマージン縦線
    const double marginLineX = 12.0;
    const double ruleHeight = 0.6;
    const double ruleSpacing = 2.5;

    return Container(
      width: panelW,
      decoration: BoxDecoration(
        color: noteBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Stack(
        children: [
          // マージン縦線（左端）
          Positioned(
            left: marginLineX,
            top: 0,
            bottom: 0,
            child: Container(width: 1.0, color: noteMargin),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(marginLineX + 6, 6, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // カテゴリ
                SizedBox(
                  width: maxTextW,
                  child: Text(
                    model.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: catFontSize,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: ruleSpacing),
                Container(height: ruleHeight, color: noteRuleLine),
                SizedBox(height: spacing),
                // モデル名
                SizedBox(
                  width: maxTextW,
                  child: Text(
                    model.modelName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: nameFontSize,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: ruleSpacing),
                Container(height: ruleHeight, color: noteRuleLine),
                // 作者
                if (model.authorName.isNotEmpty) ...[
                  SizedBox(height: spacing),
                  SizedBox(
                    width: maxTextW,
                    child: Text(
                      '${AppStrings.drawingAuthorPrefix}${model.authorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: authFontSize,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  SizedBox(height: ruleSpacing),
                  Container(height: ruleHeight, color: noteRuleLine),
                ],
                // ループ・シャッフル・最大作業時間バッジ
                if (loop || shuffle || maxWorkTimeSec > 0) ...[
                  SizedBox(height: spacing * 2),
                  // 3つすべてONの場合は2段構成：上段に最大作業時間、下段にループ＋シャッフル
                  if (maxWorkTimeSec > 0 && (loop || shuffle)) ...[
                    Wrap(
                      spacing: badgeSpacing,
                      runSpacing: badgeSpacing,
                      children: [
                        _StatusBadge(
                          icon: Icons.hourglass_bottom,
                          label: (maxWorkTimeSec - workElapsedSec)
                              .clamp(0, maxWorkTimeSec)
                              .toDisplayDuration(),
                          fontSize: badgeFontSize,
                          iconSize: badgeIconSize,
                        ),
                      ],
                    ),
                    SizedBox(height: badgeSpacing),
                    Wrap(
                      spacing: badgeSpacing,
                      runSpacing: badgeSpacing,
                      children: [
                        if (loop)
                          _StatusBadge(
                            icon: Icons.repeat,
                            label: AppStrings.drawingLoopBadge,
                            fontSize: badgeFontSize,
                            iconSize: badgeIconSize,
                          ),
                        if (shuffle)
                          _StatusBadge(
                            icon: Icons.shuffle,
                            label: AppStrings.drawingShuffleBadge,
                            fontSize: badgeFontSize,
                            iconSize: badgeIconSize,
                          ),
                      ],
                    ),
                  ] else ...[
                    Wrap(
                      spacing: badgeSpacing,
                      runSpacing: badgeSpacing,
                      children: [
                        if (loop)
                          _StatusBadge(
                            icon: Icons.repeat,
                            label: AppStrings.drawingLoopBadge,
                            fontSize: badgeFontSize,
                            iconSize: badgeIconSize,
                          ),
                        if (shuffle)
                          _StatusBadge(
                            icon: Icons.shuffle,
                            label: AppStrings.drawingShuffleBadge,
                            fontSize: badgeFontSize,
                            iconSize: badgeIconSize,
                          ),
                        if (maxWorkTimeSec > 0)
                          _StatusBadge(
                            icon: Icons.hourglass_bottom,
                            label: (maxWorkTimeSec - workElapsedSec)
                                .clamp(0, maxWorkTimeSec)
                                .toDisplayDuration(),
                            fontSize: badgeFontSize,
                            iconSize: badgeIconSize,
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 右帯：円形タイマー
// ══════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════
// 円形カウントダウンタイマー
// 残り5秒以下でアニメーション演出（パルス・色変化・背景フラッシュ）
// ══════════════════════════════════════════════════════════
class _CircularCountdownTimer extends StatefulWidget {
  final int remaining;
  final int durationSec;
  final bool isPaused;
  final double size;

  const _CircularCountdownTimer({
    required this.remaining,
    required this.durationSec,
    required this.isPaused,
    required this.size,
  });

  @override
  State<_CircularCountdownTimer> createState() =>
      _CircularCountdownTimerState();
}

class _CircularCountdownTimerState extends State<_CircularCountdownTimer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim; // 数字のスケール 1.0→1.35→1.0
  late final Animation<double> _flashAnim; // 背景フラッシュ opacity 0.0→0.4→0.0

  // アニメーションをトリガーする閾値（秒）
  static const int _alertThreshold = 5;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 60),
    ]).animate(_pulseCtrl);
    _flashAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.4)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.4, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 70),
    ]).animate(_pulseCtrl);
  }

  @override
  void didUpdateWidget(_CircularCountdownTimer old) {
    super.didUpdateWidget(old);
    // 残り秒数が変化 & アラート閾値以内 & 再生中 → パルス発火
    if (old.remaining != widget.remaining &&
        widget.remaining <= _alertThreshold &&
        widget.remaining > 0 &&
        !widget.isPaused) {
      _pulseCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // 残り秒数に応じたリングカラー
  Color _ringColor() {
    if (widget.isPaused) return Colors.grey.shade400;
    if (widget.remaining <= 2) return Colors.red.shade400;
    if (widget.remaining <= _alertThreshold) return Colors.orange.shade400;
    return AppColors.theme;
  }

  // 残り秒数に応じた数字カラー
  Color _numColor() {
    if (widget.isPaused) return Colors.grey.shade500;
    if (widget.remaining <= 2) return Colors.red.shade400;
    if (widget.remaining <= _alertThreshold) return Colors.orange.shade400;
    return AppColors.theme;
  }

  // フラッシュ背景カラー（アラート時のみ有彩色）
  Color _flashColor() {
    if (widget.remaining <= 2) return Colors.red.shade200;
    return Colors.orange.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final double progress =
        widget.durationSec > 0 ? widget.remaining / widget.durationSec : 0.0;
    final double strokeWidth = (widget.size * 0.07).clamp(4.0, 8.0);
    final double numFontSize = (widget.size * 0.30).clamp(18.0, 36.0);
    final double labelFontSize = (widget.size * 0.13).clamp(9.0, 15.0);
    final bool isAlert =
        widget.remaining <= _alertThreshold && !widget.isPaused;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── ベース背景 ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.themeLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.themeBorder, width: 1),
                ),
              ),
              // ── フラッシュ背景（アラート時のみ表示） ────
              if (isAlert)
                Opacity(
                  opacity: _flashAnim.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _flashColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              // ── プログレスリング ─────────────────────────
              CircularProgressIndicator(
                value: progress,
                strokeWidth: strokeWidth,
                backgroundColor: AppColors.themeBorder,
                valueColor: AlwaysStoppedAnimation<Color>(_ringColor()),
              ),
              // ── 数字・ラベル（アラート時はパルス） ───────
              Center(
                child: Transform.scale(
                  scale: isAlert ? _scaleAnim.value : 1.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.remaining}',
                        style: TextStyle(
                          fontSize: numFontSize,
                          fontWeight: FontWeight.bold,
                          color: _numColor(),
                          height: 1.0,
                        ),
                      ),
                      Text(
                        widget.isPaused
                            ? AppStrings.drawingPauseLabel
                            : AppStrings.drawingSecLabel,
                        style: TextStyle(
                          fontSize: labelFontSize,
                          color: widget.isPaused
                              ? Colors.grey.shade400
                              : _ringColor().withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 開始カウントダウン表示
// ══════════════════════════════════════════════════════════
class _StartCountdownDisplay extends StatelessWidget {
  final int countdown;

  const _StartCountdownDisplay({required this.countdown});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.drawingCountdownLabel,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TweenAnimationBuilder<double>(
          key: ValueKey(countdown),
          tween: Tween(begin: 1.2, end: 0.8),
          duration: const Duration(milliseconds: 800),
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Text(
            '$countdown',
            style: const TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.bold,
              color: AppColors.theme,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 0.5秒表示モデル名ラベル
// 前半300ms：完全表示、後半200ms：AnimatedOpacityでフェードアウト
// ══════════════════════════════════════════════════════════
class _ModelNameLabelDisplay extends StatelessWidget {
  final String modelName;
  final bool isFadingOut;

  const _ModelNameLabelDisplay({
    required this.modelName,
    required this.isFadingOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isFadingOut ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Text(
        modelName,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: AppColors.theme,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 終了画面
// ══════════════════════════════════════════════════════════
class _EndScreen extends StatefulWidget {
  final int totalCount;
  final bool isTimeUp;
  final VoidCallback onRestart;

  const _EndScreen({
    required this.totalCount,
    required this.onRestart,
    this.isTimeUp = false,
  });

  @override
  State<_EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<_EndScreen>
    with SingleTickerProviderStateMixin {
  late final String _message;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // ── ランダムメッセージ選択（重み付き・直前と被らない） ──
  // 直前に出たメッセージを避けるために static で保持する。
  // アプリ起動中に複数回 _EndScreen が生成される場合の重複回避。
  static int? _lastIndex;

  static String _pickMessage() {
    final defs = DrawingConfig.endMessages;
    final messages = AppStrings.drawingEndMessages;

    // 直前と被らない候補でweightedRandomを行う
    List<DrawingEndMessageDef> candidates =
        defs.where((d) => d.index != _lastIndex).toList();

    // 万が一候補が空になった場合（定義が1件のみ等）は全件対象
    if (candidates.isEmpty) candidates = List.of(defs);

    // 累積重みテーブルを作成
    final totalWeight = candidates.fold(0, (sum, d) => sum + d.weightValue);
    final rand = Random().nextInt(totalWeight);
    int cumulative = 0;
    for (final d in candidates) {
      cumulative += d.weightValue;
      if (rand < cumulative) {
        _lastIndex = d.index;
        return messages[d.index];
      }
    }
    // フォールバック（通常は到達しない）
    _lastIndex = candidates.last.index;
    return messages[candidates.last.index];
  }

  @override
  void initState() {
    super.initState();
    _message = _pickMessage();

    // 0.2秒で opacity 0.2 → 1.0 のフェードイン
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn),
    );
    // 次フレームで即開始（FINISH!! 表示後に自然にフェードイン）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // FINISH!! は最初から表示
        Text(
          AppStrings.drawingEndLabel,
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: AppColors.theme,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 8),
        // サブメッセージはフェードイン
        AnimatedBuilder(
          animation: _fadeAnim,
          builder: (context, child) => Opacity(
            opacity: _fadeAnim.value,
            child: child,
          ),
          child: Text(
            _message,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.theme.withAlpha(180),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.isTimeUp
              ? AppStrings.drawingEndTimeUpMessage
              : '${AppStrings.drawingEndCompletePrefix}${widget.totalCount}${AppStrings.drawingEndCompleteSuffix}',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.theme,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: widget.onRestart,
          icon: const Icon(Icons.replay),
          label: Text(
            AppStrings.drawingRestartButton,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 24),
        FeedbackLinkWidget(
          prompt: AppStrings.feedbackLinkPromptDrawingEnd,
          label: AppStrings.feedbackLinkLabelDrawingEnd,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// ステータスバッジ（ループ・シャッフル表示用）
// ══════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final double fontSize;
  final double iconSize;

  const _StatusBadge({
    required this.icon,
    required this.label,
    this.fontSize = 10,
    this.iconSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.themeLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.themeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: AppColors.theme),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(fontSize: fontSize, color: AppColors.theme)),
        ],
      ),
    );
  }
}
