package com.lazgram.comic_laz

import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * 通知の許可が後から取り消されたとき、巻のダウンロードの foreground 実行を切る（#10）。
 *
 * foreground 実行は、通知の許可があるときだけ Dart 側が
 * `background_downloader` に設定する（`transfer_mapping.dart` の
 * `foregroundModeFor`）。パッケージはその値を SharedPreferences に保存し、
 * ワーカーは起動のたびに**許可を見ずに**その値だけで foreground にするか決める。
 * 設定アプリで許可を取り消されると、保存済みの「always」のまま走り、通知を
 * 出せないので foreground にも移れず、9 分の自己一時停止も起きないまま
 * WorkManager の 10 分の上限で止められる（長い巻が毎回失敗する）。
 *
 * アプリが閉じている間は Dart が動かないので、プロセスの起動時にここで直す。
 * 実行時の権限を取り消すと OS はアプリのプロセスを殺すので、次のワーカーは
 * 必ず新しいプロセスで、この onCreate を通ってから走る。アプリが開いている
 * 間の取り消しは、前面に戻ったときに Dart 側が合わせ直す
 * （`ArchiveTransport.refreshForegroundMode`）。
 *
 * 書くのはパッケージの `Config.never` と同じキー・値（`BDPlugin.kt` の
 * `keyConfigForegroundFileSize` に -1）。保存先はパッケージと同じ既定の
 * SharedPreferences（androidx.preference の `getDefaultSharedPreferences` は
 * `<パッケージ名>_preferences` / MODE_PRIVATE）。androidx.preference は
 * アプリから参照できないので名前を直接組み立てる。
 */
class ComicLazApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        disableForegroundTransfersWithoutNotificationPermission()
    }

    private fun disableForegroundTransfersWithoutNotificationPermission() {
        // 通知の実行時の許可は Android 13（API 33）から。それより前は
        // foreground の通知を出せるので、そのままでよい。
        if (Build.VERSION.SDK_INT < 33) return
        if (checkSelfPermission(POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            return
        }
        getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
            .edit()
            .putInt(FOREGROUND_FILE_SIZE_KEY, FOREGROUND_NEVER)
            .apply()
    }

    private companion object {
        const val POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"

        /** `BDPlugin.keyConfigForegroundFileSize`（background_downloader 9.6.3）。 */
        const val FOREGROUND_FILE_SIZE_KEY =
            "com.bbflight.background_downloader.config.foregroundFileSize"

        /** `Config.never`（ネイティブ側では -1）。 */
        const val FOREGROUND_NEVER = -1
    }
}
