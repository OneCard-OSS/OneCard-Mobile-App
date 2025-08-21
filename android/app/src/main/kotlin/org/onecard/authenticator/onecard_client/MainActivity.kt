package org.onecard.authenticator.onecard_client

import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "onecard_client/deeplink"
    private var methodChannel: MethodChannel? = null
    private var nfcAdapter: NfcAdapter? = null
    private var pendingIntent: PendingIntent? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // NFC 어댑터 초기화
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        
        // PendingIntent 생성 (NFC 태그 감지 시 이 액티비티로 이동)
        pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_MUTABLE
        )
        
        // MethodChannel 설정
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            methodChannel = MethodChannel(messenger, CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getInitialLink" -> {
                            val initialLink = getInitialLink()
                            result.success(initialLink)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // NFC Reader Mode 활성화 (다른 NFC 앱 실행 방지)
        nfcAdapter?.let { adapter ->
            if (adapter.isEnabled) {
                adapter.enableReaderMode(
                    this,
                    { tag -> 
                        // NFC 태그가 감지되었지만 Flutter NFC Kit에서 처리하도록 함
                        // 여기서는 다른 앱이 실행되지 않도록 하는 역할만 함
                    },
                    NfcAdapter.FLAG_READER_NFC_A or 
                    NfcAdapter.FLAG_READER_NFC_B or 
                    NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                    NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS,
                    null
                )
            }
        }
    }

    override fun onPause() {
        super.onPause()
        // NFC Reader Mode 비활성화
        nfcAdapter?.disableReaderMode(this)
    }

    private fun getInitialLink(): String? {
        return intent?.data?.toString()
    }

    private fun handleIntent(intent: Intent) {
        val data: Uri? = intent.data
        if (data != null && data.scheme == "onecard" && data.host == "auth") {
            methodChannel?.invokeMethod("onNewLink", data.toString())
        }
    }
}
