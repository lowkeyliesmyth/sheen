require "spec"
require "../src/sheen"

# Spec helper for creating Foundation::MockEnv objects from a *hash*.
# Used for mocking env var behavior.
def mock_env(hash)
  Foundation::MockEnv.new(hash)
end
