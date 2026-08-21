#import "GeneratedPluginRegistrant.h"

#include <stdbool.h>
#include <stdint.h>

char *usernode_session_authority_admission_json(const char *directory);
bool usernode_session_authority_admits_background_runtime(
    const char *directory,
    const char *session_id,
    uint64_t runtime_generation
);
void usernode_session_authority_string_free(char *value);
