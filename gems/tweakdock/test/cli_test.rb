require_relative "test_helper"

class CLITest < Minitest::Test
  include SpecFiles

  FIXTURE = File.expand_path("fixtures/GeneratedExperiments.yml", __dir__)

  def run_cli(*arguments)
    out = StringIO.new
    err = StringIO.new
    status = TweakDock::CLI.start(arguments, out: out, err: err)
    [status, out.string, err.string]
  end

  def test_the_swift_test_fixture_is_up_to_date
    status, _, err = run_cli("check", FIXTURE)

    assert_equal 0, status, err
  end

  def test_generate_writes_the_file_and_then_leaves_it
    path = write_spec("output: Out.swift\nexperiments:\n  exp: [A, B]\n")
    output = File.join(@dir, "Out.swift")

    assert_equal [0, "Wrote #{output}.\n", ""], run_cli("generate", path)
    assert_includes File.read(output), "static var exp: Exp"
    assert_equal [0, "#{output} is up to date.\n", ""], run_cli("generate", path)
  end

  def test_check_fails_when_the_file_is_missing_or_changed
    path = write_spec("output: Out.swift\nexperiments:\n  exp: [A, B]\n")
    output = File.join(@dir, "Out.swift")

    status, _, err = run_cli("check", path)
    assert_equal 1, status
    assert_includes err, "#{output} is not up to date. Run: tweakdock generate #{path}"

    run_cli("generate", path)
    File.write(output, File.read(output) + "// edited\n")
    assert_equal 1, run_cli("check", path).first
    assert_equal false, File.read(output).empty?
  end

  def test_continues_after_a_file_with_an_error
    broken = write_spec("output: Broken.swift\nexperiments:\n  exp: [A, A]\n", name: "Broken.yml")
    valid = write_spec("output: Valid.swift\nexperiments:\n  exp: [A, B]\n", name: "Valid.yml")

    status, out, err = run_cli("generate", broken, valid)
    assert_equal 1, status
    assert_includes err, "duplicate variants A"
    assert_includes out, "Wrote #{File.join(@dir, 'Valid.swift')}."
  end

  def test_reports_spec_errors
    path = write_spec("output: Out.swift\nexperiments:\n  exp: [A, A]\n")

    status, _, err = run_cli("generate", path)
    assert_equal 1, status
    assert_includes err, "error: #{path}: exp: remove the duplicate variants A."
  end

  def test_shows_the_usage
    assert_equal 0, run_cli.first
    assert_equal 2, run_cli("build").first
    assert_equal 2, run_cli("generate").first
    assert_equal [0, "#{TweakDock::VERSION}\n", ""], run_cli("--version")
  end
end
