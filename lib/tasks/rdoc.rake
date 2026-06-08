# Generates HTML API documentation from the RDoc-style comments throughout
# app/ and lib/ (models, controllers, services, helpers, mailers, jobs).
#
#   rails rdoc        # generate into doc/
#   rails clobber_rdoc  # remove the generated doc/ directory
#
# Output lands in doc/ (gitignored). RDoc is a dev/test-only dependency, so the
# require is guarded — running `rails rdoc` in an environment without the gem
# (e.g. production) fails with a clear message instead of a LoadError on boot.
begin
  require "rdoc/task"

  RDoc::Task.new do |rdoc|
    rdoc.rdoc_dir = "doc"
    rdoc.title    = "Serendipity API documentation"
    rdoc.main     = "README.md"
    rdoc.rdoc_files.include("README.md", "app/**/*.rb", "lib/**/*.rb")
  end
rescue LoadError
  desc "Generate RDoc (unavailable: the rdoc gem is not installed in this environment)"
  task :rdoc do
    abort "The rdoc gem is not available. Install the development gems with `bundle install`."
  end
end
