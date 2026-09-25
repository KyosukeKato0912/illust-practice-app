// ══════════════════════════════════════════════════════════
// アプリ全体のUI文字列定数
//
// ハードコード文字列を排除し、将来の多言語化（l10n）に備える。
// ══════════════════════════════════════════════════════════
abstract class AppStrings {
  // ── アプリ共通 ──────────────────────────────────────────
  static const String appTitle = 'イラスト練習支援アプリ(仮)';

  // ── ホーム画面 ──────────────────────────────────────────
  static const String homeTitle = 'メイン';
  static const String featureDrawing = 'X秒ドローイング';
  static const String featureTopic = 'お題ジェネレーター';
  static const String featureGrowth = '成長記録';
  static const String featureHabit = '習慣化サポート';
  static const String featureProLesson = 'プロ絵師解説';
  static const String featureComingSoon = '準備中';

  // ── X秒ドローイング ─────────────────────────────────────
  static const String drawingInitialTitle = 'X秒ドローイング準備';
  static const String drawingMainTitle = 'X秒ドローイング';
  static const String drawingSettingsTitle = 'X秒ドローイング設定';
  static const String drawingModelListTitle = 'X秒ドローイングモデル一覧';
  static const String enlargeViewTitle = '拡大表示';

  static const String drawingStartPrompt = 'X秒ドローイングを開始しますか？';
  static const String drawingStartDescription =
      '開始すると3秒のカウントダウン後に\n画像が自動再生されます';
  static const String drawingStartButton = 'すぐに開始';
  static const String drawingLoadingButton = '画像を読み込み中...';
  static const String drawingModelListButton = 'モデル一覧';
  static const String drawingSettingsButton = '設定';

  static const String drawingCountdownLabel = 'まもなく開始します';
  static const String drawingEndLabel = 'FINISH!!';
  static const String drawingRestartButton = '最初から';
  static const String drawingPauseLabel = '停止';
  static const String drawingSecLabel = '秒';
  static const String drawingPinchHint = 'ピンチ操作で拡大・縮小できます';

  static const String drawingSavedSettings = '保存済みの設定';
  static const String drawingDefaultSettings = 'デフォルト設定';
  static const String drawingAllCategories = '全カテゴリ';
  static const String drawingLoopBadge = 'ループ';
  static const String drawingShuffleBadge = 'シャッフル';
  static const String drawingRandomOrder = 'ランダム';
  static const String drawingRegisteredOrder = '登録順';

  static const String drawingSettingsMaxTimeTitle = '⏳ 最大作業時間';
  static const String drawingSettingsMaxTimeUnlimited = '無制限';
  static const String drawingSettingsDurationTitle = '⏱ 画像切り替え時間';
  static const String drawingSettingsLoopTitle = '🔁 ループ再生';
  static const String drawingSettingsShuffleTitle = '🔀 再生順序';
  static const String drawingSettingsCategoryTitle = '🗂 表示するカテゴリ';
  static const String drawingSettingsSaveButton = '保存';
  static const String drawingSettingsSaveAndStartButton = '保存して開始';
  static const String drawingSettingsSaved = '設定を保存しました';
  static const String drawingSettingsReset = '設定を初期値に戻しました';
  static const String drawingSettingsResetTitle = '設定を初期値に戻す';
  static const String drawingSettingsResetMessage =
      'すべての設定をデフォルト値に戻します。よろしいですか？';
  static const String drawingSettingsCategoryWarning = '⚠ カテゴリを1つ以上選択してください';
  static const String drawingSettingsSelectAll = 'すべて選択';

  // ── X秒ドローイング 設定説明テキスト ────────────────────
  static const String drawingLoopOnTitle = 'ループあり';
  static const String drawingLoopOffTitle = 'ループなし';
  static const String drawingLoopOnDesc = '最後の画像の後、最初に戻って繰り返します';
  static const String drawingLoopOffDesc = '最後の画像で停止します';
  static const String drawingShuffleOnDesc = '画像をランダムな順番で再生します';
  static const String drawingShuffleOffDesc = '画像を登録された順番で再生します';
  static const String drawingMaxTimeUnlimitedDesc = '時間制限なしで再生します';
  static const String drawingMaxTimeLimitedDesc = '指定時間が経過すると終了します';

  // ── X秒ドローイング 設定サマリーチップ ──────────────────
  static const String drawingSummaryDurationPrefix = '切替'; // 切替: X秒
  static const String drawingSummaryMaxTimePrefix = '上限'; // 上限: X分 / 無制限

  static const String drawingPrevLabel = '前の画像';
  static const String drawingNextLabel = '次の画像';
  static const String drawingToggleHeightButton = '頭身切り替え';
  static const String drawingNoPairLabel = 'ペアなし';
  static const String drawingAuthorPrefix = '作者：';

  // ── X秒ドローイング 終了画面 ─────────────────────────────
  /// 最大作業時間超過による終了メッセージ
  static const String drawingEndTimeUpMessage = '最大作業時間に達しました';

  /// 全枚数完了メッセージのプレフィックス（後ろに枚数と suffix が続く）
  static const String drawingEndCompletePrefix = '全 ';

  /// 全枚数完了メッセージのサフィックス
  static const String drawingEndCompleteSuffix = ' 枚 完了';

  /// 終了時にランダム表示するサブメッセージ一覧。
  /// インデックスは DrawingConfig.endMessages の index フィールドと対応する。
  static const List<String> drawingEndMessages = [
    '今日も一歩前進', // index: 0
    'お疲れ様でした', // index: 1
    'よく頑張りました', // index: 2
    'いいペースです', // index: 3
    '明日も少しずつ', // index: 4
  ];

  // ── モデル一覧 ──────────────────────────────────────────
  static const String modelListCategoryLabel = 'カテゴリ';
  static const String modelListCategoryAll = 'すべて';
  static const String modelListModelNameLabel = 'モデル名';
  static const String modelListModelNameHint = 'モデル名で絞り込み...';
  static const String modelListFilterClear = 'フィルターをクリア';
  static const String modelListEmptyFiltered = '条件に一致する画像が見つかりません';
  static const String modelListEmptyNoImages = '画像が見つかりません';
  static const String modelListLoadError = '画像の読み込みに失敗しました';

  // ── 習慣化サポート ──────────────────────────────────────
  static const String habitTitle = '習慣化サポート';

  // メリハリタイマーボタン（習慣化サポートメイン画面）
  static const String habitTimerButton = 'メリハリタイマー';
  static const String habitSettingsButton = '設定';

  /// 【検証用】継続カレンダー下の件数表示ラベル
  static const String habitDebugDataCountLabel = 'データ総数';
  static const String habitDebugDaysCountLabel = '記録日数';
  static const String habitDebugDataCountSuffix = '件';
  static const String habitDebugDaysCountSuffix = '日分';

  // メリハリタイマー画面
  static const String habitTimerTitle = 'メリハリタイマー';
  static const String habitTimerStart = '開始';
  static const String habitTimerPause = '一時停止';
  static const String habitTimerResume = '再開';
  static const String habitTimerReset = 'リセット';
  static const String habitCountDownLabel = '作業中';
  static const String habitCountUpLabel = '総作業時間';
  static const String habitCountUpResetDialogTitle = '総作業時間のリセット';
  static const String habitCountUpResetDialogMessage =
      '総作業時間が0になります。この操作は元に戻せません。総作業時間をリセットしますか？';
  static const String habitCountUpResetDialogConfirm = 'リセット';
  static const String habitCountUpResetDialogCancel = 'キャンセル';

  // 設定画面
  static const String habitSettingsTitle         = '習慣化サポート設定';
  static const String habitSettingsModeTitle     = '⏱ メリハリタイマーセット';
  static const String habitSettingsTimerTitle    = '⏱ 作業時間';
  static const String habitSettingsBreakTitle    = '☕ 休憩時間';
  static const String habitSettingsSaveButton    = '保存';
  static const String habitSettingsSaveAndStartButton = '保存して開始';
  static const String habitSettingsSaved         = '設定を保存しました';

  // メリハリタイマーセット選択
  static const String habitModePreset = '基本セット';
  static const String habitModeCustom = '自由に設定';
  static const String habitPresetDesc = '25分作業 + 5分休憩（ポモドーロ標準）';
  static const String habitCustomDesc = '作業時間と休憩時間を自由に設定';

  // 作業開始促進通知
  static const String habitReminderSectionTitle  = '🔔 作業開始促進通知';
  static const String habitReminderEnabledLabel  = '毎日通知を受け取る';
  static const String habitReminderEnabledDesc   = '設定した時刻に作業開始をお知らせします';
  static const String habitReminderDisabledDesc  = '通知はオフです';
  static const String habitReminderTimeLabel     = '通知時刻';

  // 復帰促進通知
  static const String habitComebackSectionTitle   = '📅 復帰促進通知';
  static const String habitComebackEnabledLabel   = '復帰促進通知を受け取る';
  static const String habitComebackEnabledDesc    = '練習が空いたときにお知らせします';
  static const String habitComebackDisabledDesc   = '通知はオフです';
  static const String habitComebackPeriodLabel    = '通知するまでの期間';

  // リセット
  static const String habitSettingsResetTitle   = '設定を初期値に戻す';
  static const String habitSettingsResetMessage = 'すべての設定をデフォルト値に戻します。よろしいですか？';
  static const String habitSettingsReset        = '設定を初期値に戻しました';

  // ── 習慣化サポート：正確なアラーム権限の案内ダイアログ ──
  static const String habitExactAlarmDialogTitle = 'アラーム権限が必要です';
  static const String habitExactAlarmDialogMessage =
      '設定した時刻ちょうどに作業開始通知を届けるため、'
      '「アラームとリマインダー」の権限を有効にしてください。\n\n'
      '「設定を開く」を押したあと、一覧からこのアプリを選んで'
      'スイッチをONにしてください。\n\n'
      '許可しない場合も通知は設定できますが、通知時刻が数分ずれることがあります。';
  static const String habitExactAlarmDialogOpenSettings = '設定を開く';

  // ── 通知（NotificationService）──────────────────────
  // チャンネル名・説明は Android の通知設定画面でユーザーに表示される。
  // チャンネルID・通知IDは識別子のため NotificationService 側で管理する。
  static const String notificationTimerChannelName = 'メリハリタイマー';
  static const String notificationTimerChannelDesc = 'メリハリタイマーのフェーズ切替通知';
  static const String notificationReminderChannelName = '作業開始促進';
  static const String notificationReminderChannelDesc = '毎日の作業開始を促す通知';

  static const String notificationWorkFinishedTitle = '作業終了 — 休憩を始めましょう';
  static const String notificationWorkFinishedMessage = '設定時間が経過しました。少し休憩しましょう！';
  static const String notificationBreakFinishedTitle = '休憩終了 — 作業を再開しましょう';
  static const String notificationBreakFinishedMessage = '休憩時間が終わりました。また頑張りましょう！';
  static const String notificationReminderTitle = '今日も練習しましょう！';
  static const String notificationReminderMessage = 'イラスト練習の時間です。少しずつ続けることが上達への近道です🎨';
  static const String notificationComebackTitle = 'しばらく練習が空いていますよ！';
  static const String notificationComebackMessage = 'また少しずつ練習を再開しませんか？あなたのペースで大丈夫です🎨';

  // メリハリタイマー フェーズラベル
  static const String habitPhaseWork  = '作業中';
  static const String habitPhaseBreak = '休憩中';

  // 継続カレンダー
  static const String habitCalendarTitle = '継続カレンダー';
  static const String habitGoToToday = '今日の日付に戻る';

  /// 吹き出し：作業時間未入力時の表示
  static const String habitTooltipNoTime = '0分';

  /// 吹き出し：作業時間の単位サフィックス
  static const String habitTooltipMinSuffix = '分';

  // カレンダー 曜日ラベル（月曜始まり）
  static const List<String> habitWeekdays = [
    '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日',
  ];

  // ── 成長記録 ────────────────────────────────────────────
  static const String growthTitle = '成長記録';
  static const String growthUploadButton = 'ADD';
  static const String growthSnsButton = 'SNS';
  static const String growthDownloadButton = 'DL';

  /// アップロード機能が未実装の間、アップロードボタン押下時に表示する案内
  static const String growthUploadComingSoon = 'アップロード機能は準備中です';

  static const String growthEmptyState = 'まだ画像がありません\nアップロードして練習の記録を始めましょう';

  /// サムネラベルの連番サフィックス（例：'2枚目'）
  static const String growthSerialSuffix = '枚目';

  /// サムネラベルの所要時間サフィックス（例：'3分'）
  static const String growthDurationMinSuffix = '分';

  /// 選択モード時のAppBarタイトル（例：'3件選択中'）
  static const String growthSelectionCountSuffix = '件選択中';

  static const String growthDeleteDialogTitle = '削除しますか？';
  static const String growthDeleteDialogMessageSuffix = '件の画像を削除します。この操作は取り消せません。';
  static const String growthDeleteDialogCancel = 'キャンセル';
  static const String growthDeleteDialogConfirm = '削除';

  /// ダウンロード（端末ギャラリーへの保存）結果のSnackBar文言
  static const String growthDownloadSuccessSuffix = '枚を保存しました';
  static const String growthDownloadFailure = '保存に失敗した画像があります';

  // ── 成長記録：SNS投稿 ──────────────────────────────────
  /// 共有シートに添付するテキスト（Xの投稿本文の初期値になる）
  static const String growthSnsShareText = '#イラスト練習 #成長記録';

  /// 共有シートの起動に失敗した場合のSnackBar文言
  static const String growthSnsShareError = '共有に失敗しました';

  // ── 成長記録：絞込 ────────────────────────────────────────
  // model_list_screen.dart の絞込UI（ラベル・クリア文言）に準拠。
  static const String growthFilterDateLabel = '日付';
  static const String growthFilterDateHint = '日付で絞り込み';
  static const String growthFilterClear = 'フィルターをクリア';
  static const String growthEmptyFiltered = '条件に一致する画像が見つかりません';

  // ── 成長記録：PDF書き出し ──────────────────────────────
  static const String growthPdfButton = 'PDF';

  /// PDF書き出し対象が0件（絞込結果を含む）の場合のSnackBar文言
  static const String growthPdfEmptyError = '書き出せる画像がありません';

  /// PDF生成に失敗した場合のSnackBar文言
  static const String growthPdfGenerateError = 'PDFの作成に失敗しました';

  /// PDF内の各ページ上部に表示するヘッダー文言（表紙ページを除く）
  static const String growthPdfHeaderTitle = 'あなたの成長記録';

  /// PDF表紙に表示するキャッチコピー
  static const String growthPdfCoverCatchCopy = '毎日3分、描けば進む';

  /// PDF表紙に表示する総作業時間のラベル（例：'総作業時間：3時間20分'）
  static const String growthPdfCoverTotalDurationPrefix = '総作業時間：';
  static const String growthPdfCoverTotalDurationHourUnit = '時間';
  static const String growthPdfCoverTotalDurationMinuteUnit = '分';
  static const String growthPdfCoverTotalDurationNone = 'なし';

  /// PDF表紙に表示する対象枚数のサフィックス（例：'全12枚'）
  static const String growthPdfCoverCountPrefix = '全';
  static const String growthPdfCoverCountSuffix = '枚';

  /// PDFファイル名の先頭（例：'成長記録_2026-06-01.pdf'）
  static const String growthPdfFileNamePrefix = '成長記録_';

  // ── 成長記録：イラストを追加画面 ────────────────────────
  static const String growthUploadScreenTitle = 'イラストを追加';
  static const String growthDurationInputLabel = '所要時間（任意）';
  static const String growthDurationInputUnit = '分';
  static const String growthCameraUploadButton = 'カメラで追加';
  static const String growthFileUploadButton = 'ファイルで追加';

  /// プレビューエリア：画像未選択時のプレースホルダー文言
  static const String growthPreviewPlaceholder = '画像が選択されていません';

  /// 確定ボタンのラベル
  static const String growthConfirmButton = '確定';

  /// カメラの起動・撮影に失敗した場合のSnackBar文言
  /// （権限が許可されていない場合や、端末側のエラーを含む）
  static const String growthCameraError = 'カメラを起動できませんでした';

  /// ギャラリーからの画像選択に失敗した場合のSnackBar文言
  static const String growthGalleryError = '画像を選択できませんでした';

  /// 確定（保存）処理に失敗した場合のSnackBar文言
  static const String growthConfirmError = '追加に失敗しました';

  /// 所要時間欄に半角数字以外が入力された状態で確定ボタンが
  /// 押された場合に表示するエラー
  static const String growthDurationInvalidError = '所要時間は半角数字で入力してください';

  /// 【検証用】成長記録メイン画面の上限到達フラグ切り替えボタンのラベル
  /// （現在OFF→ONにする場合）
  static const String growthDebugMaxCountFlagOnButtonLabel =
      '上限到達フラグをONにする(検証用)';

  /// 【検証用】同上（現在ON→OFFにする場合）
  static const String growthDebugMaxCountFlagOffButtonLabel =
      '上限到達フラグをOFFにする(検証用)';

  /// 【検証用】上限到達フラグをONにした直後に表示するメッセージ
  static const String growthDebugMaxCountFlagOnDoneMessage =
      '上限到達フラグをONにしました';

  /// 【検証用】上限到達フラグをOFFにした直後に表示するメッセージ
  static const String growthDebugMaxCountFlagOffDoneMessage =
      '上限到達フラグをOFFにしました';

  // ── 成長記録：アップロード完了画面 ──────────────────────
  static const String growthUploadCompleteTitle = 'アップロードが完了しました';
  static const String growthUploadCompleteBackButton = '成長記録メインへ';

  /// 保持上限枚数にちょうど到達したアップロード完了時のみ表示する
  /// 特別メッセージ（{count} は [GrowthConfig.maxRecordCount] に置換）
  static const String growthUploadCompleteMaxCountMessage =
      'これで{count}枚達成です！\nこれからも成長の記録を続けていきましょう';

  /// 今日の作業時間合計表示のラベル（合計が1分以上の場合のみ表示）
  static const String growthUploadCompleteTodayDurationLabel = '今日の作業時間合計：';

  // ── 成長記録：継続カレンダー（アップロード完了画面に表示） ──
  static const String growthCalendarTitle = '今月の継続カレンダー';

  /// 吹き出し：その日の追加枚数のサフィックス（例：'2枚'）
  static const String growthTooltipCountSuffix = '枚';

  // カレンダー 曜日ラベル（月曜始まり）
  static const List<String> growthWeekdays = [
    '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日',
  ];

  // ── 未実装画面 ──────────────────────────────────────────
  static const String proLessonDescription = 'プロ絵師によるテクニックを学ぶ画面です';
  static const String topicDescription = 'ランダムなお題を生成する画面です';
  static const String habitDescription = '毎日の練習習慣をサポートする画面です';

  // ── 共通ダイアログ ──────────────────────────────────────
  static const String dialogCancel = 'キャンセル';
  static const String dialogDecide = '決定';
  static const String dialogReset = 'リセット';

  // ── Webサンプル版：フィードバックリンク ─────────────────
  /// ホーム画面に表示するリンクラベル
  static const String feedbackLinkLabelHome = 'ご意見・ご感想はこちら';

  /// X秒ドローイング終了画面に表示するリンク上の誘導テキスト
  static const String feedbackLinkPromptDrawingEnd = 'よろしければ使ってみた感想を教えてください';

  /// X秒ドローイング終了画面に表示するリンクラベル
  static const String feedbackLinkLabelDrawingEnd = 'アンケートに答える';

  /// フィードバックフォームのURL
  static const String feedbackUrl =
      'https://docs.google.com/forms/d/1B1-qUU3T6P6Q70VuZJfYdj8WtT_4ZucfD95EMzBmA6M/edit';
}
