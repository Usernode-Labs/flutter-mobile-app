package com.usernode_labs.usernode.session

/**
 * Private Android-to-Rust port for the mobile session composition root.
 *
 * None of these functions is registered on a Flutter channel. The interactive
 * channel below may only transport the one-use proof/claim values produced by
 * Rust; credential plaintext crosses this private JNI boundary exactly once.
 */
internal object NativeSessionRust {
    init {
        System.loadLibrary("usernode")
    }

    external fun nativeInstallProcessAuthority(appSupportDir: String)

    external fun nativeIssueProcessRootProof(): ByteArray

    external fun nativeRevokeProcessRoot()

    external fun nativeStageInstalledCredential(frame: ByteArray): ByteArray

    external fun nativeStageColdInstalledCredentialV1(frame: ByteArray): ByteArray

    /** Advances the exact installed credential's authenticated server lease. */
    external fun nativeApplyCredentialLeaseV1(frame: ByteArray): Boolean

    external fun nativeResolveColdCredentialAbsentV1(expectedRevision: Long): Long

    external fun nativeStageProducerPolicyV1(frame: ByteArray): ByteArray

    /**
     * Validates and fixes one bounded Present ProducerWake request behind a
     * one-use opaque claim. The mutable request is wiped by Rust.
     */
    external fun nativeStageProducerWakeV1(frame: ByteArray): ByteArray

    /** Consumes one exact claim returned by [nativeStageProducerWakeV1]. */
    external fun nativeRunProducerWakeClaimV1(claim: ByteArray): ByteArray

    /** Resolves one bounded definitive-absence ProducerWake request. */
    external fun nativeResolveProducerCredentialAbsentV1(frame: ByteArray): ByteArray

    /** Completes the exact Ready admission retained by the staged wake. */
    external fun nativeCompleteProducerWakeApplyV1(
        exactResponse: ByteArray,
        success: Boolean,
    ): Boolean
}
