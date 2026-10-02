import java.io.StringReader
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// リリース署名（#16）。鍵の情報は android/key.properties（git 管理外）から読む。
// 作り方と書式は README の「リリース署名」と android/key.properties.example。
//
// key.properties が無いときも release ビルドは通す（手元で R8 無しの release の
// 挙動を確かめたいだけのときに鍵を要求しないため）。その場合は debug 鍵で署名し、
// 警告を出す。CI のリリースビルドは COMIC_LAZ_REQUIRE_RELEASE_SIGNING=true を渡し、
// 鍵が無ければ失敗させる（debug 署名の APK を「リリース」として配らないため。
// 署名鍵が違うと上書きインストールできず、入れ直し = ダウンロード済みの巻が消える）。
val keystorePropertiesFile: File = rootProject.file("key.properties")
val hasReleaseKeystore: Boolean = keystorePropertiesFile.exists()
val keystoreProperties: Properties =
    Properties().apply {
        if (hasReleaseKeystore) {
            // UTF-8 で読む（Properties.load(InputStream) は ISO-8859-1 で、日本語の
            // ユーザー名を含むパスが化ける）。メモ帳が付ける BOM も落とす（付いたままだと
            // 先頭のキーが BOM 付きの storeFile になり、見つからないと言われる）。
            val text = keystorePropertiesFile.readText(Charsets.UTF_8).removePrefix(Char(0xFEFF).toString())
            load(StringReader(text))
        }
    }
val requireReleaseSigning: Boolean =
    System.getenv("COMIC_LAZ_REQUIRE_RELEASE_SIGNING") == "true"

// 警告・必須キーの確認・鍵ファイルの存在確認は release を作るときだけにする
// （debug ビルドのたびに鍵の無い警告を出したり、鍵の置き場が無い端末や書きかけの
// key.properties で debug を壊したりしないため）。
// `assemble` / `build` / `bundle` のように全バリアントを作るタスクも release を含む
// （名前に Release が無くても確認を飛ばすと、書きかけの key.properties が署名の
// 段になって分かりにくいエラーで落ちる）。
val isReleaseBuildRequested: Boolean =
    gradle.startParameter.taskNames.any { task ->
        val name = task.substringAfterLast(':')
        name.contains("Release", ignoreCase = true) ||
            name in setOf("assemble", "build", "bundle")
    }

// パスワードは前後の空白を削らない（keytool は末尾に空白のあるパスワードも受け付ける。
// 削ると別のパスワードとして渡り、「password was incorrect」としか言われず原因を
// 追えない）。パスと別名は貼り付けで紛れた空白を落とす。
val untrimmedKeystoreKeys: Set<String> = setOf("storePassword", "keyPassword")

fun keystoreProperty(key: String): String? {
    val raw = keystoreProperties.getProperty(key) ?: return null
    val value = if (key in untrimmedKeystoreKeys) raw else raw.trim()
    return value.takeIf { it.isNotEmpty() }
}

fun requiredKeystoreProperty(key: String): String =
    keystoreProperty(key)
        ?: throw GradleException(
            "android/key.properties に $key がありません。" +
                "android/key.properties.example と README の「リリース署名」を参照してください。",
        )

// release のときだけ必須にする（理由は isReleaseBuildRequested の上）。
fun releaseKeystoreProperty(key: String): String? =
    if (isReleaseBuildRequested) requiredKeystoreProperty(key) else keystoreProperty(key)

android {
    namespace = "com.lazgram.comic_laz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications（#14）が java.time などの新しい API を使うため、
        // 古い Android（minSdk 24）向けにライブラリの desugaring を有効にする。
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 変えない（#16）。変えると別アプリとして入り、ダウンロード済みの巻・
        // 未送信の進捗を引き継げない。
        applicationId = "com.lazgram.comic_laz"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Flutter の既定（現在 24 = Android 7.0）に従う（#16）。数値で固定すると、
        // Flutter が既定を上げたときにエンジンの要求と食い違ってビルドが壊れるため。
        // 使っているプラグインの要求もこれ以下（上回ると MinSdkCheck でビルドが止まる）。
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // pubspec.yaml の version（CI では --build-name / --build-number で上書き）。
        // バージョニングの方針は README の「バージョニング」。
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // ホームに出る名前。開発版は buildTypes.debug で上書きする。
        manifestPlaceholders["appName"] = "Comic LAZ"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                // 相対パスは android/ から（key.properties と同じ場所が起点の方が
                // 迷わないため。android/app からではない）。
                val storeFilePath = releaseKeystoreProperty("storeFile")
                if (storeFilePath != null) {
                    val keystore = rootProject.file(storeFilePath)
                    if (isReleaseBuildRequested && !keystore.isFile) {
                        throw GradleException(
                            "key.properties の storeFile が見つかりません: ${keystore.absolutePath}",
                        )
                    }
                    storeFile = keystore
                }
                storePassword = releaseKeystoreProperty("storePassword")
                keyAlias = releaseKeystoreProperty("keyAlias")
                keyPassword = releaseKeystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // 開発版は別アプリとして入れる（#16）。同じアプリ ID のままだと、署名の違う
        // リリース版と開発版を切り替えるたびにアンインストールが要り、普段使いの
        // リリース版のダウンロード済みの巻が消える。ID と名前を分けて並べて置く。
        debug {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appName"] = "Comic LAZ Dev"
        }
        release {
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    if (requireReleaseSigning) {
                        throw GradleException(
                            "COMIC_LAZ_REQUIRE_RELEASE_SIGNING=true ですが android/key.properties が" +
                                "ありません。debug 鍵で署名した APK をリリースとして作らないため止めます。",
                        )
                    }
                    if (isReleaseBuildRequested) {
                        logger.warn(
                            "警告: android/key.properties が無いため、release ビルドを debug 鍵で署名します。" +
                                "この APK は手元の確認用です（リリース署名の APK とは上書きインストールできません）。",
                        )
                    }
                    signingConfigs.getByName("debug")
                }

            // R8（コード縮小・難読化）とリソース縮小は切る（Flutter の既定は ON）。
            // background_downloader は consumer の keep ルールを持たず、kotlinx.serialization
            // や WorkManager の Worker をクラス名で引くので、R8 で消える / 名前が変わると
            // release だけで転送が壊れる。普段確かめている debug は R8 を通らないため、
            // 実機で気づくまで分からない。縮むのは Java / Kotlin 部分の数 MB だけで、
            // APK の大半（Flutter エンジンと Dart の AOT コード）は変わらないので、
            // 直接配布の個人用途では割に合わない。
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // compileOptions.isCoreLibraryDesugaringEnabled（flutter_local_notifications の要求）。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// プッシュ通知の Firebase 設定（#14）。android/app/google-services.json は
// リポジトリに置かない（公開リポジトリのため。置き方は README の「プッシュ通知」）。
// ファイルがあるときだけ google-services プラグインを適用し、無ければ Firebase の
// 設定が無いまま作る（アプリはプッシュ通知だけ「使えない」と表示して動く）。
// CI や設定を持たない手元のビルドを壊さないため。
val googleServicesFile: File = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
    // 設定ファイルに載っていないアプリ ID の版は、プラグインが「一致するクライアントが
    // 無い」でビルドを止める。版ごとに確かめ、載っていない版だけ処理を外す（その版では
    // プッシュ通知が「使えない」になる。ビルドは止めない）。
    // - 開発版（debug）は applicationIdSuffix = ".debug" で別のアプリ ID。
    // - profile は Flutter のプラグインが debug の設定より前に initWith(debug) で作るので
    //   接尾辞が付かず、release と同じ ID。
    val googleServicesJson = googleServicesFile.readText(Charsets.UTF_8)
    val variantsByApplicationId =
        mapOf(
            "com.lazgram.comic_laz" to listOf("Release", "Profile"),
            "com.lazgram.comic_laz.debug" to listOf("Debug"),
        )
    for ((applicationId, variants) in variantsByApplicationId) {
        if (googleServicesJson.contains("\"$applicationId\"")) continue
        logger.lifecycle(
            "google-services.json に $applicationId が無いため、" +
                "${variants.joinToString(" / ")} ではプッシュ通知を無効にします。",
        )
        val taskNames = variants.map { "process${it}GoogleServices" }.toSet()
        tasks.matching { it.name in taskNames }.configureEach {
            enabled = false
        }
    }
}
