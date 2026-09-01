#import "GeneratedPluginRegistrant.h"
#include <stddef.h>
#include <stdint.h>

int32_t usernode_mobile_install_process_authority_v1(
    const uint8_t *utf8_path,
    size_t length);
int32_t usernode_mobile_issue_process_root_proof_v1(
    uint8_t *output,
    size_t capacity);
int32_t usernode_mobile_revoke_process_root_v1(void);
int32_t usernode_mobile_stage_installed_credential_v1(
    uint8_t *mutable_frame,
    size_t length,
    uint8_t *output,
    size_t capacity);
int32_t usernode_mobile_stage_cold_installed_credential_v1(
    uint8_t *mutable_frame,
    size_t length,
    uint8_t *output,
    size_t capacity);
int32_t usernode_mobile_apply_credential_lease_v1(
    const uint8_t *frame,
    size_t length);
int32_t usernode_mobile_resolve_cold_credential_absent_v1(
    uint64_t expected_revision,
    uint64_t *committed_revision);
int32_t usernode_mobile_stage_producer_policy_v1(
    const uint8_t *policy_frame,
    size_t length,
    uint8_t *output,
    size_t capacity);
int32_t usernode_mobile_stage_producer_wake_v1(
    uint8_t *mutable_request,
    size_t length,
    uint8_t *output,
    size_t capacity);
int32_t usernode_mobile_run_producer_wake_claim_v1(
    uint8_t *mutable_claim,
    size_t length,
    uint8_t *output,
    size_t capacity);
int32_t usernode_mobile_resolve_producer_credential_absent_v1(
    uint8_t *mutable_request,
    size_t length,
    uint8_t *output,
    size_t capacity);
int32_t usernode_mobile_complete_producer_wake_apply_v1(
    const uint8_t *response,
    size_t length,
    uint8_t success);
