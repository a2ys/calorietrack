package com.aayush.calorie_app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var sfx: Sfx? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "calorie/sfx").setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> {
                    sfx?.release()
                    sfx = Sfx(applicationContext, call.arguments as List<*>)
                    result.success(null)
                }
                // Fire-and-forget from Dart: no reply is awaited.
                "play" -> {
                    val args = call.arguments as List<*>
                    sfx?.play((args[0] as Number).toInt(), (args[1] as Number).toFloat())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        sfx?.release()
        sfx = null
        super.onDestroy()
    }
}

/// UI sound cues decoded once into a SoundPool, so a play is a single
/// non-blocking call with no per-play setup.
///
/// Sonification usage on the system stream: it never takes audio focus (the
/// user's music keeps playing) and it is silent when the phone is on silent
/// or vibrate.
private class Sfx(private val context: Context, files: List<*>) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val pool = SoundPool.Builder()
        .setMaxStreams(6)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()

    // Index in the Dart Sfx enum -> SoundPool sample id (0 = not loaded).
    private val ids = IntArray(files.size)
    private val ready = BooleanArray(files.size)

    init {
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            val i = ids.indexOf(sampleId)
            if (i >= 0) ready[i] = status == 0
        }
        val loader = FlutterInjector.instance().flutterLoader()
        files.forEachIndexed { i, f ->
            ids[i] = try {
                val key = loader.getLookupKeyForAsset(f as String)
                try {
                    context.assets.openFd(key).use { pool.load(it, 1) }
                } catch (e: Exception) {
                    // Compressed in the APK: SoundPool needs a real file.
                    val out = File(context.cacheDir, "sfx_" + File(f).name)
                    context.assets.open(key).use { input -> out.outputStream().use { input.copyTo(it) } }
                    pool.load(out.path, 1)
                }
            } catch (e: Exception) {
                0
            }
        }
    }

    fun play(i: Int, volume: Float) {
        if (i !in ready.indices || !ready[i]) return
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return
        pool.play(ids[i], volume, volume, 1, 0, 1f)
    }

    fun release() = pool.release()
}
