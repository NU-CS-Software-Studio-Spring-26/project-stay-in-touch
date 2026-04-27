# frozen_string_literal: true

# Custom Overcommit pre-commit hook that runs gitleaks against staged changes
# only (not full history) so commits stay fast.
#
# Gitleaks is a widely-used secret scanner (https://github.com/gitleaks/gitleaks)
# distributed as a single Go binary. Install locally with:
#   macOS:  brew install gitleaks
#   Linux:  see https://github.com/gitleaks/gitleaks#installing
#
# This hook is the local fast-feedback layer. The GitHub Actions workflow runs
# the same gitleaks scan on every pull request as the authoritative backstop.
module Overcommit::Hook::PreCommit
  class Gitleaks < Base
    def run
      result = execute(command)

      return :pass if result.success?

      # gitleaks exits non-zero when secrets are detected OR on a real error.
      # Its findings are written to stdout (and a summary to stderr); surface
      # both so the developer sees exactly what matched.
      output = [result.stdout, result.stderr].reject(&:empty?).join("\n")
      [:fail, "gitleaks detected a potential secret in staged changes:\n\n#{output}"]
    end
  end
end
