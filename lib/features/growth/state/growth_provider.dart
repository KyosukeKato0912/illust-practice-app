import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import '../../../core/config/growth_config.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/testdata/growth_testdata.dart';
import '../domain/growth_record.dart';
import '../domain/growth_repository.dart';
import '../domain/growth_streak_utils.dart';
import '../domain/practice_day.dart';
import 'growth_practice_log_provider.dart';

// ══════════════════════════════════════════════════════════
// GrowthMaxCountFlagNotifier / growthMaxCountReachedProvider
//
// 保持上限枚数（GrowthConfig.maxRecordCount）に一度でも到達したことが
// あるかどうかの永続フラグを、UIからリアクティブに参照できるように
// StateNotifierとして公開する。
//
// 実体はGrowthRepository経由でHive（GrowthMetaDataSource）に保存されて
// いる同じフラグ。GrowthNotifier側のイベント（上限到達・デバッグ用の
// フラグリセット）が起きた際に、このProviderの state もあわせて
// 更新することで、AppBarやボタンの表示・非表示をその場で切り替えられる
// ようにしている。
// ══════════════════════════════════════════════════════════
class GrowthMaxCountFlagNotifier extends StateNotifier<bool> {
  final GrowthRepository _repository;

  GrowthMaxCountFlagNotifier({GrowthRepository? repository})
      : _repository = repository ?? GrowthRepository(),
        super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await _repository.hasReachedMaxCountOnce();
  }

  void markReached() => state = true;

  void reset() => state = false;
}

final growthMaxCountReachedProvider =
    StateNotifierProvider<GrowthMaxCountFlagNotifier, bool>((ref) {
  return GrowthMaxCountFlagNotifier();
});

// ══════════════════════════════════════════════════════════
// GrowthPdfNewBadgeNotifier / growthPdfNewBadgeSeenProvider
//
// PDFボタンの「NEW」表示を既に見た（＝タップした）ことがあるかどうかの
// 永続フラグ。false の間、成長記録メイン画面のPDFボタンに「NEW」を表示する
// （＝保持上限に初めて到達してから、PDFボタンを初めてタップするまでの間）。
// ══════════════════════════════════════════════════════════
class GrowthPdfNewBadgeNotifier extends StateNotifier<bool> {
  final GrowthRepository _repository;

  GrowthPdfNewBadgeNotifier({GrowthRepository? repository})
      : _repository = repository ?? GrowthRepository(),
        super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await _repository.hasSeenPdfNewBadge();
  }

  Future<void> markSeen() async {
    if (state) return;
    await _repository.markSeenPdfNewBadge();
    state = true;
  }

  /// 【検証用】GrowthNotifier.setMaxCountReachedFlagForDebug(false) が
  /// フラグをOFFにした際に呼ばれ、「NEW」を再度見せられる状態に戻す。
  void resetForDebug() => state = false;
}

final growthPdfNewBadgeSeenProvider =
    StateNotifierProvider<GrowthPdfNewBadgeNotifier, bool>((ref) {
  return GrowthPdfNewBadgeNotifier();
});

// ══════════════════════════════════════════════════════════
// GrowthMaxRecordCountNotifier / growthMaxRecordCountProvider
//
// 保持上限枚数の「実際に判定・削除処理で使う値」。
// GrowthConfig.maxRecordCount（リリース時の初期値）をアプリ起動時の
// 初期値として持ち、メンテナンス画面から検証用に上書きできるように
// するためのProvider。
//
// ⚠ この値はどこにも永続化しない（アプリ再起動で必ず
//   GrowthConfig.maxRecordCount の値に戻る）。GrowthNotifier は
//   アップロード確定のたびにこの値を読み取り、GrowthRepository の
//   上限判定・自動削除処理へ明示的に渡す。
// ══════════════════════════════════════════════════════════
class GrowthMaxRecordCountNotifier extends StateNotifier<int> {
  GrowthMaxRecordCountNotifier() : super(GrowthConfig.maxRecordCount);

  void setValue(int value) => state = value;

  /// 【検証用】メンテナンス画面の「初期状態に戻す」から呼ばれる。
  void resetToDefault() => state = GrowthConfig.maxRecordCount;
}

final growthMaxRecordCountProvider =
    StateNotifierProvider<GrowthMaxRecordCountNotifier, int>((ref) {
  return GrowthMaxRecordCountNotifier();
});

// ══════════════════════════════════════════════════════════
// GrowthNotifier / growthProvider
//
// 成長記録リストの状態管理。GrowthMainScreen・UploadScreenの
// 両方から参照されるため（画面をまたいで一覧を保持する必要があるため）
// Riverpod StateNotifierとして実装する。
//
// ui/ からは本Providerのみを参照し、GrowthRepository・
// GrowthDataSource・Hiveを直接操作しない。
//
// ⚠ 現フェーズ：
//   ・「写真で追加」（ギャラリー選択）・「カメラで追加」（撮影）の
//     両方を実装。picker種別（ImageSource）が異なるだけで、
//     保存処理（_saveRecord）は共通化している
//   ・UploadScreen側でプレビュー表示を挟むため、「画像を選ぶ」
//     （[pickImageFromGallery]／[pickImageFromCamera]）と
//     「保存を確定する」（[confirmUpload]）を別メソッドに分離している。
//     選択直後はHive・ファイルへの書き込みを一切行わず、[confirmUpload]
//     が呼ばれて初めて実際の保存処理（_saveRecord）が走る。
//   ・所要時間（分・任意入力）は uploadScreen 側でバリデーション済みの
//     int?（durationMin）として受け取り、そのままファイル名・
//     GrowthRecordに反映する
//   ・保持枚数の上限は [GrowthConfig.maxRecordCount]。上限を超えて
//     アップロードすると最古の1件が自動削除される（Hiveレコード・
//     画像ファイルの両方）
//   ・上限到達時は growthMaxCountReachedProvider の state も更新し、
//     PDFダウンロードボタンの表示条件（フラグが立っている間のみ表示）
//     に反映する
//   ・growthDataSourceModeProvider が test/merged の間は [_loadAll]（初期
//     読み込み・追加/削除後の再読込のいずれも）が
//     shared/testdata/growth_testdata.dart のテストデータを（mergedの
//     場合は実データと合わせて）返す。アップロード自体は通常どおり
//     Hiveに保存されるが、直後の _loadAll でテストデータ（実データとの
//     合算を含む）に上書き表示される点に注意
//     （テストデータ表示中は常に同じ内容を見せる一貫性を優先した設計）。
// ══════════════════════════════════════════════════════════
class GrowthNotifier extends StateNotifier<List<GrowthRecord>> {
  final GrowthRepository _repository;
  final ImagePicker _picker = ImagePicker();
  final Ref _ref;

  GrowthNotifier(this._ref, {GrowthRepository? repository})
      : _repository = repository ?? GrowthRepository(),
        super(const []) {
    _loadAll();
  }

  Future<void> _loadAll() async {
    final mode = _ref.read(growthDataSourceModeProvider);
    switch (mode) {
      case GrowthDataSourceMode.real:
        state = await _repository.getAll();
        break;
      case GrowthDataSourceMode.test:
        state = await _ref.read(growthTestDataProvider.future);
        break;
      case GrowthDataSourceMode.merged:
        final testRecords = await _ref.read(growthTestDataProvider.future);
        final realRecords = await _repository.getAll();
        state = [...testRecords, ...realRecords];
        break;
    }
  }

  /// ギャラリーから画像を選択する（保存は行わない）。
  /// 呼び出し側（UploadScreen）がプレビュー表示用に結果を保持し、
  /// 「確定」タップ時に [confirmUpload] へそのまま渡す。
  /// 選択がキャンセルされた場合は null を返す。
  Future<XFile?> pickImageFromGallery() {
    return _picker.pickImage(source: ImageSource.gallery);
  }

  /// カメラを起動して撮影する（保存は行わない）。
  /// 撮影がキャンセルされた場合は null を返す。
  /// 意味は [pickImageFromGallery] と同じ。
  Future<XFile?> pickImageFromCamera() {
    return _picker.pickImage(source: ImageSource.camera);
  }

  /// プレビュー中の画像（[pickImageFromGallery]／[pickImageFromCamera] で
  /// 取得したもの）を確定して保存する。
  /// [durationMin] は所要時間（分・任意）。呼び出し側でバリデーション
  /// 済みの値を渡すこと。
  ///
  /// 戻り値は次のフラグをまとめたレコード：
  ///   ・isMaxCountReached … 今回のアップロードで保持枚数が上限
  ///     （[GrowthConfig.maxRecordCount]）に「生涯で初めて」到達したか。
  ///     一度到達した後は、削除して枚数が減り再度上限に達しても false に
  ///     なる（特別メッセージは初回到達時のみ表示するため）。
  ///   ・isStreakMilestoneReached … 今日を含めた連続アップロード日数が
  ///     ちょうど [GrowthConfig.streakMilestoneDays] に達したか。
  ///     こちらは「生涯で一度」ではなく、連続記録が途切れて再度
  ///     ちょうどその日数に達した場合は再び true になる。
  ///
  ///   以下はアップロード完了画面の演出アニメーション（フェードイン）を
  ///   発生させるかどうかの判定専用フラグ。いずれも「今回の保存が
  ///   その日の最初のアップロードかどうか」等の一回性を踏まえており、
  ///   同じ日に2回目以降アップロードした場合に演出が再発生しないように
  ///   している（表示内容そのものの有無は isMaxCountReached /
  ///   isStreakMilestoneReached が従来どおり決める）。
  ///   ・showFlowerFadeIn … 花丸（今日のセル）をフェードイン表示するか。
  ///     その日の最初のアップロード（保存前は今日の継続カレンダーが空欄）の時のみ true。
  ///   ・showColorFadeIn … 継続カレンダーの今日のセルの色をフェードで
  ///     変化させるか。その日の最初のアップロードかつ、昨日時点の色
  ///     （[GrowthStreakUtils.colorAt]）と今日時点の色が異なる場合
  ///     （＝2日目で白→薄い黄色、streakMilestoneDays日目で薄い黄色→
  ///     濃い黄色になる場合）のみ true。
  ///   ・showMessageFadeIn … 特別メッセージをフェードイン表示するか。
  ///   ・showPdfButtonFadeIn … PDFボタンをフェードイン表示するか
  ///     （isMaxCountReachedと同じ条件）。
  Future<
      ({
        bool isMaxCountReached,
        bool isStreakMilestoneReached,
        bool showFlowerFadeIn,
        bool showColorFadeIn,
        bool showMessageFadeIn,
        bool showPdfButtonFadeIn,
      })> confirmUpload(XFile picked, {int? durationMin}) {
    return _saveRecord(picked, durationMin: durationMin);
  }

  Future<
      ({
        bool isMaxCountReached,
        bool isStreakMilestoneReached,
        bool showFlowerFadeIn,
        bool showColorFadeIn,
        bool showMessageFadeIn,
        bool showPdfButtonFadeIn,
      })> _saveRecord(XFile picked, {int? durationMin}) async {
    // メンテナンス画面での上書きを反映した「実際に使う」保持上限枚数。
    // 上書きが無ければ GrowthConfig.maxRecordCount のまま。
    final maxRecordCount = _ref.read(growthMaxRecordCountProvider);
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    final serialNumber = await _repository.nextSerialNumberForDate(date);

    final dotIndex = picked.path.lastIndexOf('.');
    final extension =
        dotIndex != -1 ? picked.path.substring(dotIndex + 1) : 'jpg';

    final savedPath = await AppFileUtils.growthImageFilePath(
      date: date,
      serialNumber: serialNumber,
      durationMin: durationMin,
      extension: extension,
    );
    await File(picked.path).copy(savedPath);

    final record = GrowthRecord(
      id: '${now.microsecondsSinceEpoch}',
      imagePath: savedPath,
      date: date,
      serialNumber: serialNumber,
      durationMin: durationMin,
    );

    // 今回の保存「前」の時点で、今日の継続カレンダーに既に記録（花丸）が
    // あったかどうか。表示中のデータソース（実データ／テストデータ／併用）
    // に合わせて判定する（growthPracticeDaysProvider と同じ考え方）。
    // ⚠ serialNumber == 1 では判定できない：連番は削除しても再利用されず
    //   日ごとに増え続けるため、同じ日に削除→再アップロードすると2以上に
    //   なり「その日の最初」を正しく表さない。
    final hadRecordToday = await _hadPracticeRecordOn(date);

    final evicted =
        await _repository.add(record, maxCount: maxRecordCount);
    // 上限超過で自動削除された記録は、Hive上だけでなく画像ファイル
    // 実体も削除する（GrowthRepository.add はファイルI/Oを行わないため）
    for (final r in evicted) {
      final file = File(r.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _loadAll();
    // 継続カレンダー用の練習日記録も更新する（アップロード完了画面が
    // 表示される時点で最新の状態になっているようにするため、ここで待つ）
    await _ref.read(growthPracticeLogProvider.notifier).reload();

    // 「生涯で初めて上限に到達したか」はRepository側の永続フラグで判定する
    // （現在の生存件数だけでは、削除→再アップロードでの再到達と
    // 区別できないため）
    // 判定に使う枚数は「一覧画面に表示されている枚数」（_loadAll 済みの
    // state）。併用モードではテストデータ分も含むため、テストデータで
    // 作った枚数と合わせて上限到達を検証できる。
    final reachedFirstTime = await _repository.checkFirstTimeReachedMax(
      maxCount: maxRecordCount,
      currentCount: state.length,
    );
    if (reachedFirstTime) {
      _ref.read(growthMaxCountReachedProvider.notifier).markReached();
    }

    // 今日を含めた連続アップロード日数が、ちょうど
    // GrowthConfig.streakMilestoneDays に達したかどうかを判定する。
    final practiceDays = _ref.read(growthPracticeDaysProvider);
    final currentStreak = _currentStreakLength(practiceDays, date);
    final streakMilestoneReached =
        currentStreak == GrowthConfig.streakMilestoneDays;

    // ── 演出アニメーションの発生判定 ──────────────────────
    // その日の最初のアップロードかどうか（今回の保存前は今日の記録が
    // 無く、継続カレンダー上で空欄から花丸に切り替わる場合のみ true）。
    final isFirstUploadOfToday = !hadRecordToday;

    // 「昨日時点の色」と「今日時点の色」を比較し、今日のセルの色が
    // 実際に変わる場合のみ色変えアニメーション対象とする
    // （例：2日目＝白→薄い黄色、21日目＝薄い黄色→濃い黄色。
    // 3〜20日目などブラケットが変わらない日は対象外）。
    final recordedDateKeys = <String>{
      for (final d in practiceDays) AppDateUtils.dateKey(d.date),
    };
    // ⚠ 「昨日時点の色」は今日の記録を除いた集合で求める。今日を含む集合の
    //   まま昨日のspanを数えると、連続区間の「先」にある今日まで含めて
    //   数えてしまい（spanAtは前後両方向に数える）、今日と同じ色になって
    //   色変けが一切発生しなくなる。
    final keysBeforeToday = {...recordedDateKeys}
      ..remove(AppDateUtils.dateKey(date));
    final yesterday = date.subtract(const Duration(days: 1));
    final colorBefore =
        GrowthStreakUtils.colorAt(yesterday, keysBeforeToday);
    final colorAfter = GrowthStreakUtils.colorAt(date, recordedDateKeys);

    final showFlowerFadeIn = isFirstUploadOfToday;
    final showColorFadeIn =
        isFirstUploadOfToday && colorBefore != colorAfter;
    final showMessageFadeIn =
        (isFirstUploadOfToday && streakMilestoneReached) || reachedFirstTime;
    final showPdfButtonFadeIn = reachedFirstTime;

    return (
      isMaxCountReached: reachedFirstTime,
      isStreakMilestoneReached: streakMilestoneReached,
      showFlowerFadeIn: showFlowerFadeIn,
      showColorFadeIn: showColorFadeIn,
      showMessageFadeIn: showMessageFadeIn,
      showPdfButtonFadeIn: showPdfButtonFadeIn,
    );
  }

  /// 保存前の時点で、[date] の継続カレンダーに記録があったか
  /// （現在のデータソースモードに応じて実データ／テストデータ／併用で判定）。
  Future<bool> _hadPracticeRecordOn(DateTime date) async {
    final key = AppDateUtils.dateKey(date);
    final mode = _ref.read(growthDataSourceModeProvider);
    final realDays = await _repository.getPracticeDays();
    List<PracticeDay> days = realDays;
    if (mode != GrowthDataSourceMode.real) {
      final testDays = PracticeDay.fromRecords(
          await _ref.read(growthTestDataProvider.future));
      days = mode == GrowthDataSourceMode.test
          ? testDays
          : PracticeDay.merge(testDays, realDays);
    }
    return days.any(
        (d) => AppDateUtils.dateKey(d.date) == key && d.uploadCount > 0);
  }

  /// [today] を含めて何日連続で記録があるかを数える（記録が途切れた
  /// 時点で打ち切り）。
  int _currentStreakLength(List<PracticeDay> days, DateTime today) {
    final keys = {for (final d in days) AppDateUtils.dateKey(d.date)};
    var count = 0;
    var cursor = today;
    while (keys.contains(AppDateUtils.dateKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// 指定したidの成長記録をまとめて削除する。
  /// Hiveのレコード削除に加え、端末ローカルの画像ファイルも削除する。
  Future<void> deleteRecords(List<String> ids) async {
    final idsToDelete = ids.toSet();
    final targets = state.where((r) => idsToDelete.contains(r.id)).toList();

    for (final record in targets) {
      await _repository.delete(record.id);
      final file = File(record.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _loadAll();
  }

  /// 指定したidの成長記録画像を端末のギャラリーに保存する。
  /// 保存に成功した件数を返す（失敗したものはスキップして続行する）。
  Future<int> downloadRecords(List<String> ids) async {
    final idsToDownload = ids.toSet();
    final targets = state.where((r) => idsToDownload.contains(r.id)).toList();

    var successCount = 0;
    for (final record in targets) {
      try {
        await Gal.putImage(record.imagePath, album: 'GrowthRecord');
        successCount++;
      } catch (_) {
        // 個別の失敗はスキップし、残りの保存を続行する
      }
    }
    return successCount;
  }

  /// 【検証用】保持上限到達フラグを明示的にON/OFF設定する。
  /// features/maintenance/ui/maintenance_screen.dart から呼び出される想定。
  Future<void> setMaxCountReachedFlagForDebug(bool value) async {
    await _repository.setMaxCountReachedFlagForDebug(value);
    if (value) {
      _ref.read(growthMaxCountReachedProvider.notifier).markReached();
    } else {
      _ref.read(growthMaxCountReachedProvider.notifier).reset();
      // フラグOFFにあわせて「NEW」既読フラグも巻き戻す（再検証用）。
      _ref.read(growthPdfNewBadgeSeenProvider.notifier).resetForDebug();
    }
  }
}

final growthProvider =
    StateNotifierProvider<GrowthNotifier, List<GrowthRecord>>((ref) {
  return GrowthNotifier(ref);
});
