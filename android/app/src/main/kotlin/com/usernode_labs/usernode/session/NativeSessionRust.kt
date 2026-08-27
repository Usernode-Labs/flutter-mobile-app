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
}
