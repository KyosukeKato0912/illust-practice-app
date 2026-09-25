import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import '../../../core/config/growth_config.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/testdata/growth_testdata.dart';
import '../domain/growth_record.dart';
import '../domain/growth_repository.dart';
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
//   ・GrowthConfig.useTestData が true の間は [_loadAll]（初期読み込み・
//     追加/削除後の再読込のいずれも）が shared/testdata/growth_testdata.dart
//     のテストデータを返す。アップロード自体は通常どおりHiveに保存
//     されるが、直後の _loadAll でテストデータに上書き表示される点に注意
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
    state = GrowthConfig.useTestData
        ? await _ref.read(growthTestDataProvider.future)
        : await _repository.getAll();
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
  /// 戻り値は今回のアップロードで保持枚数が上限
  /// （[GrowthConfig.maxRecordCount]）に「生涯で初めて」到達したかどうか。
  /// 一度到達した後は、削除して枚数が減り再度上限に達しても false になる
  /// （特別メッセージは初回到達時のみ表示するため）。
  Future<bool> confirmUpload(XFile picked, {int? durationMin}) {
    return _saveRecord(picked, durationMin: durationMin);
  }

  Future<bool> _saveRecord(XFile picked, {int? durationMin}) async {
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

    final evicted = await _repository.add(record);
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
    final reachedFirstTime = await _repository.checkFirstTimeReachedMax();
    if (reachedFirstTime) {
      _ref.read(growthMaxCountReachedProvider.notifier).markReached();
    }
    return reachedFirstTime;
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

  /// 【検証用】保持上限到達フラグをON/OFF切り替える。
  /// GrowthConfig.showDebugMaxCountReachedToggleButton が true の間のみ、
  /// UI（成長記録メイン画面）から呼び出される想定。
  Future<void> toggleMaxCountReachedFlagForDebug() async {
    final next = !_ref.read(growthMaxCountReachedProvider);
    await _repository.setMaxCountReachedFlagForDebug(next);
    if (next) {
      _ref.read(growthMaxCountReachedProvider.notifier).markReached();
    } else {
      _ref.read(growthMaxCountReachedProvider.notifier).reset();
    }
  }
}

final growthProvider =
    StateNotifierProvider<GrowthNotifier, List<GrowthRecord>>((ref) {
  return GrowthNotifier(ref);
});
