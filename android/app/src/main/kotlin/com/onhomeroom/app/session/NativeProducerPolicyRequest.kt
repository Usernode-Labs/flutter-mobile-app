package com.onhomeroom.app.session

/** A read-only HTTP request prepared under the vault monitor. */
internal class NativeProducerPolicyRequest(
    private val storedRaw: String,
    private val origin: String,
    private val fetch: () -> NativeHttpResult,
    private val apply: (NativeHttpResult) -> ProducerWakeCredential,
    private val release: () -> Unit,
) {
    fun execute(
        vaultMonitor: Any,
        currentStoredRaw: () -> String?,
        currentOrigin: () -> String?,
    ): ProducerWakeCredential {
        try {
            val response = fetch()
            return synchronized(vaultMonitor) {
                // Even a lease renewal makes this snapshot stale. Retry later
                // rather than apply an older response to newer vault state.
                // Check before *any* response handling, including a 401 delete
                // or the node-epoch-unavailable fallback without a lease receipt.
                if (currentStoredRaw() != storedRaw || currentOrigin() != origin) {
                    ProducerWakeCredential.Uncertain
                } else {
                    apply(response)
                }
            }
        } finally {
            release()
        }
    }
}
