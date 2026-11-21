require_relative "lib/tweakdock/version"

Gem::Specification.new do |spec|
  spec.name = "tweakdock"
  spec.version = TweakDock::VERSION
  spec.authors = ["yyjim"]
  spec.summary = "Generates TweakDock experiments from a YAML file."
  spec.description = "Reads an experiments YAML file and writes the TweakDock @Tweak declarations."
  spec.homepage = "https://github.com/yyjim/DockPond/tree/main/gems/tweakdock"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["tweakdock"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
