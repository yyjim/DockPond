require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "../lib/tweakdock"

module SpecFiles
  def write_spec(yaml, name: "Experiments.yml")
    @dir ||= Dir.mktmpdir
    path = File.join(@dir, name)
    File.write(path, yaml)
    path
  end

  def load_spec(yaml)
    TweakDock::Spec.load(write_spec(yaml))
  end

  def assert_spec_error(yaml, message)
    error = assert_raises(TweakDock::Error) { load_spec(yaml) }
    assert_includes error.message, message
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir
  end
end
